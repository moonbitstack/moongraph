///|
/// The home page: `docs/index.html`.

///|
test "index/dijkstra" {
  // docs:begin dijkstra
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new(directed=false)
  for _ in 0..<4 {
    g.add_node(()) |> ignore
  }
  g.add_edge(0, 1, 2.0) |> ignore
  g.add_edge(1, 2, 3.0) |> ignore

  let paths = @path.dijkstra(g, 0, weight=g.weights(fn(cost) { cost }))
  assert_eq(paths.distance[2], Some(5.0))
  assert_eq(paths.path_to(2), Some([0, 1, 2]))
  assert_eq(paths.distance[3], None) // node 3 has no edge yet
  // docs:end
}
