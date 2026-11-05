///|
fn weighted() -> @moongraph.Graph[Unit, Double] {
  // 0 -1-> 1 -2-> 2, 0 -5-> 2, 1 -1-> 3, 3 -2-> 2
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new()
  for _ in 0..<5 {
    g.add_node(()) |> ignore
  }
  g.add_edge(0, 1, 1.0) |> ignore
  g.add_edge(1, 2, 2.0) |> ignore
  g.add_edge(0, 2, 5.0) |> ignore
  g.add_edge(1, 3, 1.0) |> ignore
  g.add_edge(3, 2, 2.0) |> ignore
  g
}

///|
fn w(g : @moongraph.Graph[Unit, Double]) -> (Int) -> Double {
  g.weights(fn(cost) { cost })
}

///|
test "dijkstra finds the cheaper of two routes" {
  let g = weighted()
  let paths = dijkstra(g, 0, weight=w(g))
  assert_eq(paths.distance[2], Some(3.0))
  assert_eq(paths.path_to(2), Some([0, 1, 2]))
  assert_eq(paths.distance[4], None)
}

///|
test "dijkstra refuses a negative edge and names it" {
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges([(0, 1)], node=(), edge=1.0)
  g.add_node(()) |> ignore
  g.add_edge(1, 2, -1.0) |> ignore
  let outcome = try {
    dijkstra(g, 0, weight=w(g)) |> ignore
    None
  } catch {
    @moongraph.Refused::NegativeWeight(edge~) => Some(edge)
    _ => None
  }
  assert_eq(outcome, Some(1))
}

///|
test "dijkstra_multi starts every source at zero" {
  let g = weighted()
  let paths = dijkstra_multi(g, [0, 3], weight=w(g))
  assert_eq(paths.distance[3], Some(0.0))
  assert_eq(paths.distance[2], Some(2.0))
}

///|
test "dijkstra_bidirectional agrees with dijkstra on the route" {
  let g = weighted()
  let one = dijkstra(g, 0, weight=w(g))
  let two = dijkstra_bidirectional(g, 0, 2, weight=w(g))
  assert_eq(two.distance[2], one.distance[2])
  assert_eq(two.path_to(2), one.path_to(2))
}

///|
test "bellman_ford handles a negative edge without a cycle" {
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (0, 2)],
    node=(),
    edge=1.0,
  )
  g.set_edge_data(0, -4.0)
  let paths = bellman_ford(g, 0, weight=w(g))
  assert_eq(paths.distance[2], Some(-3.0))
  assert_eq(paths.path_to(2), Some([0, 1, 2]))
}

///|
test "bellman_ford refuses a negative cycle with a witness" {
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=1.0,
  )
  g.set_edge_data(2, -3.0)
  let cycle = try {
    bellman_ford(g, 0, weight=w(g)) |> ignore
    None
  } catch {
    @moongraph.Refused::Cycle(nodes~) => Some(nodes)
    _ => None
  }
  match cycle {
    Some(nodes) => {
      assert_true(nodes.length() >= 2)
      assert_eq(nodes[0], nodes[nodes.length() - 1])
    }
    None => fail("a negative cycle must be refused")
  }
}

///|
test "spfa agrees with bellman_ford" {
  let g = weighted()
  let a = bellman_ford(g, 0, weight=w(g))
  let b = spfa(g, 0, weight=w(g))
  assert_eq(a.distance, b.distance)
}

///|
test "floyd_warshall fills every pair" {
  let g = weighted()
  let all = floyd_warshall(g, weight=w(g))
  assert_eq(all.distance[0][2], Some(3.0))
  assert_eq(all.path(0, 2), Some([0, 1, 2]))
  assert_eq(all.distance[4][0], None)
}

///|
test "johnson agrees with floyd_warshall" {
  let g = weighted()
  let a = floyd_warshall(g, weight=w(g))
  let b = johnson(g, weight=w(g))
  for i in 0..<5 {
    for j in 0..<5 {
      assert_eq(a.distance[i][j], b.distance[i][j])
    }
  }
}

///|
test "johnson accepts a negative edge but refuses a negative cycle" {
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges([(0, 1), (1, 2)], node=(), edge=1.0)
  g.set_edge_data(0, -2.0)
  let all = johnson(g, weight=w(g))
  assert_eq(all.distance[0][2], Some(-1.0))
  g.add_edge(2, 0, -5.0) |> ignore
  let refused = try {
    johnson(g, weight=w(g)) |> ignore
    false
  } catch {
    @moongraph.Refused::Cycle(_) => true
    _ => false
  }
  assert_true(refused)
}

///|
test "dijkstra_all and bfs_all agree on an unweighted graph" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (0, 2), (2, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  let a = bfs_all(g)
  assert_eq(a.distance[0][3], Some(2.0))
  assert_eq(a.path(0, 3), Some([0, 2, 3]))
  let b = dijkstra_all(g)
  assert_eq(a.distance, b.distance)
}

///|
test "astar finds the same route as dijkstra" {
  let g = weighted()
  let estimate = fn(node) { if node == 2 { 0.0 } else { 0.0 } }
  let paths = astar(g, 0, 2, weight=w(g), estimate=estimate)
  assert_eq(paths.distance[2], Some(3.0))
  assert_eq(paths.path_to(2), Some([0, 1, 2]))
}

///|
test "astar refuses when the target is out of reach" {
  let g = weighted()
  let refused = try {
    astar(g, 0, 4, weight=w(g), estimate=fn(_) { 0.0 }) |> ignore
    false
  } catch {
    @moongraph.Refused::NoSolution => true
    _ => false
  }
  assert_true(refused)
}

///|
test "k_shortest returns the routes in order of cost" {
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (0, 2), (0, 3), (3, 2)],
    node=(),
    edge=1.0,
    directed=false,
  )
  let routes = k_shortest(g, 0, 2, 3, weight=w(g))
  assert_eq(routes, [[0, 2], [0, 1, 2], [0, 3, 2]])
}

///|
test "widest keeps the bottleneck of each route" {
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 3), (0, 2), (2, 3)],
    node=(),
    edge=1.0,
    directed=false,
  )
  g.set_edge_data(0, 5.0)
  g.set_edge_data(1, 2.0)
  g.set_edge_data(2, 3.0)
  g.set_edge_data(3, 4.0)
  let paths = widest(g, 0, weight=w(g))
  assert_eq(paths.distance[3], Some(3.0))
  assert_eq(paths.path_to(3), Some([0, 2, 3]))
}

///|
test "shortest picks the method the weights allow" {
  let g = weighted()
  assert_eq(shortest(g, 0, 2, weight=w(g)), Some([0, 1, 2]))
  g.set_edge_data(0, -10.0)
  // 0 -> 1 is now -10, so the two-edge route costs -8 and beats the direct 5.
  assert_eq(shortest(g, 0, 2, weight=w(g)), Some([0, 1, 2]))
}

///|
test "has_path respects the direction" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges([(0, 1)], node=(), edge=())
  assert_true(has_path(g, 0, 1))
  assert_false(has_path(g, 1, 0))
  assert_true(has_path(g, 1, 1))
  assert_false(has_path(g, 5, 1))
}

///|
test "path_weight sums the cheapest edge between each pair" {
  let g = weighted()
  assert_eq(path_weight(g, [0, 1, 3, 2], weight=w(g)), 4.0)
  let refused = try {
    path_weight(g, [0, 4], weight=w(g)) |> ignore
    false
  } catch {
    @moongraph.Refused::Disconnected(from~, to~) => from == 0 && to == 4
    _ => false
  }
  assert_true(refused)
}

///|
test "all_simple enumerates every simple route" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (0, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(all_simple(g, 0, 2).collect(), [[0, 1, 2], [0, 2]])
  assert_eq(all_simple(g, 2, 2).collect(), [[2]])
}

///|
test "all_simple_edges names the edges of each route" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (0, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  let routes = all_simple_edges(g, 0, 2).collect()
  assert_eq(routes, [[0, 1], [2]])
}

///|
test "is_simple_path rejects a repeat and a missing edge" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_true(is_simple_path(g, [0, 1, 2]))
  assert_false(is_simple_path(g, [0, 1, 0]))
  assert_false(is_simple_path(g, [0, 2]))
  assert_false(is_simple_path(g, []))
}
