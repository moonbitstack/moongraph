///|
test "a bipartite projection joins everyone who shares a neighbour" {
  // 0 and 1 share the two events 2 and 3; 2 and 3 are the other side.
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 2), (0, 3), (1, 2), (1, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  let projected = bipartite_projection(g, [0, 1])
  // Two events, one pair of people: the pair is one edge, not two.
  assert_eq(projected.edge_count(), 1)
  assert_true(projected.find_edge(0, 1) is Some(_))
  // The event side keeps its numbers and loses its edges.
  assert_eq(projected.node_count(), 4)
  assert_eq(projected.endpoints(0), (0, 1))

  // Three people at one event become a triangle.
  let star : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 3), (1, 3), (2, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(bipartite_projection(star, [0, 1, 2]).edge_count(), 3)
}

///|
test "a projection onto one side of a bipartite graph keeps that side's degrees" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 4), (0, 5), (1, 4), (2, 5), (2, 4)],
    node=(),
    edge=(),
    directed=false,
  )
  let projected = bipartite_projection(g, [0, 1, 2])
  // Event 4 is shared by 0, 1 and 2, so all three are joined; event 5 only repeats 0-2.
  assert_eq(projected.neighbors(0).length(), 2)
  assert_eq(projected.neighbors(1).length(), 2)
  assert_true(projected.find_edge(1, 2) is Some(_))
}
