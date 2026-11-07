///|
test "the exact chromatic number agrees with the reference" {
  for case in @internal.colour_cases() {
    let graph = @internal.vector_graph(case.graph)
    let exact = chromatic_number(graph, limit=16) catch { _ => -1 }
    if exact != case.exact {
      fail(case.graph.name + ": exact chromatic number differs")
    }
  }
}

///|
test "whether two colours suffice agrees with the reference" {
  for case in @internal.colour_cases() {
    let graph = @internal.vector_graph(case.graph)
    let two = try {
      let _ = chromatic_number(graph, limit=2)
      true
    } catch {
      _ => false
    }
    if two != case.bipartite {
      fail(case.graph.name + ": two-colour reading differs")
    }
  }
}
