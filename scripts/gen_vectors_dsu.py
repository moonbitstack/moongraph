#!/usr/bin/env python3
"""Generate src/internal/vectors_dsu.mbt from a reference union-find.

A merge sequence has no library that answers for it, so the reference is written here: one
label per element, relabelled across the whole piece on a merge. That reading is obvious
enough to be right by construction, and it is slow on purpose — the library under test is the
fast one. Each partition the reference produces is also handed to NetworkX's connected
components, which is a second, unrelated implementation, so a mistake in the reference stops
the generator instead of becoming a vector.

Run from the repository root:  python3 scripts/gen_vectors_dsu.py
"""

from __future__ import annotations

import random
from pathlib import Path

import networkx as nx

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "src" / "internal" / "vectors_dsu.mbt"


class Reference:
    """One label per element; a merge relabels the whole piece it absorbs."""

    def __init__(self, count: int) -> None:
        self.label = list(range(count))

    def union(self, a: int, b: int) -> bool:
        if self.label[a] == self.label[b]:
            return False
        old = self.label[b]
        new = self.label[a]
        for i, value in enumerate(self.label):
            if value == old:
                self.label[i] = new
        return True

    def pieces(self) -> int:
        return len(set(self.label))

    def groups(self) -> list[list[int]]:
        by_label: dict[int, list[int]] = {}
        for i, value in enumerate(self.label):
            by_label.setdefault(value, []).append(i)
        return sorted(by_label.values(), key=lambda group: group[0])

    def sizes(self) -> list[int]:
        by_label: dict[int, int] = {}
        for value in self.label:
            by_label[value] = by_label.get(value, 0) + 1
        return [by_label[value] for value in self.label]


def merge_script(count: int, merges) -> dict:
    """The answers the reference gives for one sequence of merges."""
    reference = Reference(count)
    joined: list[bool] = []
    pieces: list[int] = []
    for a, b in merges:
        joined.append(reference.union(a, b))
        pieces.append(reference.pieces())
    groups = reference.groups()
    check_against_networkx(count, merges, groups)
    return {
        "nodes": count,
        "merges": list(merges),
        "joined": joined,
        "pieces": pieces,
        "groups": groups,
        "sizes": reference.sizes(),
    }


def check_against_networkx(count: int, merges, groups) -> None:
    """The same partition from a graph library: the merges are the edges."""
    graph = nx.Graph()
    graph.add_nodes_from(range(count))
    graph.add_edges_from(merges)
    theirs = sorted(
        (sorted(component) for component in nx.connected_components(graph)),
        key=lambda group: group[0],
    )
    if theirs != groups:
        raise SystemExit(f"the reference and NetworkX disagree on {merges}: {groups} vs {theirs}")


def chain(count: int) -> list[tuple[int, int]]:
    return [(i, i + 1) for i in range(count - 1)]


def star(count: int) -> list[tuple[int, int]]:
    return [(0, i) for i in range(1, count)]


def pairs(count: int) -> list[tuple[int, int]]:
    return [(i, i + 1) for i in range(0, count - 1, 2)]


def seeded(count: int, count_of_merges: int, seed: str) -> list[tuple[int, int]]:
    rng = random.Random(seed)
    return [(rng.randrange(count), rng.randrange(count)) for _ in range(count_of_merges)]


CASES = [
    ("singletons", 6, []),
    ("one-merge", 2, [(0, 1)]),
    ("self-merge", 3, [(0, 0), (1, 1), (0, 1)]),
    ("chain-8", 8, chain(8)),
    ("star-9", 9, star(9)),
    ("pairs-10", 10, pairs(10)),
    ("twice-merged", 5, [(0, 1), (2, 3), (1, 2), (0, 3), (4, 0), (4, 1)]),
    ("reverse-chain", 7, [(i, i - 1) for i in range(6, 0, -1)]),
    ("random-16", 16, seeded(16, 24, "dsu-16")),
    ("random-64", 64, seeded(64, 120, "dsu-64")),
    ("random-100-sparse", 100, seeded(100, 60, "dsu-100")),
    ("random-257", 257, seeded(257, 400, "dsu-257")),
]


def numbers(values) -> str:
    return "[" + ", ".join(str(v) for v in values) + "]"


def groups_of(groups) -> str:
    return "[" + ", ".join(numbers(group) for group in groups) + "]"


def flags(values) -> str:
    return "[" + ", ".join("true" if v else "false" for v in values) + "]"


def pair_list(pairs) -> str:
    return "[" + ", ".join(f"({a}, {b})" for a, b in pairs) + "]"


def main() -> int:
    rows = []
    for name, count, merges in CASES:
        case = merge_script(count, merges)
        rows.append(
            "    {\n"
            f'      name: "{name}",\n'
            f"      nodes: {case['nodes']},\n"
            f"      merges: {pair_list(case['merges'])},\n"
            f"      joined: {flags(case['joined'])},\n"
            f"      pieces: {numbers(case['pieces'])},\n"
            f"      groups: {groups_of(case['groups'])},\n"
            f"      sizes: {numbers(case['sizes'])},\n"
            "    }"
        )
    header = """// Generated by scripts/gen_vectors_dsu.py from a reference union-find. Do not edit.
//
// Each case is a set of numbers and a sequence of merges; the answers are one label per
// element relabelled across the whole piece on every merge, which is correct by
// construction and has nothing in common with the compressed forest that answers in the
// library. The tests replay the merges and compare at every step.

///|
/// A merge sequence over `nodes` numbers, and what the reference partition looks like while
/// and after it runs.
pub(all) struct DsuCase {
  name : String
  nodes : Int32
  merges : Array[(Int32, Int32)]
  joined : Array[Bool]
  pieces : Array[Int32]
  groups : Array[Array[Int32]]
  sizes : Array[Int32]
}

///|
/// The cases, one merge sequence each.
pub fn dsu_cases() -> Array[DsuCase] {
  [
"""
    body = ",\n".join(rows)
    text = header + body + ",\n  ]\n}\n"
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {OUT.relative_to(ROOT)}: {len(CASES)} cases")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
