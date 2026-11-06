///|
test "trees, forests and cycles" {
  let path : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_true(is_tree(path))
  assert_true(is_forest(path))
  assert_true(is_bipartite(path))
  path.add_edge(2, 0, ()) |> ignore
  assert_false(is_tree(path))
  assert_false(is_forest(path))
}

///|
test "an odd cycle is not bipartite" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(bipartition(g), None)
  assert_false(is_bipartite(g))
}

///|
test "core numbers of a triangle with a pendant" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0), (2, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(core_numbers(g), [2, 2, 2, 1])
  assert_eq(k_core(g, 2), [0, 1, 2])
  assert_eq(k_shell(g, 1), [3])
}

///|
test "degree sequences of a graph" {
  assert_true(is_graphical([2, 2, 2]))
  assert_false(is_graphical([3, 1]))
  assert_true(is_multigraphical([4, 2, 2]))
}

///|
test "a tournament has one edge per pair" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (0, 2)],
    node=(),
    edge=(),
  )
  assert_true(is_tournament(g))
  assert_eq(score_sequence(g), [2, 1, 0])
}

///|
test "d-separation blocks the route" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_false(d_separator(g, [0], [2], []))
  assert_true(d_separator(g, [0], [2], [1]))
  assert_eq(minimal_d_separator(g, [0], [2]), Some([1]))
  assert_eq(minimal_d_separator(g, [0], [5]), None)
}
