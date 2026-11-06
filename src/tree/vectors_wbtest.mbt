///|
test "the spanning tree weight agrees with the reference" {
  for case in @internal.spanning_cases() {
    let graph = @internal.vector_graph(case.graph)
    let tree = minimum_spanning(graph, weight=graph.weights(fn(cost) { cost }))
    if !@internal.close(tree.weight, case.weight) {
      fail(case.graph.name + ": tree weight differs")
    }
  }
}
