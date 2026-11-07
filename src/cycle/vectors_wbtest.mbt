///|
test "the girth agrees with the reference" {
  for case in @internal.cycle_cases() {
    let graph = @internal.vector_graph(case.graph)
    match girth(graph) {
      Some(value) =>
        if value != case.girth {
          fail(case.graph.name + ": girth differs")
        }
      None =>
        if case.girth != -1 {
          fail(case.graph.name + ": expected no cycle, the reference found one")
        }
    }
  }
}

///|
test "whether the graph is Eulerian agrees with the reference" {
  for case in @internal.cycle_cases() {
    let graph = @internal.vector_graph(case.graph)
    if is_eulerian(graph) != case.eulerian {
      fail(case.graph.name + ": Eulerian reading differs")
    }
  }
}
