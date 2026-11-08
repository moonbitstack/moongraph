// Incremental minimum-cost flow: the same network, asked for the whole price curve instead
// of one number.

///|
/// A cost flow network you keep. Each edge has a capacity and a cost per unit, and the
/// answer to `slope` is the whole shape of the trade — how much the next unit costs, for
/// every unit the network can carry.
///
/// This is AtCoder's `mcf_graph`: `add_edge`, `slope`, and `flow` as the last point of the
/// slope. The curve is built by sending flow along the cheapest route each time and is
/// therefore exact, not an approximation.
pub struct CostFlow {
  nodes : Int32
  froms : Array[Int32]
  tos : Array[Int32]
  caps : Array[Double]
  costs : Array[Double]
  flows : Array[Double]
}

///|
/// An empty network on a fixed number of nodes.
pub fn CostFlow::new(nodes : Int32) -> CostFlow {
  let size = if nodes < 0 { 0 } else { nodes }
  { nodes: size, froms: [], tos: [], caps: [], costs: [], flows: [], }
}

///|
/// Adds an edge with a capacity and a cost per unit, and returns its number. A negative cost
/// is allowed: it means the edge pays to be used.
pub fn CostFlow::add_edge(
  self : CostFlow,
  from : Int32,
  to : Int32,
  capacity : Double,
  cost : Double,
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
  self.costs.push(cost)
  self.flows.push(0.0)
  eid
}

///|
/// What an edge carries: where it starts, where it ends, its capacity, its flow and its cost.
pub fn CostFlow::edge_flow(
  self : CostFlow,
  edge : Int32,
) -> (Int32, Int32, Double, Double, Double)? {
  if edge < 0 || edge >= self.froms.length() {
    return None
  }
  Some(
    (
      self.froms[edge],
      self.tos[edge],
      self.caps[edge],
      self.flows[edge],
      self.costs[edge],
    ),
  )
}

///|
/// How many edges the network has.
pub fn CostFlow::edge_count(self : CostFlow) -> Int32 {
  self.froms.length()
}

///|
/// The price curve from one node to another: the points `(flow, cost)` where the cost of the
/// next unit changes. The first point is always `(0, 0)` and the last is the cheapest way to
/// send as much as the network allows.
///
/// A straight segment means every unit in it costs the same; a bend is a route filling up and
/// a more expensive one taking over. Reading the curve is how a planner decides how much of a
/// shipment is worth sending, which one number cannot answer.
///
/// The call sends the flow it describes, so the network is spent afterwards: a second call
/// answers from what is left. That is AtCoder's rule, and it is the honest one — the curve
/// and the shipment are the same event.
pub fn CostFlow::slope(
  self : CostFlow,
  source : Int32,
  sink : Int32,
) -> Array[(Double, Double)] raise @moongraph.Refused {
  if source < 0 || source >= self.nodes || sink < 0 || sink >= self.nodes {
    raise @moongraph.Refused::OutOfRange(node=source)
  }
  if source == sink {
    raise @moongraph.Refused::NotA(
      kind="cost flow",
      what="the source is the sink",
    )
  }
  let points : Array[(Double, Double)] = [(0.0, 0.0)]
  if self.froms.length() == 0 {
    return points
  }
  let n = self.nodes
  let far = 1.0e18
  let mut total_flow = 0.0
  let mut total_cost = 0.0
  let mut marginal = 0.0
  let mut have_marginal = false
  while true {
    // Bellman-Ford over the residual: reverse arcs carry a negative cost, so the search has
    // to tolerate them, and a heap would not.
    let distance : Array[Double] = Array::make(n, far)
    let through : Array[Int32] = Array::make(n, -1)
    let backward : Array[Bool] = Array::make(n, false)
    distance[source] = 0.0
    let mut changed = true
    while changed {
      changed = false
      for edge in 0..<self.froms.length() {
        let from = self.froms[edge]
        let to = self.tos[edge]
        let cost = self.costs[edge]
        if self.caps[edge] - self.flows[edge] > 0.0 &&
          distance[from] < far &&
          distance[from] + cost < distance[to] - 1.0e-12 {
          distance[to] = distance[from] + cost
          through[to] = edge
          backward[to] = false
          changed = true
        }
        if self.flows[edge] > 0.0 &&
          distance[to] < far &&
          distance[to] - cost < distance[from] - 1.0e-12 {
          distance[from] = distance[to] - cost
          through[from] = edge
          backward[from] = true
          changed = true
        }
      }
    }
    if distance[sink] >= far {
      break
    }
    // The widest push this route allows.
    let mut push = far
    let mut at = sink
    while at != source {
      let edge = through[at]
      if edge < 0 {
        push = 0.0
        break
      }
      let room = if backward[at] {
        self.flows[edge]
      } else {
        self.caps[edge] - self.flows[edge]
      }
      if room < push {
        push = room
      }
      at = if backward[at] { self.tos[edge] } else { self.froms[edge] }
    }
    if push <= 0.0 {
      break
    }
    at = sink
    while at != source {
      let edge = through[at]
      if backward[at] {
        self.flows[edge] = self.flows[edge] - push
        at = self.tos[edge]
      } else {
        self.flows[edge] = self.flows[edge] + push
        at = self.froms[edge]
      }
    }
    total_flow = total_flow + push
    total_cost = total_cost + push * distance[sink]
    // A point per bend: an augmentation at the same unit price only lengthens the segment.
    if have_marginal && (distance[sink] - marginal).abs() < 1.0e-9 {
      points[points.length() - 1] = (total_flow, total_cost)
    } else {
      points.push((total_flow, total_cost))
      marginal = distance[sink]
      have_marginal = true
    }
  }
  points
}

///|
/// The cheapest way to send as much as possible from one node to another: the amount and what
/// it costs. This is the last point of `slope`, for the caller who only wants the total.
pub fn CostFlow::flow(
  self : CostFlow,
  source : Int32,
  sink : Int32,
) -> (Double, Double) raise @moongraph.Refused {
  let points = self.slope(source, sink)
  points[points.length() - 1]
}
