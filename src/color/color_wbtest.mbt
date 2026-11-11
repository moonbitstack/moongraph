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

///|
/// The orders a caller can ask for, so a test can walk all of them.
fn all_orders() -> Array[ColoringOrder] {
  [
    LargestFirst,
    SmallestLast,
    SaturationLargest,
    ConnectedSequential,
    RandomSequential,
  ]
}

///|
test "every order produces a proper colouring" {
  // A pentagon with a chord, and a path hanging off it: two pieces, odd and even.
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 4), (4, 0), (0, 2), (3, 5)],
    node=(),
    edge=(),
    directed=false,
  )
  let rng = @moonrand.seeded(b"colour-order")
  for order in all_orders() {
    let colouring = greedy_coloring(g, order~, rng~)
    if !is_coloring(g, colouring) {
      fail("an order left a neighbour with the same colour")
    }
    if colouring.count < chromatic_number(g) {
      fail("an order used fewer colours than the graph needs")
    }
    if colouring.count > g.node_count() {
      fail("an order used more colours than there are nodes")
    }
  }
}

///|
test "the saturation order is not the degree order" {
  // A path of six nodes is two-colourable, but taking the most connected node first leaves
  // the last pair of neighbours to the same third colour.
  let path : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (0, 5), (2, 3), (3, 4), (4, 5)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(chromatic_number(path), 2)
  assert_eq(greedy_coloring(path, order=LargestFirst).count, 3)
  assert_eq(greedy_coloring(path, order=SaturationLargest).count, 2)
  assert_eq(dsatur(path).count, 2)
  assert_true(is_coloring(path, greedy_coloring(path, order=SaturationLargest)))
}

///|
test "a random order is a proper colouring, and the same seed gives the same one" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 0), (0, 2), (4, 5), (5, 6)],
    node=(),
    edge=(),
    directed=false,
  )
  let first = greedy_coloring(
    g,
    order=RandomSequential,
    rng=@moonrand.seeded(b"colour-seed"),
  )
  let second = greedy_coloring(
    g,
    order=RandomSequential,
    rng=@moonrand.seeded(b"colour-seed"),
  )
  assert_eq(first.color, second.color)
  assert_true(is_coloring(g, first))
}
