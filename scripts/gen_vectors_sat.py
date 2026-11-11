#!/usr/bin/env python3
"""Generate src/internal/vectors_sat.mbt from a reference SAT solver.

The library answers two-variable clauses by reading an implication graph; the reference here
is a general CDCL solver, which knows nothing about the two-variable case and decides the same
instances from the clauses alone. A two-variable instance can have many models, so the vector
records the two things every model agrees on — whether one exists, and which variables are
true (or false) in all of them — and not the one model the solver happened to return, which
another run of the same solver is free to change.

The version is pinned here and in CI: a solver upgrade may answer a different instance the
same way, and a vector that moved under the test suite would say nothing.

Run from the repository root:  python3 scripts/gen_vectors_sat.py
"""

from __future__ import annotations

import random
from pathlib import Path

from pysat.solvers import Solver

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "src" / "internal" / "vectors_sat.mbt"

# The pinned reference. `m22` is MiniSat 2.2, the solver the reference package ships first.
REFERENCE = "m22"


def literal(variable: int, value: bool) -> int:
    """The reference's numbering: variable `i` is the integer `i + 1`, positive when true."""
    return variable + 1 if value else -(variable + 1)


def clause_of(clause) -> list[int]:
    i, f, j, g = clause
    return [literal(i, f), literal(j, g)]


def solve(count: int, clauses) -> dict:
    encoded = [clause_of(clause) for clause in clauses]
    with Solver(name=REFERENCE, bootstrap_with=encoded) as solver:
        satisfiable = solver.solve()
        model = solver.get_model() if satisfiable else None
        forced_true: list[int] = []
        forced_false: list[int] = []
        # An unsatisfiable instance implies every literal, which says nothing; only a
        # satisfiable one has variables that every model agrees on.
        if satisfiable:
            for variable in range(count):
                if not solver.solve(assumptions=[literal(variable, True)]):
                    forced_false.append(variable)
                elif not solver.solve(assumptions=[literal(variable, False)]):
                    forced_true.append(variable)
    if satisfiable:
        accepted = set(model)
        for clause in encoded:
            if not any(value in accepted for value in clause):
                raise SystemExit(f"the reference returned a model that misses {clause}")
        for variable in forced_true:
            if variable + 1 not in accepted:
                raise SystemExit(f"variable {variable} is forced true but the model says false")
        for variable in forced_false:
            if -(variable + 1) not in accepted:
                raise SystemExit(f"variable {variable} is forced false but the model says true")
    return {
        "satisfiable": satisfiable,
        "forced_true": forced_true,
        "forced_false": forced_false,
    }


def seeded(count: int, count_of_clauses: int, seed: str) -> list[tuple[int, bool, int, bool]]:
    """A random two-variable instance: each clause picks two variables and a sign each.

    The pairs are drawn without replacement, so a clause is never `x or x`, which is a unit
    clause in disguise and would be a different family of instance.
    """
    rng = random.Random(seed)
    clauses = []
    for _ in range(count_of_clauses):
        i = rng.randrange(count)
        j = rng.randrange(count - 1)
        if j >= i:
            j += 1
        clauses.append((i, rng.random() < 0.5, j, rng.random() < 0.5))
    return clauses


CASES = [
    ("no-clauses", 3, []),
    ("single-clause", 2, [(0, True, 1, False)]),
    ("both-ways", 1, [(0, True, 0, False)]),
    ("contradiction", 1, [(0, True, 0, True), (0, False, 0, False)]),
    ("implication-chain", 4, [(0, True, 1, True), (1, True, 2, True), (2, True, 3, True)]),
    (
        "two-pieces",
        4,
        [(0, True, 1, False), (1, True, 0, False), (2, True, 3, False), (3, True, 2, False)],
    ),
    (
        "odd-ring",
        3,
        [(0, True, 1, True), (1, True, 2, True), (2, True, 0, True)],
    ),
    (
        "even-ring",
        4,
        [(0, True, 1, True), (1, True, 2, True), (2, True, 3, True), (3, True, 0, True)],
    ),
    ("forced-both", 3, [(0, True, 0, True), (1, False, 1, False), (0, True, 1, False)]),
    ("random-8-sat", 8, seeded(8, 8, "sat-8")),
    ("random-8-heavy", 8, seeded(8, 20, "sat-8-heavy")),
    ("random-12", 12, seeded(12, 14, "sat-12")),
    ("random-12-heavy", 12, seeded(12, 40, "sat-12-heavy")),
    ("random-30", 30, seeded(30, 32, "sat-30")),
    ("random-60-sparse", 60, seeded(60, 55, "sat-60")),
]


def clauses_of(clauses) -> str:
    rows = ", ".join(
        f"({i}, {'true' if f else 'false'}, {j}, {'true' if g else 'false'})" for i, f, j, g in clauses
    )
    return "[" + rows + "]"


def numbers(values) -> str:
    return "[" + ", ".join(str(v) for v in values) + "]"


def flags(values) -> str:
    return "[" + ", ".join("true" if v else "false" for v in values) + "]"


def main() -> int:
    rows = []
    for name, count, clauses in CASES:
        answer = solve(count, clauses)
        rows.append(
            "    {\n"
            f'      name: "{name}",\n'
            f"      variables: {count},\n"
            f"      clauses: {clauses_of(clauses)},\n"
            f"      satisfiable: {'true' if answer['satisfiable'] else 'false'},\n"
            f"      forced_true: {numbers(answer['forced_true'])},\n"
            f"      forced_false: {numbers(answer['forced_false'])},\n"
            "    }"
        )
    header = f"""// Generated by scripts/gen_vectors_sat.py from python-sat 1.8.dev24 ({REFERENCE}). Do not edit.
//
// Each case is a two-variable instance and what a general CDCL solver answers on it: whether
// a model exists, and which variables every model agrees on. A clause whose two halves are the
// same variable is a unit clause, which the reference reads as the degenerate case of the same
// question.

///|
/// A two-variable instance and the reference solver's reading of it.
pub(all) struct SatCase {{
  name : String
  variables : Int32
  clauses : Array[(Int32, Bool, Int32, Bool)]
  satisfiable : Bool
  forced_true : Array[Int32]
  forced_false : Array[Int32]
}}

///|
/// The cases, one instance each.
pub fn sat_cases() -> Array[SatCase] {{
  [
"""
    text = header + ",\n".join(rows) + ",\n  ]\n}\n"
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print(f"wrote {OUT.relative_to(ROOT)}: {len(CASES)} cases")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
