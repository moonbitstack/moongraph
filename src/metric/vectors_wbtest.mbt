///|
test "transitivity agrees with the reference" {
  for case in @internal.clustering_cases() {
    let graph = @internal.vector_graph(case.graph)
    if !@internal.close(transitivity(graph), case.transitivity) {
      fail(case.graph.name + ": transitivity differs")
    }
  }
}
