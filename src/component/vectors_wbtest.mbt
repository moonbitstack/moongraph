///|
test "the piece counts agree with the reference" {
  for case in @internal.component_cases() {
    let graph = @internal.vector_graph(case.graph)
    if components(graph).count != case.weak {
      fail(case.graph.name + ": weak count differs")
    }
    if strong_components(graph).count != case.strong {
      fail(case.graph.name + ": strong count differs")
    }
  }
}
