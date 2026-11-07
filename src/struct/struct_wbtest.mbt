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

///|
test "the two forbidden shapes are refused" {
  let complete : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [
      (0, 1),
      (0, 2),
      (0, 3),
      (0, 4),
      (1, 2),
      (1, 3),
      (1, 4),
      (2, 3),
      (2, 4),
      (3, 4),
    ],
    node=(),
    edge=(),
    directed=false,
  )
  assert_false(is_planar(complete))
  let three_by_three : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 3), (0, 4), (0, 5), (1, 3), (1, 4), (1, 5), (2, 3), (2, 4), (2, 5)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_false(is_planar(three_by_three))
  // Removing one edge of either shape leaves a graph that can be drawn flat.
  assert_true(is_planar(without_edge(complete, 4, 3)))
  assert_true(is_planar(without_edge(three_by_three, 2, 5)))
}

///|
/// A copy of a graph with one edge taken out.
fn without_edge(
  graph : @moongraph.Graph[Unit, Unit],
  a : Int32,
  b : Int32,
) -> @moongraph.Graph[Unit, Unit] {
  let out : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new(directed=false)
  for _ in 0..<graph.node_count() {
    out.add_node(()) |> ignore
  }
  for edge in 0..<graph.edge_count() {
    let (from_, to_) = graph.endpoints(edge)
    if (from_ == a && to_ == b) || (from_ == b && to_ == a) {
      continue
    }
    out.add_edge(from_, to_, ()) |> ignore
  }
  out
}

///|
test "a subdivided forbidden shape is still refused" {
  // Every edge of K3,3 given one extra node: the shape is hidden, the crossing is not.
  let pairs : Array[(Int32, Int32)] = [
    (0, 3),
    (0, 4),
    (0, 5),
    (1, 3),
    (1, 4),
    (1, 5),
    (2, 3),
    (2, 4),
    (2, 5),
  ]
  let edges : Array[(Int32, Int32)] = []
  let mut next = 6
  for pair in pairs {
    edges.push((pair.0, next))
    edges.push((next, pair.1))
    next = next + 1
  }
  let hidden : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    edges,
    node=(),
    edge=(),
    directed=false,
  )
  assert_false(is_planar(hidden))
}

///|
test "flat graphs are accepted" {
  // A cube and a three by three grid have drawings; Petersen has none.
  let cube : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [
      (0, 1),
      (1, 2),
      (2, 3),
      (3, 0),
      (4, 5),
      (5, 6),
      (6, 7),
      (7, 4),
      (0, 4),
      (1, 5),
      (2, 6),
      (3, 7),
    ],
    node=(),
    edge=(),
    directed=false,
  )
  assert_true(is_planar(cube))
  let grid : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [
      (0, 1),
      (1, 2),
      (3, 4),
      (4, 5),
      (6, 7),
      (7, 8),
      (0, 3),
      (3, 6),
      (1, 4),
      (4, 7),
      (2, 5),
      (5, 8),
    ],
    node=(),
    edge=(),
    directed=false,
  )
  assert_true(is_planar(grid))
  // Petersen is the smallest snark, and it is not flat.
  let petersen : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [
      (0, 1),
      (1, 2),
      (2, 3),
      (3, 4),
      (4, 0),
      (0, 5),
      (1, 6),
      (2, 7),
      (3, 8),
      (4, 9),
      (5, 7),
      (7, 9),
      (9, 6),
      (6, 8),
      (8, 5),
    ],
    node=(),
    edge=(),
    directed=false,
  )
  assert_false(is_planar(petersen))
}

///|
test "direction, parallel edges and loops do not decide planarity" {
  let complete : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [
      (0, 1),
      (1, 0),
      (0, 1),
      (0, 2),
      (0, 3),
      (0, 4),
      (1, 2),
      (1, 3),
      (1, 4),
      (2, 3),
      (2, 4),
      (3, 4),
      (2, 2),
    ],
    node=(),
    edge=(),
    directed=true,
  )
  // K5 with a doubled edge and a loop is still K5 underneath.
  assert_false(is_planar(complete))
  let triangle : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 0), (1, 2), (2, 0), (0, 0)],
    node=(),
    edge=(),
    directed=true,
  )
  assert_true(is_planar(triangle))
}

///|
test "the truss peeling keeps support up to date" {
  // Two triangles sharing the edge 0-1: the shared edge sits in two triangles, the
  // other four in one each. At k = 4 only the shared edge starts out strong enough,
  // and taking the four others out costs it both of its triangles.
  let shared : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (0, 2), (1, 2), (0, 3), (1, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(k_truss(shared, 3), [0, 1, 2, 3])
  assert_eq(k_truss(shared, 4), [])
  // A complete graph on four nodes: every edge is in two triangles.
  let complete : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (0, 2), (0, 3), (1, 2), (1, 3), (2, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(k_truss(complete, 4), [0, 1, 2, 3])
  assert_eq(k_truss(complete, 5), [])
  // Below three the truss is the graph itself.
  assert_eq(k_truss(complete, 2), [0, 1, 2, 3])
}
///|
test "digraphical pairs by the Gale-Ryser criterion" {
  // A triangle: every node has out-degree 1 and in-degree 1.
  assert_true(is_digraphical([(1, 1), (1, 1), (1, 1)]))
  // An in-degree up to the node count is fine in a directed graph, though it
  // would not be graphical as an undirected degree on its own.
  assert_true(is_digraphical([(3, 4), (3, 2), (3, 4), (3, 2)]))
  // The row and column sums differ, so no adjacency matrix can carry them.
  assert_false(is_digraphical([(0, 1), (0, 1)]))
  // Equal sums, yet no placement: both out-degree-3 rows would need every
  // column at once, and the in-degrees cannot absorb that.
  assert_false(is_digraphical([(0, 3), (3, 3), (3, 0)]))
  // A negative degree is refused outright.
  assert_false(is_digraphical([(1, -1), (1, 1)]))
}
