///|
test "the clique numbers agree with the reference" {
  for case in @internal.clique_cases() {
    let graph = @internal.vector_graph(case.graph)
    if clique_number(graph) != case.omega {
      fail(case.graph.name + ": largest clique differs")
    }
    if independence_number(graph) != case.alpha {
      fail(case.graph.name + ": largest independent set differs")
    }
  }
}

///|
test "the count of maximal cliques agrees with the reference" {
  for case in @internal.clique_cases() {
    let graph = @internal.vector_graph(case.graph)
    let cliques = maximal_cliques(graph)
    if cliques.members.length() != case.maximal {
      fail(case.graph.name + ": maximal clique count differs")
    }
  }
}

///|
test "chordality agrees with the reference" {
  for case in @internal.clique_cases() {
    let graph = @internal.vector_graph(case.graph)
    if is_chordal(graph) != case.chordal {
      fail(case.graph.name + ": chordality differs")
    }
  }
}
