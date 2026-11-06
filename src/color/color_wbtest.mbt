///|
test "a triangle needs three colours" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  let colouring = greedy_coloring(g)
  assert_eq(colouring.count, 3)
  assert_true(is_coloring(g, colouring))
  assert_eq(chromatic_number(g), 3)
  assert_eq(dsatur(g).count, 3)
}

///|
test "an even cycle needs two colours" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(chromatic_number(g), 2)
  assert_eq(greedy_coloring(g, order=SmallestLast).count, 2)
}

///|
test "edge colouring of a star uses as many colours as edges" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (0, 2), (0, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  let colouring = edge_coloring(g)
  assert_eq(colouring.count, 3)
  assert_true(is_edge_coloring(g, colouring))
}

///|
test "a colour limit that is too small is refused" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  let refused = try {
    chromatic_number(g, limit=2) |> ignore
    false
  } catch {
    @moongraph.Refused::NoSolution => true
    _ => false
  }
  assert_true(refused)
}
