///|
/// The text one graph of `n` nodes writes, built from its edge pairs.
fn written(n : Int32, edges : Array[(Int32, Int32)]) -> String {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new(directed=false)
  for _ in 0..<n {
    g.add_node(()) |> ignore
  }
  for (a, b) in edges {
    g.add_edge(a, b, ()) |> ignore
  }
  sparse6(g)
}

///|
test "sparse6 writes the bytes the format defines" {
  // Published texts for the small shapes: the writer's bytes are the format's, not a
  // rendering that happens to read back.
  assert_eq(written(0, []), ":?")
  assert_eq(written(1, [(0, 0)]), ":@N")
  assert_eq(written(2, [(0, 1)]), ":An")
  assert_eq(written(4, [(0, 1)]), ":Cb")
  assert_eq(
    written(4, [(0, 1), (0, 2), (0, 3), (1, 2), (1, 3), (2, 3)]),
    ":CcKI",
  )
  assert_eq(written(5, [(0, 1), (1, 2), (2, 3), (3, 4), (4, 0)]), ":DaY_~")
  // The worked example from the format's description: seven nodes, four edges.
  let example = parse_sparse6(":Fa@x^")
  assert_eq(example.node_count(), 7)
  assert_eq(example.edge_count(), 4)
  assert_eq(sparse6(example), ":Fa@x^")
}

///|
test "a count wider than a byte widens the header, not the bits" {
  // Three node counts on either side of both widenings: one byte, four, eight. The text
  // is the same graph every time, so a reader that guessed the width from the body would
  // come apart here.
  assert_eq(written(63, [(0, 1), (1, 2), (2, 3)]), ":~??~_OWV")
  assert_eq(written(64, [(0, 1), (1, 2), (2, 3)]), ":~?@?_OWV")
  assert_eq(written(300, [(0, 1), (1, 2), (299, 3)]), ":~?Ck_A?[j?N")
}

///|
test "a node count takes one, four or eight bytes" {
  let cases : Array[(Int32, Int32)] = [
    (0, 1),
    (62, 1),
    (63, 4),
    (258047, 4),
    (258048, 8),
    (300000, 8),
  ]
  for (count, bytes) in cases {
    let header = count_header(count)
    assert_eq(header.length(), bytes)
    assert_eq(read_count(header, 0), Some((count, bytes)))
  }
}

///|
test "the last node's filler cannot read as a loop" {
  // Four nodes, k two bits, and an edge whose high end is the node before the last: a run
  // of one bits here would be read as a pair on the last node and add a loop to it.
  assert_eq(written(8, [(0, 1), (1, 2)]), ":GaV")
  assert_eq(written(16, [(0, 1)]), ":O`")
  assert_eq(written(32, [(0, 1)]), ":__")
  // The case the rule is for: the edge is on the node below the last one, so a run of ones
  // would be read as a loop on the last node. One zero first, then the same ones.
  assert_eq(written(8, [(6, 5)]), ":GxV")
  assert_eq(written(16, [(14, 13)]), ":O{v")
}

///|
test "loops and repeated edges are the format's own" {
  assert_eq(written(3, [(0, 1), (0, 1), (1, 2)]), ":B_n")
  assert_eq(written(2, [(0, 0), (1, 1)]), ":AN")
  let back = parse_sparse6(":B_n")
  assert_eq(back.node_count(), 3)
  assert_eq(back.edge_count(), 3)
}

///|
test "a file marker is dropped, and a text that is not sparse6 is refused" {
  let marked = parse_sparse6(">>sparse6<<:An\n")
  assert_eq(marked.edge_count(), 1)
  let kind = try {
    parse_sparse6("An") |> ignore
    ""
  } catch {
    @moongraph.Refused::Malformed(want~, ..) => want
    _ => "another refusal"
  }
  assert_eq(kind, "a sparse6 string")
  // A count that stops in the middle of a wide header is refused rather than read as a
  // smaller graph.
  let cut = try {
    parse_sparse6(":~??") |> ignore
    ""
  } catch {
    @moongraph.Refused::Malformed(want~, ..) => want
    _ => "another refusal"
  }
  assert_eq(cut, "a node count")
}

///|
test "graph6 counts above 62 in four bytes as well" {
  let wide : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new(
    directed=false,
  )
  for _ in 0..<63 {
    wide.add_node(()) |> ignore
  }
  wide.add_edge(0, 62, ()) |> ignore
  let text = graph6(wide)
  // 63 * 62 / 2 bits of adjacency, six to a byte, after a four-byte count.
  assert_eq(text.length(), 4 + 326)
  let back = parse_graph6(text)
  assert_eq(back.node_count(), 63)
  assert_eq(back.edge_count(), 1)
}
