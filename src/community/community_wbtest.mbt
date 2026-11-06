///|
fn two_triangles() -> @moongraph.Graph[Unit, Unit] {
  @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0), (3, 4), (4, 5), (5, 3), (2, 3)],
    node=(),
    edge=(),
    directed=false,
  )
}

///|
test "louvain splits two triangles joined by an edge" {
  let parts = louvain(two_triangles())
  assert_eq(parts.count, 2)
  assert_eq(parts.label[0], parts.label[1])
  assert_eq(parts.label[3], parts.label[4])
  assert_true(parts.label[0] != parts.label[3])
}

///|
test "label propagation finds the same two groups" {
  let parts = label_propagation(two_triangles())
  assert_eq(parts.count, 2)
}

///|
test "greedy modularity finds two groups" {
  let parts = greedy_modularity(two_triangles())
  assert_eq(parts.count, 2)
}
