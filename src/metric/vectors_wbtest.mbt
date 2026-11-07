///|
test "transitivity agrees with the reference" {
  for case in @internal.clustering_cases() {
    let graph = @internal.vector_graph(case.graph)
    if !@internal.close(transitivity(graph), case.transitivity) {
      fail(case.graph.name + ": transitivity differs")
    }
  }
}

///|
test "the link prediction family agrees with the reference" {
  for case in @internal.similarity_cases() {
    let graph = @internal.vector_graph(case.graph)
    let spot = case.graph.name +
      " at " +
      case.a.to_string() +
      ", " +
      case.b.to_string()
    assert_eq(common_neighbors(graph, case.a, case.b), case.shared)
    let checks : Array[(String, Double, Double)] = [
      ("jaccard", similarity(graph, case.a, case.b), case.jaccard),
      ("dice", similarity(graph, case.a, case.b, kind=Dice), case.dice),
      ("cosine", similarity(graph, case.a, case.b, kind=Cosine), case.cosine),
      ("overlap", similarity(graph, case.a, case.b, kind=Overlap), case.overlap),
      (
        "adamic-adar",
        similarity(graph, case.a, case.b, kind=AdamicAdar),
        case.adamic,
      ),
      (
        "resource allocation",
        similarity(graph, case.a, case.b, kind=ResourceAllocation),
        case.resource,
      ),
      (
        "preferential attachment",
        similarity(graph, case.a, case.b, kind=PreferentialAttachment),
        case.attachment,
      ),
    ]
    for check in checks {
      let (label, got, want) = check
      if !@internal.close(got, want) {
        fail(spot + ": " + label + " differs")
      }
    }
  }
}

///|
test "the link prediction list covers every non-edge, once" {
  for case in @internal.similarity_cases() {
    let graph = @internal.vector_graph(case.graph)
    let scored = link_prediction(graph)
    let n = graph.node_count()
    let mut expected = 0
    for a in 0..<n {
      for b in (a + 1)..<n {
        if !@internal.adjacent(graph, a, b) {
          expected = expected + 1
        }
      }
    }
    assert_eq(scored.length(), expected)
  }
}
