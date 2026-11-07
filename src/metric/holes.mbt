// Structural holes: how much of a node's social capital is spent on itself.

///|
/// The weight joining two nodes, counted both ways: what one has to spend to reach the other
/// plus what the other has to spend to come back. For an undirected graph the two arcs are
/// the same edges, so this is just the weight between them.
fn[G : @moongraph.Topology + @moongraph.Inbound] mutual_weight(
  graph : G,
  from : Int32,
  to : Int32,
  w : (Int32) -> Double,
) -> Double {
  let mut total = 0.0
  let nbrs = @moongraph.Topology::neighbors(graph, from)
  let eids = @moongraph.Topology::incident(graph, from)
  for at in 0..<eids.length() {
    if nbrs[at] == to {
      total = total + w(eids[at])
    }
  }
  if @moongraph.Topology::directed(graph) {
    let back = @moongraph.Inbound::in_neighbors(graph, from)
    let back_eids = @moongraph.Inbound::in_incident(graph, from)
    for at in 0..<back_eids.length() {
      if back[at] == to {
        total = total + w(back_eids[at])
      }
    }
  }
  total
}

///|
/// The share of a node's attention that goes to one neighbour: the mutual weight between
/// them over the mutual weight of all the node's neighbours.
fn[G : @moongraph.Topology + @moongraph.Inbound] attention(
  graph : G,
  from : Int32,
  to : Int32,
  w : (Int32) -> Double,
) -> Double {
  let mut scale = 0.0
  for nbr in both_set(graph, from) {
    scale = scale + mutual_weight(graph, from, nbr, w)
  }
  if scale == 0.0 {
    0.0
  } else {
    mutual_weight(graph, from, to, w) / scale
  }
}

///|
/// Burt's constraint: how much of a node's time is spent on neighbours who are themselves
/// tied to the node's other neighbours. A node whose friends all know each other is
/// constrained — every favour it does travels down the same channels, and it has no way to
/// play one side against the other. A node whose neighbours are strangers to each other sits
/// in a structural hole, and the constraint is low.
///
/// For a node `v` with neighbours `w`, the local constraint on `v` with respect to `w` is
/// `(p(v,w) + Σ p(v,x)·p(x,w))²`, where `p` is the share of mutual weight a node spends on
/// a neighbour, and the constraint is the sum over `w`. An isolated node has no
/// relationships to constrain and answers `None`.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (0, 2), (1, 2), (2, 3)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   // Node 3 has one neighbour, so everything it spends goes through one channel.
///   assert_eq(@metric.constraint(g)[3], Some(1.0))
/// }
/// ```
pub fn[G : @moongraph.Topology + @moongraph.Inbound] constraint(
  graph : G,
  weight? : (Int32) -> Double,
) -> Array[Double?] {
  let w = @internal.take_weight(weight)
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Double?] = Array::make(n, (None : Double?))
  for node in 0..<n {
    let nbrs = both_set(graph, node)
    if nbrs.length() == 0 {
      continue
    }
    let mut total = 0.0
    for other in nbrs {
      let direct = attention(graph, node, other, w)
      let mut indirect = 0.0
      for between in nbrs {
        let share = attention(graph, node, between, w)
        let onward = attention(graph, between, other, w)
        indirect = indirect + share * onward
      }
      let through = direct + indirect
      total = total + through * through
    }
    out[node] = Some(total)
  }
  out
}

///|
/// Effective size: the number of neighbours a node has, discounted by how much those
/// neighbours are tied to each other. A node whose five friends are five strangers has an
/// effective size near five; a node in a clique of five has one near one, because every
/// friend is the same friend.
///
/// The measure is the size of the ego network without the node itself, less twice the edges
/// inside it divided by that size — which is the count of neighbours, each reduced by the
/// share of its relationships that are shared with the others. Isolated nodes answer `None`.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] effective_size(
  graph : G,
  weight? : (Int32) -> Double,
) -> Array[Double?] {
  let w = @internal.take_weight(weight)
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Double?] = Array::make(n, (None : Double?))
  for node in 0..<n {
    let nbrs = both_set(graph, node)
    let size = nbrs.length()
    if size == 0 {
      continue
    }
    // The edges among the neighbours, counted once each and in either direction.
    let mut edges = 0.0
    for i in 0..<size {
      for j in (i + 1)..<size {
        let joined = mutual_weight(graph, nbrs[i], nbrs[j], w)
        if joined > 0.0 {
          edges = edges + 1.0
        }
      }
    }
    out[node] = Some(size.to_double() - 2.0 * edges / size.to_double())
  }
  out
}
