///|
test "the cells are the assignment grouped by centre" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 4)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(voronoi(g, [0, 4]), [0, 0, 0, 4, 4])
  assert_eq(voronoi_cells(g, [0, 4]), [[0, 1, 2], [3, 4]])
  // A centre that is not in the graph reaches nothing, and its cell is empty.
  assert_eq(voronoi_cells(g, [9, 4]), [[], [0, 1, 2, 3, 4]])
}

///|
test "a node equally far from two centres goes to the smaller one" {
  let star : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (0, 2), (0, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  // The hub is one hop from either centre, so the smaller number keeps it.
  assert_eq(voronoi(star, [1, 2]), [1, 1, 2, 1])
  assert_eq(voronoi(star, [2, 1]), [1, 1, 2, 1])
}

///|
test "a negative weight is refused, as everywhere else" {
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2)],
    node=(),
    edge=0.0,
    directed=false,
  )
  g.set_edge_data(0, -1.0)
  let weight = g.weights(fn(w) { w })
  try {
    voronoi(g, [0], weight~) |> ignore
    fail("a negative weight was accepted")
  } catch {
    @moongraph.Refused::NegativeWeight(_) => ()
    _ => fail("the wrong refusal")
  }
}
