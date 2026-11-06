///|
test "renamed graphs are isomorphic" {
  let a : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  let b : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(2, 0), (0, 1), (1, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_true(is_isomorphic(a, b))
  assert_true(could_be_isomorphic(a, b))
  match vf2_mapping(a, b) {
    Some(mapping) => {
      assert_eq(mapping.to.length(), 3)
    }
    None => fail("a mapping exists")
  }
}

///|
test "a path and a star are not isomorphic" {
  let path : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  let star : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (0, 2), (0, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_false(is_isomorphic(path, star))
  assert_false(could_be_isomorphic(path, star))
  assert_true(fast_could_be_isomorphic(path, star))
}
