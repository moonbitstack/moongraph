///|
/// A read-only snapshot of a graph in compressed adjacency form: one flat array
/// of neighbours per direction, with an offset per node.
///
/// Building costs one pass and one sort; every later `neighbors` call is a slice
/// of the flat array, which is what makes this the type to hand to an algorithm
/// that walks the same graph a million times. An undirected edge sits in both
/// directions, and each node's slice is sorted by target and then by edge number,
/// so two walks over the same edges visit them in the same order.
///
/// Edge numbers are the snapshot's own, dense from 0 and in the order the source
/// graph reported them.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Int] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2)],
///     node=(),
///     edge=0,
///   )
///   let csr = @moongraph.Csr::from(g)
///   assert_eq(csr.node_count(), 3)
///   assert_eq(csr.neighbors(1), [0, 2][:])
///   assert_eq(csr.in_neighbors(2), [1][:])
/// }
/// ```
pub struct Csr[N, E] {
  directed : Bool
  n : Int
  node_payload : Array[N]
  edge_payload : Array[E]
  froms : Array[Int]
  tos : Array[Int]
  f_off : Array[Int]
  f_nbr : Array[Int]
  f_eid : Array[Int]
  r_off : Array[Int]
  r_nbr : Array[Int]
  r_eid : Array[Int]
  scratch : Array[Int]
}

///|
/// Builds the snapshot from a `Graph`.
pub fn[N, E] Csr::from(graph : Graph[N, E]) -> Csr[N, E] {
  let n = graph.node_count()
  let payload : Array[E] = []
  let froms : Array[Int] = []
  let tos : Array[Int] = []
  for eid in graph.edges() {
    payload.push(graph.edge_data(eid))
    let (from, to) = graph.endpoints(eid)
    froms.push(from)
    tos.push(to)
  }
  let nodes : Array[N] = []
  for node in graph.nodes() {
    nodes.push(graph.node_data(node))
  }
  Csr::assemble(graph.directed(), nodes, n, payload, froms, tos)
}

///|
/// Builds the snapshot from a `StableGraph`. Vacant numbers stay vacant: the
/// snapshot keeps the same node numbering, which is the point of the stable form.
pub fn[N, E] Csr::from_stable(graph : StableGraph[N, E]) -> Csr[N, E] {
  let n = graph.slot_count()
  let payload : Array[E] = []
  let froms : Array[Int] = []
  let tos : Array[Int] = []
  for eid in graph.edges() {
    payload.push(graph.edge_data(eid))
    let (from, to) = graph.endpoints(eid)
    froms.push(from)
    tos.push(to)
  }
  let nodes : Array[N] = []
  for node in 0..<n {
    nodes.push(graph.slot_data(node))
  }
  Csr::assemble(graph.directed(), nodes, n, payload, froms, tos)
}

///|
/// The one place that lays out the flat arrays: count the degree, then fill each
/// slice and sort it.
fn[N, E] Csr::assemble(
  directed : Bool,
  nodes : Array[N],
  n : Int,
  payload : Array[E],
  froms : Array[Int],
  tos : Array[Int],
) -> Csr[N, E] {
  let forward : Array[Array[(Int, Int)]] = Array::makei(n, fn(_) {
    ([] : Array[(Int, Int)])
  })
  let reverse : Array[Array[(Int, Int)]] = Array::makei(n, fn(_) {
    ([] : Array[(Int, Int)])
  })
  for eid in 0..<froms.length() {
    let from = froms[eid]
    let to = tos[eid]
    if from >= 0 && from < n && to >= 0 && to < n {
      forward[from].push((to, eid))
      reverse[to].push((from, eid))
      if !directed && from != to {
        forward[to].push((from, eid))
        reverse[from].push((to, eid))
      }
    }
  }
  let f_off : Array[Int] = [0]
  let f_nbr : Array[Int] = []
  let f_eid : Array[Int] = []
  for node in 0..<n {
    let list = forward[node]
    list.sort_by(fn(a, b) {
      if a.0 != b.0 {
        a.0 - b.0
      } else {
        a.1 - b.1
      }
    })
    for (nbr, eid) in list {
      f_nbr.push(nbr)
      f_eid.push(eid)
    }
    f_off.push(f_nbr.length())
  }
  let r_off : Array[Int] = [0]
  let r_nbr : Array[Int] = []
  let r_eid : Array[Int] = []
  for node in 0..<n {
    let list = reverse[node]
    list.sort_by(fn(a, b) {
      if a.0 != b.0 {
        a.0 - b.0
      } else {
        a.1 - b.1
      }
    })
    for (nbr, eid) in list {
      r_nbr.push(nbr)
      r_eid.push(eid)
    }
    r_off.push(r_nbr.length())
  }
  Csr::{
    directed,
    n,
    node_payload: nodes,
    edge_payload: payload,
    froms,
    tos,
    f_off,
    f_nbr,
    f_eid,
    r_off,
    r_nbr,
    r_eid,
    scratch: [],
  }
}

///|
/// The payload of a node.
pub fn[N, E] Csr::node_data(self : Csr[N, E], node : Int) -> N {
  self.node_payload[node]
}

///|
/// The payload of an edge.
pub fn[N, E] Csr::edge_data(self : Csr[N, E], edge : Int) -> E {
  self.edge_payload[edge]
}

///|
/// A weight function over edge numbers, derived from one over payloads.
pub fn[N, E] Csr::weights(
  self : Csr[N, E],
  of : (E) -> Double,
) -> (Int) -> Double {
  fn(edge) { of(self.edge_payload[edge]) }
}

///|
/// Back to a mutable graph carrying the same payloads and the same numbering.
pub fn[N, E] Csr::to_graph(self : Csr[N, E]) -> Graph[N, E] {
  let g : Graph[N, E] = Graph::new(directed=self.directed)
  for node in 0..<self.n {
    g.add_node(self.node_payload[node]) |> ignore
  }
  for eid in 0..<self.froms.length() {
    g.add_edge(self.froms[eid], self.tos[eid], self.edge_payload[eid]) |> ignore
  }
  g
}

///|
pub impl[N, E] Topology for Csr[N, E] with node_count(self) {
  self.n
}

///|
pub impl[N, E] Topology for Csr[N, E] with edge_count(self) {
  self.froms.length()
}

///|
pub impl[N, E] Topology for Csr[N, E] with directed(self) {
  self.directed
}

///|
pub impl[N, E] Topology for Csr[N, E] with neighbors(self, node) {
  if node < 0 || node >= self.n {
    return self.scratch.exact_view(start=0, end=0)
  }
  let start = self.f_off[node]
  let stop = self.f_off[node + 1]
  self.f_nbr.exact_view(start=start, end=stop)
}

///|
pub impl[N, E] Topology for Csr[N, E] with incident(self, node) {
  if node < 0 || node >= self.n {
    return self.scratch.exact_view(start=0, end=0)
  }
  let start = self.f_off[node]
  let stop = self.f_off[node + 1]
  self.f_eid.exact_view(start=start, end=stop)
}

///|
pub impl[N, E] Topology for Csr[N, E] with endpoints(self, edge) {
  if edge < 0 || edge >= self.froms.length() {
    return (-1, -1)
  }
  (self.froms[edge], self.tos[edge])
}

///|
pub impl[N, E] Inbound for Csr[N, E] with in_neighbors(self, node) {
  if node < 0 || node >= self.n {
    return self.scratch.exact_view(start=0, end=0)
  }
  let start = self.r_off[node]
  let stop = self.r_off[node + 1]
  self.r_nbr.exact_view(start=start, end=stop)
}

///|
pub impl[N, E] Inbound for Csr[N, E] with in_incident(self, node) {
  if node < 0 || node >= self.n {
    return self.scratch.exact_view(start=0, end=0)
  }
  let start = self.r_off[node]
  let stop = self.r_off[node + 1]
  self.r_eid.exact_view(start=start, end=stop)
}

///|
pub extend Csr with Topology::{ node_count, edge_count, directed, neighbors, incident, endpoints }

///|
pub extend Csr with Inbound::{ in_neighbors, in_incident }
