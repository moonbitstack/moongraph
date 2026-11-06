///|
fn star() -> @moongraph.Graph[Unit, Unit] {
  @moongraph.Graph::from_edges(
    [(0, 1), (0, 2), (0, 3)],
    node=(),
    edge=(),
    directed=false,
  )
}

///|
test "degree centrality of a star" {
  let scores = degree_centrality(star())
  assert_eq(scores.score[0], 1.0)
  assert_eq(scores.score[1], 1.0 / 3.0)
}

///|
test "betweenness of a path puts the weight on the middle" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  let scores = betweenness_centrality(g)
  assert_eq(scores.score[0], 0.0)
  assert_eq(scores.score[1], 1.0)
  // Both edges lie on the route from 0 to 1 and on the route from 0 to 2, so each
  // carries two pairs.
  let edges = edge_betweenness(g)
  assert_eq(edges, [2.0, 2.0])
}

///|
test "closeness is highest at the middle of a path" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  let scores = closeness_centrality(g)
  assert_true(scores.score[1] > scores.score[0])
}

///|
test "pagerank on a star favours the middle" {
  let scores = pagerank(star())
  assert_true(scores.score[0] > scores.score[1])
  let total = scores.score.fold(init=0.0, fn(acc, value) { acc + value })
  assert_true(total > 0.99 && total < 1.01)
}

///|
test "eigenvector and hub scores agree on a star" {
  let scores = eigenvector_centrality(star())
  assert_true(scores.score[0] > scores.score[1])
  let (hub, authority) = hits(star())
  assert_true(hub.score[0] >= hub.score[1])
  assert_true(authority.score[0] >= authority.score[1])
}
