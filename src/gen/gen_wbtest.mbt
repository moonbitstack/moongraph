///|
test "named graphs have the shapes their names promise" {
  assert_eq(complete(4, directed=false).edge_count(), 6)
  assert_eq(path(4).edge_count(), 3)
  assert_eq(cycle(4).edge_count(), 4)
  assert_eq(star(4).edge_count(), 3)
  assert_eq(grid(2, 3).node_count(), 6)
  assert_eq(grid(2, 3).edge_count(), 7)
  assert_eq(wheel(5).node_count(), 6)
  // A ladder of four rungs is two paths of four, joined by four rungs.
  assert_eq(ladder(4).edge_count(), 11)
  assert_eq(barbell(3).node_count(), 6)
  assert_eq(petersen().node_count(), 10)
  assert_eq(petersen().edge_count(), 15)
}

///|
test "random families keep their invariants" {
  let rng = @moonrand.seeded(b"moongraph")
  let gnp = random_gnp(20, probability=0.5, rng~)
  assert_eq(gnp.node_count(), 20)
  let gnm = random_gnm(20, 30, rng~)
  assert_eq(gnm.edge_count(), 30)
  let tree = random_tree(15, rng~)
  assert_eq(tree.edge_count(), 14)
  let attachment = barabasi_albert(20, attach=2, rng~)
  assert_true(attachment.edge_count() > 0)
}

///|
test "a double edge swap keeps every degree and creates no loops" {
  let base : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 0), (0, 3)],
    node=0,
    edge=(),
    directed=false,
  )
  let rng = @moonrand.seeded(b"moongraph-swap")
  let shuffled = double_edge_swap(base, swaps=40, rng~)
  assert_eq(shuffled.edge_count(), base.edge_count())
  assert_eq(shuffled.node_count(), base.node_count())
  let before = degree_sequence(base)
  let after = degree_sequence(shuffled)
  if before != after {
    fail("a swap changed the degree sequence")
  }
  for edge in shuffled.edges() {
    let (from, to) = shuffled.endpoints(edge)
    if from == to {
      fail("a swap created a loop")
    }
  }
}

///|
/// The degrees of a graph, sorted, for comparing two graphs that claim the same sequence.
fn degree_sequence(g : @moongraph.Graph[Int32, Unit]) -> Array[Int32] {
  let out : Array[Int32] = []
  for node in 0..<g.node_count() {
    out.push(g.neighbors(node).length())
  }
  out.sort()
  out
}
