// The two things the families need from a disjoint set that moonstl's
// `DisjointSet` does not hand over directly: a partition pre-filled with a known
// number of singletons, and a snapshot of the partition. Everything else is
// moonstl's; these are thin wrappers, not a second union-find.

///|
/// A `DisjointSet` with `count` singletons `0 .. count - 1`, the shape the
/// algorithms that label nodes by number want on entry.
pub fn disjoint_new(count : Int32) -> @moonstl.DisjointSet {
  let sets = @moonstl.DisjointSet::new()
  for _ in 0..<count {
    sets.add() |> ignore
  }
  sets
}

///|
/// A fresh copy of `sets` holding the same partition, for an enumeration that
/// branches on a merge and must restore the partition it had before. moonstl's
/// set is not copyable through its public face, so the partition is read back as
/// groups and rebuilt; the representatives may move, the connectivity does not.
pub fn disjoint_copy(sets : @moonstl.DisjointSet) -> @moonstl.DisjointSet {
  let n = sets.length()
  let copy = @moonstl.DisjointSet::new()
  for _ in 0..<n {
    copy.add() |> ignore
  }
  for members in sets.to_sets() {
    if members.length() > 1 {
      let first = members[0]
      for at in 1..<members.length() {
        copy.union(first, members[at]) |> ignore
      }
    }
  }
  copy
}
