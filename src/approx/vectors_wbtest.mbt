///|
test "the vertex cover touches exactly the nodes the reference names" {
  for case in @internal.approx_cases() {
    let graph : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
      directed=case.directed,
    )
    for node in 0..<case.nodes {
      graph.add_node(node) |> ignore
    }
    for (a, b, _) in case.arcs {
      graph.add_edge(a, b, ()) |> ignore
    }
    let cover = vertex_cover(graph)
    if cover != case.cover {
      fail(case.name + ": vertex cover differs")
    }
  }
}

///|
test "the exact tour is the cheapest one, and the heuristic is not cheaper" {
  for case in @internal.tour_cases() {
    let graph = @internal.vector_graph(case.graph)
    let weight = graph.weights(fn(w) { w })
    let exact = traveling_salesman_exact(graph, start=case.start, weight~)
    // A closed tour: every node once, the start repeated at the end.
    assert_eq(exact.length(), graph.node_count() + 1)
    assert_eq(exact[0], case.start)
    assert_eq(exact[exact.length() - 1], case.start)
    let seen : Array[Bool] = Array::make(graph.node_count(), false)
    for node in exact {
      seen[node] = true
    }
    for flag in seen {
      assert_true(flag)
    }
    match tour_length(graph, exact, weight~) {
      Some(length) =>
        if !@internal.close(length, case.cost) {
          fail(case.graph.name + ": the exact tour is not the cheapest")
        }
      None => fail(case.graph.name + ": the exact tour has a leg with no route")
    }
    // The heuristic cannot beat the optimum, and must also be a tour.
    let greedy = traveling_salesman(graph, start=case.start, weight~)
    match tour_length(graph, greedy, weight~) {
      Some(length) => assert_true(length >= case.cost - 1.0e-9)
      None => fail(case.graph.name + ": the heuristic has a leg with no route")
    }
  }
}
