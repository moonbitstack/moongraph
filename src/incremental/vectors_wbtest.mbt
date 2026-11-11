// A network that is kept is compared twice at every step: once with the reference's flow on
// the capacities as they now stand, and once with the same family rebuilt from nothing. A
// network that only remembered part of what it pushed would agree with neither for long.

///|
/// The flow across a network built from scratch at these capacities: the answer the kept
/// network has to reproduce without rebuilding anything.
fn rebuilt(
  case : @internal.IncrementalCase,
  capacities : Array[Double],
) -> Double raise @moongraph.Refused {
  let graph : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new(
    directed=true,
  )
  for _ in 0..<case.nodes {
    graph.add_node(()) |> ignore
  }
  for at in 0..<case.edges.length() {
    let (a, b, _) = case.edges[at]
    graph.add_edge(a, b, capacities[at]) |> ignore
  }
  @flow.max_flow_value(
    graph,
    case.source,
    case.sink,
    capacity=graph.weights(fn(cost) { cost }),
  )
}

///|
/// Whether every edge carries no more than it holds, no node keeps what it was given, and the
/// total is what leaves the source.
fn is_network_flow(
  case : @internal.IncrementalCase,
  net : Flow,
  total : Double,
) -> Bool {
  let into : Array[Double] = Array::make(case.nodes, 0.0)
  let out : Array[Double] = Array::make(case.nodes, 0.0)
  for at in 0..<net.edge_count() {
    match net.edge_flow(at) {
      Some((a, b, capacity, carried)) => {
        if carried < -1.0e-9 || carried > capacity + 1.0e-9 {
          return false
        }
        out[a] = out[a] + carried
        into[b] = into[b] + carried
      }
      None => return false
    }
  }
  for node in 0..<case.nodes {
    if node == case.source || node == case.sink {
      continue
    }
    if !@internal.close(into[node], out[node]) {
      return false
    }
  }
  @internal.close(out[case.source] - into[case.source], total) &&
  @internal.close(into[case.sink] - out[case.sink], total)
}

///|
test "a kept network answers what the reference answers" {
  for case in @internal.incremental_cases() {
    let capacities : Array[Double] = case.edges.map(fn(edge) { edge.2 })
    let net = Flow::new(case.nodes)
    for (a, b, capacity) in case.edges {
      net.add_edge(a, b, capacity) |> ignore
    }
    let spot = case.name + ": "
    let mut total = net.flow(case.source, case.sink)
    if !@internal.close(total, case.first) {
      let got = total.to_string()
      fail(
        spot + "the first answer is " + got + ", not " + case.first.to_string(),
      )
    }
    if !@internal.close(rebuilt(case, capacities), total) {
      fail(spot + "a network built from scratch disagrees with the kept one")
    }
    for at in 0..<case.changes.length() {
      let (edge, extra) = case.changes[at]
      let (_, _, capacity, carried) = net.edge_flow(edge).unwrap()
      net.change_edge(edge, capacity + extra, carried)
      capacities[edge] = capacity + extra
      total = total + net.flow(case.source, case.sink)
      let step = at.to_string()
      if !@internal.close(total, case.after[at]) {
        let got = total.to_string()
        fail(
          spot +
          "after change " +
          step +
          " the total is " +
          got +
          ", not " +
          case.after[at].to_string(),
        )
      }
      if !@internal.close(rebuilt(case, capacities), total) {
        fail(
          spot +
          "after change " +
          step +
          " the kept network is not the rebuilt one",
        )
      }
      if !is_network_flow(case, net, total) {
        fail(
          spot + "after change " + step + " what the edges carry is not a flow",
        )
      }
    }
  }
}

///|
test "the cut a kept network reports holds what the reference's cut holds" {
  for case in @internal.incremental_cases() {
    let net = Flow::new(case.nodes)
    for (a, b, capacity) in case.edges {
      net.add_edge(a, b, capacity) |> ignore
    }
    net.flow(case.source, case.sink) |> ignore
    for (edge, extra) in case.changes {
      let (_, _, capacity, carried) = net.edge_flow(edge).unwrap()
      net.change_edge(edge, capacity + extra, carried)
      net.flow(case.source, case.sink) |> ignore
    }
    let side = net.min_cut(case.source)
    let mut cut = 0.0
    for at in 0..<net.edge_count() {
      let (a, b, capacity, _) = net.edge_flow(at).unwrap()
      if side[a] && !side[b] {
        cut = cut + capacity
      }
    }
    if !@internal.close(cut, case.cut) {
      let got = cut.to_string()
      fail(
        case.name + ": the cut holds " + got + ", not " + case.cut.to_string(),
      )
    }
  }
}

///|
/// The cost of a whole amount of flow, read off the piecewise-linear curve the network answers
/// with: a segment is a run of units that cost the same, so the total at a point inside one is
/// the interpolation between its ends.
fn cost_at(points : Array[(Double, Double)], amount : Double) -> Double {
  if points.length() == 0 {
    return 0.0
  }
  for at in 1..<points.length() {
    let (from_flow, from_cost) = points[at - 1]
    let (to_flow, to_cost) = points[at]
    if amount <= to_flow && to_flow > from_flow {
      return from_cost +
        (to_cost - from_cost) * (amount - from_flow) / (to_flow - from_flow)
    }
  }
  points[points.length() - 1].1
}

///|
test "the price curve is the reference's cheapest total at every amount" {
  for case in @internal.cost_flow_cases() {
    let net = CostFlow::new(case.nodes)
    for (a, b, capacity, cost) in case.edges {
      net.add_edge(a, b, capacity, cost) |> ignore
    }
    let points = net.slope(case.source, case.sink)
    for (amount, want) in case.curve {
      if !@internal.close(cost_at(points, amount), want) {
        let spot = case.name + " at " + amount.to_string() + " units: "
        let got = cost_at(points, amount).to_string()
        fail(spot + "the curve says " + got + ", not " + want.to_string())
      }
    }
  }
}

///|
test "a spent cost flow network answers the second question from what is left" {
  for case in @internal.cost_flow_cases() {
    let net = CostFlow::new(case.nodes)
    for (a, b, capacity, cost) in case.edges {
      net.add_edge(a, b, capacity, cost) |> ignore
    }
    net.slope(case.source, case.sink) |> ignore
    // Everything that could be sent has been, so a second curve is the one point at zero.
    assert_eq(net.slope(case.source, case.sink), [(0.0, 0.0)])
  }
}
