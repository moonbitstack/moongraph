// The one thing the families need from a disjoint set that moonstl's `DisjointSet`
// does not hand over: a partition pre-filled with a known number of singletons,
// which is the shape an algorithm that labels nodes by number wants on entry.
// Everything else, including the copy an enumeration branches on, is moonstl's.

///|
/// A `DisjointSet` with `count` singletons `0 .. count - 1`.
pub fn disjoint_new(count : Int32) -> @moonstl.DisjointSet {
  let sets = @moonstl.DisjointSet::new()
  for _ in 0..<count {
    sets.add() |> ignore
  }
  sets
}
