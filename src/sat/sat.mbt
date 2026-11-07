// Two-satisfiability: every clause touches at most two variables, so the question is whether a
// graph has a consistent orientation, and the graph is the implication graph of the clauses.
//
// The classical reduction: a clause (x = f) OR (y = g) is the pair of implications
// (x != f) -> (y = g) and (y != g) -> (x = f). The clauses are satisfiable exactly when no
// variable and its negation fall in the same strongly connected piece, which is what
// `answer` asks. The solution it returns is the one AtCoder's `TwoSat` returns: read the
// pieces in the order the search closes them, and a literal is true when its piece closes
// before its negation's.

///|
/// A two-satisfiability instance over `count` boolean variables.
///
/// `add_clause` states that one of two literals holds; `satisfiable` asks whether some
/// assignment makes every clause true, and `answer` hands one back. Building the clauses costs
/// `O(1)` each, and the question costs `O(n + m)` once, `n` variables and `m` clauses, because
/// it is a strongly-connected-components pass over `2n` nodes.
pub struct TwoSat {
  count : Int32
  graph : @moongraph.Graph[Unit, Unit]
}

///|
/// An instance over `count` variables with no clauses yet.
pub fn TwoSat::new(count : Int32) -> TwoSat {
  let graph : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new(
    directed=true,
  )
  for _ in 0..<(2 * count) {
    graph.add_node(()) |> ignore
  }
  { count, graph, }
}

///|
/// The node standing for the literal "variable `variable` is `value`".
///
/// Variable `i` owns nodes `2i` (true) and `2i + 1` (false), the layout AtCoder's `TwoSat`
/// uses, so the two literal nodes of a variable are neighbours in number.
fn literal(variable : Int32, value : Bool) -> Int32 {
  if value {
    2 * variable
  } else {
    2 * variable + 1
  }
}

///|
/// Adds the clause "(variable `i` is `f`) or (variable `j` is `g`)".
pub fn TwoSat::add_clause(
  self : TwoSat,
  i : Int32,
  f : Bool,
  j : Int32,
  g : Bool,
) -> Unit {
  // (x != f) -> (y = g), and (y != g) -> (x = f).
  self.graph.add_edge(literal(i, !f), literal(j, g), ()) |> ignore
  self.graph.add_edge(literal(j, !g), literal(i, f), ()) |> ignore
}

///|
/// An assignment that satisfies every clause, or `None` when none exists.
///
/// The answer is the classical one: a literal is true when the piece it belongs to closes
/// before the piece of its negation, because a piece that closes early is a sink of the
/// implication graph, and only a literal that can be made true sits downstream of its own
/// negation.
pub fn TwoSat::answer(self : TwoSat) -> Array[Bool]? {
  let pieces = @component.strong_components(self.graph)
  for variable in 0..<self.count {
    if pieces.label[2 * variable] == pieces.label[2 * variable + 1] {
      // The variable and its negation are one piece: no orientation is consistent.
      return None
    }
  }
  let out : Array[Bool] = Array::make(self.count, false)
  for variable in 0..<self.count {
    out[variable] = pieces.label[2 * variable] < pieces.label[2 * variable + 1]
  }
  Some(out)
}

///|
/// Whether some assignment makes every clause true.
pub fn TwoSat::satisfiable(self : TwoSat) -> Bool {
  match self.answer() {
    Some(_) => true
    None => false
  }
}
