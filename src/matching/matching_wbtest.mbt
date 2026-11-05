///|
test "maximal and maximum matching of a path" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(matching_maximal(g).pairs.length(), 2)
  assert_eq(matching_maximum(g).pairs.length(), 2)
  assert_true(is_maximal_matching(g, matching_maximal(g).pairs))
  assert_true(is_perfect_matching(g, matching_maximum(g).pairs))
}

///|
test "maximum matching of an odd cycle leaves one node out" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 4), (4, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  let m = matching_maximum(g)
  assert_eq(m.pairs.length(), 2)
  assert_true(is_matching(g, m.pairs))
}

///|
test "bipartite matching refuses a graph with an odd cycle" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(bipartition(g), None)
  let refused = try {
    matching_bipartite(g) |> ignore
    false
  } catch {
    @moongraph.Refused::NotA(kind~, ..) => kind == "bipartite"
    _ => false
  }
  assert_true(refused)
}

///|
test "bipartite matching of a complete bipartite graph is perfect" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 2), (0, 3), (1, 2), (1, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  let m = matching_bipartite(g)
  assert_eq(m.pairs.length(), 2)
  assert_true(is_perfect_matching(g, m.pairs))
}

///|
test "assignment picks the cheap pairing" {
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges(
    [(0, 2), (0, 3), (1, 2), (1, 3)],
    node=(),
    edge=1.0,
    directed=false,
  )
  g.set_edge_data(0, 1.0)
  g.set_edge_data(3, 9.0)
  let m = assignment(g, weight=g.weights(fn(cost) { cost }))
  assert_eq(m.weight, 2.0)
  assert_true(is_matching(g, m.pairs))
}

///|
test "edge cover touches every node" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  let cover = edge_cover(g)
  assert_true(is_edge_cover(g, cover))
}

///|
test "a vertex cover of a star is one node" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (0, 2), (0, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  let cover = vertex_cover_bipartite(g)
  assert_eq(cover.length(), 1)
  assert_eq(cover[0], 0)
}
