// Deciding whether two graphs are one graph under a renaming.

///|
/// Whether the two graphs are the same graph with the nodes renamed.
///
/// The search is VF2: it matches one node at a time, and prunes a branch as soon as the
/// degree or the adjacency of the matched part cannot be continued.
///
/// ```mbt check
/// test {
///   let a : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   let b : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(2, 0), (0, 1)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   assert_true(@iso.is_isomorphic(a, b))
/// }
/// ```
pub fn[G : @moongraph.Topology] is_isomorphic(a : G, b : G) -> Bool {
  match vf2_mapping(a, b) {
    Some(_) => true
    None => false
  }
}

///|
/// A renaming that turns the first graph into the second, or `None` when there is none.
pub fn[G : @moongraph.Topology] vf2_mapping(
  a : G,
  b : G,
) -> @moongraph.Mapping? {
  let n = @moongraph.Topology::node_count(a)
  if n != @moongraph.Topology::node_count(b) ||
    @moongraph.Topology::edge_count(a) != @moongraph.Topology::edge_count(b) ||
    @moongraph.Topology::directed(a) != @moongraph.Topology::directed(b) ||
    !same_degrees(a, b) {
    return None
  }
  let map : Array[Int32] = Array::make(n, -1)
  let used : Array[Bool] = Array::make(n, false)
  if search(a, b, map, used, 0) {
    Some({ to: map, })
  } else {
    None
  }
}

///|
/// The degrees of the two graphs, sorted, must agree before any search is worth doing.
fn[G : @moongraph.Topology] same_degrees(a : G, b : G) -> Bool {
  let left : Array[Int32] = []
  let right : Array[Int32] = []
  for node in 0..<@moongraph.Topology::node_count(a) {
    left.push(@internal.distinct_neighbors(a, node).length())
  }
  for node in 0..<@moongraph.Topology::node_count(b) {
    right.push(@internal.distinct_neighbors(b, node).length())
  }
  left.sort()
  right.sort()
  left == right
}

///|
/// One step of the walk: try every free node of the second graph for the next node of the
/// first, keeping only the ones that agree with everything matched so far.
fn[G : @moongraph.Topology] search(
  a : G,
  b : G,
  map : Array[Int32],
  used : Array[Bool],
  at : Int32,
) -> Bool {
  let n = @moongraph.Topology::node_count(a)
  if at == n {
    return true
  }
  for candidate in 0..<n {
    if used[candidate] {
      continue
    }
    if compatible(a, b, map, at, candidate) {
      map[at] = candidate
      used[candidate] = true
      if search(a, b, map, used, at + 1) {
        return true
      }
      used[candidate] = false
      map[at] = -1
    }
  }
  false
}

///|
/// Whether a candidate agrees with every pair already matched: joined to a matched node
/// exactly when the node it is matched to is.
fn[G : @moongraph.Topology] compatible(
  a : G,
  b : G,
  map : Array[Int32],
  node : Int32,
  candidate : Int32,
) -> Bool {
  for other in 0..<node {
    let partner = map[other]
    if partner < 0 {
      continue
    }
    let left = @internal.adjacent(a, node, other)
    let right = @internal.adjacent(b, candidate, partner)
    if left != right {
      return false
    }
  }
  // A self-loop is part of the shape too.
  let loop_a = @internal.adjacent(a, node, node)
  let loop_b = @internal.adjacent(b, candidate, candidate)
  loop_a == loop_b
}

///|
/// A cheap necessary condition: the same number of nodes, edges and the same degree
/// sequence. Two graphs that pass may still differ; two that fail cannot match.
pub fn[G : @moongraph.Topology] could_be_isomorphic(a : G, b : G) -> Bool {
  @moongraph.Topology::node_count(a) == @moongraph.Topology::node_count(b) &&
  @moongraph.Topology::edge_count(a) == @moongraph.Topology::edge_count(b) &&
  same_degrees(a, b)
}

///|
/// The cheapest necessary condition there is: the same node and edge counts.
pub fn[G : @moongraph.Topology] fast_could_be_isomorphic(a : G, b : G) -> Bool {
  @moongraph.Topology::node_count(a) == @moongraph.Topology::node_count(b) &&
  @moongraph.Topology::edge_count(a) == @moongraph.Topology::edge_count(b)
}
