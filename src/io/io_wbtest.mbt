///|
fn sample() -> @moongraph.Graph[Unit, Unit] {
  @moongraph.Graph::from_edges([(0, 1), (1, 2)], node=(), edge=(), directed=false)
}

///|
test "edge list round trip" {
  let g = sample()
  let text = edge_list(g)
  let back = parse_edges(text)
  assert_eq(back.node_count(), 3)
  assert_eq(back.edge_count(), 2)
  assert_eq(back.directed(), false)
}

///|
test "adjacency list round trip" {
  let g = sample()
  let back = parse_adjacency(adjacency_list(g))
  assert_eq(back.node_count(), 3)
  assert_eq(back.edge_count(), 2)
}

///|
test "gml round trip" {
  let g = sample()
  let back = parse_gml(gml(g))
  assert_eq(back.node_count(), 3)
  assert_eq(back.edge_count(), 2)
}

///|
test "pajek round trip counts from one" {
  let g = sample()
  let text = pajek(g)
  assert_eq(text.has_prefix("*Vertices 3"), true)
  let back = parse_pajek(text)
  assert_eq(back.node_count(), 3)
  assert_eq(back.edge_count(), 2)
}

///|
test "graph6 round trip" {
  let g = sample()
  let back = parse_graph6(graph6(g))
  assert_eq(back.node_count(), 3)
  assert_eq(back.edge_count(), 2)
}

///|
test "sparse6 round trip" {
  let g = sample()
  let text = sparse6(g)
  let back = parse_sparse6(text)
  assert_eq(back.node_count(), 3)
  assert_eq(back.edge_count(), 2)
}

///|
test "a broken edge list names where it broke" {
  let refused = try {
    parse_edges("0 1\n2 x\n") |> ignore
    None
  } catch {
    @moongraph.Refused::Malformed(line=l, column=c, ..) => Some((l, c))
    _ => None
  }
  assert_eq(refused, Some((2, 1)))
}
