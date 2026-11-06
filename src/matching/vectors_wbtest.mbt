///|
test "the largest matching size agrees with the reference" {
  for case in @internal.matching_cases() {
    let graph = @internal.vector_graph(case.graph)
    let m = matching_maximum(graph)
    if m.pairs.length() != case.pairs {
      fail(case.graph.name + ": matching size differs")
    }
  }
}
