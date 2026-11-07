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

///|
test "the triadic census agrees with the reference, shape by shape" {
  for case in @internal.triad_cases() {
    let graph = @internal.vector_graph(case.graph)
    let census = triadic_census(graph)
    for i in 0..<16 {
      if census.count[i] != case.count[i] {
        let want = case.count[i].to_string()
        let got = census.count[i].to_string()
        fail(
          case.graph.name +
          " " +
          triad_names[i] +
          ": want " +
          want +
          ", got " +
          got,
        )
      }
    }
    // The sixteen shapes account for every triple the graph has room for.
    let n = graph.node_count()
    let mut sum = 0
    for value in census.count {
      sum = sum + value
    }
    assert_eq(sum, n * (n - 1) * (n - 2) / 6)
  }
}

///|
test "the rich-club coefficient agrees with the reference" {
  for case in @internal.rich_club_cases() {
    let graph = @internal.vector_graph(case.graph)
    let got = rich_club(graph)
    assert_eq(got.length(), case.coefficient.length())
    for i in 0..<got.length() {
      match got[i] {
        Some(value) =>
          if case.coefficient[i] < 0.0 ||
            !@internal.close(value, case.coefficient[i]) {
            fail(
              case.graph.name +
              " at degree " +
              i.to_string() +
              ": the club differs",
            )
          }
        None =>
          if case.coefficient[i] >= 0.0 {
            fail(
              case.graph.name +
              " at degree " +
              i.to_string() +
              ": undefined here",
            )
          }
      }
    }
  }
}

///|
test "the Wiener index and the barycentre agree with the reference" {
  for case in @internal.distance_cases() {
    let graph = @internal.vector_graph(case.graph)
    match wiener_index(graph) {
      Some(value) =>
        if case.wiener < 0.0 || !@internal.close(value, case.wiener) {
          fail(case.graph.name + ": the Wiener index differs")
        }
      None =>
        if case.wiener >= 0.0 {
          fail(
            case.graph.name + ": the reference reaches every pair, we do not",
          )
        }
    }
    assert_eq(barycenter(graph), case.barycenter)
  }
}

///|
test "the resistance distances agree with the pseudo-inverse of the Laplacian" {
  for case in @internal.resistance_cases() {
    let graph = @internal.vector_graph(case.graph)
    let weight = graph.weights(fn(w) { w })
    let got = resistance_matrix(graph, weight~)
    for a in 0..<got.length() {
      for b in 0..<got.length() {
        let want = case.distance[a][b]
        match got[a][b] {
          Some(value) =>
            if want < 0.0 || !@internal.close(value, want) {
              fail(case.graph.name + ": resistance differs between two nodes")
            }
          None =>
            if want >= 0.0 {
              fail(
                case.graph.name + ": the reference reaches this pair, we do not",
              )
            }
        }
      }
    }
  }
}

///|
test "constraint and effective size agree with the reference" {
  for case in @internal.hole_cases() {
    let graph = @internal.vector_graph(case.graph)
    let tight = constraint(graph)
    let wide = effective_size(graph)
    for node in 0..<tight.length() {
      match tight[node] {
        Some(value) =>
          if case.constraint[node] < 0.0 ||
            !@internal.close(value, case.constraint[node]) {
            fail(case.graph.name + ": constraint differs")
          }
        None =>
          if case.constraint[node] >= 0.0 {
            fail(
              case.graph.name +
              ": the reference constrains this node, we do not",
            )
          }
      }
      match wide[node] {
        Some(value) =>
          if case.effective[node] < 0.0 ||
            !@internal.close(value, case.effective[node]) {
            fail(case.graph.name + ": effective size differs")
          }
        None =>
          if case.effective[node] >= 0.0 {
            fail(case.graph.name + ": the reference sizes this node, we do not")
          }
      }
    }
  }
}
