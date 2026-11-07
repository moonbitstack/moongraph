///|
test "the transitive reduction agrees with the reference" {
  for case in @internal.dag_cases() {
    let graph : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
      directed=true,
    )
    for node in 0..<case.nodes {
      graph.add_node(node) |> ignore
    }
    for (a, b, _) in case.arcs {
      graph.add_edge(a, b, ()) |> ignore
    }
    let reduction = transitive_reduction(graph).copy()
    reduction.sort_by(fn(x, y) {
      if x.0 != y.0 {
        x.0 - y.0
      } else {
        x.1 - y.1
      }
    })
    let expected : Array[(Int32, Int32)] = case.reduction.copy()
    expected.sort_by(fn(x, y) { if x.0 != y.0 { x.0 - y.0 } else { x.1 - y.1 } })
    if reduction != expected {
      fail(case.name + ": transitive reduction differs")
    }
  }
}

///|
test "the longest route of a dag agrees with the reference" {
  for case in @internal.dag_cases() {
    let graph : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
      directed=true,
    )
    for node in 0..<case.nodes {
      graph.add_node(node) |> ignore
    }
    for (a, b, _) in case.arcs {
      graph.add_edge(a, b, ()) |> ignore
    }
    let length = longest_path_length(graph) catch { _ => -1.0 }
    if length != case.longest.to_double() {
      fail(case.name + ": longest route differs")
    }
  }
}
