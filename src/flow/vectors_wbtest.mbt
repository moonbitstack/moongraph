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

///|
test "every method answers the reference's value" {
  // The vectors were generated from one implementation's answer; all five methods here have to
  // land on it, since a maximum flow is a number and not an algorithm.
  let methods : Array[FlowMethod] = [
    Dinitz,
    PushRelabel,
    EdmondsKarp,
    ShortestAugmenting,
    BoykovKolmogorov,
  ]
  for case in @internal.flow_cases() {
    let graph = @internal.vector_graph(case.graph)
    for solver in methods {
      let value = max_flow(
          graph,
          case.source,
          case.sink,
          capacity=graph.weights(fn(cost) { cost }),
          kind=solver,
        ).value
      if !@internal.close(value, case.value) {
        fail(case.graph.name + ": a method answers a different flow")
      }
    }
  }
}
