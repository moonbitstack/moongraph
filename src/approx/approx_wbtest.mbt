///|
test "a tour visits every node once and returns" {
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 0), (0, 2)],
    node=(),
    edge=1.0,
    directed=false,
  )
  let tour = traveling_salesman(g, start=0, weight=g.weights(fn(w) { w }))
  assert_eq(tour.length(), 5)
  assert_eq(tour[0], 0)
  assert_eq(tour[tour.length() - 1], 0)
}

///|
test "the cover and the dominating set cover" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  let cover = vertex_cover(g)
  assert_eq(cover, [0, 1, 2])
  let dominating = dominating_set(g)
  assert_eq(dominating, [1])
}

///|
test "the densest part of a triangle with a pendant is the triangle" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0), (2, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  // The whole graph and the triangle are both of density one, and the earlier set wins.
  assert_eq(densest_subgraph(g), [0, 1, 2, 3])
}

///|
test "a tree has treewidth one and a spanner keeps the routes" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(treewidth_bound(g), 1)
  let s = spanner(g, stretch=2)
  assert_eq(s.node_count(), 4)
  assert_true(s.edge_count() >= 3)
}
