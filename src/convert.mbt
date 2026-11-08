// Conversions: the same graph read with a direction, and the same graph numbered differently.

///|
/// The same graph, made directed: every undirected edge becomes two arcs that point at each
/// other, and a self-loop stays one arc because it already points both ways.
///
/// Node numbers are kept, so an answer indexed by node still names the same node. Edge
/// numbers are reissued in pairs — the `k`-th undirected edge becomes arcs `2k` and `2k+1`,
/// the second pointing back — so the pair is one addition apart. A directed graph is copied
/// as it stands.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   let d = g.to_directed()
///   assert_eq(d.directed(), true)
///   assert_eq(d.edge_count(), 4)
///   assert_eq(d.endpoints(2), (1, 2))
///   assert_eq(d.endpoints(3), (2, 1))
/// }
/// ```
pub fn[N, E] Graph::to_directed(self : Graph[N, E]) -> Graph[N, E] {
  if self.directed {
    return self.copy()
  }
  let out : Graph[N, E] = Graph::new(directed=true)
  for node in 0..<self.node_count() {
    out.add_node(self.node_data(node)) |> ignore
  }
  for eid in self.edges() {
    let (from, to) = self.endpoints(eid)
    let data = self.edge_data(eid)
    out.add_edge(from, to, data) |> ignore
    if from != to {
      out.add_edge(to, from, data) |> ignore
    }
  }
  out
}

///|
/// The same graph, made undirected: two arcs that point at each other become one edge, and
/// an arc with no partner becomes one edge.
///
/// When both directions are present, the edge keeps the payload of the lowest-numbered arc
/// that joins the pair, so the answer does not depend on which direction was added first and
/// two runs over the same graph agree. Node numbers are kept. An undirected graph is copied
/// as it stands.
pub fn[N, E] Graph::to_undirected(self : Graph[N, E]) -> Graph[N, E] {
  if !self.directed {
    return self.copy()
  }
  let out : Graph[N, E] = Graph::new(directed=false)
  for node in 0..<self.node_count() {
    out.add_node(self.node_data(node)) |> ignore
  }
  for eid in self.edges() {
    let (from, to) = self.endpoints(eid)
    match out.find_edge(from, to) {
      Some(_) => ()
      None => out.add_edge(from, to, self.edge_data(eid)) |> ignore
    }
  }
  out
}

///|
/// The same graph with its nodes numbered differently. `labels[old]` is the number the node
/// takes in the answer, and it has to be a permutation of `0..n` — a one-to-one map onto the
/// same range, which is what keeps the result dense and keeps every node's number meaningful
/// without a translation table at the call site.
///
/// Payloads travel with their nodes and edges, and edges are reissued in their original
/// order. To drop nodes instead of renumbering them, use `subgraph`; to renumber a
/// `StableGraph` without losing its vacant slots, do not — that is the one thing the stable
/// storage exists to prevent.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1)],
///     node=0,
///     edge=(),
///     directed=false,
///   )
///   g.set_node_data(0, 7)
///   let flipped = g.relabel([1, 0])
///   assert_eq(flipped.node_data(1), 7)
///   assert_eq(flipped.endpoints(0), (1, 0))
/// }
/// ```
pub fn[N, E] Graph::relabel(
  self : Graph[N, E],
  labels : Array[Int32],
) -> Graph[N, E] raise Refused {
  let n = self.node_count()
  if labels.length() != n {
    let given = "the mapping has " + labels.length().to_string()
    let wanted = " numbers for " + n.to_string() + " nodes"
    raise Refused::NotA(kind="relabel", what=given + wanted)
  }
  let taken : Array[Bool] = Array::make(n, false)
  for label in labels {
    if label < 0 || label >= n {
      let wanted = "0.." + n.to_string()
      raise Refused::NotA(
        kind="relabel",
        what="a label points outside " + wanted,
      )
    }
    if taken[label] {
      let repeated = "two nodes are given the number " + label.to_string()
      raise Refused::NotA(kind="relabel", what=repeated)
    }
    taken[label] = true
  }
  let out : Graph[N, E] = Graph::new(directed=self.directed())
  // Place every node's payload under its new number, found by inverting the mapping.
  for slot in 0..<n {
    let mut source = -1
    for node in 0..<n {
      if labels[node] == slot {
        source = node
      }
    }
    out.add_node(self.node_data(source)) |> ignore
  }
  for eid in self.edges() {
    let (from, to) = self.endpoints(eid)
    out.add_edge(labels[from], labels[to], self.edge_data(eid)) |> ignore
  }
  out
}

///|
/// The same graph, made directed, with its slot numbers kept — vacant slots stay vacant, so a
/// node number means the same thing in both graphs. This is the conversion a `StableGraph`
/// exists for: with `Graph` a copy is already exact, but here keeping the numbering is the
/// whole point.
pub fn[N, E] StableGraph::to_directed(
  self : StableGraph[N, E],
) -> StableGraph[N, E] {
  if self.directed {
    return self.copy()
  }
  let out : StableGraph[N, E] = StableGraph::new(directed=true)
  copy_slots(self, out)
  for eid in self.edges() {
    let (from, to) = self.endpoints(eid)
    let data = self.edge_data(eid)
    out.add_edge(from, to, data) |> ignore
    if from != to {
      out.add_edge(to, from, data) |> ignore
    }
  }
  out
}

///|
/// The same graph, made undirected, with its slot numbers kept. Reciprocal arcs become one
/// edge carrying the payload of the lowest-numbered arc, as in `Graph::to_undirected`.
pub fn[N, E] StableGraph::to_undirected(
  self : StableGraph[N, E],
) -> StableGraph[N, E] {
  if !self.directed {
    return self.copy()
  }
  let out : StableGraph[N, E] = StableGraph::new(directed=false)
  copy_slots(self, out)
  for eid in self.edges() {
    let (from, to) = self.endpoints(eid)
    match out.find_edge(from, to) {
      Some(_) => ()
      None => out.add_edge(from, to, self.edge_data(eid)) |> ignore
    }
  }
  out
}

///|
/// Gives `out` the same slots as `graph`: the same payloads, and the same holes. The slots are
/// added in order first, so no number is reused, and the vacant ones are removed once there is
/// nothing attached to them to take away.
fn[N, E] copy_slots(graph : StableGraph[N, E], out : StableGraph[N, E]) -> Unit {
  let slots = graph.slot_count()
  for slot in 0..<slots {
    out.add_node(graph.slot_data(slot)) |> ignore
  }
  for slot in 0..<slots {
    if graph.is_vacant(slot) {
      out.remove_node(slot)
    }
  }
}
