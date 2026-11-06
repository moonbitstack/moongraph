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
