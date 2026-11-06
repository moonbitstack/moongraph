///|
fn weighted_square() -> @moongraph.Graph[Unit, Double] {
  @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 0), (0, 2)],
    node=(),
    edge=1.0,
    directed=false,
  )
}

///|
test "the three methods agree on the cheapest tree" {
  let g = weighted_square()
  g.set_edge_data(0, 4.0)
  g.set_edge_data(3, 4.0)
  let w = g.weights(fn(cost) { cost })
  let by_kruskal = minimum_spanning(g, weight=w)
  let by_prim = minimum_spanning(g, weight=w, kind=Prim)
  let by_boruvka = minimum_spanning(g, weight=w, kind=Boruvka)
  assert_eq(by_kruskal.weight, 3.0)
  assert_eq(by_prim.weight, 3.0)
  assert_eq(by_boruvka.weight, 3.0)
  assert_eq(by_kruskal.edges.length(), 3)
}

///|
test "a disconnected graph is refused" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (2, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  let refused = try {
    minimum_spanning(g) |> ignore
    false
  } catch {
    @moongraph.Refused::Disconnected(_) => true
    _ => false
  }
  assert_true(refused)
}

///|
test "maximum_spanning keeps the expensive edges" {
  let g = weighted_square()
  g.set_edge_data(4, 9.0)
  let tree = maximum_spanning(g, weight=g.weights(fn(cost) { cost }))
  assert_eq(tree.weight, 11.0)
}

///|
test "spanning_count counts the trees of a square" {
  let g = weighted_square()
  assert_eq(spanning_count(g), 8.0)
}

///|
test "spanning_trees lists four trees for a triangle" {
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (0, 2)],
    node=(),
    edge=1.0,
    directed=false,
  )
  assert_eq(spanning_trees(g).collect().length(), 3)
}

///|
test "a random spanning tree has one edge less than nodes" {
  let g = weighted_square()
  let rng = @moonrand.seeded(b"moongraph")
  let tree = random_spanning(g, rng~)
  assert_eq(tree.edges.length(), 3)
}

///|
test "prufer code round trips" {
  let g : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3)],
    node=0,
    edge=(),
    directed=false,
  )
  let code = prufer_sequence(g)
  assert_eq(code.length(), 2)
  let back = from_prufer(code)
  assert_eq(back.node_count(), 4)
  assert_eq(back.edge_count(), 3)
  assert_eq(prufer_sequence(back), code)
}

///|
test "tree centre of a path is its middle" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 4)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(tree_center(g), [2])
  assert_eq(tree_centroid(g), [2])
  let (node, worst) = broadcast_center(g)
  assert_eq(node, 2)
  assert_eq(worst, 2)
}

///|
test "depth and subtree sizes of a rooted star" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (0, 2), (1, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(tree_depth(g, 0), [0, 1, 1, 2])
  assert_eq(subtree_sizes(g, 0), [4, 2, 1, 1])
}

///|
test "nested shape round trips" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (0, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  let nested = to_nested(g, 0)
  let (back, root) = from_nested(nested)
  assert_eq(root, 0)
  assert_eq(back.node_count(), 3)
  assert_eq(back.edge_count(), 2)
}

///|
test "lowest common ancestor answers in one step" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (1, 3), (3, 4)],
    node=(),
    edge=(),
    directed=false,
  )
  let lca = Lca::new(g, 0)
  assert_eq(lca.of(2, 4), Some(1))
  assert_eq(lca.of(2, 1), Some(1))
  assert_eq(lca.depth(4), 3)
  assert_eq(lca.ancestor_at(4, 2), Some(1))
  assert_eq(lca.ancestor_at(4, 9), None)
}

///|
test "a branching picks one parent per node" {
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges(
    [(0, 1), (0, 2), (1, 2), (2, 3)],
    node=(),
    edge=1.0,
  )
  g.set_edge_data(2, 5.0)
  let tree = minimum_branching(g, weight=g.weights(fn(cost) { cost }))
  assert_eq(tree.edges.length(), 3)
  assert_eq(tree.weight, 3.0)
}

///|
test "steiner tree connects the terminals" {
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3)],
    node=(),
    edge=1.0,
    directed=false,
  )
  let tree = steiner_tree(g, [0, 2], weight=g.weights(fn(cost) { cost }))
  assert_eq(tree.edges, [0, 1])
  assert_eq(tree.weight, 2.0)
}
