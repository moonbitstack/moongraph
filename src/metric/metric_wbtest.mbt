///|
test "density and degrees" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(density(g), 1.0)
  assert_eq(degree(g), [2, 2, 2])
  assert_eq(degree_histogram(g), [0, 0, 3])
}

///|
test "distance measures of a path" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(diameter(g), 3)
  assert_eq(radius(g), 2)
  assert_eq(center(g), [1, 2])
  assert_eq(periphery(g), [0, 3])
  assert_eq(eccentricity(g, 0), 3)
}

///|
test "clustering of a triangle and a square" {
  let triangle : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(clustering(triangle, 0), 1.0)
  assert_eq(transitivity(triangle), 1.0)
  let square : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(clustering(square, 0), 0.0)
  // The two neighbours of 0 in a square are joined by a two-step route, which is a square.
  assert_eq(square_clustering(square, 0), 1.0)
}

///|
test "neighbourhood similarity" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 2), (1, 2), (0, 3), (1, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(similarity(g, 0, 1), 1.0)
  assert_eq(similarity(g, 0, 1, kind=Dice), 1.0)
  assert_true(adamic_adar(g, 0, 1) > 0.0)
}
