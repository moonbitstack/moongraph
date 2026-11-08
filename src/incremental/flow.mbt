// Incremental maximum flow: the network is a value you own, and every change leaves it at a
// maximum flow, so the next question starts where the last answer ended.

///|
/// A flow network you keep. Edges are added one at a time, capacities can be changed after
/// the fact, and every call to `flow` pushes only what the change made possible — the flow
/// already there is the starting point, not something to recompute.
///
/// This is AtCoder's `mf_graph`, with the same three operations: `add_edge`, `change_edge`,
/// and `flow` that returns the amount added rather than the total. The total is the sum over
/// the calls, and `edge_flow` reads it per edge.
pub struct Flow {
  nodes : Int32
  froms : Array[Int32]
  tos : Array[Int32]
  caps : Array[Double]
  flows : Array[Double]
}

///|
/// An empty network on a fixed number of nodes. Nodes are numbered `0..n`; the count is
/// chosen here and never changes, since a flow is a question about one fixed set of places.
pub fn Flow::new(nodes : Int32) -> Flow {
  let size = if nodes < 0 { 0 } else { nodes }
  { nodes: size, froms: [], tos: [], caps: [], flows: [], }
}

///|
/// Adds an edged from one node to another with a capacity, and returns its number. The edge
/// carries no flow to begin with.
pub fn Flow::add_edge(
  self : Flow,
  from : Int32,
  to : Int32,
  capacity : Double,
) -> Int32 raise @moongraph.Refused {
  if from < 0 || from >= self.nodes || to < 0 || to >= self.nodes {
    raise @moongraph.Refused::OutOfRange(node=from)
  }
  if capacity < 0.0 {
    raise @moongraph.Refused::NegativeWeight(edge=self.froms.length())
  }
  let eid = self.froms.length()
  self.froms.push(from)
  self.tos.push(to)
  self.caps.push(capacity)
  self.flows.push(0.0)
  eid
}

///|
/// Replaces one edge's capacity and flow. The flow has to sit between zero and the new
/// capacity, which is what makes the result a flow again; `flow` then pushes whatever the
/// change allows.
pub fn Flow::change_edge(
  self : Flow,
  edge : Int32,
  capacity : Double,
  flow : Double,
) -> Unit raise @moongraph.Refused {
  if edge < 0 || edge >= self.froms.length() {
    raise @moongraph.Refused::OutOfRange(node=edge)
  }
  if capacity < 0.0 || flow < 0.0 || flow > capacity {
    let carried = "a flow of " + flow.to_string()
    let room = " does not fit a capacity of " + capacity.to_string()
    raise @moongraph.Refused::NotA(kind="flow", what=carried + room)
  }
  self.caps[edge] = capacity
  self.flows[edge] = flow
}

///|
/// What an edge carries, in the order AtCoder reports it: where it starts, where it ends, its
/// capacity, and its flow.
pub fn Flow::edge_flow(
  self : Flow,
  edge : Int32,
) -> (Int32, Int32, Double, Double)? {
  if edge < 0 || edge >= self.froms.length() {
    return None
  }
  Some((self.froms[edge], self.tos[edge], self.caps[edge], self.flows[edge]))
}

///|
/// How many edges the network has.
pub fn Flow::edge_count(self : Flow) -> Int32 {
  self.froms.length()
}

///|
/// Pushes as much as possible from one node to another, starting from the flow already in
/// the network, and answers how much was added. `limit` stops the search early, which is what
/// a caller who only needs a known amount asks for.
///
/// The network is left at a maximum flow for its current capacities, so `min_cut` and
/// `edge_flow` are meaningful afterwards, and a second call with nothing changed adds nothing.
pub fn Flow::flow(
  self : Flow,
  source : Int32,
  sink : Int32,
  limit? : Double,
) -> Double raise @moongraph.Refused {
  if source < 0 || source >= self.nodes || sink < 0 || sink >= self.nodes {
    raise @moongraph.Refused::OutOfRange(node=source)
  }
  if source == sink {
    raise @moongraph.Refused::NotA(kind="flow", what="the source is the sink")
  }
  let bound = limit.unwrap_or(1.0e18)
  if bound <= 0.0 {
    return 0.0
  }
  // The residual network, as a graph of two arcs per edge plus a lid on the sink that turns
  // the limit into a capacity rather than a special case in the search.
  let extra = self.nodes
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new(directed=true)
  for _ in 0..<(self.nodes + 1) {
    g.add_node(()) |> ignore
  }
  for edge in 0..<self.froms.length() {
    g.add_edge(self.froms[edge], self.tos[edge], ()) |> ignore
    g.add_edge(self.tos[edge], self.froms[edge], ()) |> ignore
  }
  let lid = g.edge_count()
  g.add_edge(sink, extra, ()) |> ignore
  let capacity = fn(eid : Int32) -> Double {
    if eid >= lid {
      return bound
    }
    let edge = eid / 2
    if eid % 2 == 0 {
      self.caps[edge] - self.flows[edge]
    } else {
      self.flows[edge]
    }
  }
  let network = @flow.Network::build(g, capacity)
  network.solve(source, extra, @flow.Dinitz)
  let pushed = network.report(g)
  let mut added = 0.0
  for edge in 0..<self.froms.length() {
    let forward = pushed.flow[edge * 2]
    let backward = pushed.flow[edge * 2 + 1]
    self.flows[edge] = self.flows[edge] + forward - backward
    added = added + forward - backward
  }
  // The answer is what left the source, which the lid also measures when a limit was given.
  let mut value = 0.0
  for edge in 0..<self.froms.length() {
    if self.froms[edge] == source {
      value = value + pushed.flow[edge * 2]
    }
    if self.tos[edge] == source {
      value = value - pushed.flow[edge * 2 + 1]
    }
  }
  ignore(added)
  if value < 0.0 {
    0.0
  } else {
    value
  }
}

///|
/// The source side of a minimum cut, read off the residual network: every node still
/// reachable from the source through an edge with room left. After a `flow` call this is the
/// cut of smallest capacity, and the nodes on the other side are the ones it separates.
pub fn Flow::min_cut(self : Flow, source : Int32) -> Array[Bool] {
  let out : Array[Bool] = Array::make(self.nodes, false)
  if source < 0 || source >= self.nodes {
    return out
  }
  let queue : Array[Int32] = [source]
  out[source] = true
  let mut head = 0
  while head < queue.length() {
    let at = queue[head]
    head = head + 1
    for edge in 0..<self.froms.length() {
      let forward = self.froms[edge] == at &&
        self.caps[edge] - self.flows[edge] > 0.0
      let backward = self.tos[edge] == at && self.flows[edge] > 0.0
      if !forward && !backward {
        continue
      }
      let next = if forward { self.tos[edge] } else { self.froms[edge] }
      if !out[next] {
        out[next] = true
        queue.push(next)
      }
    }
  }
  out
}
