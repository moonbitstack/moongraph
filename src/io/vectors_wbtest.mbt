///|
fn parsed_size(
  format : String,
  directed : Bool,
  text : StringView,
) -> (Int32, Int32) raise @moongraph.Refused {
  if format == "edges" {
    let back = parse_edges(text, directed~)
    (back.node_count(), back.edge_count())
  } else if format == "adjacency" {
    let back = parse_adjacency(text, directed~)
    (back.node_count(), back.edge_count())
  } else if format == "graph6" {
    let back = parse_graph6(text)
    (back.node_count(), back.edge_count())
  } else if format == "sparse6" {
    let back = parse_sparse6(text)
    (back.node_count(), back.edge_count())
  } else {
    (0, 0)
  }
}

///|
test "the read formats parse to the graph the reference records" {
  for case in @internal.io_cases() {
    let (nodes, edges) = parsed_size(case.format, case.directed, case.text)
    if nodes != case.nodes || edges != case.edges {
      fail(case.format + ": parsed size differs")
    }
  }
}
