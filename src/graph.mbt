///|
/// An adjacency-list graph: directed or undirected, parallel edges allowed, one
/// payload per node and one per edge.
///
/// Node numbers are dense and run from 0. Adding a node or an edge never changes
/// an existing number; `remove_node` renumbers every node above the hole, which
/// is why `StableGraph` exists for callers that hold numbers across deletions.
/// Edge numbers are never reused, so an edge number stays valid until that edge
/// is removed.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[String, Double] = @moongraph.Graph::new()
///   let a = g.add_node("a")
///   let b = g.add_node("b")
///   g.add_edge(a, b, 2.5) |> ignore
///   assert_eq(g.node_count(), 2)
///   assert_eq(g.neighbors(a), [b][:])
///   assert_eq(g.edge_data(g.find_edge(a, b).unwrap()), 2.5)
/// }
/// ```
pub struct Graph[N, E] {
  directed : Bool
  nodes : Array[N]
  payload : Array[E]
  froms : Array[Int32]
  tos : Array[Int32]
  alive : Array[Bool]
  mut live : Int32
  mut out_nbrs : Array[Array[Int32]]
  mut out_eids : Array[Array[Int32]]
  mut in_nbrs : Array[Array[Int32]]
  mut in_eids : Array[Array[Int32]]
  empty : Array[Int32]
}

///|
/// An empty graph. `directed` decides how every later edge is read; it cannot be
/// changed afterwards, because the adjacency is stored that way.
pub fn[N, E] Graph::new(directed~ : Bool = true) -> Graph[N, E] {
  Graph::{
    directed,
    nodes: ([] : Array[N]),
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
/// An empty graph with room for the given counts, so that a build loop does not
/// reallocate. The counts are hints; exceeding them is not an error.
pub fn[N, E] Graph::with_capacity(
  nodes? : Int32,
  edges? : Int32,
  directed~ : Bool = true,
) -> Graph[N, E] {
  // The counts are hints the allocator can use; creating the slots here would
  // create nodes and edges that were only meant to be room for them.
  ignore(nodes)
  ignore(edges)
  Graph::new(directed~)
}

///|
/// A graph built from `(from, to)` pairs, every node carrying `node` and every
/// edge `edge`. Nodes are created up to the highest number in the list.
pub fn[N, E] Graph::from_edges(
  edges : Array[(Int32, Int32)],
  node~ : N,
  edge~ : E,
  directed~ : Bool = true,
) -> Graph[N, E] {
  let mut highest = -1
  for pair in edges {
    if pair.0 > highest {
      highest = pair.0
    }
    if pair.1 > highest {
      highest = pair.1
    }
  }
  let g : Graph[N, E] = Graph::with_capacity(
    nodes=highest + 1,
    edges=edges.length(),
    directed~,
  )
  for _ in 0..<(highest + 1) {
    g.add_node(node) |> ignore
  }
  for pair in edges {
    g.add_edge(pair.0, pair.1, edge) |> ignore
  }
  g
}

///|
/// Adds a node and returns its number.
pub fn[N, E] Graph::add_node(self : Graph[N, E], data : N) -> Int32 {
  self.nodes.push(data)
  self.out_nbrs.push([])
  self.out_eids.push([])
  self.in_nbrs.push([])
  self.in_eids.push([])
  self.nodes.length() - 1
}

///|
/// Adds an edge from `from` to `to` carrying `data`, and returns its number. In
/// an undirected graph the edge is reported from both endpoints.
///
/// A negative endpoint is clamped to 0 and one beyond the last node is refused by
/// not creating an edge, because the signature has no error to raise; check the
/// endpoints first when the numbers come from outside.
pub fn[N, E] Graph::add_edge(
  self : Graph[N, E],
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
  self.attach(eid)
  eid
}

///|
/// Appends the adjacency entries of an edge that is already in the parallel
/// arrays. The one place that knows how an edge is stored.
fn[N, E] Graph::attach(self : Graph[N, E], eid : Int32) -> Unit {
  let from = self.froms[eid]
  let to = self.tos[eid]
  if from < 0 ||
    from >= self.out_nbrs.length() ||
    to < 0 ||
    to >= self.out_nbrs.length() {
    self.alive[eid] = false
    self.live = self.live - 1
    return
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
}

///|
/// Removes the adjacency entries of an edge that is still in the parallel arrays.
fn[N, E] Graph::detach(self : Graph[N, E], eid : Int32) -> Unit {
  let from = self.froms[eid]
  let to = self.tos[eid]
  if from < 0 ||
    from >= self.out_nbrs.length() ||
    to < 0 ||
    to >= self.out_nbrs.length() {
    return
  }
  remove_from(self.out_nbrs[from], self.out_eids[from], eid)
  if self.directed {
    remove_from(self.in_nbrs[to], self.in_eids[to], eid)
  } else if from != to {
    remove_from(self.out_nbrs[to], self.out_eids[to], eid)
  }
}

///|
/// Removes the entry for `eid` from one node's edge list, and the neighbour at
/// the same position.
fn remove_from(nbrs : Array[Int32], eids : Array[Int32], eid : Int32) -> Unit {
  let mut at = 0
  let n = eids.length()
  while at < n && eids[at] != eid {
    at = at + 1
  }
  if at < n {
    eids.remove(at) |> ignore
    nbrs.remove(at) |> ignore
  }
}

///|
/// Rebuilds every adjacency list from the edge arrays. Used after a renumbering,
/// where patching lists in place would mean visiting each twice.
fn[N, E] Graph::rebuild(self : Graph[N, E]) -> Unit {
  let n = self.nodes.length()
  self.out_nbrs = ([] : Array[Array[Int32]])
  self.out_eids = ([] : Array[Array[Int32]])
  self.in_nbrs = ([] : Array[Array[Int32]])
  self.in_eids = ([] : Array[Array[Int32]])
  for _ in 0..<n {
    self.out_nbrs.push([])
    self.out_eids.push([])
    self.in_nbrs.push([])
    self.in_eids.push([])
  }
  self.live = 0
  for eid in 0..<self.froms.length() {
    if self.alive[eid] {
      let from = self.froms[eid]
      let to = self.tos[eid]
      if from >= 0 && from < n && to >= 0 && to < n {
        self.live = self.live + 1
        self.out_nbrs[from].push(to)
        self.out_eids[from].push(eid)
        if self.directed {
          self.in_nbrs[to].push(from)
          self.in_eids[to].push(eid)
        } else if from != to {
          self.out_nbrs[to].push(from)
          self.out_eids[to].push(eid)
        }
      } else {
        self.alive[eid] = false
      }
    }
  }
}

///|
/// Removes a node and every edge on it, and renumbers the nodes after it down by
/// one so the numbering stays dense. A number outside the graph is ignored.
///
/// This is the one operation that invalidates node numbers; use `StableGraph` if
/// that matters.
pub fn[N, E] Graph::remove_node(self : Graph[N, E], node : Int32) -> Unit {
  let n = self.nodes.length()
  if node < 0 || node >= n {
    return
  }
  for eid in 0..<self.froms.length() {
    if self.alive[eid] && (self.froms[eid] == node || self.tos[eid] == node) {
      self.alive[eid] = false
    }
  }
  self.nodes.remove(node) |> ignore
  for eid in 0..<self.froms.length() {
    if self.alive[eid] {
      if self.froms[eid] > node {
        self.froms[eid] = self.froms[eid] - 1
      }
      if self.tos[eid] > node {
        self.tos[eid] = self.tos[eid] - 1
      }
    }
  }
  self.rebuild()
}

///|
/// Removes an edge. Its number stays vacant, and the numbers of the other edges
/// do not change. A number outside the graph, or one already removed, is
/// ignored.
pub fn[N, E] Graph::remove_edge(self : Graph[N, E], edge : Int32) -> Unit {
  if edge < 0 || edge >= self.alive.length() || !self.alive[edge] {
    return
  }
  self.detach(edge)
  self.alive[edge] = false
  self.live = self.live - 1
}

///|
/// Removes every node and every edge.
pub fn[N, E] Graph::clear(self : Graph[N, E]) -> Unit {
  self.nodes.clear()
  self.payload.clear()
  self.froms.clear()
  self.tos.clear()
  self.alive.clear()
  self.live = 0
  self.out_nbrs.clear()
  self.out_eids.clear()
  self.in_nbrs.clear()
  self.in_eids.clear()
}

///|
/// Removes every edge, keeping the nodes.
pub fn[N, E] Graph::clear_edges(self : Graph[N, E]) -> Unit {
  self.payload.clear()
  self.froms.clear()
  self.tos.clear()
  self.alive.clear()
  self.live = 0
  for list in self.out_nbrs {
    list.clear()
  }
  for list in self.out_eids {
    list.clear()
  }
  for list in self.in_nbrs {
    list.clear()
  }
  for list in self.in_eids {
    list.clear()
  }
}

///|
/// An independent copy. Payloads are shared, because they are values the caller
/// owns; the structure is not.
pub fn[N, E] Graph::copy(self : Graph[N, E]) -> Graph[N, E] {
  Graph::{
    directed: self.directed,
    nodes: self.nodes.copy(),
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
fn copy_lists(lists : Array[Array[Int32]]) -> Array[Array[Int32]] {
  let out : Array[Array[Int32]] = []
  for list in lists {
    out.push(list.copy())
  }
  out
}

///|
/// A weight function over edge numbers, derived from one over payloads. Pass the
/// result as the `weight` argument of an algorithm.
pub fn[N, E] Graph::weights(
  self : Graph[N, E],
  of : (E) -> Double,
) -> (Int32) -> Double {
  fn(edge) { of(self.payload[edge]) }
}

///|
/// Whether a node number is inside the graph.
pub fn[N, E] Graph::contains_node(self : Graph[N, E], node : Int32) -> Bool {
  node >= 0 && node < self.nodes.length()
}

///|
/// Whether the edge exists and has not been removed.
pub fn[N, E] Graph::contains_edge(self : Graph[N, E], edge : Int32) -> Bool {
  edge >= 0 && edge < self.alive.length() && self.alive[edge]
}

///|
/// The lowest-numbered edge from `from` to `to`, or `None` when there is none. In
/// an undirected graph either direction counts.
pub fn[N, E] Graph::find_edge(
  self : Graph[N, E],
  from : Int32,
  to : Int32,
) -> Int32? {
  if from < 0 || from >= self.out_eids.length() {
    return None
  }
  for eid in self.out_eids[from] {
    if self.matches(eid, from, to) {
      return Some(eid)
    }
  }
  None
}

///|
/// Every edge between the pair, in number order.
pub fn[N, E] Graph::find_edges(
  self : Graph[N, E],
  from : Int32,
  to : Int32,
) -> Array[Int32] {
  let out : Array[Int32] = []
  if from < 0 || from >= self.out_eids.length() {
    return out
  }
  for eid in self.out_eids[from] {
    if self.matches(eid, from, to) {
      out.push(eid)
    }
  }
  out
}

///|
/// Whether an edge is the one between the pair, reading the endpoints the way the
/// graph's direction says to.
fn[N, E] Graph::matches(
  self : Graph[N, E],
  eid : Int32,
  from : Int32,
  to : Int32,
) -> Bool {
  let a = self.froms[eid]
  let b = self.tos[eid]
  if self.directed {
    a == from && b == to
  } else {
    (a == from && b == to) || (a == to && b == from)
  }
}

///|
/// Every node number, ascending.
pub fn[N, E] Graph::nodes(self : Graph[N, E]) -> Iter[Int32] {
  let total = self.nodes.length()
  let at = [0]
  Iter::new(fn() {
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
pub fn[N, E] Graph::edges(self : Graph[N, E]) -> Iter[Int32] {
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
/// The payload of a node. Reading a number outside the graph aborts, which is the
/// only place in this package that does: a payload has no neutral value to give.
pub fn[N, E] Graph::node_data(self : Graph[N, E], node : Int32) -> N {
  self.nodes[node]
}

///|
/// The payload of an edge.
pub fn[N, E] Graph::edge_data(self : Graph[N, E], edge : Int32) -> E {
  self.payload[edge]
}

///|
/// Replaces a node's payload.
pub fn[N, E] Graph::set_node_data(
  self : Graph[N, E],
  node : Int32,
  data : N,
) -> Unit {
  self.nodes[node] = data
}

///|
/// Replaces an edge's payload.
pub fn[N, E] Graph::set_edge_data(
  self : Graph[N, E],
  edge : Int32,
  data : E,
) -> Unit {
  self.payload[edge] = data
}

///|
pub impl[N, E] Topology for Graph[N, E] with fn node_count(self) {
  self.nodes.length()
}

///|
pub impl[N, E] Topology for Graph[N, E] with fn edge_count(self) {
  self.live
}

///|
pub impl[N, E] Topology for Graph[N, E] with fn directed(self) {
  self.directed
}

///|
pub impl[N, E] Topology for Graph[N, E] with fn neighbors(self, node) {
  if node < 0 || node >= self.out_nbrs.length() {
    return self.empty[:]
  }
  self.out_nbrs[node][:]
}

///|
pub impl[N, E] Topology for Graph[N, E] with fn incident(self, node) {
  if node < 0 || node >= self.out_eids.length() {
    return self.empty[:]
  }
  self.out_eids[node][:]
}

///|
pub impl[N, E] Topology for Graph[N, E] with fn endpoints(self, edge) {
  if edge < 0 || edge >= self.froms.length() {
    return (-1, -1)
  }
  (self.froms[edge], self.tos[edge])
}

///|
pub impl[N, E] Inbound for Graph[N, E] with fn in_neighbors(self, node) {
  if !self.directed {
    if node < 0 || node >= self.out_nbrs.length() {
      return self.empty[:]
    }
    return self.out_nbrs[node][:]
  }
  if node < 0 || node >= self.in_nbrs.length() {
    return self.empty[:]
  }
  self.in_nbrs[node][:]
}

///|
pub impl[N, E] Inbound for Graph[N, E] with fn in_incident(self, node) {
  if !self.directed {
    if node < 0 || node >= self.out_eids.length() {
      return self.empty[:]
    }
    return self.out_eids[node][:]
  }
  if node < 0 || node >= self.in_eids.length() {
    return self.empty[:]
  }
  self.in_eids[node][:]
}

///|
pub extend Graph with Topology::{
  node_count,
  edge_count,
  directed,
  neighbors,
  incident,
  endpoints,
}

///|
pub extend Graph with Inbound::{in_neighbors, in_incident}
