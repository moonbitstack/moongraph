///|
///
test "components label a disconnected graph" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (3, 4)],
    node=(),
    edge=(),
    directed=false,
  )
  let parts = components(g)
  assert_eq(parts.count, 2)
  assert_eq(parts.label, [0, 0, 0, 1, 1])
  assert_false(is_connected(g))
  assert_eq(component_of(g, 4), [3, 4])
  assert_eq(component_count(g), 2)
}

///|
test "strong components follow the edge direction" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0), (2, 3)],
    node=(),
    edge=(),
  )
  let parts = strong_components(g)
  assert_eq(parts.count, 2)
  assert_eq(parts.label[0], parts.label[1])
  assert_eq(parts.label[0], parts.label[2])
  assert_true(parts.label[3] != parts.label[0])
  assert_false(is_strongly_connected(g))
  let k = strong_components_kosaraju(g)
  assert_eq(k.count, 2)
}

///|
test "the condensation has one node per component" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 0), (1, 2)],
    node=(),
    edge=(),
  )
  let cond = condensation(g)
  assert_eq(cond.graph.node_count(), 2)
  assert_eq(cond.members.fold(init=0, fn(acc, m) { acc + m.length() }), 3)
  // Tarjan numbers sinks first, so the edge runs from the higher label down.
  let from = cond.of_node[1]
  let to = cond.of_node[2]
  assert_true(from > to)
  assert_true(cond.graph.find_edge(from, to) is Some(_))
}

///|
test "weak components ignore direction" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges([(0, 1), (2, 1)], node=(), edge=())
  assert_eq(weak_components(g).count, 1)
  assert_true(is_weakly_connected(g))
  assert_false(is_strongly_connected(g))
}

///|
test "a chain graph is semiconnected" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges([(0, 1), (1, 2), (2, 3)], node=(), edge=())
  assert_true(is_semiconnected(g))
  let v : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges([(0, 1), (2, 1)], node=(), edge=())
  assert_false(is_semiconnected(v))
}

///|
test "articulation points and bridges" {
  // 0-1-2 plus the triangle 1-3-4-1
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (1, 3), (3, 4), (4, 1)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(articulation_points(g), [1])
  assert_eq(bridges(g), [0, 1])
  assert_true(has_bridges(g))
  assert_false(is_biconnected(g))
}

///|
test "a cycle has no bridge and no articulation point" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(bridges(g), [])
  assert_eq(articulation_points(g), [])
  assert_true(is_biconnected(g))
}

///|
test "biconnected pieces cover every edge" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0), (2, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  let pieces = biconnected_components(g)
  let total = pieces.fold(init=0, fn(acc, piece) { acc + piece.length() })
  assert_eq(total, 4)
  assert_eq(biconnected_component_nodes(g).length(), pieces.length())
}

///|
test "boundaries and reach" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(edge_boundary(g, [0, 1]), [1])
  assert_eq(node_boundary(g, [0, 1]), [2])
  assert_eq(reachable_count(g, 3), 4)
  assert_eq(reachable_count(g, 9), 0)
}

///|
test "local bridges see the short way around" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(local_bridges(g), [])
  let path : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges([(0, 1), (1, 2)], node=(), edge=(), directed=false)
  assert_eq(local_bridges(path), [0, 1])
}

///|
test "chain decomposition returns paths" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  let chains = chain_decomposition(g)
  assert_eq(chains.length(), 1)
  assert_eq(chains[0].length(), 3)
}

///|
test "attracting components are the sinks of the condensation" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges([(0, 1), (1, 2)], node=(), edge=())
  let attracting = attracting_components(g)
  assert_eq(attracting.length(), 1)
  assert_eq(attracting[0], [2])
}
