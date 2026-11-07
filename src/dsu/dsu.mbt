// The disjoint-set forest, as the textbook writes it: two operations and a walk home.
//
// The forest is moonstl's `DisjointSet` — path compression and union by size already in it —
// behind a face that numbers the elements 0 .. count - 1 and names the operations `union`,
// `find`, `same`, `size`. Nothing here re-implements the structure; this is the public shape
// the graph families and a caller reach for, and the one the module documents.

///|
/// A disjoint-set forest over the numbers `0 .. count - 1`.
///
/// `union` merges the pieces two numbers are in, `find` says which piece a number is in now,
/// and `same` answers the question most graph algorithms actually ask. A sequence of `m`
/// operations over `n` numbers costs `O(m α(n))` amortised, `α` being the inverse of
/// Ackermann's function and never above 4 for any input that fits in memory.
pub struct Dsu {
  sets : @moonstl.DisjointSet
}

///|
/// A forest of `count` pieces, each holding one number.
pub fn Dsu::new(count : Int32) -> Dsu {
  let sets = @moonstl.DisjointSet::new()
  for _ in 0..<count {
    sets.add() |> ignore
  }
  { sets, }
}

///|
/// The representative of the piece `node` is in. Two numbers are in the same piece exactly
/// when their representatives are equal.
pub fn Dsu::find(self : Dsu, node : Int32) -> Int32 {
  self.sets.find(node)
}

///|
/// Joins the pieces `a` and `b` are in, and answers whether they were apart — `false` when the
/// two were already in one piece, which is what a spanning-tree walk counts with.
pub fn Dsu::union(self : Dsu, a : Int32, b : Int32) -> Bool {
  self.sets.union(a, b)
}

///|
/// Whether `a` and `b` are in the same piece.
pub fn Dsu::same(self : Dsu, a : Int32, b : Int32) -> Bool {
  self.sets.connected(a, b)
}

///|
/// How many numbers the piece `node` is in holds.
pub fn Dsu::size(self : Dsu, node : Int32) -> Int32 {
  self.sets.component_size(node)
}

///|
/// How many pieces are left.
pub fn Dsu::count(self : Dsu) -> Int32 {
  self.sets.set_count()
}

///|
/// Every piece, as the numbers it holds in ascending order; the pieces themselves in the order
/// their smallest number appears.
pub fn Dsu::groups(self : Dsu) -> Array[Array[Int32]] {
  self.sets.to_sets()
}

///|
/// How many numbers the forest was built for.
pub fn Dsu::length(self : Dsu) -> Int32 {
  self.sets.length()
}
