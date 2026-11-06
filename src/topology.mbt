///|
/// What every algorithm needs from a graph.
///
/// `neighbors` and `incident` are parallel: position `i` of each describes one
/// edge leaving `node`, so a walk that only wants nodes allocates nothing and a
/// walk that wants weights reads both. In an undirected graph an edge appears at
/// both of its endpoints, and a self-loop appears once.
///
/// A third party's storage joins the family by implementing this trait: no
/// algorithm in this library names a concrete graph type.
pub(open) trait Topology {
  /// How many nodes the graph has. Node numbers run from `0` to this minus one,
  /// except in `StableGraph`, where a deleted node leaves a vacant number and is
  /// not counted.
  fn node_count(Self) -> Int32
  /// How many edges the graph has. Edge numbers need not be below this: a graph
  /// that deleted an edge keeps the number vacant.
  fn edge_count(Self) -> Int32
  /// Whether the graph is directed.
  fn directed(Self) -> Bool
  /// The nodes reachable from `node` along the edges leaving it, one entry per
  /// edge, in the same order as `incident`. Parallel edges therefore repeat the
  /// neighbour.
  fn neighbors(Self, Int32) -> ArrayView[Int32]
  /// The edges leaving `node`, one entry per edge, in the same order as
  /// `neighbors`.
  fn incident(Self, Int32) -> ArrayView[Int32]
  /// The two endpoints of an edge, source first in a directed graph.
  fn endpoints(Self, Int32) -> (Int32, Int32)
}

///|
/// A graph that can also walk its edges backwards.
///
/// `Graph`, `StableGraph` and `Csr` keep both directions, so starting such a
/// walk costs O(1) and allocates nothing. An implementation that keeps only the
/// forward direction can still satisfy the trait by building the list on demand,
/// at O(d) per call.
pub(open) trait Inbound {
  /// The nodes with an edge into `node`, in the same order as `in_incident`.
  fn in_neighbors(Self, Int32) -> ArrayView[Int32]
  /// The edges into `node`.
  fn in_incident(Self, Int32) -> ArrayView[Int32]
}
