#!/usr/bin/env python3
"""Generate src/internal/vectors.mbt from a reference implementation.

The graphs are fixed here, the answers come from NetworkX 3.7, and the emitted file is what the
tests replay. Nothing about the library is decided here: this script only records what an
independent implementation answers on the same input, so a divergence shows up as a failing test
rather than as a quiet difference of opinion. Distances are `-1` where the reference found no
route, which is outside the range of any weight these graphs carry.

Run from the repository root:  python3 scripts/gen_vectors.py
"""

from __future__ import annotations

import itertools
import math
import sys
import warnings
from pathlib import Path

import numpy as np
import networkx as nx
from networkx.algorithms import clique as nxc
from networkx.algorithms import chordal as nxcord
from networkx.algorithms import community as nxcmm
from networkx.algorithms import graphical as nxf
from networkx.algorithms import link_prediction as nx_link
from networkx.algorithms import richclub as nx_rc
from networkx.algorithms import structuralholes as nx_holes
from networkx.algorithms import triads as nx_triads
from networkx.readwrite import graph6 as nx_g6

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "src" / "internal" / "vectors.mbt"

# (name, directed, nodes, arcs as (from, to, weight))
GRAPHS = [
    ("path4", False, 4, [(0, 1, 1.0), (1, 2, 1.0), (2, 3, 1.0)]),
    (
        "square-diagonal",
        False,
        4,
        [(0, 1, 2.0), (1, 2, 3.0), (2, 3, 4.0), (3, 0, 5.0), (0, 2, 1.0)],
    ),
    ("star5", False, 5, [(0, 1, 1.0), (0, 2, 1.0), (0, 3, 1.0), (0, 4, 1.0)]),
    ("two-pieces", False, 6, [(0, 1, 1.0), (1, 2, 2.0), (3, 4, 1.0), (4, 5, 1.0)]),
    (
        "directed-diamond",
        True,
        4,
        [(0, 1, 1.0), (0, 2, 4.0), (1, 2, 2.0), (1, 3, 6.0), (2, 3, 3.0)],
    ),
    ("cycle5", True, 5, [(0, 1, 1.0), (1, 2, 1.0), (2, 3, 1.0), (3, 4, 1.0), (4, 0, 1.0)]),
    (
        "negative-dag",
        True,
        4,
        [(0, 1, -2.0), (1, 2, 3.0), (0, 2, 5.0), (2, 3, 1.0)],
    ),
]

# A directed graph with no cycle, and a directed graph with one, for the dag family.
DAGS = [
    ("dag3", [(0, 1), (0, 2), (1, 2)]),
    ("diamond-dag", [(0, 1), (0, 2), (1, 3), (2, 3)]),
]

# Shapes the cycle family needs and the other families do not: graphs whose arcs balance,
# graphs whose arcs leave one side, and a ring whose arc home is longer than the triangle
# the undirected shadow carries. A reading by degree parity answers the wrong way on the
# first two, and an undirected reading answers three on the last.
CYCLE_SHAPES = [
    ("directed-ring3", True, 3, [(0, 1, 1.0), (1, 2, 1.0), (2, 0, 1.0)]),
    ("directed-fan", True, 3, [(0, 1, 1.0), (0, 2, 1.0)]),
    ("directed-two-rings", True, 5, [(0, 1, 1.0), (1, 2, 1.0), (2, 0, 1.0), (0, 3, 1.0), (3, 4, 1.0), (4, 0, 1.0)]),
    ("directed-split-pairs", True, 4, [(0, 1, 1.0), (1, 0, 1.0), (2, 3, 1.0), (3, 2, 1.0)]),
    (
        "directed-chord4",
        True,
        6,
        [(0, 1, 1.0), (1, 2, 1.0), (2, 3, 1.0), (3, 4, 1.0), (4, 0, 1.0), (0, 2, 1.0)],
    ),
    ("directed-loop", True, 2, [(0, 0, 1.0), (0, 1, 1.0)]),
    ("directed-in-star", True, 4, [(1, 0, 1.0), (2, 0, 1.0), (3, 0, 1.0)]),
    ("directed-out-star", True, 4, [(0, 1, 1.0), (0, 2, 1.0), (0, 3, 1.0)]),
]

# Graphs for the sparse6 text: the small shapes every format has to carry, and node counts
# on either side of the header's two widenings, where a count needs four bytes and then
# eight. The last three carry a repeated edge and a self loop, which the format allows and
# a graph of this library can hold.
SPARSE6_SHAPES = [
    ("sparse6-path", 4, False, [(0, 1), (1, 2), (2, 3)]),
    ("sparse6-square", 4, False, [(0, 1), (1, 2), (2, 3), (3, 0)]),
    ("sparse6-empty", 0, False, []),
    ("sparse6-one-loop", 1, False, [(0, 0)]),
    ("sparse6-pair", 2, False, [(0, 1)]),
    ("sparse6-width-3", 8, False, [(0, 1), (1, 2), (5, 6)]),
    ("sparse6-width-4", 16, False, [(0, 1), (7, 15), (14, 15)]),
    ("sparse6-width-5", 32, False, [(0, 1), (30, 31)]),
    ("sparse6-filler-4", 4, False, [(2, 1)]),
    ("sparse6-filler-8", 8, False, [(6, 5)]),
    ("sparse6-filler-16", 16, False, [(14, 13)]),
    ("sparse6-count-63", 63, False, [(0, 1), (1, 2), (2, 3), (62, 61)]),
    ("sparse6-count-64", 64, False, [(0, 1), (1, 2), (2, 3), (63, 62)]),
    ("sparse6-count-300", 300, False, [(0, 1), (1, 2), (299, 3), (150, 170), (299, 0)]),
    ("sparse6-repeated", 3, True, [(0, 1), (0, 1), (1, 2)]),
    ("sparse6-loops", 4, True, [(0, 0), (1, 1), (2, 3)]),
    ("sparse6-mixed", 5, True, [(0, 0), (0, 1), (0, 1), (1, 2), (4, 3)]),
]

# Directed pairs for the isomorphism family: two graphs over the same node count.
ISO_PAIRS = [
    ("same-path", False, [(0, 1), (1, 2)], [(0, 1), (1, 2)]),
    ("path-vs-star", False, [(0, 1), (1, 2), (2, 3)], [(0, 1), (0, 2), (0, 3)]),
    ("same-cycle", False, [(0, 1), (1, 2), (2, 3), (3, 0)], [(0, 2), (1, 3), (2, 1), (3, 0)]),
]

# Graphs with isolated nodes, so the vertex cover (the non-isolated vertices) is non-trivial.
APPROX_GRAPHS = [
    ("with-isolates", False, 5, [(0, 1, 1.0), (2, 3, 1.0)]),
    ("edge-and-isolate", False, 3, [(0, 1, 1.0)]),
    ("triangle-plus-isolate", False, 4, [(0, 1, 1.0), (1, 2, 1.0), (2, 0, 1.0)]),
]

# Small digraphs that between them hold every triad shape worth counting: a tournament, a
# cycle with a chord, two nodes that point at each other, and both kinds of star.
TRIAD_GRAPHS = [
    ("tournament4", 4, [(0, 1), (1, 2), (2, 3), (3, 0), (0, 2), (1, 3)]),
    ("cycle-chord", 5, [(0, 1), (1, 2), (2, 3), (3, 4), (4, 0), (0, 2)]),
    ("mutual-chain", 4, [(0, 1), (1, 0), (1, 2), (2, 1), (2, 3)]),
    ("star-out", 5, [(0, 1), (0, 2), (0, 3), (0, 4)]),
    ("star-in", 5, [(1, 0), (2, 0), (3, 0), (4, 0)]),
    ("pieces", 6, [(0, 1), (2, 3), (3, 4)]),
]

# Undirected graphs with a hub, so the rich-club coefficient has a club to measure.
RICH_GRAPHS = [
    (
        "clique-and-leaves",
        8,
        [(0, 1), (0, 2), (1, 2), (0, 3), (1, 3), (0, 4), (0, 5), (0, 6), (0, 7)],
    ),
    (
        "two-hubs",
        7,
        [(0, 1), (0, 2), (1, 2), (2, 3), (3, 4), (4, 5), (3, 5), (5, 6)],
    ),
]

# Small graphs for the exact tour: complete enough to have choices, plus one sparse graph
# where the tour has to hop through nodes it is not visiting.
TSP_GRAPHS = [
    (
        "tsp4",
        4,
        [(0, 1, 2.0), (0, 2, 9.0), (0, 3, 10.0), (1, 2, 6.0), (1, 3, 4.0), (2, 3, 3.0)],
    ),
    (
        "tsp5",
        5,
        [
            (0, 1, 3.0),
            (0, 2, 8.0),
            (0, 3, 6.0),
            (0, 4, 7.0),
            (1, 2, 5.0),
            (1, 3, 9.0),
            (1, 4, 4.0),
            (2, 3, 2.0),
            (2, 4, 8.0),
            (3, 4, 5.0),
        ],
    ),
    (
        "tsp6",
        6,
        [
            (0, 1, 4.0),
            (0, 2, 7.0),
            (0, 3, 3.0),
            (0, 4, 9.0),
            (0, 5, 6.0),
            (1, 2, 5.0),
            (1, 3, 8.0),
            (1, 4, 6.0),
            (1, 5, 7.0),
            (2, 3, 4.0),
            (2, 4, 3.0),
            (2, 5, 9.0),
            (3, 4, 6.0),
            (3, 5, 5.0),
            (4, 5, 2.0),
        ],
    ),
    ("line4", 4, [(0, 1, 5.0), (1, 2, 1.0), (2, 3, 2.0)]),
]

SOURCES = [0, 2]

# The length of a diagonal step: the diagonal of a unit square.
DIAGONAL = math.sqrt(2.0)

# Boards for the grid family, as (name, width, height, blocked cells, start, end), with the
# cells given as (x, y) and the ends as cells too. A diagonal step is allowed into any free
# diagonal cell, which is the board the searches here walk: the corner of a blocked cell is not
# a doorway only in the sense that the cell itself is blocked.
BOARDS = [
    ("open-3x3", 3, 3, [], (0, 0), (2, 2)),
    ("open-9x9", 9, 9, [], (0, 0), (8, 8)),
    ("single-cell", 1, 1, [], (0, 0), (0, 0)),
    ("single-row", 5, 1, [], (0, 0), (4, 0)),
    ("single-column", 1, 4, [], (0, 0), (0, 3)),
    ("wall-with-gap", 5, 5, [(2, 0), (2, 1), (2, 3), (2, 4)], (0, 2), (4, 2)),
    ("wall-no-gap", 5, 5, [(2, y) for y in range(5)], (0, 2), (4, 2)),
    ("detour-around-wall", 6, 6, [(3, y) for y in range(5)], (0, 3), (5, 3)),
    ("diagonal-blocked", 3, 3, [(1, 1)], (0, 0), (2, 2)),
    ("u-trap", 5, 5, [(1, 1), (2, 1), (3, 1), (1, 2), (3, 2), (1, 3), (2, 3), (3, 3)], (2, 0), (2, 4)),
    ("ring", 5, 5, [(x, y) for y in range(1, 4) for x in range(1, 4)], (0, 0), (4, 4)),
    ("two-islands", 4, 4, [(3, y) for y in range(4)], (0, 0), (0, 3)),
    ("blocked-end", 4, 4, [(3, 3)], (0, 0), (3, 3)),
    ("blocked-start", 4, 4, [(0, 0)], (0, 0), (3, 3)),
    ("goal-is-the-start", 4, 4, [(1, 1)], (2, 2), (2, 2)),
    ("corridor", 8, 3, [(x, y) for x in range(8) for y in (0, 2)], (0, 1), (7, 1)),
    ("comb", 7, 7, [(x, y) for x in (1, 3, 5) for y in range(1, 7)], (0, 0), (6, 0)),
    (
        "maze-7x7",
        7,
        7,
        [
            (1, 1), (2, 1), (3, 1), (5, 1),
            (3, 2), (3, 3), (1, 3), (2, 3),
            (1, 4), (5, 4), (5, 5), (1, 5),
            (2, 5), (3, 5), (4, 5),
        ],
        (0, 0),
        (6, 6),
    ),
]

# Flow networks for the incremental family, as (name, nodes, source, sink, edges, changes),
# where an edge is (from, to, capacity) and a change is (edge number, capacity added). A change
# only ever adds capacity: reducing one would leave the flow that is already on it invalid.
FLOW_NETWORKS = [
    (
        "two-paths",
        4,
        0,
        3,
        [(0, 1, 3.0), (1, 3, 2.0), (0, 2, 2.0), (2, 3, 4.0), (1, 2, 1.0)],
        [(1, 3.0), (3, 2.0), (0, 4.0)],
    ),
    (
        "diamond",
        4,
        0,
        3,
        [(0, 1, 2.0), (0, 2, 2.0), (1, 2, 1.0), (1, 3, 1.0), (2, 3, 2.0)],
        [(3, 2.0), (0, 1.0)],
    ),
    ("line", 3, 0, 2, [(0, 1, 2.0), (1, 2, 3.0)], [(0, 5.0)]),
    ("no-route", 4, 0, 3, [(0, 1, 5.0), (2, 3, 5.0)], [(0, 1.0)]),
    (
        "fan",
        6,
        0,
        5,
        [(0, i, 2.0) for i in range(1, 5)] + [(i, 5, 2.0) for i in range(1, 5)],
        [(3, 2.0), (7, 2.0), (0, 3.0)],
    ),
    (
        "bipartite",
        7,
        0,
        6,
        [
            (0, 1, 4.0), (0, 2, 3.0), (0, 3, 2.0),
            (1, 4, 2.0), (2, 4, 2.0), (3, 4, 2.0),
            (1, 5, 2.0), (2, 5, 3.0), (3, 5, 1.0),
            (4, 6, 3.0), (5, 6, 3.0),
        ],
        [(9, 2.0), (5, 2.0), (0, 2.0)],
    ),
    (
        "two-inputs",
        5,
        0,
        4,
        [(0, 1, 3.0), (1, 4, 3.0), (2, 1, 2.0), (2, 3, 2.0), (3, 4, 2.0)],
        [(1, 4.0), (3, 1.0)],
    ),
]

# Cost flow networks, as (name, nodes, source, sink, edges), an edge being (from, to, capacity,
# cost per unit). Capacities are whole numbers so that the price of every whole unit of flow is
# a number the reference can state.
COST_NETWORKS = [
    (
        "two-routes",
        4,
        0,
        3,
        [(0, 1, 2.0, 1.0), (1, 3, 2.0, 1.0), (0, 2, 2.0, 3.0), (2, 3, 2.0, 1.0)],
    ),
    (
        "shared-middle",
        4,
        0,
        3,
        [(0, 1, 3.0, 2.0), (0, 2, 1.0, 1.0), (1, 3, 4.0, 1.0), (2, 3, 2.0, 4.0)],
    ),
    ("single-route", 3, 0, 2, [(0, 1, 4.0, 5.0), (1, 2, 2.0, 3.0)]),
    (
        "ladder",
        6,
        0,
        5,
        [
            (0, 1, 2.0, 1.0), (0, 2, 2.0, 4.0),
            (1, 2, 1.0, 1.0), (2, 3, 3.0, 1.0),
            (1, 4, 2.0, 2.0), (3, 4, 2.0, 2.0),
            (4, 5, 4.0, 1.0), (3, 5, 2.0, 5.0),
        ],
    ),
]



def build(name: str, directed: bool, nodes: int, arcs) -> nx.Graph:
    g = nx.DiGraph() if directed else nx.Graph()
    g.add_nodes_from(range(nodes))
    for a, b, w in arcs:
        g.add_edge(a, b, weight=w)
    return g


def num(value: float) -> str:
    """A Double literal that reads the same in MoonBit and in Python."""
    if value == float("inf"):
        return "1.0e9"
    text = f"{value:.6f}".rstrip("0").rstrip(".")
    if text in ("", "-0"):
        text = "0"
    if "." not in text:
        text = text + ".0"
    return text


def graph_literal(name: str, directed: bool, nodes: int, arcs) -> str:
    parts = ", ".join(f"({a}, {b}, {num(w)})" for a, b, w in arcs)
    return (
        f'{{ name: "{name}", nodes: {nodes}, directed: {str(directed).lower()}, '
        f"arcs: [{parts}] }}"
    )


def edge_list_of(g) -> str:
    """A 0-indexed edge list, one `a b weight` per line, in sorted order."""
    lines = []
    for a, b in sorted(g.edges()):
        lines.append(f"{a} {b} 1")
    return "\n".join(lines) + ("\n" if lines else "")


def adjacency_of(g) -> str:
    """A 0-indexed adjacency list, one `node n1 n2 ...` per line."""
    lines = []
    if g.is_directed():
        prefix = "# directed\n"
        for node in sorted(g.nodes()):
            nbrs = " ".join(str(m) for m in g.successors(node))
            lines.append(f"{node} {nbrs}".rstrip())
        return prefix + "\n".join(lines) + ("\n" if lines else "")
    for node in sorted(g.nodes()):
        nbrs = " ".join(str(m) for m in g.neighbors(node) if m >= node)
        lines.append(f"{node} {nbrs}".rstrip())
    return "\n".join(lines) + ("\n" if lines else "")


def text_literal(text: str) -> str:
    """A MoonBit string literal for a possibly multi-line text, with the newlines and
    quotes escaped so it reads back to the same bytes."""
    escaped = text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return '"' + escaped + '"'


def sparse6_written(count: int, edges) -> str:
    """The sparse6 text of a graph, written from the format's description.

    This is the generator's own reading of the format — the header widths, the `k` bits a
    node number takes, the run-length flag, the filler — so a text it agrees with NetworkX
    on is a text two independent readings agree on. The one place the description and the
    reference implementation part company is which filler to use before the last node; the
    condition here is the reference's, which is the one the library matches.
    """
    if count <= 62:
        header = [count]
    elif count <= 258047:
        header = [63, (count >> 12) & 0x3F, (count >> 6) & 0x3F, count & 0x3F]
    else:
        header = [
            63,
            63,
            (count >> 30) & 0x3F,
            (count >> 24) & 0x3F,
            (count >> 18) & 0x3F,
            (count >> 12) & 0x3F,
            (count >> 6) & 0x3F,
            count & 0x3F,
        ]
    width = 1
    while (1 << width) < count:
        width += 1

    def enc(value: int) -> list[int]:
        return [(value >> (width - 1 - i)) & 1 for i in range(width)]

    bits: list[int] = []
    current = 0
    for high, low in sorted((max(a, b), min(a, b)) for a, b in edges):
        if high == current:
            bits.append(0)
            bits += enc(low)
        elif high == current + 1:
            current = high
            bits.append(1)
            bits += enc(low)
        else:
            current = high
            bits.append(1)
            bits += enc(high)
            bits.append(0)
            bits += enc(low)
    padding = (-len(bits)) % 6
    if width < 6 and count == (1 << width) and padding >= width and current < count - 1:
        bits.append(0)
        bits += [1] * (padding - 1)
    else:
        bits += [1] * padding
    body = [
        sum(bits[i + j] << (5 - j) for j in range(6))
        for i in range(0, len(bits), 6)
    ]
    return ":" + "".join(chr(63 + value) for value in header + body)


def gale_ryser_pairs(pairs) -> bool:
    """The reference reading: two sequences are digraphical when some 0-1 matrix has them
    as row and column sums, which the Gale-Ryser criterion decides."""
    outs = sorted((o for o, i in pairs), reverse=True)
    ins = sorted((i for o, i in pairs), reverse=True)
    if sum(outs) != sum(ins):
        return False
    n = len(outs)
    for k in range(1, n + 1):
        if sum(outs[:k]) > sum(min(v, k) for v in ins):
            return False
    return True


def multigraphical(degrees) -> bool:
    """A sequence is multigraphical when its total is even and no entry exceeds the rest."""
    if any(d < 0 for d in degrees):
        return False
    total = sum(degrees)
    if total % 2:
        return False
    if not degrees:
        return True
    highest = max(degrees)
    return highest <= total - highest


def chromatic_exact(g) -> int:
    """The exact chromatic number for the small graphs here, by testing every k-colouring."""
    import itertools

    n = g.number_of_nodes()
    if n == 0:
        return 0
    edges = [(a, b) for a, b in g.edges()]

    def ok(k):
        for assign in itertools.product(range(k), repeat=n):
            for a, b in edges:
                if assign[a] == assign[b]:
                    break
            else:
                return True
        return False

    for k in range(1, n + 1):
        if ok(k):
            return k
    return n


def board_graph(width: int, height: int, blocked) -> nx.Graph:
    """A board as a graph: a free cell joins the eight free cells around it.

    A diagonal step is allowed into any free diagonal cell, whether or not the two cells it
    passes are free — that is the board the searches here walk, and the reason a board is not
    the same thing as a map with walls of no width.
    """
    walls = set(blocked)
    g = nx.Graph()
    for y in range(height):
        for x in range(width):
            if (x, y) not in walls:
                g.add_node(y * width + x)
    steps = ((0, -1), (0, 1), (-1, 0), (1, 0), (-1, -1), (1, -1), (-1, 1), (1, 1))
    for y in range(height):
        for x in range(width):
            if (x, y) in walls:
                continue
            here = y * width + x
            for dx, dy in steps:
                there_x, there_y = x + dx, y + dy
                if not (0 <= there_x < width and 0 <= there_y < height):
                    continue
                if (there_x, there_y) in walls:
                    continue
                weight = DIAGONAL if dx != 0 and dy != 0 else 1.0
                g.add_edge(here, there_y * width + there_x, weight=weight)
    return g


def octile(from_cell: int, to_cell: int, width: int) -> float:
    """The octile distance: the estimate a board search steers by, and never an overestimate."""
    dx = abs(from_cell % width - to_cell % width)
    dy = abs(from_cell // width - to_cell // width)
    return abs(dx - dy) + DIAGONAL * min(dx, dy)


def flow_network(nodes: int, edges) -> nx.DiGraph:
    g = nx.DiGraph()
    g.add_nodes_from(range(nodes))
    for a, b, capacity in edges:
        g.add_edge(a, b, capacity=capacity)
    return g


def flow_and_cut(nodes: int, edges, source: int, sink: int) -> tuple[float, float]:
    """The largest flow and the smallest cut, which the max-flow min-cut theorem says agree."""
    g = flow_network(nodes, edges)
    value = nx.maximum_flow_value(g, source, sink)
    cut, _ = nx.minimum_cut(g, source, sink)
    if abs(value - cut) > 1e-9:
        raise SystemExit(f"the reference disagrees with itself: flow {value}, cut {cut}")
    return value, cut


def cost_curve(nodes: int, edges, source: int, sink: int):
    """The cheapest cost of every whole amount of flow, by the reference's network simplex.

    Asking for each amount separately is what makes the curve a measurement rather than a
    reading of one solver's augmenting order: two implementations that send flow differently
    still agree on what the cheapest total is.
    """
    g = nx.DiGraph()
    g.add_nodes_from(range(nodes))
    for a, b, capacity, cost in edges:
        g.add_edge(a, b, capacity=capacity, weight=cost)
    most = nx.maximum_flow_value(g, source, sink)
    curve = []
    for amount in range(int(round(most)) + 1):
        for node in g.nodes():
            g.nodes[node]["demand"] = 0
        g.nodes[source]["demand"] = -amount
        g.nodes[sink]["demand"] = amount
        try:
            shipped = nx.min_cost_flow(g)
        except nx.NetworkXUnfeasible:
            raise SystemExit(f"the reference cannot send {amount} units")
        curve.append((float(amount), nx.cost_of_flow(g, shipped)))
    return curve


def main() -> int:
    blocks: list[str] = []
    blocks.append(
        """// Generated by scripts/gen_vectors.py from NetworkX 3.7. Do not edit.
//
// Each case is a graph and the answer an independent implementation gives on it. The tests
// replay the graph and compare, so a disagreement is a failing test and not a matter of
// opinion. Distances are `-1` where the reference found no route, which is outside the range
// of any weight these graphs carry.
"""
    )

    # One shared list of graphs, so every family is tested on the same shapes.
    graph_rows = ",\n    ".join(graph_literal(*g) for g in GRAPHS)
    blocks.append(
        "///|\n/// The graphs every family is tested on.\npub fn vector_graphs() -> Array[WeightedCase] {\n  [\n    "
        + graph_rows
        + ",\n  ]\n}\n"
    )

    # Dijkstra and Bellman-Ford: distances from one source, on graphs with no negative weight.
    dijkstra_rows = []
    bellman_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        if any(w < 0 for _, _, w in arcs):
            continue
        g = build(name, directed, nodes, arcs)
        for source in SOURCES:
            lengths = nx.single_source_dijkstra_path_length(g, source, weight="weight")
            row = [num(lengths.get(node, -1.0)) if node in lengths else "-1.0" for node in range(nodes)]
            entry = (
                f'{{ graph: {graph_literal(name, directed, nodes, arcs)}, source: {source}, '
                f"distance: [{', '.join(row)}] }}"
            )
            dijkstra_rows.append(entry)
            if all(w >= 0 for _, _, w in arcs):
                bellman_rows.append(entry)

    blocks.append(
        "///|\n/// Dijkstra's distances, from two sources on every graph.\npub fn dijkstra_cases() -> Array[PathCase] {\n  [\n    "
        + ",\n    ".join(dijkstra_rows)
        + ",\n  ]\n}\n"
    )
    blocks.append(
        "///|\n/// Bellman-Ford's distances where no edge is negative, which is the same answer.\npub fn bellman_ford_cases() -> Array[PathCase] {\n  [\n    "
        + ",\n    ".join(bellman_rows)
        + ",\n  ]\n}\n"
    )

    # Breadth-first hops: the unweighted distance.
    bfs_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        g = build(name, directed, nodes, arcs)
        for source in SOURCES:
            hops = nx.single_source_shortest_path_length(g, source)
            row = [f"{hops[node]}.0" if node in hops else "-1.0" for node in range(nodes)]
            bfs_rows.append(
                f'{{ graph: {graph_literal(name, directed, nodes, arcs)}, source: {source}, '
                f"distance: [{', '.join(row)}] }}"
            )
    blocks.append(
        "///|\n/// Breadth-first hops, which ignore the weights.\npub fn bfs_cases() -> Array[PathCase] {\n  [\n    "
        + ",\n    ".join(bfs_rows)
        + ",\n  ]\n}\n"
    )

    # All pairs, by the triple loop.
    floyd_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        if any(w < 0 for _, _, w in arcs):
            continue
        g = build(name, directed, nodes, arcs)
        lengths = dict(nx.all_pairs_dijkstra_path_length(g, weight="weight"))
        rows = []
        for a in range(nodes):
            cells = []
            for b in range(nodes):
                value = lengths.get(a, {}).get(b)
                cells.append(num(value) if value is not None else "-1.0")
            rows.append("[" + ", ".join(cells) + "]")
        floyd_rows.append(
            f'{{ graph: {graph_literal(name, directed, nodes, arcs)}, distance: [{", ".join(rows)}] }}'
        )
    blocks.append(
        "///|\n/// Every pair's cheapest cost, as a matrix.\npub fn all_pairs_cases() -> Array[AllPairsCase] {\n  [\n    "
        + ",\n    ".join(floyd_rows)
        + ",\n  ]\n}\n"
    )

    # Spanning trees and components, on the graphs that are connected enough for them.
    tree_rows = []
    component_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        g = build(name, directed, nodes, arcs)
        if not directed and nx.is_connected(g):
            weight = nx.minimum_spanning_tree(g, weight="weight").size(weight="weight")
            tree_rows.append(
                f'{{ graph: {graph_literal(name, directed, nodes, arcs)}, weight: {num(weight)} }}'
            )
        count = nx.number_weakly_connected_components(g) if directed else nx.number_connected_components(g)
        strong = nx.number_strongly_connected_components(g) if directed else count
        component_rows.append(
            f'{{ graph: {graph_literal(name, directed, nodes, arcs)}, weak: {count}, strong: {strong} }}'
        )
    blocks.append(
        "///|\n/// The cheapest tree that joins every node, on the connected undirected graphs.\npub fn spanning_cases() -> Array[SpanningCase] {\n  [\n    "
        + ",\n    ".join(tree_rows)
        + ",\n  ]\n}\n"
    )
    blocks.append(
        "///|\n/// How many pieces each graph has, read both ways.\npub fn component_cases() -> Array[ComponentCase] {\n  [\n    "
        + ",\n    ".join(component_rows)
        + ",\n  ]\n}\n"
    )

    # Betweenness and clustering, which do not depend on a source.
    centrality_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        g = build(name, directed, nodes, arcs)
        scores = nx.betweenness_centrality(g, weight=None, normalized=False)
        row = [num(scores[node]) for node in range(nodes)]
        centrality_rows.append(
            f'{{ graph: {graph_literal(name, directed, nodes, arcs)}, betweenness: [{", ".join(row)}] }}'
        )
    blocks.append(
        "///|\n/// Betweenness over shortest routes counted by hops.\npub fn centrality_cases() -> Array[CentralityCase] {\n  [\n    "
        + ",\n    ".join(centrality_rows)
        + ",\n  ]\n}\n"
    )

    clustering_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        if directed:
            continue
        g = build(name, directed, nodes, arcs)
        value = nx.transitivity(g)
        clustering_rows.append(
            f'{{ graph: {graph_literal(name, directed, nodes, arcs)}, transitivity: {num(value)} }}'
        )
    blocks.append(
        "///|\n/// The share of open triples that close into triangles.\npub fn clustering_cases() -> Array[ClusteringCase] {\n  [\n    "
        + ",\n    ".join(clustering_rows)
        + ",\n  ]\n}\n"
    )

    # Maximum flow and the size of a largest matching, on the small directed shapes.
    flow_rows = []
    matching_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        g = build(name, directed, nodes, arcs)
        if directed and nx.has_path(g, 0, nodes - 1):
            value = nx.maximum_flow_value(g, 0, nodes - 1, capacity="weight")
            flow_rows.append(
                f'{{ graph: {graph_literal(name, directed, nodes, arcs)}, source: 0, '
                f"sink: {nodes - 1}, value: {num(value) }}}"
            )
        if not directed:
            size = len(nx.max_weight_matching(g, maxcardinality=True))
            matching_rows.append(
                f'{{ graph: {graph_literal(name, directed, nodes, arcs)}, pairs: {size} }}'
            )
    blocks.append(
        "///|\n/// The most a network can carry from its first node to its last.\npub fn flow_cases() -> Array[FlowCase] {\n  [\n    "
        + ",\n    ".join(flow_rows)
        + ",\n  ]\n}\n"
    )
    blocks.append(
        "///|\n/// The number of pairs in a largest matching.\npub fn matching_cases() -> Array[MatchingCase] {\n  [\n    "
        + ",\n    ".join(matching_rows)
        + ",\n  ]\n}\n"
    )

    # ----- colouring: the exact chromatic number and whether two colours suffice -----
    colour_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        if directed:
            continue
        g = build(name, directed, nodes, arcs)
        exact = chromatic_exact(g)
        bip = bool(nx.bipartite.is_bipartite(g))
        colour_rows.append(
            f'{{ graph: {graph_literal(name, directed, nodes, arcs)}, exact: {exact}, '
            f"bipartite: {str(bip).lower()} }}"
        )
    blocks.append(
        "///|\n/// The exact chromatic number, and whether two colours suffice.\n"
        "pub fn colour_cases() -> Array[ColourCase] {\n  [\n    "
        + ",\n    ".join(colour_rows)
        + ",\n  ]\n}\n"
    )

    # ----- cliques: the largest, the largest independent set, the maximal count, chordality -----
    clique_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        if directed:
            continue
        g = build(name, directed, nodes, arcs)
        omegas = [len(s) for s in nxc.find_cliques(g)]
        omega = max(omegas) if omegas else 0
        alphas = [len(s) for s in nxc.find_cliques(nx.complement(g))] if g.number_of_nodes() else []
        alpha = max(alphas) if alphas else 0
        maximal = len(list(nxc.find_cliques(g)))
        chordal = bool(nxcord.is_chordal(g)) if g.number_of_nodes() else False
        clique_rows.append(
            f'{{ graph: {graph_literal(name, directed, nodes, arcs)}, omega: {omega}, alpha: {alpha}, '
            f"maximal: {maximal}, chordal: {str(chordal).lower()} }}"
        )
    blocks.append(
        "///|\n/// The largest clique, the largest independent set, the count of maximal cliques, and chordality.\n"
        "pub fn clique_cases() -> Array[CliqueCase] {\n  [\n    "
        + ",\n    ".join(clique_rows)
        + ",\n  ]\n}\n"
    )

    # ----- community: how many blocks the k-clique partition cuts out -----
    community_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        if directed:
            continue
        g = build(name, directed, nodes, arcs)
        parts = list(nxcmm.k_clique_communities(g, 2))
        sizes = sorted(len(p) for p in parts)
        community_rows.append(
            f'{{ graph: {graph_literal(name, directed, nodes, arcs)}, '
            f"blocks: {len(parts)}, sizes: [{', '.join(map(str, sizes))}] }}"
        )
    blocks.append(
        "///|\n/// How many blocks the k-clique partition cuts out, and their sizes.\n"
        "pub fn community_cases() -> Array[CommunityCase] {\n  [\n    "
        + ",\n    ".join(community_rows)
        + ",\n  ]\n}\n"
    )

    # ----- cycle: the shortest cycle and whether the graph is Eulerian, arcs included -----
    # `girth` is a function of the directed graph only: the reference refuses a directed
    # graph, so the shortest closed walk is read off its simple cycles, which is the same
    # reading — a directed graph's girth is the shortest directed cycle. The Eulerian
    # question is the reference's own answer for both directions.
    cycle_rows = []
    for name, directed, nodes, arcs in GRAPHS + CYCLE_SHAPES:
        g = build(name, directed, nodes, arcs)
        if g.number_of_nodes() == 0:
            continue
        if directed:
            lengths = [len(cycle) for cycle in nx.simple_cycles(g)]
            girth = min(lengths) if lengths else -1
        else:
            girth = nx.girth(g)
            if girth == float("inf"):
                girth = -1
        eulerian = bool(nx.is_eulerian(g))
        cycle_rows.append(
            f'{{ graph: {graph_literal(name, directed, nodes, arcs)}, girth: {girth}, '
            f"eulerian: {str(eulerian).lower()} }}"
        )
    blocks.append(
        "///|\n/// The shortest cycle, or `-1` when there is none, and whether the graph is Eulerian.\n"
        "pub fn cycle_cases() -> Array[CycleCase] {\n  [\n    "
        + ",\n    ".join(cycle_rows)
        + ",\n  ]\n}\n"
    )

    # ----- metric: the Weisfeiler-Lehman fingerprint, as the reference computes it -----
    # The digest is blake2b at sixteen bytes, so the texts are the same string and not only
    # two strings that agree on which graphs match. Directed shapes are here because the
    # refinement reads successors before predecessors, which is where a reading that
    # ignored the arc direction would come apart.
    wl_rows = []
    for name, directed, nodes, arcs in GRAPHS + CYCLE_SHAPES:
        g = build(name, directed, nodes, arcs)
        if g.number_of_nodes() == 0:
            continue
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            hexdigest = nx.weisfeiler_lehman_graph_hash(g)
        wl_rows.append(
            f'{{ graph: {graph_literal(name, directed, nodes, arcs)}, hex: "{hexdigest}" }}'
        )
    blocks.append(
        "///|\n/// A graph and the fingerprint the reference takes of it, round for round.\n"
        "pub fn wl_cases() -> Array[WlCase] {\n  [\n    "
        + ",\n    ".join(wl_rows)
        + ",\n  ]\n}\n"
    )


    # ----- dag: reachability, the transitive reduction, and the longest route -----
    dag_rows = []
    for name, arcs in DAGS:
        g = nx.DiGraph()
        nodes = max([a for a, b in arcs] + [b for a, b in arcs], default=-1) + 1
        g.add_nodes_from(range(nodes))
        g.add_edges_from(arcs)
        # The transitive reduction, as a sorted edge list.
        red = nx.transitive_reduction(g)
        edges = sorted((a, b) for a, b in red.edges())
        # The longest path, by hops, in a topological order.
        order = list(nx.topological_sort(g))
        dist = {node: 0 for node in order}
        for node in order:
            for m in g.successors(node):
                if dist[node] + 1 > dist[m]:
                    dist[m] = dist[node] + 1
        longest = max(dist.values())
        edges_lit = "[" + ", ".join(f"({a}, {b})" for a, b in edges) + "]"
        arcs_lit = "[" + ", ".join(f"({a}, {b}, 1.0)" for a, b in arcs) + "]"
        dag_rows.append(
            f'{{ name: "{name}", nodes: {nodes}, directed: true, arcs: {arcs_lit}, '
            f"reduction: {edges_lit}, longest: {longest} }}"
        )
    blocks.append(
        "///|\n/// The transitive reduction and the longest route of a directed acyclic graph.\n"
        "pub fn dag_cases() -> Array[DagCase] {\n  [\n    "
        + ",\n    ".join(dag_rows)
        + ",\n  ]\n}\n"
    )

    # ----- isomorphism: whether two graphs of the same shape match -----
    iso_rows = []
    for name, directed, a_arcs, b_arcs in ISO_PAIRS:
        ga = (nx.DiGraph() if directed else nx.Graph())
        ga.add_edges_from(a_arcs)
        ga.add_nodes_from(range(max(ga.nodes(), default=-1) + 1))
        gb = (nx.DiGraph() if directed else nx.Graph())
        gb.add_edges_from(b_arcs)
        gb.add_nodes_from(range(max(gb.nodes(), default=-1) + 1))
        iso = bool(nx.is_isomorphic(ga, gb))
        a_lit = "[" + ", ".join(f"({a}, {b})" for a, b in sorted(a_arcs)) + "]"
        b_lit = "[" + ", ".join(f"({a}, {b})" for a, b in sorted(b_arcs)) + "]"
        iso_rows.append(
            f'{{ name: "{name}", a: {a_lit}, b: {b_lit}, isomorphic: {str(iso).lower()} }}'
        )
    blocks.append(
        "///|\n/// Whether two graphs match, with the arc lists the reference was asked about.\n"
        "pub fn iso_cases() -> Array[IsoCase] {\n  [\n    "
        + ",\n    ".join(iso_rows)
        + ",\n  ]\n}\n"
    )

    # ----- structural properties: graphical, multigraphical, and digraphical -----
    struct_rows = []
    degree_cases = [
        [1, 1, 1],
        [2, 2, 2],
        [3, 1],
        [0, 1, 1],
        [4, 2, 2],
        [1],
        [0, 0],
    ]
    for degrees in degree_cases:
        structural = bool(nxf.is_graphical(degrees))
        multi = bool(nxf.is_multigraphical(degrees))
        struct_rows.append(
            f'{{ kind: "graphical", degrees: [{", ".join(map(str, degrees))}], '
            f"holds: {str(structural).lower()} }}"
        )
        struct_rows.append(
            f'{{ kind: "multigraphical", degrees: [{", ".join(map(str, degrees))}], '
            f"holds: {str(multi).lower()} }}"
        )
    blocks.append(
        "///|\n/// A degree sequence read through the graphical or multigraphical test.\n"
        "pub fn struct_cases() -> Array[StructCase] {\n  [\n    "
        + ",\n    ".join(struct_rows)
        + ",\n  ]\n}\n"
    )

    digraphical_rows = []
    pair_cases = [
        [(1, 1), (1, 1), (1, 1)],
        [(0, 1), (0, 1)],
        [(0, 3), (3, 3), (3, 0)],
        [(3, 4), (3, 2), (3, 4), (3, 2)],
    ]
    for pairs in pair_cases:
        holds = gale_ryser_pairs(pairs)
        digraphical_rows.append(
            f'{{ degrees: [{", ".join(f"({o}, {i})" for o, i in pairs)}], '
            f"holds: {str(holds).lower()} }}"
        )
    blocks.append(
        "///|\n/// In- and out-degree pairs read through the digraphical test.\n"
        "pub fn digraphical_cases() -> Array[DigraphicalCase] {\n  [\n    "
        + ",\n    ".join(digraphical_rows)
        + ",\n  ]\n}\n"
    )

    # ----- graph operations: the node and edge counts of the result, by the set reading -----
    def undirected_edges(g):
        return {tuple(sorted(e)) for e in g.edges()}

    def directed_edges(g):
        return {e for e in g.edges()}

    op_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        g = build(name, directed, nodes, arcs)
        if g.number_of_nodes() == 0:
            continue
        # A fixed partner that overlaps the node range, so the set operations are non-trivial.
        p_nodes = 3
        p_arcs = [(0, 1), (1, 2), (0, 2)]
        p = (nx.DiGraph() if directed else nx.Graph())
        p.add_nodes_from(range(p_nodes))
        p.add_edges_from(p_arcs)
        partner = f'{{ name: "triangle", nodes: {p_nodes}, directed: {str(directed).lower()}, arcs: [(0, 1, 1.0), (1, 2, 1.0), (0, 2, 1.0)] }}'
        na, nb = set(g.nodes()), set(p.nodes())
        ea = (directed_edges(g) if directed else undirected_edges(g))
        eb = (directed_edges(p) if directed else undirected_edges(p))
        results = {
            "union": (len(na | nb), len(ea | eb)),
            "intersection": (len(na & nb), len(ea & eb)),
            "difference": (len(na), len(ea - eb)),
            "symmetric_difference": (len(na | nb), len(ea ^ eb)),
            "disjoint_union": (
                len(na) + len(nb),
                len(ea) + len(eb),
            ),
        }
        for op, (n, m) in results.items():
            op_rows.append(
                f'{{ name: "{op}", graph: {graph_literal(name, directed, nodes, arcs)}, '
                f"partner: {partner}, nodes: {n}, edges: {m} }}"
            )
        if not directed:
            comp = nx.complement(g)
            op_rows.append(
                f'{{ name: "complement", graph: {graph_literal(name, directed, nodes, arcs)}, '
                f"partner: {partner}, nodes: {comp.number_of_nodes()}, "
                f"edges: {comp.number_of_edges()} }}"
            )
            lg = nx.line_graph(g)
            op_rows.append(
                f'{{ name: "line_graph", graph: {graph_literal(name, directed, nodes, arcs)}, '
                f"partner: {partner}, nodes: {lg.number_of_nodes()}, "
                f"edges: {lg.number_of_edges()} }}"
            )
        if directed:
            op_rows.append(
                f'{{ name: "reverse", graph: {graph_literal(name, directed, nodes, arcs)}, '
                f"partner: {partner}, nodes: {g.number_of_nodes()}, edges: {g.number_of_edges()} }}"
            )
    blocks.append(
        "///|\n/// The size of a graph operation's result.\n"
        "pub fn op_cases() -> Array[OpCase] {\n  [\n    "
        + ",\n    ".join(op_rows)
        + ",\n  ]\n}\n"
    )

    # ----- generators: the node and edge counts a named graph carries -----
    # `size` is the argument this library's generator takes; the reference graph is built to
    # have the same node count so the counts line up.
    gen_rows = []
    for n in [3, 5]:
        gen_rows.append(
            f'{{ name: "complete", size: {n}, nodes: {n}, edges: {n * (n - 1) // 2} }}'
        )
        gen_rows.append(
            f'{{ name: "path", size: {n}, nodes: {n}, edges: {n - 1} }}'
        )
        if n >= 3:
            gen_rows.append(
                f'{{ name: "cycle", size: {n}, nodes: {n}, edges: {n} }}'
            )
        # star(n) is n nodes: the reference star with n nodes is star_graph(n - 1).
        gen_rows.append(
            f'{{ name: "star", size: {n}, nodes: {n}, edges: {n - 1} }}'
        )
        gen_rows.append(
            f'{{ name: "ladder", size: {n}, nodes: {2 * n}, edges: {3 * n - 1} }}'
        )
    for n in [5, 6]:
        gen_rows.append(
            f'{{ name: "wheel", size: {n}, nodes: {n + 1}, edges: {2 * n} }}'
        )
    gen_rows.append(
        f'{{ name: "petersen", size: 0, nodes: 10, edges: 15 }}'
    )
    blocks.append(
        "///|\n/// The node and edge counts a named generator produces.\n"
        "pub fn gen_cases() -> Array[GenCase] {\n  [\n    "
        + ",\n    ".join(gen_rows)
        + ",\n  ]\n}\n"
    )

    # ----- io: standard texts an independent writer produces, with the counts they name -----
    # A graph6 or sparse6 row carries the graph as well as the text, so the test can write
    # the graph again and compare byte for byte rather than only counting what reads back.
    io_rows = []

    def io_row(fmt: str, directed: bool, nodes: int, arcs, text: str, g) -> str:
        return (
            f'{{ format: "{fmt}", directed: {str(directed).lower()}, text: {text_literal(text)}, '
            f"nodes: {g.number_of_nodes()}, edges: {g.number_of_edges()}, "
            f"graph: {graph_literal(fmt, directed, nodes, arcs)} }}"
        )

    for name, directed, nodes, arcs in GRAPHS:
        g = build(name, directed, nodes, arcs)
        if not g.number_of_nodes():
            continue
        if not directed:
            g6 = nx_g6.to_graph6_bytes(g).decode().replace(">>graph6<<", "").strip()
            io_rows.append(io_row("graph6", directed, nodes, arcs, g6, g))
        io_rows.append(io_row("edges", directed, nodes, arcs, edge_list_of(g), g))
        io_rows.append(io_row("adjacency", directed, nodes, arcs, adjacency_of(g), g))

    for name, nodes, repeated, edges in SPARSE6_SHAPES:
        g = nx.MultiGraph() if repeated else nx.Graph()
        g.add_nodes_from(range(nodes))
        g.add_edges_from(edges)
        text = nx.to_sparse6_bytes(g).decode().replace(">>sparse6<<", "").strip()
        written = sparse6_written(nodes, edges)
        if written != text:
            raise SystemExit(
                f"{name}: the format writes {written!r}, the reference writes {text!r}"
            )
        arcs = [(a, b, 1.0) for a, b in edges]
        io_rows.append(io_row("sparse6", False, nodes, arcs, text, g))

    blocks.append(
        "///|\n/// A graph in one of the read formats, with the counts the reference records for it.\n"
        "pub fn io_cases() -> Array[IoCase] {\n  [\n    "
        + ",\n    ".join(io_rows)
        + ",\n  ]\n}\n"
    )

    # ----- approx: the vertex cover, which is the set of non-isolated vertices -----
    approx_rows = []
    for name, directed, nodes, arcs in APPROX_GRAPHS:
        g = build(name, directed, nodes, arcs)
        cover = sorted(n for n in g.nodes() if g.degree(n) > 0)
        approx_rows.append(
            f'{{ name: "{name}", nodes: {nodes}, directed: {str(directed).lower()}, '
            f"arcs: [{', '.join(f'({a}, {b}, 1.0)' for a, b, _ in arcs)}], "
            f"cover: [{', '.join(map(str, cover))}] }}"
        )
    blocks.append(
        "///|\n/// A graph and the vertex cover: the nodes the cover touches, smallest first.\n"
        "pub fn approx_cases() -> Array[ApproxCase] {\n  [\n    "
        + ",\n    ".join(approx_rows)
        + ",\n  ]\n}\n"
    )

    # ----- graphml: a standard document, with the counts it carries -----
    graphml_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        g = build(name, directed, nodes, arcs)
        if not g.number_of_nodes():
            continue
        tmp = ROOT / "scripts" / f"_tmp_{name}.graphml"
        nx.write_graphml(g, tmp)
        text = tmp.read_text(encoding="utf-8")
        tmp.unlink()
        graphml_rows.append(
            f'{{ text: {text_literal(text)}, nodes: {g.number_of_nodes()}, '
            f"edges: {g.number_of_edges()} }}"
        )
    blocks.append(
        "///|\n/// A graph as a GraphML document, with the counts it carries.\n"
        "pub fn graphml_cases() -> Array[GraphmlCase] {\n  [\n    "
        + ",\n    ".join(graphml_rows)
        + ",\n  ]\n}\n"
    )

    # Link prediction: every pair without an edge, scored seven ways. Four of the seven
    # are NetworkX 3.7's own functions; dice, cosine and overlap were dropped from that
    # release, so their reference is the definition written out here.
    similarity_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        if directed:
            continue
        g = build(name, directed, nodes, arcs)
        for a in range(nodes):
            for b in range(a + 1, nodes):
                if g.has_edge(a, b):
                    continue
                left, right = set(g[a]), set(g[b])
                both = len(left & right)
                shared = len(nx.common_neighbors(g, a, b))
                jaccard = next(iter(nx_link.jaccard_coefficient(g, [(a, b)])))[2]
                adamic = next(iter(nx_link.adamic_adar_index(g, [(a, b)])))[2]
                resource = next(iter(nx_link.resource_allocation_index(g, [(a, b)])))[2]
                attachment = next(iter(nx_link.preferential_attachment(g, [(a, b)])))[2]
                dice = 2 * shared / (len(left) + len(right)) if left or right else 0.0
                cosine = (
                    shared / math.sqrt(len(left) * len(right))
                    if left and right
                    else 0.0
                )
                overlap = shared / min(len(left), len(right)) if left and right else 0.0
                similarity_rows.append(
                    f"{{ graph: {graph_literal(name, directed, nodes, arcs)}, a: {a}, b: {b}, "
                    f"shared: {shared}, jaccard: {num(jaccard)}, dice: {num(dice)}, cosine: {num(cosine)}, "
                    f"overlap: {num(overlap)}, adamic: {num(adamic)}, "
                    f"resource: {num(resource)}, attachment: {num(attachment)} }}"
                )
    blocks.append(
        "///|\n/// Every pair of nodes with no edge, scored seven ways.\n"
        "pub fn similarity_cases() -> Array[SimilarityCase] {\n  [\n    "
        + ",\n    ".join(similarity_rows)
        + ",\n  ]\n}\n"
    )

    # The triadic census, on digraphs that between them hold most of the sixteen shapes,
    # and on the undirected vectors read as the digraph that carries both arcs per edge.
    triad_rows = []
    for name, nodes, arcs in TRIAD_GRAPHS:
        census = nx.triadic_census(build(name, True, nodes, [(a, b, 1.0) for a, b in arcs]))
        row = ", ".join(str(census[triad]) for triad in nx_triads.TRIAD_NAMES)
        triad_rows.append(
            f"{{ graph: {graph_literal(name, True, nodes, [(a, b, 1.0) for a, b in arcs])}, "
            f"count: [{row}] }}"
        )
    for name, directed, nodes, arcs in GRAPHS:
        if directed:
            continue
        g = build(name, directed, nodes, arcs)
        doubled = nx.DiGraph()
        doubled.add_nodes_from(range(nodes))
        doubled.add_edges_from((a, b) for a, b in g.edges())
        doubled.add_edges_from((b, a) for a, b in g.edges())
        census = nx.triadic_census(doubled)
        row = ", ".join(str(census[triad]) for triad in nx_triads.TRIAD_NAMES)
        triad_rows.append(
            f"{{ graph: {graph_literal(name, directed, nodes, arcs)}, count: [{row}] }}"
        )
    blocks.append(
        "///|\n/// The sixteen triad counts, in the order the names come in.\n"
        "pub fn triad_cases() -> Array[TriadCase] {\n  [\n    "
        + ",\n    ".join(triad_rows)
        + ",\n  ]\n}\n"
    )

    # The rich-club coefficient, one entry per degree threshold, with `-1` where fewer
    # than two nodes sit above it and the ratio has no meaning.
    rich_rows = []
    rich_shapes = [(name, nodes, arcs) for name, directed, nodes, arcs in GRAPHS if not directed]
    rich_shapes += [(name, nodes, [(a, b, 1.0) for a, b in arcs]) for name, nodes, arcs in RICH_GRAPHS]
    for name, nodes, arcs in rich_shapes:
        g = build(name, False, nodes, arcs)
        rc = nx_rc.rich_club_coefficient(g, normalized=False)
        top = max(dict(g.degree()).values())
        row = [num(rc[k]) if k in rc else "-1.0" for k in range(top)]
        rich_rows.append(
            f"{{ graph: {graph_literal(name, False, nodes, arcs)}, "
            f"coefficient: [{', '.join(row)}] }}"
        )
    blocks.append(
        "///|\n/// The rich-club coefficient at every degree threshold, `-1` where undefined.\n"
        "pub fn rich_club_cases() -> Array[RichClubCase] {\n  [\n    "
        + ",\n    ".join(rich_rows)
        + ",\n  ]\n}\n"
    )

    # The Wiener index and the barycentre, on every vector graph. `-1` stands for an
    # infinite sum, which is what a graph that falls apart has.
    distance_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        g = build(name, directed, nodes, arcs)
        connected = nx.is_strongly_connected(g) if directed else nx.is_connected(g)
        wiener = nx.wiener_index(g) if connected else -1.0
        if connected:
            reach = dict(nx.all_pairs_dijkstra_path_length(g))
            totals = [sum(reach[v].values()) for v in range(nodes)]
            lowest = min(totals)
            bary = [v for v in range(nodes) if totals[v] == lowest]
        else:
            bary = []
        distance_rows.append(
            f"{{ graph: {graph_literal(name, directed, nodes, arcs)}, "
            f"wiener: {num(wiener)}, barycenter: [{', '.join(str(v) for v in bary)}] }}"
        )
    blocks.append(
        "///|\n/// The Wiener index and the barycentre, `-1` where the sum is infinite.\n"
        "pub fn distance_cases() -> Array[DistanceCase] {\n  [\n    "
        + ",\n    ".join(distance_rows)
        + ",\n  ]\n}\n"
    )

    # Resistance distances, as the pseudo-inverse of the Laplacian — a different route to
    # the same numbers the library takes through a Cholesky factor. Pairs in different
    # pieces are `-1`: there is no current path, not a resistance of zero.
    resistance_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        if directed:
            continue
        g = build(name, directed, nodes, arcs)
        lap = np.zeros((nodes, nodes))
        for u, v, data in g.edges(data=True):
            c = data["weight"]
            lap[u][u] += c
            lap[v][v] += c
            lap[u][v] -= c
            lap[v][u] -= c
        pinv = np.linalg.pinv(lap, hermitian=True)
        piece = {n: i for i, part in enumerate(nx.connected_components(g)) for n in part}
        rows = []
        for a in range(nodes):
            cells = []
            for b in range(nodes):
                if piece[a] != piece[b]:
                    cells.append("-1.0")
                else:
                    value = pinv[a][a] + pinv[b][b] - 2 * pinv[a][b]
                    cells.append(num(max(value, 0.0)))
            rows.append("[" + ", ".join(cells) + "]")
        resistance_rows.append(
            f'{{ graph: {graph_literal(name, directed, nodes, arcs)}, distance: [{", ".join(rows)}] }}'
        )
    blocks.append(
        "///|\n/// Resistance distances, `-1` between pieces of a graph that falls apart.\n"
        "pub fn resistance_cases() -> Array[ResistanceCase] {\n  [\n    "
        + ",\n    ".join(resistance_rows)
        + ",\n  ]\n}\n"
    )

    # Voronoi cells: distances from each centre by NetworkX, then the assignment rule the
    # library documents — nearest centre, ties to the smaller number.
    voronoi_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        if any(w < 0 for _, _, w in arcs):
            continue
        g = build(name, directed, nodes, arcs)
        centers = [0, 2] if nodes > 3 else [0]
        reach = {c: nx.single_source_dijkstra_path_length(g, c, weight="weight") for c in centers}
        cell = []
        for node in range(nodes):
            options = [(reach[c][node], c) for c in centers if node in reach[c]]
            cell.append(str(min(options)[1]) if options else "-1")
        voronoi_rows.append(
            f"{{ graph: {graph_literal(name, directed, nodes, arcs)}, "
            f"centers: [{', '.join(str(c) for c in centers)}], cell: [{', '.join(cell)}] }}"
        )
    blocks.append(
        "///|\n/// The centre each node looks to, `-1` when no centre reaches it.\n"
        "pub fn voronoi_cases() -> Array[VoronoiCase] {\n  [\n    "
        + ",\n    ".join(voronoi_rows)
        + ",\n  ]\n}\n"
    )

    # Structural holes: constraint and effective size, with `-1` where the reference says
    # the measure is undefined because the node has no neighbours.
    hole_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        if directed:
            continue
        g = build(name, directed, nodes, arcs)
        tight = nx_holes.constraint(g)
        wide = nx_holes.effective_size(g)
        tight_row = [num(tight[v]) if not math.isnan(tight[v]) else "-1.0" for v in range(nodes)]
        wide_row = [num(wide[v]) if not math.isnan(wide[v]) else "-1.0" for v in range(nodes)]
        hole_rows.append(
            f"{{ graph: {graph_literal(name, directed, nodes, arcs)}, "
            f"constraint: [{', '.join(tight_row)}], "
            f"effective: [{', '.join(wide_row)}] }}"
        )
    blocks.append(
        "///|\n/// Constraint and effective size, `-1` where the measure is undefined.\n"
        "pub fn hole_cases() -> Array[HoleCase] {\n  [\n    "
        + ",\n    ".join(hole_rows)
        + ",\n  ]\n}\n"
    )

    # The exact tour, against a brute force over every ordering of the stops.
    tsp_rows = []
    for name, nodes, arcs in TSP_GRAPHS:
        g = build(name, False, nodes, [(a, b, w) for a, b, w in arcs])
        reach = dict(nx.all_pairs_dijkstra_path_length(g, weight="weight"))
        start = 0
        best = float("inf")
        for rest in itertools.permutations([v for v in range(nodes) if v != start]):
            order = (start, *rest, start)
            total = sum(reach[a][b] for a, b in zip(order, order[1:]))
            best = min(best, total)
        tsp_rows.append(
            f"{{ graph: {graph_literal(name, False, nodes, [(a, b, w) for a, b, w in arcs])}, "
            f"start: {start}, cost: {num(best)} }}"
        )
    blocks.append(
        "///|\n/// The cheapest tour through every node, by brute force over the orderings.\n"
        "pub fn tour_cases() -> Array[TourCase] {\n  [\n    "
        + ",\n    ".join(tsp_rows)
        + ",\n  ]\n}\n"
    )

    # The spectrum family: communicability from the exponential of the adjacency, current-flow
    # closeness from the resistance distances, and vote-rank from the reference's greedy rule.
    spectrum_rows = []
    closeness_rows = []
    vote_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        if directed:
            continue
        g = build(name, directed, nodes, arcs)
        adj = np.zeros((nodes, nodes))
        for u, v, data in g.edges(data=True):
            adj[u][v] += data["weight"]
            adj[v][u] += data["weight"]
        eigenvalues, eigenvectors = np.linalg.eigh(adj)
        expm = eigenvectors @ np.diag(np.exp(eigenvalues)) @ eigenvectors.T
        rows = ["[" + ", ".join(num(expm[i][j]) for j in range(nodes)) + "]" for i in range(nodes)]
        spectrum_rows.append(
            f'{{ graph: {graph_literal(name, directed, nodes, arcs)}, value: [{", ".join(rows)}] }}'
        )
        lap = np.zeros((nodes, nodes))
        for u, v, data in g.edges(data=True):
            c = data["weight"]
            lap[u][u] += c
            lap[v][v] += c
            lap[u][v] -= c
            lap[v][u] -= c
        pinv = np.linalg.pinv(lap, hermitian=True)
        piece = {n: k for k, part in enumerate(nx.connected_components(g)) for n in part}
        scores = []
        for u in range(nodes):
            total = 0.0
            whole = True
            for v in range(nodes):
                if u == v:
                    continue
                if piece[u] != piece[v]:
                    whole = False
                    continue
                total += pinv[u][u] + pinv[v][v] - 2 * pinv[u][v]
            scores.append((nodes - 1) / total if whole and total > 0 else 0.0)
        closeness_rows.append(
            f'{{ graph: {graph_literal(name, directed, nodes, arcs)}, '
            f'score: [{", ".join(num(v) for v in scores)}] }}'
        )
        ranked = nx.voterank(g)
        vote_rows.append(
            f'{{ graph: {graph_literal(name, directed, nodes, arcs)}, '
            f'ranked: [{", ".join(str(v) for v in ranked)}] }}'
        )
    blocks.append(
        "///|\n/// The exponential of the adjacency matrix, entry by entry.\n"
        "pub fn communicability_cases() -> Array[SpectrumCase] {\n  [\n    "
        + ",\n    ".join(spectrum_rows)
        + ",\n  ]\n}\n"
    )
    blocks.append(
        "///|\n/// Current-flow closeness, per node.\n"
        "pub fn closeness_flow_cases() -> Array[ScoreCase] {\n  [\n    "
        + ",\n    ".join(closeness_rows)
        + ",\n  ]\n}\n"
    )
    blocks.append(
        "///|\n/// The vote-rank order.\n"
        "pub fn voterank_cases() -> Array[RankCase] {\n  [\n    "
        + ",\n    ".join(vote_rows)
        + ",\n  ]\n}\n"
    )

    # Current-flow betweenness, by the definition: send one unit between every pair, solve
    # for the voltages, and halve the current on a node's edges. Unit conductances, which is
    # what the library assumes when no weight is given.
    flow_between_rows = []
    percolation_rows = []
    for name, directed, nodes, arcs in GRAPHS:
        if directed:
            continue
        g = build(name, directed, nodes, arcs)
        simple = nx.Graph()
        simple.add_nodes_from(range(nodes))
        simple.add_edges_from((a, b) for a, b in g.edges())
        lap = nx.laplacian_matrix(simple).toarray() if False else None
        n = nodes
        lap = np.zeros((n, n))
        for u, v in simple.edges():
            lap[u][u] += 1
            lap[v][v] += 1
            lap[u][v] -= 1
            lap[v][u] -= 1
        pinv = np.linalg.pinv(lap, hermitian=True)
        cb = np.zeros(n)
        for s in range(n):
            for u in range(s + 1, n):
                if not nx.has_path(simple, s, u):
                    continue
                b = np.zeros(n)
                b[s] = 1.0
                b[u] = -1.0
                volts = pinv @ b
                for v in range(n):
                    current = sum(abs(volts[v] - volts[w]) for w in simple[v])
                    cb[v] += current / 2.0
        flow_between_rows.append(
            f"{{ graph: {graph_literal(name, directed, nodes, arcs)}, "
            f"score: [{', '.join(num(x) for x in cb)}] }}"
        )
        states = {v: 1.0 if v % 2 == 0 else 0.25 for v in range(n)}
        try:
            percolation = nx.percolation_centrality(simple, states=states)
            row = [num(percolation[v]) for v in range(n)]
        except Exception:
            row = ["-1.0"] * n
        percolation_rows.append(
            f"{{ graph: {graph_literal(name, directed, nodes, arcs)}, "
            f"state: [{', '.join(num(states[v]) for v in range(n))}], "
            f"score: [{', '.join(row)}] }}"
        )
    blocks.append(
        "///|\n/// Current-flow betweenness, unit conductances.\n"
        "pub fn flow_between_cases() -> Array[ScoreCase] {\n  [\n    "
        + ",\n    ".join(flow_between_rows)
        + ",\n  ]\n}\n"
    )
    blocks.append(
        "///|\n/// Percolation centrality for a state vector, `-1` where the reference refused.\n"
        "pub fn percolation_cases() -> Array[PercolationCase] {\n  [\n    "
        + ",\n    ".join(percolation_rows)
        + ",\n  ]\n}\n"
    )

    # Boards: the cheapest cost of a route, from the reference's A* over the same board. Its
    # Dijkstra has to agree, or the estimate the search steers by is not admissible on this
    # board and the vector would be a reading of one algorithm rather than of the board.
    board_rows = []
    for name, width, height, blocked, start, goal in BOARDS:
        g = board_graph(width, height, blocked)
        from_cell = start[1] * width + start[0]
        to_cell = goal[1] * width + goal[0]
        if from_cell in g and to_cell in g:
            try:
                cost = nx.astar_path_length(
                    g,
                    from_cell,
                    to_cell,
                    heuristic=lambda a, b: octile(a, b, width),
                    weight="weight",
                )
            except nx.NetworkXNoPath:
                cost = -1.0
            else:
                cheapest = nx.dijkstra_path_length(g, from_cell, to_cell, weight="weight")
                if abs(cost - cheapest) > 1.0e-9:
                    raise SystemExit(f"{name}: the reference's A* and Dijkstra disagree")
        else:
            cost = -1.0
        walls = ", ".join(str(y * width + x) for x, y in blocked)
        board_rows.append(
            f'{{ name: "{name}", width: {width}, height: {height}, blocked: [{walls}], '
            f"start: {from_cell}, goal: {to_cell}, cost: {num(cost)} }}"
        )
    blocks.append(
        "///|\n/// Boards and the cheapest route across each, `-1` where the ends are not both\n"
        "/// free or not joined.\npub fn board_cases() -> Array[BoardCase] {\n  [\n    "
        + ",\n    ".join(board_rows)
        + ",\n  ]\n}\n"
    )

    # Flow networks that grow: the first answer, one answer per capacity increase, and the
    # smallest cut of the network at the end.
    flow_rows = []
    for name, nodes, source, sink, edges, changes in FLOW_NETWORKS:
        first, _ = flow_and_cut(nodes, edges, source, sink)
        current = list(edges)
        after = []
        for edge, extra in changes:
            a, b, capacity = current[edge]
            current[edge] = (a, b, capacity + extra)
            after.append(flow_and_cut(nodes, current, source, sink)[0])
        cut = flow_and_cut(nodes, current, source, sink)[1]
        edges_of = ", ".join(f"({a}, {b}, {num(c)})" for a, b, c in edges)
        changes_of = ", ".join(f"({edge}, {num(extra)})" for edge, extra in changes)
        after_of = ", ".join(num(value) for value in after)
        flow_rows.append(
            f'{{ name: "{name}", nodes: {nodes}, edges: [{edges_of}], source: {source}, '
            f"sink: {sink}, first: {num(first)}, changes: [{changes_of}], "
            f"after: [{after_of}], cut: {num(cut)} }}"
        )
    blocks.append(
        "///|\n/// Networks, the flow they carry, and what one more unit of capacity each buys.\n"
        "pub fn incremental_cases() -> Array[IncrementalCase] {\n  [\n    "
        + ",\n    ".join(flow_rows)
        + ",\n  ]\n}\n"
    )

    # The price of every whole amount of flow: the curve a cost flow network answers with.
    cost_rows = []
    for name, nodes, source, sink, edges in COST_NETWORKS:
        curve = cost_curve(nodes, edges, source, sink)
        edges_of = ", ".join(
            f"({a}, {b}, {num(capacity)}, {num(cost)})" for a, b, capacity, cost in edges
        )
        curve_of = ", ".join(f"({num(flow)}, {num(cost)})" for flow, cost in curve)
        cost_rows.append(
            f'{{ name: "{name}", nodes: {nodes}, edges: [{edges_of}], source: {source}, '
            f"sink: {sink}, curve: [{curve_of}] }}"
        )
    blocks.append(
        "///|\n/// Networks with a price per unit, and the cheapest total for each whole amount.\n"
        "pub fn cost_flow_cases() -> Array[CostFlowCase] {\n  [\n    "
        + ",\n    ".join(cost_rows)
        + ",\n  ]\n}\n"
    )

    header = build_header()
    OUT.write_text("\n".join([blocks[0], header] + blocks[1:]), encoding="utf-8", newline="\n")
    total = sum(1 for line in "\n".join(blocks).splitlines() if line.strip().startswith("{"))
    print(f"wrote {OUT.relative_to(ROOT)}: {total} cases, {len(GRAPHS)} graphs")
    return 0


def build_header() -> str:
    return """// The shapes the vectors use, in one place so every family shares them.
///|
/// A graph as the generator wrote it: node count, direction, and the arcs with their weights.
pub(all) struct WeightedCase {
  name : String
  nodes : Int
  directed : Bool
  arcs : Array[(Int, Int, Double)]
}

///|
/// A one-source answer: the distances, with `-1` where there was no route.
pub(all) struct PathCase {
  graph : WeightedCase
  source : Int
  distance : Array[Double]
}

///|
/// An all-pairs answer: the cost matrix, with `-1` where there was no route.
pub(all) struct AllPairsCase {
  graph : WeightedCase
  distance : Array[Array[Double]]
}

///|
/// The weight of the cheapest spanning tree.
pub(all) struct SpanningCase {
  graph : WeightedCase
  weight : Double
}

///|
/// How many pieces a graph has, weakly and strongly.
pub(all) struct ComponentCase {
  graph : WeightedCase
  weak : Int
  strong : Int
}

///|
/// One pair of nodes and the seven similarity scores between them.
pub(all) struct SimilarityCase {
  graph : WeightedCase
  a : Int
  b : Int
  shared : Int
  jaccard : Double
  dice : Double
  cosine : Double
  overlap : Double
  adamic : Double
  resource : Double
  attachment : Double
}

///|
/// How many triples of each of the sixteen shapes a graph has.
pub(all) struct TriadCase {
  graph : WeightedCase
  count : Array[Int]
}

///|
/// The rich-club coefficient at each degree threshold.
pub(all) struct RichClubCase {
  graph : WeightedCase
  coefficient : Array[Double]
}

///|
/// The total distance between every pair, and the nodes that sit closest to all of it.
pub(all) struct DistanceCase {
  graph : WeightedCase
  wiener : Double
  barycenter : Array[Int]
}

///|
/// Resistance distances between every pair.
pub(all) struct ResistanceCase {
  graph : WeightedCase
  distance : Array[Array[Double]]
}

///|
/// The centre each node belongs to.
pub(all) struct VoronoiCase {
  graph : WeightedCase
  centers : Array[Int]
  cell : Array[Int]
}

///|
/// Burt's constraint and effective size, per node.
pub(all) struct HoleCase {
  graph : WeightedCase
  constraint : Array[Double]
  effective : Array[Double]
}

///|
/// The cheapest closed tour through every node.
pub(all) struct TourCase {
  graph : WeightedCase
  start : Int
  cost : Double
}

///|
/// A matrix of numbers per graph.
pub(all) struct SpectrumCase {
  graph : WeightedCase
  value : Array[Array[Double]]
}

///|
/// One score per node.
pub(all) struct ScoreCase {
  graph : WeightedCase
  score : Array[Double]
}

///|
/// One score per node, for a state vector.
pub(all) struct PercolationCase {
  graph : WeightedCase
  state : Array[Double]
  score : Array[Double]
}

///|
/// An ordered list of nodes.
pub(all) struct RankCase {
  graph : WeightedCase
  ranked : Array[Int]
}

///|
/// A betweenness score per node.
pub(all) struct CentralityCase {
  graph : WeightedCase
  betweenness : Array[Double]
}

///|
/// The transitivity of a graph.
pub(all) struct ClusteringCase {
  graph : WeightedCase
  transitivity : Double
}

///|
/// The value of a maximum flow between two nodes.
pub(all) struct FlowCase {
  graph : WeightedCase
  source : Int
  sink : Int
  value : Double
}

///|
/// How many pairs a largest matching holds.
pub(all) struct MatchingCase {
  graph : WeightedCase
  pairs : Int
}

///|
/// The exact chromatic number, and whether two colours suffice.
pub(all) struct ColourCase {
  graph : WeightedCase
  exact : Int
  bipartite : Bool
}

///|
/// The largest clique and independent set, the count of maximal cliques, and chordality.
pub(all) struct CliqueCase {
  graph : WeightedCase
  omega : Int
  alpha : Int
  maximal : Int
  chordal : Bool
}

///|
/// How many blocks a community partition cuts out, and their sizes, smallest first.
pub(all) struct CommunityCase {
  graph : WeightedCase
  blocks : Int
  sizes : Array[Int]
}

///|
/// The shortest cycle, or `-1` when there is none, and whether the graph is Eulerian.
pub(all) struct CycleCase {
  graph : WeightedCase
  girth : Int
  eulerian : Bool
}

///|
/// A directed acyclic graph's transitive reduction and longest route, by hops.
pub(all) struct DagCase {
  name : String
  nodes : Int
  directed : Bool
  arcs : Array[(Int, Int, Double)]
  reduction : Array[(Int, Int)]
  longest : Int
}

///|
/// Two graphs the reference was asked whether match.
pub(all) struct IsoCase {
  name : String
  a : Array[(Int, Int)]
  b : Array[(Int, Int)]
  isomorphic : Bool
}

///|
/// A degree sequence read through the graphical or multigraphical test.
pub(all) struct StructCase {
  kind : String
  degrees : Array[Int]
  holds : Bool
}

///|
/// In- and out-degree pairs read through the digraphical test.
pub(all) struct DigraphicalCase {
  degrees : Array[(Int, Int)]
  holds : Bool
}

///|
/// A graph operation and the size of its result.
pub(all) struct OpCase {
  name : String
  graph : WeightedCase
  partner : WeightedCase
  nodes : Int
  edges : Int
}

///|
/// A named generator and the graph it produces.
pub(all) struct GenCase {
  name : String
  size : Int
  nodes : Int
  edges : Int
}

///|
/// A graph in one of the read formats, with the counts the reference records for it and
/// the graph itself, so a writer can be held to the text byte for byte.
pub(all) struct IoCase {
  format : String
  directed : Bool
  text : String
  nodes : Int
  edges : Int
  graph : WeightedCase
}

///|
/// A graph and the Weisfeiler-Lehman fingerprint the reference takes of it.
pub(all) struct WlCase {
  graph : WeightedCase
  hex : String
}

///|
/// A graph as a GraphML document, with the counts it carries.
pub(all) struct GraphmlCase {
  text : String
  nodes : Int
  edges : Int
}

///|
/// A graph and the vertex cover: the nodes the cover touches, smallest first.
pub(all) struct ApproxCase {
  name : String
  nodes : Int
  directed : Bool
  arcs : Array[(Int, Int, Double)]
  cover : Array[Int]
}

///|
/// A board, the ends of the walk, and the cheapest cost of a route, `-1` when there is none.
pub(all) struct BoardCase {
  name : String
  width : Int
  height : Int
  blocked : Array[Int]
  start : Int
  goal : Int
  cost : Double
}

///|
/// A flow network, the flow it carries now, and what it carries after each capacity increase.
pub(all) struct IncrementalCase {
  name : String
  nodes : Int
  edges : Array[(Int, Int, Double)]
  source : Int
  sink : Int
  first : Double
  changes : Array[(Int, Double)]
  after : Array[Double]
  cut : Double
}

///|
/// A network with a price per unit, and the cheapest total for every whole amount of flow.
pub(all) struct CostFlowCase {
  name : String
  nodes : Int
  edges : Array[(Int, Int, Double, Double)]
  source : Int
  sink : Int
  curve : Array[(Double, Double)]
}
"""


if __name__ == "__main__":
    sys.exit(main())
