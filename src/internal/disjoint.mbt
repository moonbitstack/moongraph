// A disjoint-set forest with path halving and union by rank.
//
// Component labelling, Kruskal, and the connectivity tests all need the same two
// operations; the count of remaining classes is kept so that "is the graph
// connected yet" is O(1) rather than a second pass.

///|
/// A partition of `0 .. count - 1` into singletons, merged on demand.
pub struct UnionFind {
  parent : Array[Int]
  rank : Array[Int]
  mut groups : Int
}

///|
pub fn UnionFind::new(count : Int) -> UnionFind {
  UnionFind::{
    parent: Array::makei(count, fn(i) { i }),
    rank: Array::make(count, 0),
    groups: count,
  }
}

///|
/// The representative of the set holding `node`.
pub fn UnionFind::find(self : UnionFind, node : Int) -> Int {
  let mut at = node
  while self.parent[at] != at {
    let grand = self.parent[self.parent[at]]
    self.parent[at] = grand
    at = grand
  }
  at
}

///|
/// Merges the sets holding the two nodes, and answers whether they were separate.
pub fn UnionFind::union(self : UnionFind, a : Int, b : Int) -> Bool {
  let root_a = self.find(a)
  let root_b = self.find(b)
  if root_a == root_b {
    return false
  }
  if self.rank[root_a] < self.rank[root_b] {
    self.parent[root_a] = root_b
  } else if self.rank[root_a] > self.rank[root_b] {
    self.parent[root_b] = root_a
  } else {
    self.parent[root_b] = root_a
    self.rank[root_a] = self.rank[root_a] + 1
  }
  self.groups = self.groups - 1
  true
}

///|
/// Whether the two nodes are in the same set.
pub fn UnionFind::same(self : UnionFind, a : Int, b : Int) -> Bool {
  self.find(a) == self.find(b)
}

///|
/// An independent copy, for an enumeration that branches on a merge and then needs
/// the state back.
pub fn UnionFind::copy(self : UnionFind) -> UnionFind {
  UnionFind::{
    parent: self.parent.copy(),
    rank: self.rank.copy(),
    groups: self.groups,
  }
}

///|
/// How many sets are left.
pub fn UnionFind::groups(self : UnionFind) -> Int {
  self.groups
}
