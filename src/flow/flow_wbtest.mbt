///|
fn diamond() -> @moongraph.Graph[Unit, Double] {
  @moongraph.Graph::from_edges([(0, 1), (1, 3), (0, 2), (2, 3)], node=(), edge=1.0)
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
  let flow = min_cost_flow(g, [1.0, -1.0, 0.0, 0.0], cost=cost)
  assert_eq(flow.flow[0], 1.0)
  assert_eq(flow.flow[2], 0.0)
  assert_eq(flow_cost(g, flow, cost=cost), 2.0)
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
