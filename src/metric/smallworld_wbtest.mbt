///|
test "the average path length of a path has the closed form" {
  for n in [4, 7, 10] {
    let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new(directed=false)
    for node in 0..<n {
      g.add_node(()) |> ignore
      if node > 0 {
        g.add_edge(node - 1, node, ()) |> ignore
      }
    }
    // On a path the average over the pairs is (n+1)/3, whatever the length.
    let wanted = (n + 1).to_double() / 3.0
    if !@internal.close(average_path_length(g), wanted) {
      fail("a path of " + n.to_string() + " has the wrong average length")
    }
  }
}

///|
test "a lattice measured against itself is the reference point" {
  let ring : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  let complete : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 0), (0, 2), (1, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  // Against itself there is nothing to explain: omega is exactly zero.
  assert_eq(smallworld_omega(ring, lattice=ring), 0.0)
  // A complete graph has the shortest routes there are, so the ring is the longer one.
  assert_true(average_path_length(complete) < average_path_length(ring))
}
