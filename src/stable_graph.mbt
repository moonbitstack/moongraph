///|
/// An adjacency-list graph whose node numbers never change: removing a node
/// leaves its number vacant and occupied numbers stay where they were.
///
/// Use it when you hold node numbers across deletions — an index, a map from
/// something else to a node, a list built in an earlier pass. `Graph` is cheaper
/// when you do not, because it has no vacancy check on the way to the neighbours.
///
/// ```mbt check
/// test {
///   let g : @moongraph.StableGraph[String, Unit] = @moongraph.StableGraph::new()
///   for name in ["a", "b", "c"] {
///     g.add_node(name) |> ignore
///   }
///   g.remove_node(1)
///   assert_eq(g.node_count(), 2)
///   assert_eq(g.is_vacant(1), true)
///   assert_eq(g.highest_node(), Some(2))
/// }
/// ```
pub struct StableGraph[N, E] {
  directed : Bool
  nodes : Array[N]
  node_alive : Array[Bool]
  mut vacant : Int32
  payload : Array[E]
  froms : Array[Int32]
  tos : Array[Int32]
  alive : Array[Bool]
  mut live : Int32
  out_nbrs : Array[Array[Int32]]
  out_eids : Array[Array[Int32]]
  in_nbrs : Array[Array[Int32]]
  in_eids : Array[Array[Int32]]
  empty : Array[Int32]
}

///|
/// An empty graph.
pub fn[N, E] StableGraph::new(directed~ : Bool = true) -> StableGraph[N, E] {
  StableGraph::{
    directed,
    nodes: ([] : Array[N]),
    node_alive: [],
    vacant: 0,
    payload: ([] : Array[E]),
    froms: [],
    tos: [],
    alive: [],
    live: 0,
    out_nbrs: ([] : Array[Array[Int32]]),
    out_eids: ([] : Array[Array[Int32]]),
    in_nbrs: ([] : Array[Array[Int32]]),
    in_eids: ([] : Array[Array[Int32]]),
    empty: [],
  }
}

///|
/// A graph built from `(from, to)` pairs, every node carrying `node` and every
/// edge `edge`.
pub fn[N, E] StableGraph::from_edges(
  edges : Array[(Int32, Int32)],
  node~ : N,
  edge~ : E,
  directed~ : Bool = true,
) -> StableGraph[N, E] {
  let mut highest = -1
  for pair in edges {
    if pair.0 > highest {
      highest = pair.0
    }
    if pair.1 > highest {
      highest = pair.1
    }
  }
  let g : StableGraph[N, E] = StableGraph::new(directed~)
  for _ in 0..<(highest + 1) {
    g.add_node(node) |> ignore
  }
  for pair in edges {
    g.add_edge(pair.0, pair.1, edge) |> ignore
  }
  g
}

///|
/// Adds a node in the lowest vacant number, or at the end when none is vacant,
/// and returns that number.
pub fn[N, E] StableGraph::add_node(self : StableGraph[N, E], data : N) -> Int32 {
  if self.vacant > 0 {
    for node in 0..<self.nodes.length() {
      if !self.node_alive[node] {
        self.nodes[node] = data
        self.node_alive[node] = true
        self.vacant = self.vacant - 1
        return node
      }
    }
  }
  self.nodes.push(data)
  self.node_alive.push(true)
  self.out_nbrs.push([])
  self.out_eids.push([])
  self.in_nbrs.push([])
  self.in_eids.push([])
  self.nodes.length() - 1
}

///|
/// Adds an edge from `from` to `to` carrying `data`, and returns its number.
pub fn[N, E] StableGraph::add_edge(
  self : StableGraph[N, E],
  from : Int32,
  to : Int32,
  data : E,
) -> Int32 {
  let eid = self.froms.length()
  self.froms.push(from)
  self.tos.push(to)
  self.alive.push(true)
  self.payload.push(data)
  self.live = self.live + 1
  let exists = from >= 0 &&
    from < self.nodes.length() &&
    self.node_alive[from] &&
    to >= 0 &&
    to < self.nodes.length() &&
    self.node_alive[to]
  if !exists {
    self.alive[eid] = false
    self.live = self.live - 1
    return eid
  }
  self.out_nbrs[from].push(to)
  self.out_eids[from].push(eid)
  if self.directed {
    self.in_nbrs[to].push(from)
    self.in_eids[to].push(eid)
  } else if from != to {
    self.out_nbrs[to].push(from)
    self.out_eids[to].push(eid)
  }
  eid
}

///|
/// Removes a node and every edge on it, leaving its number vacant.
pub fn[N, E] StableGraph::remove_node(
  self : StableGraph[N, E],
  node : Int32,
) -> Unit {
  if node < 0 || node >= self.nodes.length() || !self.node_alive[node] {
    return
  }
  let incident : Array[Int32] = []
  for eid in self.out_eids[node] {
    incident.push(eid)
  }
  if self.directed {
    for eid in self.in_eids[node] {
      if !incident.contains(eid) {
        incident.push(eid)
      }
    }
  }
  for eid in incident {
    if self.alive[eid] {
      self.remove_edge(eid)
    }
  }
  self.node_alive[node] = false
  self.vacant = self.vacant + 1
}

///|
/// Removes an edge, leaving its number vacant.
pub fn[N, E] StableGraph::remove_edge(
  self : StableGraph[N, E],
  edge : Int32,
) -> Unit {
  if edge < 0 || edge >= self.alive.length() || !self.alive[edge] {
    return
  }
  let from = self.froms[edge]
  let to = self.tos[edge]
  if from >= 0 && from < self.out_eids.length() {
    remove_from(self.out_nbrs[from], self.out_eids[from], edge)
  }
  if self.directed {
    if to >= 0 && to < self.in_eids.length() {
      remove_from(self.in_nbrs[to], self.in_eids[to], edge)
    }
  } else if from != to && to >= 0 && to < self.out_eids.length() {
    remove_from(self.out_nbrs[to], self.out_eids[to], edge)
  }
  self.alive[edge] = false
  self.live = self.live - 1
}

///|
/// Whether a node number is inside the graph and vacant.
pub fn[N, E] StableGraph::is_vacant(
  self : StableGraph[N, E],
  node : Int32,
) -> Bool {
  node >= 0 && node < self.nodes.length() && !self.node_alive[node]
}

///|
/// How many numbers are vacant.
pub fn[N, E] StableGraph::vacant_count(self : StableGraph[N, E]) -> Int32 {
  self.vacant
}

///|
/// How many numbers exist, vacant ones included: one more than the largest
/// number ever handed out.
pub fn[N, E] StableGraph::slot_count(self : StableGraph[N, E]) -> Int32 {
  self.nodes.length()
}

///|
/// The payload in a slot, vacant or not. A vacant slot keeps the payload it had
/// when it was removed, which is what lets a snapshot copy the array whole.
pub fn[N, E] StableGraph::slot_data(
  self : StableGraph[N, E],
  slot : Int32,
) -> N {
  self.nodes[slot]
}

///|
/// The largest occupied node number, or `None` for a graph with no nodes.
pub fn[N, E] StableGraph::highest_node(self : StableGraph[N, E]) -> Int32? {
  let mut at = self.nodes.length() - 1
  while at >= 0 {
    if self.node_alive[at] {
      return Some(at)
    }
    at = at - 1
  }
  None
}

///|
/// Whether a node number is inside the graph and occupied.
pub fn[N, E] StableGraph::contains_node(
  self : StableGraph[N, E],
  node : Int32,
) -> Bool {
  node >= 0 && node < self.nodes.length() && self.node_alive[node]
}

///|
/// Whether the edge exists and has not been removed.
pub fn[N, E] StableGraph::contains_edge(
  self : StableGraph[N, E],
  edge : Int32,
) -> Bool {
  edge >= 0 && edge < self.alive.length() && self.alive[edge]
}

///|
/// The lowest-numbered edge from `from` to `to`.
pub fn[N, E] StableGraph::find_edge(
  self : StableGraph[N, E],
  from : Int32,
  to : Int32,
) -> Int32? {
  if from < 0 || from >= self.out_eids.length() {
    return None
  }
  for eid in self.out_eids[from] {
    let a = self.froms[eid]
    let b = self.tos[eid]
    if self.directed {
      if a == from && b == to {
        return Some(eid)
      }
    } else if (a == from && b == to) || (a == to && b == from) {
      return Some(eid)
    }
  }
  None
}

///|
/// Every edge between the pair, in number order.
pub fn[N, E] StableGraph::find_edges(
  self : StableGraph[N, E],
  from : Int32,
  to : Int32,
) -> Array[Int32] {
  let out : Array[Int32] = []
  if from < 0 || from >= self.out_eids.length() {
    return out
  }
  for eid in self.out_eids[from] {
    let a = self.froms[eid]
    let b = self.tos[eid]
    let hit = if self.directed {
      a == from && b == to
    } else {
      (a == from && b == to) || (a == to && b == from)
    }
    if hit {
      out.push(eid)
    }
  }
  out
}

///|
/// Every occupied node number, ascending.
pub fn[N, E] StableGraph::nodes(self : StableGraph[N, E]) -> Iter[Int32] {
  let total = self.nodes.length()
  let at = [0]
  Iter::new(fn() {
    while at[0] < total && !self.node_alive[at[0]] {
      at[0] = at[0] + 1
    }
    if at[0] < total {
      let node = at[0]
      at[0] = node + 1
      Some(node)
    } else {
      None
    }
  })
}

///|
/// Every live edge number, ascending.
pub fn[N, E] StableGraph::edges(self : StableGraph[N, E]) -> Iter[Int32] {
  let total = self.alive.length()
  let at = [0]
  Iter::new(fn() {
    while at[0] < total && !self.alive[at[0]] {
      at[0] = at[0] + 1
    }
    if at[0] < total {
      let eid = at[0]
      at[0] = eid + 1
      Some(eid)
    } else {
      None
    }
  })
}

///|
/// The payload of an occupied node.
pub fn[N, E] StableGraph::node_data(
  self : StableGraph[N, E],
  node : Int32,
) -> N {
  self.nodes[node]
}

///|
/// The payload of an edge.
pub fn[N, E] StableGraph::edge_data(
  self : StableGraph[N, E],
  edge : Int32,
) -> E {
  self.payload[edge]
}

///|
/// Replaces a node's payload.
pub fn[N, E] StableGraph::set_node_data(
  self : StableGraph[N, E],
  node : Int32,
  data : N,
) -> Unit {
  self.nodes[node] = data
}

///|
/// Replaces an edge's payload.
pub fn[N, E] StableGraph::set_edge_data(
  self : StableGraph[N, E],
  edge : Int32,
  data : E,
) -> Unit {
  self.payload[edge] = data
}

///|
/// A weight function over edge numbers, derived from one over payloads.
pub fn[N, E] StableGraph::weights(
  self : StableGraph[N, E],
  of : (E) -> Double,
) -> (Int32) -> Double {
  fn(edge) { of(self.payload[edge]) }
}

///|
/// An independent copy.
pub fn[N, E] StableGraph::copy(self : StableGraph[N, E]) -> StableGraph[N, E] {
  StableGraph::{
    directed: self.directed,
    nodes: self.nodes.copy(),
    node_alive: self.node_alive.copy(),
    vacant: self.vacant,
    payload: self.payload.copy(),
    froms: self.froms.copy(),
    tos: self.tos.copy(),
    alive: self.alive.copy(),
    live: self.live,
    out_nbrs: copy_lists(self.out_nbrs),
    out_eids: copy_lists(self.out_eids),
    in_nbrs: copy_lists(self.in_nbrs),
    in_eids: copy_lists(self.in_eids),
    empty: [],
  }
}

///|
pub impl[N, E] Topology for StableGraph[N, E] with fn node_count(self) {
  self.nodes.length() - self.vacant
}

///|
pub impl[N, E] Topology for StableGraph[N, E] with fn edge_count(self) {
  self.live
}

///|
pub impl[N, E] Topology for StableGraph[N, E] with fn directed(self) {
  self.directed
}

///|
pub impl[N, E] Topology for StableGraph[N, E] with fn neighbors(self, node) {
  if node < 0 || node >= self.out_nbrs.length() || !self.node_alive[node] {
    return self.empty[:]
  }
  self.out_nbrs[node][:]
}

///|
pub impl[N, E] Topology for StableGraph[N, E] with fn incident(self, node) {
  if node < 0 || node >= self.out_eids.length() || !self.node_alive[node] {
    return self.empty[:]
  }
  self.out_eids[node][:]
}

///|
pub impl[N, E] Topology for StableGraph[N, E] with fn endpoints(self, edge) {
  if edge < 0 || edge >= self.froms.length() {
    return (-1, -1)
  }
  (self.froms[edge], self.tos[edge])
}

///|
pub impl[N, E] Inbound for StableGraph[N, E] with fn in_neighbors(self, node) {
  if node < 0 || node >= self.nodes.length() || !self.node_alive[node] {
    return self.empty[:]
  }
  if !self.directed {
    return self.out_nbrs[node][:]
  }
  self.in_nbrs[node][:]
}

///|
pub impl[N, E] Inbound for StableGraph[N, E] with fn in_incident(self, node) {
  if node < 0 || node >= self.nodes.length() || !self.node_alive[node] {
    return self.empty[:]
  }
  if !self.directed {
    return self.out_eids[node][:]
  }
  self.in_eids[node][:]
}

///|
pub extend StableGraph with Topology::{
  node_count,
  edge_count,
  directed,
  neighbors,
  incident,
  endpoints,
}

///|
pub extend StableGraph with Inbound::{in_neighbors, in_incident}
