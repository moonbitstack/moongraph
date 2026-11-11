///|
test "density and degrees" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(density(g), 1.0)
  assert_eq(degree(g), [2, 2, 2])
  assert_eq(degree_histogram(g), [0, 0, 3])
}

///|
test "distance measures of a path" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(diameter(g), 3)
  assert_eq(radius(g), 2)
  assert_eq(center(g), [1, 2])
  assert_eq(periphery(g), [0, 3])
  assert_eq(eccentricity(g, 0), 3)
}

///|
test "clustering of a triangle and a square" {
  let triangle : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(clustering(triangle, 0), 1.0)
  assert_eq(transitivity(triangle), 1.0)
  let square : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(clustering(square, 0), 0.0)
  // The two neighbours of 0 in a square are joined by a two-step route, which is a square.
  assert_eq(square_clustering(square, 0), 1.0)
}

///|
test "neighbourhood similarity" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 2), (1, 2), (0, 3), (1, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(similarity(g, 0, 1), 1.0)
  assert_eq(similarity(g, 0, 1, kind=Dice), 1.0)
  assert_true(adamic_adar(g, 0, 1) > 0.0)
}

///|
test "the nearest points of interest, rank by rank" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 4)],
    node=(),
    edge=(),
    directed=false,
  )
  let near = nearest_pois(g, [1, 3], count=3, cutoff=10.0)
  assert_eq(near[0], [Some(1.0), Some(3.0), (None : Double?)])
  assert_eq(near[1], [Some(0.0), Some(2.0), None])
  assert_eq(near[2], [Some(1.0), Some(1.0), None])
  assert_eq(near[4], [Some(1.0), Some(3.0), None])
  // A cutoff that reaches only the nearer of the two.
  let narrow = nearest_pois(g, [1, 3], count=2, cutoff=1.5)
  assert_eq(narrow[0], [Some(1.0), (None : Double?)])
  assert_eq(narrow[2], [Some(1.0), Some(1.0)])
  // Nothing to look for.
  assert_eq(nearest_pois(g, [], count=1, cutoff=10.0)[0], [None])
}

///|
test "the first rank is the multi-source distance, which is another way to compute it" {
  let paths = [
    [(0, 1), (1, 2), (2, 3), (3, 4)],
    [(0, 1), (0, 2), (1, 2), (2, 3), (3, 4), (4, 0)],
    [(0, 1), (1, 2), (2, 0), (2, 3), (3, 4)],
  ]
  for edges in paths {
    let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
      edges,
      node=(),
      edge=(),
      directed=false,
    )
    let pois = [0, 3]
    let near = nearest_pois(g, pois, count=1, cutoff=1.0e9)
    let multi = @path.dijkstra_multi(g, pois)
    for node in 0..<g.node_count() {
      match multi.distance[node] {
        Some(distance) => assert_eq(near[node][0], Some(distance))
        None => assert_eq(near[node][0], (None : Double?))
      }
    }
  }
}

///|
test "a triangle is counted once, and every node that closes it is told" {
  let triangle : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(triangles(triangle), ([1, 1, 1], 1))
  let square : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 0), (0, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  // Both triangles pass through 0, so it closes two of them; the count is still two.
  assert_eq(triangles(square), ([2, 1, 2, 1], 2))
}

///|
test "a directed triangle is counted where its arcs leave" {
  // The two arcs of the closing corner leave one node, so a directed triangle is counted once,
  // at that node, even though the neighbours are read the same way in both directions.
  let diamond : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (0, 2), (1, 2), (1, 3), (2, 3)],
    node=(),
    edge=(),
    directed=true,
  )
  assert_eq(triangles(diamond), ([1, 1, 0, 0], 2))
}

///|
test "the transitivity of a directed graph reads the nodes an arc leaves" {
  // A triangle here is a node with two successors that are joined either way, over the pairs
  // of successors a node has. It is the undirected reading applied to each out-neighbourhood,
  // which is not the reading a general graph library takes — see the note in the README.
  let diamond : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (0, 2), (1, 2), (1, 3), (2, 3)],
    node=(),
    edge=(),
    directed=true,
  )
  // Nodes 0 and 1 each close one triangle out of one pair, and 2 and 3 close none.
  assert_eq(transitivity(diamond), 1.0)
  // A directed ring closes nothing: no node has two successors to join, however the arcs
  // come back, which is the difference from reading the ring as an undirected triangle.
  let ring : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=true,
  )
  assert_eq(transitivity(ring), 0.0)
}
