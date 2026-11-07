///|
test "the GraphML documents parse to the graph the reference records" {
  for case in @internal.graphml_cases() {
    let loaded = read(case.text) catch { _ => fail("graphml: refused to read") }
    if loaded.graph.node_count() != case.nodes ||
      loaded.graph.edge_count() != case.edges {
      fail("graphml: parsed size differs")
    }
  }
}
