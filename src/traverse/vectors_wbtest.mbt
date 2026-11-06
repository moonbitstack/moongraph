///|
test "breadth-first hops agree with the reference" {
  for case in @internal.bfs_cases() {
    let graph = @internal.vector_graph(case.graph)
    let paths = bfs_tree(graph, case.source)
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
