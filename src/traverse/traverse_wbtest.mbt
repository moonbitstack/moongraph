///|
fn sample() -> @moongraph.Graph[Unit, Unit] {
  // 0 - 1 - 3
  // |   |
  // 2 - 4
  @moongraph.Graph::from_edges(
    [(0, 1), (0, 2), (1, 3), (1, 4), (2, 4)],
    node=(),
    edge=(),
    directed=false,
  )
}

///|
test "bfs lists nodes by distance then number" {
  let g = sample()
  assert_eq(bfs(g, 0), [0, 1, 2, 3, 4])
  assert_eq(bfs(g, 3), [3, 1, 0, 4, 2])
}

///|
test "bfs_tree uses the smallest parent" {
  let g = sample()
  let paths = bfs_tree(g, 0)
  assert_eq(paths.distance, [
    Some(0.0),
    Some(1.0),
    Some(1.0),
    Some(2.0),
    Some(2.0),
  ])
  assert_eq(paths.previous, [None, Some(0), Some(0), Some(1), Some(1)])
  assert_eq(paths.path_to(4), Some([0, 1, 4]))
}

///|
test "bfs from a node that is not there is empty" {
  let g = sample()
  assert_eq(bfs(g, 9), [])
  assert_eq(bfs(g, -1), [])
  let paths = bfs_tree(g, 9)
  assert_eq(paths.distance.length(), g.node_count())
  assert_eq(paths.reached(0), false)
}

///|
test "bfs_edges is one tree edge per reached node except the source" {
  let g = sample()
  let edges = bfs_edges(g, 0).collect()
  assert_eq(edges, [(0, 1), (0, 2), (1, 3), (1, 4)])
}

///|
test "bfs_layers groups by distance across several sources" {
  let g = sample()
  let layers = bfs_layers(g, [0, 2])
  assert_eq(layers, [[0, 2], [1, 4], [3]])
}

///|
test "bfs_beam keeps the lowest numbered nodes of a layer" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (0, 2), (0, 3), (0, 4)],
    node=(),
    edge=(),
  )
  // The 0.xx seeds are only here to keep the shape of the test readable.
  assert_eq(bfs_beam(g, 0, width=2), [0, 1, 2])
}

///|
test "dfs preorder follows ascending neighbour numbers" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 2), (0, 1), (1, 3), (2, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(dfs(g, 0), [0, 1, 3, 2])
  assert_eq(dfs_postorder(g, 0), [2, 3, 1, 0])
}

///|
test "dfs_tree records depth and parent" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (0, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  let paths = dfs_tree(g, 0)
  assert_eq(paths.previous, [None, Some(0), Some(1)])
  assert_eq(paths.distance, [Some(0.0), Some(1.0), Some(2.0)])
}

///|
test "dfs_labeled marks a back edge" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
  )
  let labeled = dfs_labeled(g, 0)
  assert_eq(labeled, [(0, 1, 0), (1, 2, 0), (2, 0, 2)])
}

///|
test "dfs_events brackets every node it enters" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1)],
    node=(),
    edge=(),
  )
  let events = dfs_events(g, 0).collect()
  assert_eq(events, [Enter(node=0), Enter(node=1), Leave(node=1), Leave(node=0)])
}

///|
test "edge_bfs covers every component without repeating" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (2, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(edge_bfs(g, 0).collect(), [(0, 1), (2, 3)])
  assert_eq(edge_dfs(g, 0).collect(), [(0, 1), (2, 3)])
}

///|
test "descendants_at answers one layer" {
  let g = sample()
  assert_eq(descendants_at(g, 0, 2), [3, 4])
  assert_eq(descendants_at(g, 0, 0), [0])
  assert_eq(descendants_at(g, 0, 7), [])
  assert_eq(descendants_at(g, 0, -1), [])
}

///|
test "a walk on a directed graph does not go backwards" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (2, 1)],
    node=(),
    edge=(),
  )
  assert_eq(bfs(g, 1), [1])
  assert_eq(bfs(g, 2), [2, 1])
}
