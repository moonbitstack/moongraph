///|
fn diamond() -> @moongraph.Graph[Unit, Double] {
  @moongraph.Graph::from_edges(
    [(0, 1), (1, 3), (0, 2), (2, 3)],
    node=(),
    edge=1.0,
  )
}

///|
test "every method agrees on the maximum flow" {
  let g = diamond()
  let cap = g.weights(fn(c) { c })
  assert_eq(max_flow(g, 0, 3, capacity=cap).value, 2.0)
  assert_eq(max_flow(g, 0, 3, capacity=cap, kind=EdmondsKarp).value, 2.0)
  assert_eq(max_flow(g, 0, 3, capacity=cap, kind=PushRelabel).value, 2.0)
  assert_eq(max_flow(g, 0, 3, capacity=cap, kind=ShortestAugmenting).value, 2.0)
  assert_eq(max_flow_value(g, 0, 3, capacity=cap), 2.0)
}

///|
test "the flow is reported per edge" {
  let g = diamond()
  let flow = max_flow(g, 0, 3, capacity=g.weights(fn(c) { c }))
  assert_eq(flow.flow.length(), 4)
  // One unit runs 0 -> 1 -> 3 and one runs 0 -> 2 -> 3.
  assert_eq(flow.flow[0], 1.0)
  assert_eq(flow.flow[1], 1.0)
  assert_eq(flow.flow[2], 1.0)
  assert_eq(flow.flow[3], 1.0)
}

///|
test "the minimum cut matches the flow" {
  let g = diamond()
  let cut = min_cut(g, 0, 3, capacity=g.weights(fn(c) { c }))
  assert_eq(cut.value, 2.0)
  assert_true(cut.source_side[0])
  assert_false(cut.source_side[3])
}

///|
test "global minimum cut of a barbell" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (0, 2), (2, 3), (3, 4), (4, 5), (3, 5)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(min_cut_global(g).value, 1.0)
  assert_eq(min_edge_cut(g), [3])
}

///|
test "connectivity of a cycle is two" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(edge_connectivity(g), 2)
  assert_eq(edge_connectivity_pair(g, 0, 1), 2)
  assert_eq(node_connectivity(g), 2)
}

///|
test "edge disjoint paths of a diamond" {
  let g = diamond()
  let paths = edge_disjoint_paths(g, 0, 3)
  assert_eq(paths.length(), 2)
  for path in paths {
    assert_eq(path[0], 0)
    assert_eq(path[path.length() - 1], 3)
  }
}

///|
test "node disjoint paths of a diamond" {
  let g = diamond()
  let paths = node_disjoint_paths(g, 0, 3)
  assert_eq(paths.length(), 2)
}

///|
test "min cost flow routes along the cheap edge" {
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges(
    [(0, 2), (2, 1), (0, 3), (3, 1)],
    node=(),
    edge=1.0,
  )
  g.set_edge_data(0, 1.0)
  g.set_edge_data(1, 1.0)
  g.set_edge_data(2, 9.0)
  g.set_edge_data(3, 9.0)
  let cost = g.weights(fn(c) { c })
  let flow = min_cost_flow(g, [1.0, -1.0, 0.0, 0.0], cost~)
  assert_eq(flow.flow[0], 1.0)
  assert_eq(flow.flow[2], 0.0)
  assert_eq(flow_cost(g, flow, cost~), 2.0)
}

///|
test "cut tree of a path separates next to the cheapest edge" {
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3)],
    node=(),
    edge=1.0,
    directed=false,
  )
  g.set_edge_data(1, 5.0)
  let tree = gomory_hu(g, capacity=g.weights(fn(c) { c }))
  assert_eq(tree.length(), 3)
}

///|
test "edge components split a barbell" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (0, 2), (2, 3), (3, 4), (4, 5), (3, 5)],
    node=(),
    edge=(),
    directed=false,
  )
  let parts = k_edge_components(g, 2)
  assert_eq(parts.length(), 2)
}

///|
test "min cuts are handed out one at a time" {
  // A path of three nodes: the least cut is one edge, and there are two of them.
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(all_min_cuts(g, 0, 2).take(1).collect().length(), 1)
  let cuts = all_min_cuts(g, 0, 2).collect()
  assert_eq(cuts.length(), 2)
  for cut in cuts {
    assert_eq(cut.value, 1.0)
  }
}

///|
test "every method answers one value, and each of them reports a flow" {
  // A network with three routes of different widths, so a method that stops at the first
  // augmenting path cannot agree with one that keeps going.
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new(directed=true)
  for _ in 0..<4 {
    g.add_node(()) |> ignore
  }
  g.add_edge(0, 1, 3.0) |> ignore
  g.add_edge(0, 2, 2.0) |> ignore
  g.add_edge(1, 3, 2.0) |> ignore
  g.add_edge(2, 3, 4.0) |> ignore
  g.add_edge(1, 2, 1.0) |> ignore
  let cap = g.weights(fn(cost) { cost })
  let methods : Array[FlowMethod] = [
    Dinitz,
    PushRelabel,
    EdmondsKarp,
    ShortestAugmenting,
  ]
  for solver in methods {
    let flow = max_flow(g, 0, 3, capacity=cap, kind=solver)
    if flow.value != 5.0 {
      let got = flow.value.to_string()
      fail("a solver answers " + got + " where the network carries 5")
    }
    // Whatever the solver, what it reports has to be a flow: nothing above capacity, and
    // nothing kept at the inner nodes.
    let into : Array[Double] = Array::make(4, 0.0)
    let out : Array[Double] = Array::make(4, 0.0)
    for edge in 0..<flow.flow.length() {
      let (a, b) = g.endpoints(edge)
      let carried = flow.flow[edge]
      if carried < 0.0 || carried > g.edge_data(edge) {
        fail("an edge carries more than it holds")
      }
      out[a] = out[a] + carried
      into[b] = into[b] + carried
    }
    for node in [1, 2] {
      if into[node] != out[node] {
        let got = into[node].to_string()
        fail("node " + node.to_string() + " keeps " + got)
      }
    }
    if out[0] - into[0] != 5.0 {
      fail("the value is not what leaves the source")
    }
  }
}
