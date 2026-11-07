///|
fn of(c : @internal.WeightedCase) -> @moongraph.Graph[Int32, Unit] {
  let graph : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=c.directed,
  )
  for node in 0..<c.nodes {
    graph.add_node(node) |> ignore
  }
  for (a, b, _) in c.arcs {
    graph.add_edge(a, b, ()) |> ignore
  }
  graph
}

///|
test "the size of a graph operation agrees with the reference" {
  for case in @internal.op_cases() {
    let graph = of(case.graph)
    let partner = of(case.partner)
    let result : @moongraph.Graph[Int32, Unit] = match case.name {
      "union" => union(graph, partner)
      "intersection" => intersection(graph, partner)
      "difference" => difference(graph, partner)
      "symmetric_difference" => symmetric_difference(graph, partner)
      "disjoint_union" => disjoint_union(graph, partner)
      "complement" => complement(graph)
      "line_graph" => line_graph(graph)
      "reverse" => reverse(graph)
      _ => graph
    }
    if result.node_count() != case.nodes || result.edge_count() != case.edges {
      fail(case.name + " on " + case.graph.name + ": result size differs")
    }
  }
}
