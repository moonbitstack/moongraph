// The differential test for the contraction hierarchy: every answer is checked against a plain
// Dijkstra on the same graph. If the shortcuts ever left out a route, or the upward-only search
// ever missed one, the two would disagree — which is the whole point of building the structure.
//
// The route is checked as well as the cost: it must be a walk in the graph the caller handed
// over, with one edge between each pair of stops, and its edges must add up to the cost claimed.

///|
/// A random graph over `count` nodes with about `count * 2` edges, each costing a whole number
/// from 1 to 5 so that sums are exact and two answers can be compared with `assert_eq`.
fn random_weighted(
  count : Int32,
  rng : &@contract.Rng,
  directed : Bool,
) -> @moongraph.Graph[Int32, Double] {
  let graph : @moongraph.Graph[Int32, Double] = @moongraph.Graph::new(directed~)
  for _ in 0..<count {
    graph.add_node(0) |> ignore
  }
  if count < 2 {
    return graph
  }
  for _ in 0..<(count * 2) {
    let a = @moonrand.randint(rng, 0, (count - 1).to_int64()).to_int()
    let b = @moonrand.randint(rng, 0, (count - 1).to_int64()).to_int()
    if a != b {
      let cost = @moonrand.randint(rng, 1, 5).to_int().to_double()
      graph.add_edge(a, b, cost) |> ignore
    }
  }
  graph
}

///|
/// The cost of a walk, taking the cheapest edge between each pair of stops. Returns `None` when
/// some pair is not joined at all, which would mean the route the hierarchy reported is not a
/// walk in the graph.
fn walk_cost(
  graph : @moongraph.Graph[Int32, Double],
  route : Array[Int32],
) -> Double? {
  let mut total = 0.0
  for at in 0..<(route.length() - 1) {
    let edges = graph.find_edges(route[at], route[at + 1])
    if edges.length() == 0 {
      return None
    }
    let mut cheapest = graph.edge_data(edges[0])
    for edge in edges {
      if graph.edge_data(edge) < cheapest {
        cheapest = graph.edge_data(edge)
      }
    }
    total = total + cheapest
  }
  Some(total)
}

///|
test "every pair costs what Dijkstra says, undirected" {
  let rng = @moonrand.seeded(b"ch-undirected")
  for _ in 0..<8 {
    let count = @moonrand.randint(rng, 2, 8).to_int()
    let graph = random_weighted(count, rng, false)
    let ch = contraction_hierarchy(
      graph,
      weight=graph.weights(fn(cost) { cost }),
    )
    for source in 0..<count {
      let paths = dijkstra(
        graph,
        source,
        weight=graph.weights(fn(cost) { cost }),
      )
      for target in 0..<count {
        assert_eq(ch.query(source, target), paths.distance[target])
        // The route is a walk, and its cost is the cost claimed.
        match ch.path(source, target) {
          Some(route) => {
            assert_eq(route[0], source)
            assert_eq(route[route.length() - 1], target)
            assert_eq(walk_cost(graph, route), paths.distance[target])
          }
          None =>
            fail(
              "no route from " +
              source.to_string() +
              " to " +
              target.to_string(),
            )
        }
      }
    }
  }
}

///|
test "every pair costs what Dijkstra says, directed" {
  let rng = @moonrand.seeded(b"ch-directed")
  for _ in 0..<8 {
    let count = @moonrand.randint(rng, 2, 7).to_int()
    let graph = random_weighted(count, rng, true)
    let ch = contraction_hierarchy(
      graph,
      weight=graph.weights(fn(cost) { cost }),
    )
    for source in 0..<count {
      let paths = dijkstra(
        graph,
        source,
        weight=graph.weights(fn(cost) { cost }),
      )
      for target in 0..<count {
        let expected = paths.distance[target]
        let actual = ch.query(source, target)
        if expected != actual {
          let pair = source.to_string() + " to " + target.to_string()
          fail("contraction differs from Dijkstra at " + pair)
        }
        match actual {
          Some(_) =>
            match ch.path(source, target) {
              Some(route) => assert_eq(walk_cost(graph, route), expected)
              None => fail("a cost but no route")
            }
          None => assert_true(ch.path(source, target) is None)
        }
      }
    }
  }
}

///|
test "the rank order is a permutation of the nodes" {
  let rng = @moonrand.seeded(b"ch-rank")
  let count = @moonrand.randint(rng, 3, 9).to_int()
  let graph = random_weighted(count, rng, false)
  let ch = contraction_hierarchy(graph, weight=graph.weights(fn(cost) { cost }))
  let seen : Array[Bool] = Array::make(count, false)
  for node in 0..<count {
    let rank = ch.rank_of(node)
    assert_true(rank >= 0 && rank < count)
    assert_false(seen[rank])
    seen[rank] = true
  }
  // A number the graph does not have has no place in the order.
  assert_eq(ch.rank_of(count), -1)
  assert_eq(ch.rank_of(-1), -1)
  // The structure only ever adds arcs.
  assert_true(ch.shortcut_count() >= 0)
}

///|
test "a graph that does not reach asks for nothing" {
  // Two nodes, no edge: the hierarchy reports no route rather than a cost of zero.
  let graph : @moongraph.Graph[Int32, Double] = @moongraph.Graph::new(
    directed=false,
  )
  graph.add_node(0) |> ignore
  graph.add_node(1) |> ignore
  let ch = contraction_hierarchy(graph)
  assert_true(ch.query(0, 1) is None)
  assert_true(ch.path(0, 1) is None)
  // A node reaches itself at no cost, and the route is itself.
  assert_eq(ch.query(0, 0), Some(0.0))
  assert_eq(ch.path(0, 0), Some([0]))
  assert_eq(ch.shortcut_count(), 0)
}

///|
test "a negative cost is refused, as Dijkstra refuses it" {
  let graph : @moongraph.Graph[Int32, Double] = @moongraph.Graph::new(
    directed=false,
  )
  graph.add_node(0) |> ignore
  graph.add_node(1) |> ignore
  graph.add_edge(0, 1, -1.0) |> ignore
  let refused = try {
    contraction_hierarchy(graph, weight=graph.weights(fn(cost) { cost }))
    |> ignore
    false
  } catch {
    @moongraph.Refused::NegativeWeight(edge~) => edge == 0
    _ => false
  }
  assert_true(refused)
}

///|
test "a five-by-five board, every pair, against Dijkstra" {
  // A board joined up and down as well as across. A contraction here needs no shortcut — every
  // route through a node can be walked round the corner instead — so what this checks is that
  // the order and the upward search still answer every pair correctly on a graph with real
  // depth.
  let side = 5
  let n = side * side
  let graph : @moongraph.Graph[Int32, Double] = @moongraph.Graph::new(
    directed=false,
  )
  for _ in 0..<n {
    graph.add_node(0) |> ignore
  }
  for row in 0..<side {
    for column in 0..<side {
      let here = row * side + column
      if column + 1 < side {
        graph.add_edge(here, here + 1, 1.0) |> ignore
      }
      if row + 1 < side {
        graph.add_edge(here, here + side, 1.0) |> ignore
      }
    }
  }
  let ch = contraction_hierarchy(graph, weight=graph.weights(fn(cost) { cost }))
  for source in 0..<n {
    let paths = dijkstra(graph, source, weight=graph.weights(fn(cost) { cost }))
    for target in 0..<n {
      assert_eq(ch.query(source, target), paths.distance[target])
    }
  }
  // A corner to the opposite corner: four steps across and four down.
  assert_eq(ch.query(0, n - 1), Some(8.0))
  match ch.path(0, n - 1) {
    Some(route) => {
      assert_eq(route.length(), 9)
      assert_eq(walk_cost(graph, route), Some(8.0))
    }
    None => fail("a grid corner should reach the other corner")
  }
}

///|
test "a ring needs a shortcut, and the shortcut unpacks to the route" {
  // A ring of six: contracting any node leaves the two neighbours with no way round except the
  // long way, so the preprocessing has to build the shortcut between them — and a query that
  // uses it has to unpack it back into the two edges it stands for.
  let graph : @moongraph.Graph[Int32, Double] = @moongraph.Graph::new(
    directed=false,
  )
  for _ in 0..<6 {
    graph.add_node(0) |> ignore
  }
  for node in 0..<6 {
    graph.add_edge(node, (node + 1) % 6, 1.0) |> ignore
  }
  let ch = contraction_hierarchy(graph, weight=graph.weights(fn(cost) { cost }))
  assert_true(ch.shortcut_count() > 0)
  // Halfway round either way.
  assert_eq(ch.query(0, 3), Some(3.0))
  // Through the shortcut, still three steps of the ring.
  assert_eq(ch.query(0, 2), Some(2.0))
  match ch.path(0, 2) {
    Some(route) => assert_eq(walk_cost(graph, route), Some(2.0))
    None => fail("a ring reaches its own next-but-one")
  }
}
