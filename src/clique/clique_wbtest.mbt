///|
test "maximal cliques of a triangle with a pendant" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0), (2, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(maximal_cliques(g).members, [[0, 1, 2], [2, 3]])
  assert_eq(clique_number(g), 3)
  assert_eq(clique_numbers(g), [3, 3, 3, 2])
}

///|
test "all cliques of a given size" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  let cliques = all_cliques(g, at_least=2)
  assert_eq(cliques.members.length(), 4)
}

///|
test "an independent set is a clique of the complement" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0), (3, 4)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(maximum_independent_set(g).length(), 2)
  assert_eq(independence_number(g), 2)
}

///|
test "chordal and non chordal" {
  let square : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_false(is_chordal(square))
  square.add_edge(0, 2, ()) |> ignore
  assert_true(is_chordal(square))
  assert_eq(chordal_fill_in(square), [])
  assert_eq(chordal_treewidth(square), 2)
}
