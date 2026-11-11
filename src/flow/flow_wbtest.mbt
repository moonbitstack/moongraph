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
    BoykovKolmogorov,
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

///|
/// A random directed network, whole capacities, parallel edges allowed.
fn random_network(
  rng : &@contract.Rng,
  count : Int32,
  arcs : Int32,
) -> @moongraph.Graph[Unit, Double] {
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new(directed=true)
  for _ in 0..<count {
    g.add_node(()) |> ignore
  }
  for _ in 0..<arcs {
    let a = @moonrand.randint(rng, 0, (count - 1).to_int64()).to_int()
    let b = @moonrand.randint(rng, 0, (count - 1).to_int64()).to_int()
    let capacity = @moonrand.randint(rng, 1, 9).to_int()
    if a != b {
      g.add_edge(a, b, capacity.to_double()) |> ignore
    }
  }
  g
}

///|
/// Whether what a solver reports is a flow: nothing above capacity, nothing kept at an inner
/// node, and the total equal to what leaves the source.
fn is_flow(
  graph : @moongraph.Graph[Unit, Double],
  flow : @moongraph.Flow,
  source : Int32,
  sink : Int32,
) -> Bool {
  let n = graph.node_count()
  let into : Array[Double] = Array::make(n, 0.0)
  let out : Array[Double] = Array::make(n, 0.0)
  for edge in 0..<flow.flow.length() {
    let (a, b) = graph.endpoints(edge)
    let carried = flow.flow[edge]
    if carried < -1.0e-9 || carried > graph.edge_data(edge) + 1.0e-9 {
      return false
    }
    out[a] = out[a] + carried
    into[b] = into[b] + carried
  }
  for node in 0..<n {
    if node == source || node == sink {
      continue
    }
    if (into[node] - out[node]).abs() > 1.0e-9 {
      return false
    }
  }
  (out[source] - into[source] - flow.value).abs() <= 1.0e-9
}

///|
test "the two-tree walk answers what the level-graph walk answers" {
  let rng = @moonrand.seeded(b"flow-two-trees")
  for round in 0..<500 {
    let count = 3 + @moonrand.randint(rng, 0, 6).to_int()
    let arcs = 6 + @moonrand.randint(rng, 0, 16).to_int()
    let g = random_network(rng, count, arcs)
    let cap = g.weights(fn(cost) { cost })
    let level = max_flow(g, 0, count - 1, capacity=cap)
    let trees = max_flow(g, 0, count - 1, capacity=cap, kind=BoykovKolmogorov)
    if level.value != trees.value {
      let spot = "round " + round.to_string() + ": "
      fail(spot + "the two walks answer different values")
    }
    if !is_flow(g, trees, 0, count - 1) {
      fail(
        "round " +
        round.to_string() +
        ": what the two-tree walk reports is not a flow",
      )
    }
  }
}

///|
test "the two-tree walk answers a board, where its trees are worth keeping" {
  // A board is the shape the walk exists for: low degree, many short routes. Every cell is a
  // node with a capacity on the step to its right and its neighbour below.
  let width = 9
  let height = 9
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new(directed=true)
  for _ in 0..<(width * height) {
    g.add_node(()) |> ignore
  }
  let rng = @moonrand.seeded(b"flow-board")
  for y in 0..<height {
    for x in 0..<width {
      let here = y * width + x
      if x + 1 < width {
        let room = @moonrand.randint(rng, 1, 4).to_int()
        g.add_edge(here, here + 1, room.to_double()) |> ignore
      }
      if y + 1 < height {
        let room = @moonrand.randint(rng, 1, 4).to_int()
        g.add_edge(here, here + width, room.to_double()) |> ignore
      }
    }
  }
  let cap = g.weights(fn(cost) { cost })
  let sink = width * height - 1
  let level = max_flow(g, 0, sink, capacity=cap)
  let trees = max_flow(g, 0, sink, capacity=cap, kind=BoykovKolmogorov)
  assert_eq(trees.value, level.value)
  assert_true(is_flow(g, trees, 0, sink))
  // And the cut agrees from the other side.
  assert_eq(min_cut(g, 0, sink, capacity=cap).value, level.value)
}
