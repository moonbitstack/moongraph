// Turning a generated case into a graph, so every family replays the same way.

///|
/// The graph a generated case describes, with the weights as the edge payloads.
pub fn vector_graph(c : WeightedCase) -> @moongraph.Graph[Unit, Double] {
  let graph : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new(
    directed=c.directed,
  )
  for _ in 0..<c.nodes {
    graph.add_node(()) |> ignore
  }
  for (a, b, w) in c.arcs {
    graph.add_edge(a, b, w) |> ignore
  }
  graph
}

///|
/// Whether two distances agree to the precision the generator wrote them with.
pub fn close(a : Double, b : Double) -> Bool {
  let delta = a - b
  let size = if delta < 0.0 { -delta } else { delta }
  size < 1.0e-6
}
