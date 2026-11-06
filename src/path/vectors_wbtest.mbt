///|
test "dijkstra agrees with the reference on every case" {
  for case in @internal.dijkstra_cases() {
    let graph = @internal.vector_graph(case.graph)
    let paths = dijkstra(
      graph,
      case.source,
      weight=graph.weights(fn(cost) { cost }),
    )
    for node in 0..<case.graph.nodes {
      let expected = case.distance[node]
      match paths.distance[node] {
        Some(value) =>
          if expected < 0.0 {
            fail(
              case.graph.name +
              ": reached node " +
              node.to_string() +
              " where none exists",
            )
          } else if !@internal.close(value, expected) {
            fail(case.graph.name + ": node " + node.to_string() + " differs")
          }
        None =>
          if expected >= 0.0 {
            fail(case.graph.name + ": missed node " + node.to_string())
          }
      }
    }
  }
}

///|
test "bellman_ford agrees with the reference where no edge is negative" {
  for case in @internal.bellman_ford_cases() {
    let graph = @internal.vector_graph(case.graph)
    let paths = bellman_ford(
      graph,
      case.source,
      weight=graph.weights(fn(cost) { cost }),
    )
    for node in 0..<case.graph.nodes {
      let expected = case.distance[node]
      match paths.distance[node] {
        Some(value) =>
          if expected < 0.0 || !@internal.close(value, expected) {
            fail(case.graph.name + ": node " + node.to_string() + " differs")
          }
        None =>
          if expected >= 0.0 {
            fail(case.graph.name + ": missed node " + node.to_string())
          }
      }
    }
  }
}

///|
test "floyd_warshall agrees with the reference on every pair" {
  for case in @internal.all_pairs_cases() {
    let graph = @internal.vector_graph(case.graph)
    let all = floyd_warshall(graph, weight=graph.weights(fn(cost) { cost }))
    for a in 0..<case.graph.nodes {
      for b in 0..<case.graph.nodes {
        let expected = case.distance[a][b]
        match all.distance[a][b] {
          Some(value) =>
            if expected < 0.0 || !@internal.close(value, expected) {
              fail(
                case.graph.name +
                ": pair " +
                a.to_string() +
                "," +
                b.to_string() +
                " differs",
              )
            }
          None =>
            if expected >= 0.0 {
              fail(
                case.graph.name +
                ": missed the pair " +
                a.to_string() +
                "," +
                b.to_string(),
              )
            }
        }
      }
    }
  }
}
