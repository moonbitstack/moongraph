///|
test "graphml round trip keeps labels and weights" {
  let g : @moongraph.Graph[String, Double] = @moongraph.Graph::new()
  g.add_node("a") |> ignore
  g.add_node("b") |> ignore
  g.add_edge(0, 1, 2.5) |> ignore
  let text = write(
    g,
    labels=fn(node) { g.node_data(node) },
    weight=g.weights(fn(w) { w }),
  )
  let loaded = read(text)
  assert_eq(loaded.graph.node_count(), 2)
  assert_eq(loaded.graph.edge_count(), 1)
  assert_eq(loaded.graph.node_data(0), "a")
  assert_eq(loaded.graph.edge_data(0), 2.5)
  assert_eq(loaded.graph.directed(), true)
}

///|
test "graphml refuses a document that is not graphml" {
  let refused = try {
    read("<html><body/></html>") |> ignore
    false
  } catch {
    @moongraph.Refused::NotA(kind~, ..) => kind == "GraphML"
    _ => false
  }
  assert_true(refused)
}
