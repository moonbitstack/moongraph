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

///|
test "the bytes a writer produces are the reference's bytes" {
  // The read formats are interchange formats, so the text itself is the answer: a graph
  // that reads back correctly but writes a different string is not the same format.
  for case in @internal.io_cases() {
    if case.format != "graph6" && case.format != "sparse6" {
      continue
    }
    let graph = @internal.vector_graph(case.graph)
    let written = if case.format == "graph6" {
      graph6(graph)
    } else {
      sparse6(graph)
    }
    if written != case.text {
      fail(case.format + " of " + case.graph.name + ": wrote " + written)
    }
  }
}

///|
test "what a sparse6 text carries is the graph it came from" {
  for case in @internal.io_cases() {
    if case.format != "sparse6" {
      continue
    }
    let back = parse_sparse6(case.text)
    assert_eq(back.node_count(), case.nodes)
    assert_eq(back.edge_count(), case.edges)
    // An edge and its reverse are the same edge, so the pairs are compared by number.
    let want : Array[(Int32, Int32)] = []
    for (a, b, _) in case.graph.arcs {
      want.push(if a < b { (a, b) } else { (b, a) })
    }
    want.sort()
    let got : Array[(Int32, Int32)] = []
    for edge in 0..<back.edge_count() {
      let (a, b) = back.endpoints(edge)
      got.push(if a < b { (a, b) } else { (b, a) })
    }
    got.sort()
    assert_eq(got, want)
  }
}
