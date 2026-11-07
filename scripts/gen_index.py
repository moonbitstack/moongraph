#!/usr/bin/env python3
"""Fill the home page's generated blocks from the compiler's interface files.

The page has two places that must agree with the code: the package index, which lists every
package with its function count and what it answers, and the dense API index at the bottom.
Both are written from `src/*/pkg.generated.mbti`, so neither can drift from the library.

    python3 scripts/gen_index.py

Run it after `moon info`. The build checks the same thing for the reference page.
"""

from __future__ import annotations

import html
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# The order the families are read in, which is also the order a learner meets them.
PACKAGES = [
    ("traverse", "src/traverse", "walks, trees, distances"),
    ("path", "src/path", "shortest routes, contraction hierarchies"),
    ("grid", "src/grid", "board search: BFS, A*, JPS, Theta*, D* Lite"),
    ("flow", "src/flow", "max flow, min cost, cuts"),
    ("matching", "src/matching", "pairings, assignments, covers"),
    ("color", "src/color", "colouring, edge colouring, chromatic number"),
    ("clique", "src/clique", "cliques, independent sets, chordality"),
    ("approx", "src/approx", "tours, covers, spanners, treewidth bounds"),
    ("component", "src/component", "pieces, SCC in order, condensation"),
    ("dag", "src/dag", "topological orders, closures, dominance"),
    ("cycle", "src/cycle", "cycles, girth, Euler walks, postman"),
    ("tree", "src/tree", "spanning trees, Steiner, centres, LCA"),
    ("centrality", "src/centrality", "degree, closeness, betweenness, PageRank"),
    ("community", "src/community", "Louvain, Leiden, label propagation"),
    ("metric", "src/metric", "density, distance, clustering, accessibility"),
    ("struct", "src/struct", "what kind of graph this is"),
    ("iso", "src/iso", "isomorphism, and the mapping"),
    ("op", "src/op", "unions, products, contraction, nmap, closure"),
    ("gen", "src/gen", "named graphs, and the random families"),
    ("io", "src/io", "edge lists, adjacency lists, GML, graph6"),
    ("io/graphml", "src/io/graphml", "GraphML, on an XML parser"),
    ("dsu", "src/dsu", "the disjoint-set forest"),
    ("sat", "src/sat", "two-variable clauses"),
]

SIGNATURE = re.compile(r"pub fn\s*(?:\[[^\]]*\]\s*)?([A-Za-z_]\w*(?:::[A-Za-z_]\w*)?)\s*\(([^)]*)\)")


def signatures(mbti_path: str):
    """Every public function in one interface file, as (name, arguments)."""
    if not os.path.exists(mbti_path):
        return []
    out = []
    for line in io.open(mbti_path, encoding="utf-8").read().splitlines():
        line = line.strip()
        if not line.startswith("pub fn"):
            continue
        match = SIGNATURE.match(line)
        if match:
            out.append((match.group(1), match.group(2).strip()))
    return out


def main() -> int:
    rows = []
    blocks = []
    total = 0
    missing = []

    for shown, path, blurb in PACKAGES:
        functions = signatures(os.path.join(ROOT, path, "pkg.generated.mbti"))
        if not functions:
            missing.append(shown)
            continue
        total += len(functions)

        leaf = shown.split("/")[-1]
        rows.append(
            f'      <a class="pkg-row" href="api.html#{html.escape(leaf)}">'
            f'<span class="p">{html.escape(shown)}</span>'
            f'<span class="a">{html.escape(blurb)}</span>'
            f'<span class="c">{len(functions)}</span></a>'
        )
        items = "".join(
            f'<div class="item"><div class="sig"><span class="name">{html.escape(name)}</span> '
            f'<span class="ty">({html.escape(args)})</span></div></div>'
            for name, args in functions
        )
        blocks.append(
            f'<div class="pkg"><h2>{html.escape(shown)}'
            f'<span class="count">{len(functions)} · {html.escape(blurb)}</span></h2>{items}</div>'
        )

    page = os.path.join(ROOT, "docs", "index.html")
    text = io.open(page, encoding="utf-8").read()

    text = re.sub(
        r"(<div class=\"pkgs\">\n)(.*?)(\n    </div>)",
        lambda m: m.group(1) + "\n".join(rows) + m.group(3),
        text,
        count=1,
        flags=re.S,
    )
    text = re.sub(
        r"(<div class=\"api-grid\">\n)(.*?)(\n    </div>)",
        lambda m: m.group(1) + "\n".join(blocks) + m.group(3),
        text,
        count=1,
        flags=re.S,
    )
    text = re.sub(r'(data-count="packages">)\d+(<)', rf"\g<1>{len(blocks)}\g<2>", text)
    text = re.sub(r'(data-count="functions">)\d+(<)', rf"\g<1>{total}\g<2>", text)

    io.open(page, "w", encoding="utf-8", newline="\n").write(text)
    print(f"index.html: {len(blocks)} packages, {total} functions")
    if missing:
        print("no interface file for: " + ", ".join(missing), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
