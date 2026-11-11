///|
/// The guide: `docs/guide.html`.

///|
test "guide/first-graph" {
  // docs:begin first-graph
  let g : @moongraph.Graph[String, Double] = @moongraph.Graph::new(
    directed=false,
  )
  let a = g.add_node("a")
  let b = g.add_node("b")
  let c = g.add_node("c")
  g.add_edge(a, b, 1.5) |> ignore
  g.add_edge(b, c, 2.0) |> ignore
  assert_eq(a, 0) // the number the node was given
  assert_eq(g.neighbors(a).to_owned(), [b])
  assert_eq(g.node_data(c), "c")
  // docs:end
}

///|
test "guide/parallel-edges" {
  let g : @moongraph.Graph[String, Double] = @moongraph.Graph::new(
    directed=false,
  )
  let a = g.add_node("a")
  let b = g.add_node("b")
  g.add_node("c") |> ignore
  g.add_edge(a, b, 1.5) |> ignore
  g.add_edge(b, 2, 2.0) |> ignore
  // docs:begin parallel-edges
  let e = g.add_edge(a, b, 9.0)
  assert_eq(g.find_edges(a, b), [0, 2]) // two edges, numbers kept
  assert_eq(g.endpoints(e), (0, 1))
  assert_eq(g.edge_data(e), 9.0)
  // docs:end
  assert_eq(g.node_count(), 3)
}

///|
test "guide/keyed" {
  // docs:begin keyed
  let inner : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new()
  let k = @moongraph.Keyed::new(graph=inner)
  k.add_node("oslo", ()) |> ignore
  k.add_node("bergen", ()) |> ignore
  k.add_edge("oslo", "bergen", 3.0) |> ignore
  assert_eq(k.node("bergen"), Some(1))
  assert_eq(k.key(0), Some("oslo"))
  // docs:end
}

///|
test "guide/weights" {
  // docs:begin weights
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new(directed=false)
  for _ in 0..<5 {
    g.add_node(()) |> ignore
  }
  g.add_edge(0, 1, 1.0) |> ignore
  g.add_edge(1, 2, 2.0) |> ignore
  g.add_edge(0, 2, 5.0) |> ignore
  g.add_edge(1, 3, 1.0) |> ignore
  g.add_edge(3, 2, 2.0) |> ignore

  let w = g.weights(fn(cost) { cost })
  let paths = @path.dijkstra(g, 0, weight=w)
  assert_eq(paths.distance[2], Some(3.0)) // 0 to 1 to 2 beats 0 to 2
  assert_eq(paths.path_to(2), Some([0, 1, 2]))
  assert_eq(paths.distance[4], None) // node 4 is not reached
  // docs:end
}

///|
test "guide/refusal" {
  // docs:begin refusal
  let paid : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new(
    directed=false,
  )
  paid.add_node(()) |> ignore
  paid.add_node(()) |> ignore
  paid.add_edge(0, 1, -1.0) |> ignore

  let outcome = try {
    let _ = @path.dijkstra(paid, 0, weight=paid.weights(fn(cost) { cost }))
    "answered"
  } catch {
    @moongraph.Refused::NegativeWeight(edge~) =>
      "edge " + edge.to_string() + " is negative"
    _ => "something else"
  }
  assert_eq(outcome, "edge 0 is negative")
  // docs:end
}

///|
test "guide/walks" {
  // docs:begin walks
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (0, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(@traverse.bfs(g, 0), [0, 1, 2])
  assert_eq(@traverse.bfs_layers(g, [0]), [[0], [1, 2]])
  assert_eq(@traverse.dfs(g, 0), [0, 1, 2])
  // docs:end
}

///|
test "guide/shape" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (0, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  // docs:begin shape
  let parts = @component.components(g)
  assert_eq(parts.count, 1)
  assert_eq(parts.label, [0, 0, 0])
  assert_eq(@component.bridges(g), []) // every edge is on a cycle
  assert_eq(@component.articulation_points(g), [])
  // docs:end
}

///|
test "guide/trees-flow" {
  // docs:begin trees-flow
  let net : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new(
    directed=false,
  )
  for _ in 0..<4 {
    net.add_node(()) |> ignore
  }
  net.add_edge(0, 1, 1.0) |> ignore
  net.add_edge(1, 2, 2.0) |> ignore
  net.add_edge(0, 2, 5.0) |> ignore
  net.add_edge(1, 3, 1.0) |> ignore
  net.add_edge(3, 2, 2.0) |> ignore

  let weight = net.weights(fn(cost) { cost })
  let tree = @tree.minimum_spanning(net, weight~)
  assert_eq(tree.edges, [0, 3, 1]) // three edges for four nodes
  assert_eq(tree.weight, 4.0)

  let errand : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new(
    directed=true,
  )
  for _ in 0..<4 {
    errand.add_node(()) |> ignore
  }
  errand.add_edge(0, 2, 1.0) |> ignore
  errand.add_edge(0, 1, 1.0) |> ignore
  errand.add_edge(1, 3, 1.0) |> ignore
  errand.add_edge(2, 3, 1.0) |> ignore

  let flow = @flow.max_flow(
    errand,
    0,
    3,
    capacity=errand.weights(fn(cost) { cost }),
  )
  assert_eq(flow.value, 2.0)
  assert_eq(flow.flow, [1.0, 1.0, 1.0, 1.0]) // the amount on each edge
  // docs:end
}

///|
test "guide/cycles" {
  // docs:begin cycles
  let ring : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=true,
  )
  assert_eq(@cycle.girth(ring), Some(3))
  assert_true(@cycle.is_eulerian(ring))
  assert_eq(@cycle.eulerian_circuit(ring).length(), 3)

  let fan : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (0, 2)],
    node=(),
    edge=(),
    directed=true,
  )
  assert_eq(@cycle.girth(fan), None) // the arcs never come back
  assert_false(@cycle.is_eulerian(fan)) // two out of 0, nothing in
  assert_false(@cycle.has_eulerian_path(fan))
  // docs:end
}

///|
test "guide/files" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (0, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  // docs:begin files
  let text = @io.edge_list(g)
  assert_eq(text, "0 1\n1 2\n0 2\n")

  let back = @io.parse_edges(text)
  assert_eq(@io.graph6(back), "Bw") // a node count, then one bit an edge
  assert_eq(@io.sparse6(back), ":BcN") // only the edges that are there
  let zeroes : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new()
  assert_eq(@io.sparse6(zeroes), ":?")
  // docs:end
  assert_eq(back.node_count(), 3)
  assert_eq(back.edge_count(), 3)
}

///|
test "guide/graphml" {
  let g : @moongraph.Graph[String, Double] = @moongraph.Graph::new()
  g.add_node("a") |> ignore
  g.add_node("b") |> ignore
  g.add_edge(0, 1, 2.5) |> ignore
  let document = @graphml.write(
    g,
    labels=fn(node) { g.node_data(node) },
    weight=g.weights(fn(w) { w }),
  )
  // docs:begin graphml
  let loaded = @graphml.read(document)
  assert_eq(loaded.graph.node_count(), 2)
  assert_eq(loaded.graph.edge_data(0), 2.5)
  // docs:end
}

///|
test "guide/measure" {
  let net : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new(
    directed=false,
  )
  for _ in 0..<4 {
    net.add_node(()) |> ignore
  }
  net.add_edge(0, 1, 1.0) |> ignore
  net.add_edge(1, 2, 2.0) |> ignore
  net.add_edge(0, 2, 5.0) |> ignore
  net.add_edge(1, 3, 1.0) |> ignore
  net.add_edge(3, 2, 2.0) |> ignore
  // docs:begin measure
  let ring : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0), (0, 3)],
    node=(),
    edge=(),
    directed=true,
  )
  let census = @metric.triadic_census(ring)
  assert_eq(census.of("030C"), Some(1)) // one cycle, three arcs
  assert_eq(census.count.length(), 16) // every shape, counted

  assert_eq(@metric.wiener_index(net), Some(7.0)) // every distance, added up
  assert_eq(@metric.wl_hash(net).length(), 32) // one fingerprint, 16 bytes
  // docs:end
}

///|
test "guide/ranking" {
  let net : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new(
    directed=false,
  )
  for _ in 0..<4 {
    net.add_node(()) |> ignore
  }
  net.add_edge(0, 1, 1.0) |> ignore
  net.add_edge(1, 2, 2.0) |> ignore
  net.add_edge(0, 2, 5.0) |> ignore
  net.add_edge(1, 3, 1.0) |> ignore
  net.add_edge(3, 2, 2.0) |> ignore
  // docs:begin ranking
  assert_eq(@metric.similarity(net, 0, 3), 1.0) // Jaccard, by default
  assert_eq(@metric.similarity(net, 0, 3, kind=AdamicAdar), 1.8204784532536746)
  assert_eq(@path.voronoi(net, [0, 3]), [0, 0, 0, 3]) // the nearest centre
  assert_eq(@metric.link_prediction(net), [(0, 3, 1.0)]) // no edge, but close
  assert_eq(@approx.traveling_salesman_exact(net, start=0), [0, 2, 3, 1, 0])
  // docs:end
}

///|
test "guide/board" {
  // docs:begin board
  let board = @grid.Grid::new(4, 4)
  let route = board.jps(0, 15).unwrap()
  assert_eq(route[0], 0)
  assert_eq(route[route.length() - 1], 15)
  assert_eq(board.path_cost(route), 4.242640687119286) // three diagonals
  board.block(1, 1)
  let around = board.jps(0, 15).unwrap()
  assert_eq(board.path_cost(around), 4.82842712474619) // one wall, one detour
  // docs:end
}

///|
test "guide/sets-clauses" {
  // docs:begin sets-clauses
  let forest = @dsu.Dsu::new(6)
  forest.union(0, 1) |> ignore
  forest.union(1, 2) |> ignore
  forest.union(4, 5) |> ignore
  assert_eq(forest.count(), 3)
  assert_eq(forest.groups(), [[0, 1, 2], [3], [4, 5]])
  assert_true(forest.same(2, 0))

  let clauses = @sat.TwoSat::new(2)
  clauses.add_clause(0, true, 1, false) // x0, or x1 is false
  assert_true(clauses.satisfiable())
  let model = clauses.answer().unwrap()
  assert_true(model[0] || !model[1])
  // docs:end
  let contradiction = @sat.TwoSat::new(1)
  contradiction.add_clause(0, true, 0, true)
  contradiction.add_clause(0, false, 0, false)
  assert_eq(contradiction.answer(), None)
}

///|
test "guide/kept-flow" {
  // docs:begin kept-flow
  let net = @incremental.Flow::new(4)
  net.add_edge(0, 1, 2.0) |> ignore
  net.add_edge(1, 3, 2.0) |> ignore
  net.add_edge(0, 2, 1.0) |> ignore
  net.add_edge(2, 3, 1.0) |> ignore
  assert_eq(net.flow(0, 3), 3.0) // both routes, filled
  net.change_edge(0, 4.0, 2.0) // widen the first edge only
  assert_eq(net.flow(0, 3), 0.0) // the second is still the bottleneck
  net.change_edge(1, 4.0, 2.0) // widen that one too
  assert_eq(net.flow(0, 3), 2.0) // two more units, without rebuilding
  assert_eq(net.min_cut(0), [true, false, false, false])
  // docs:end
}
