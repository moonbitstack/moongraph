#!/usr/bin/env python3
"""Ask a second independent implementation the questions the vectors answer.

`gen_vectors.py` records what NetworkX answers; this script asks rustworkx the same questions on
the same shapes, one family at a time — paths, connectivity, metrics, matching and boards. Where
the two agree, the vector is a fact two mature implementations hold. Where they part company,
the library has to choose a reading, and the choice is listed in the README's consistency
section: a difference that is not on that list fails the run, so a new one cannot arrive
unnoticed.

The shapes, the source numbering, the edge weights and the board builder come from
`gen_vectors.py`, so the two scripts cannot drift apart on what "the same graph" means.

    python3 scripts/compare_references.py            # report and check
    python3 scripts/compare_references.py --verbose  # print every answer, agreeing or not

NetworkX and rustworkx are pinned in CI. Neither is a dependency of the library.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import networkx as nx
import rustworkx as rx

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_vectors import BOARDS, GRAPHS, SOURCES, board_graph, build, octile  # noqa: E402

# The differences that are decisions rather than mistakes, keyed by family and question. Each is
# a paragraph in the README's consistency section; the check below fails on anything else.
DOCUMENTED = {
    ("metrics", "transitivity"): (
        "the transitivity of a directed graph, where NetworkX reads the arcs as edges and "
        "rustworkx counts directed triangles."
    ),
}

FAMILIES = ["paths", "connectivity", "metrics", "matching", "boards"]

# boards is the one family whose shapes are not (name, directed, nodes, arcs).
BOARD_ONLY = {"boards"}


def rx_graph(directed: bool, nodes: int, arcs) -> rx.PyGraph | rx.PyDiGraph:
    """The same graph in rustworkx, with the weight as the edge payload."""
    graph = rx.PyDiGraph(multigraph=False) if directed else rx.PyGraph(multigraph=False)
    graph.add_nodes_from([None] * nodes)
    for a, b, weight in arcs:
        graph.add_edge(a, b, weight)
    return graph


def agree(left: float, right: float, tolerance: float = 1.0e-9) -> bool:
    return abs(left - right) <= tolerance


def same_mapping(left, right) -> bool:
    if set(left) != set(right):
        return False
    return all(agree(left[node], right[node]) for node in left)


def partition(groups) -> list[tuple[int, ...]]:
    """A set of node groups in one shape, so two libraries' pieces can be compared as pieces.

    The order the components come back in is not part of the answer, and neither is how the
    nodes inside one are ordered; a count alone would not notice two libraries splitting the
    same graph in different places.
    """
    return sorted(tuple(sorted(group)) for group in groups)


def path_answers(name, directed, nodes, arcs):
    """Single-source distances from every source on record, by two shortest-path algorithms."""
    graph = build(name, directed, nodes, arcs)
    theirs = rx_graph(directed, nodes, arcs)
    negative = any(weight < 0.0 for _, _, weight in arcs)
    out = []
    if not negative:
        for source in SOURCES:
            mine = dict(nx.single_source_dijkstra_path_length(graph, source, weight="weight"))
            # rustworkx leaves the source out of the mapping; it is zero by definition.
            lengths = (
                rx.digraph_dijkstra_shortest_path_lengths
                if directed
                else rx.dijkstra_shortest_path_lengths
            )
            found = dict(lengths(theirs, source, lambda weight: weight))
            found.setdefault(source, 0.0)
            out.append((f"dijkstra {source}", same_mapping(mine, found), mine, found))
    for source in SOURCES:
        mine = dict(nx.single_source_bellman_ford_path_length(graph, source, weight="weight"))
        lengths = (
            rx.digraph_bellman_ford_shortest_path_lengths
            if directed
            else rx.bellman_ford_shortest_path_lengths
        )
        found = dict(lengths(theirs, source, lambda weight: weight))
        found.setdefault(source, 0.0)
        out.append((f"bellman-ford {source}", same_mapping(mine, found), mine, found))
    return name, out


def connectivity_answers(name, directed, nodes, arcs):
    """Which pieces the graph falls into, and what the cheapest spanning tree weighs."""
    graph = build(name, directed, nodes, arcs)
    theirs = rx_graph(directed, nodes, arcs)
    out = []
    if directed:
        mine = nx.number_weakly_connected_components(graph)
        other = rx.number_weakly_connected_components(theirs)
        out.append(("weak pieces", mine == other, mine, other))
        mine = partition(nx.weakly_connected_components(graph))
        other = partition(rx.weakly_connected_components(theirs))
        out.append(("weak partition", mine == other, mine, other))
        mine = nx.number_strongly_connected_components(graph)
        other = rx.number_strongly_connected_components(theirs)
        out.append(("strong pieces", mine == other, mine, other))
        mine = partition(nx.strongly_connected_components(graph))
        other = partition(rx.strongly_connected_components(theirs))
        out.append(("strong partition", mine == other, mine, other))
    else:
        mine = nx.number_connected_components(graph)
        other = rx.number_connected_components(theirs)
        out.append(("pieces", mine == other, mine, other))
        mine = partition(nx.connected_components(graph))
        other = partition(rx.connected_components(theirs))
        out.append(("partition", mine == other, mine, other))
        if nx.is_connected(graph):
            mine = nx.minimum_spanning_tree(graph, weight="weight").size(weight="weight")
            tree = rx.minimum_spanning_tree(theirs, lambda weight: weight)
            other = sum(weight for _, _, weight in tree.weighted_edge_list())
            out.append(("spanning weight", agree(mine, other), mine, other))
    return name, out


def metric_answers(name, directed, nodes, arcs):
    """The graph-wide measurements the metric and centrality families state."""
    graph = build(name, directed, nodes, arcs)
    theirs = rx_graph(directed, nodes, arcs)
    out = []
    mine = nx.density(graph)
    cells = nodes * (nodes - 1) if directed else nodes * (nodes - 1) / 2
    other = len(theirs.edge_list()) / cells if cells else 0.0
    out.append(("density", agree(mine, other), mine, other))
    mine = nx.transitivity(graph)
    other = rx.digraph_transitivity(theirs) if directed else rx.transitivity(theirs)
    out.append(("transitivity", agree(mine, other), mine, other))
    mine = nx.degree_centrality(graph)
    other = rx.digraph_degree_centrality(theirs) if directed else rx.degree_centrality(theirs)
    out.append(("degree centrality", same_mapping(mine, dict(other)), mine, dict(other)))
    if directed:
        # NetworkX refuses neither of these on a directed graph; on an undirected one the
        # comparison waits for a graph in one piece, which is the only case it defines.
        mine = nx.closeness_centrality(graph)
        other = rx.digraph_closeness_centrality(theirs)
        out.append(("closeness", same_mapping(mine, dict(other)), mine, dict(other)))
        mine = nx.betweenness_centrality(graph, normalized=True)
        other = rx.digraph_betweenness_centrality(theirs, normalized=True)
        out.append(("betweenness", same_mapping(mine, dict(other)), mine, dict(other)))
    elif nx.is_connected(graph):
        mine = nx.closeness_centrality(graph)
        other = rx.closeness_centrality(theirs)
        out.append(("closeness", same_mapping(mine, dict(other)), mine, dict(other)))
        mine = nx.betweenness_centrality(graph, normalized=True)
        other = rx.betweenness_centrality(theirs, normalized=True)
        out.append(("betweenness", same_mapping(mine, dict(other)), mine, dict(other)))
    return name, out


def matching_answers(name, directed, nodes, arcs):
    """The heaviest pairing of nodes, by weight and by how many pairs it holds.

    A heaviest pairing is not unique, so the weight is the answer two implementations must
    agree on; the number of pairs is recorded because a pairing that weighs the same but pairs
    nothing is a different mistake.
    """
    if directed or any(weight < 0.0 for _, _, weight in arcs):
        # rustworkx pairs the nodes of an undirected graph, and weighs edges as integers.
        return name, []
    graph = build(name, directed, nodes, arcs)
    theirs = rx_graph(directed, nodes, arcs)
    mine = nx.max_weight_matching(graph)
    # The weights are read in thousandths, which is finer than any shape on record weighs, so
    # the pairing asked for here is the pairing asked for above.
    scale = 1000
    other = rx.max_weight_matching(theirs, False, lambda weight: int(round(weight * scale)))
    weights = {(min(a, b), max(a, b)): weight for a, b, weight in arcs}
    mine_weight = sum(graph[u][v]["weight"] for u, v in mine)
    other_weight = sum(weights[(min(u, v), max(u, v))] for u, v in other)
    return name, [
        (
            "heaviest pairing",
            agree(mine_weight, other_weight),
            (len(mine), mine_weight),
            (len(other), other_weight),
        )
    ]


def board_answers(name, width, height, blocked, start, goal):
    """The cheapest cost of a route across a board, by both libraries' own searches."""
    graph = board_graph(width, height, blocked)
    # Every cell is a node, walls included and isolated, so a rustworkx node index is the cell
    # number the vectors use.
    theirs = rx.PyGraph(multigraph=False)
    theirs.add_nodes_from([None] * (width * height))
    for a, b, attributes in graph.edges(data=True):
        theirs.add_edge(a, b, attributes["weight"])
    from_cell = start[1] * width + start[0]
    to_cell = goal[1] * width + goal[0]
    mine = None
    if from_cell in graph and to_cell in graph:
        try:
            mine = nx.astar_path_length(
                graph,
                from_cell,
                to_cell,
                heuristic=lambda a, b: octile(a, b, width),
                weight="weight",
            )
        except nx.NetworkXNoPath:
            mine = None
    if from_cell == to_cell and from_cell in graph:
        other = 0.0
    else:
        lengths = dict(rx.dijkstra_shortest_path_lengths(theirs, from_cell, lambda weight: weight))
        other = lengths.get(to_cell)
    if mine is None or other is None:
        return name, [("cheapest route", (mine is None) == (other is None), mine, other)]
    return name, [("cheapest route", agree(mine, other), mine, other)]


ANSWERS = {
    "paths": path_answers,
    "connectivity": connectivity_answers,
    "metrics": metric_answers,
    "matching": matching_answers,
    "boards": board_answers,
}


def cases(family: str):
    """The shapes one family is asked about, in the order its function takes them."""
    if family in BOARD_ONLY:
        return list(BOARDS)
    return [(name, directed, nodes, arcs) for name, directed, nodes, arcs in GRAPHS]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--verbose", action="store_true", help="print every answer, agreeing or not")
    options = parser.parse_args()

    checked = 0
    failed = []
    for family in FAMILIES:
        ask = ANSWERS[family]
        for case in cases(family):
            name, answers = ask(*case)
            for question, same, mine, other in answers:
                checked += 1
                label = f"{family}/{name}/{question}"
                if same:
                    if options.verbose:
                        print(f"  agree  {label}")
                    continue
                if (family, question) in DOCUMENTED:
                    print(f"  known  {label}: {DOCUMENTED[(family, question)]}")
                    continue
                print(
                    f"  DIFFER {label}\n         NetworkX: {str(mine)[:120]}\n"
                    f"         rustworkx: {str(other)[:120]}"
                )
                failed.append(label)

    print(f"\n{checked} answers, {len(failed)} unexplained differences")
    if failed:
        print(
            "A difference is either a bug in one of the two, or a reading this library must "
            "choose and the README must record. Nothing is silently accepted.",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
