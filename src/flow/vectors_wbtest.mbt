///|
test "the maximum flow value agrees with the reference" {
  for case in @internal.flow_cases() {
    let graph = @internal.vector_graph(case.graph)
    let value = max_flow_value(
      graph,
      case.source,
      case.sink,
      capacity=graph.weights(fn(cost) { cost }),
    )
    if !@internal.close(value, case.value) {
      fail(case.graph.name + ": flow value differs")
    }
  }
}
