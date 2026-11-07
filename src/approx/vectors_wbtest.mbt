///|
test "the vertex cover touches exactly the nodes the reference names" {
  for case in @internal.approx_cases() {
    let graph : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
      directed=case.directed,
    )
    for node in 0..<case.nodes {
      graph.add_node(node) |> ignore
    }
    for (a, b, _) in case.arcs {
      graph.add_edge(a, b, ()) |> ignore
    }
    let cover = vertex_cover(graph)
    if cover != case.cover {
      fail(case.name + ": vertex cover differs")
    }
  }
}
