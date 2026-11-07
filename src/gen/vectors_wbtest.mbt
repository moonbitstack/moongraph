///|
test "the named generators produce the graphs the reference records" {
  for case in @internal.gen_cases() {
    let graph : @moongraph.Graph[Int32, Unit] = match case.name {
      "complete" => complete(case.size, directed=false)
      "path" => path(case.size, directed=false)
      "cycle" => cycle(case.size)
      "star" => star(case.size)
      "wheel" => wheel(case.size)
      "ladder" => ladder(case.size)
      "petersen" => petersen()
      _ => petersen()
    }
    if graph.node_count() != case.nodes || graph.edge_count() != case.edges {
      fail(case.name + " " + case.size.to_string() + ": size differs")
    }
  }
}
