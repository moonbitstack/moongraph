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

///|
/// Whether every group of a partition draws a connected subgraph.
fn each_group_connected(
  g : @moongraph.Graph[Unit, Unit],
  parts : @moongraph.Partition,
) -> Bool {
  let n = g.node_count()
  for start in 0..<n {
    let group = parts.label[start]
    // The walk only crosses edges that stay inside the group, so a group that falls
    // into two pieces leaves part of itself unseen.
    let reached : Array[Bool] = Array::make(n, false)
    reached[start] = true
    let queue : Array[Int32] = [start]
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      for nbr in g.neighbors(node) {
        if !reached[nbr] && parts.label[nbr] == group {
          reached[nbr] = true
          queue.push(nbr)
        }
      }
    }
    for node in 0..<n {
      if parts.label[node] == group && !reached[node] {
        return false
      }
    }
  }
  true
}

///|
test "leiden splits the two triangles and keeps each group in one piece" {
  let g = two_triangles()
  let parts = leiden(g)
  assert_eq(parts.count, 2)
  assert_eq(parts.label[0], parts.label[1])
  assert_true(parts.label[0] != parts.label[3])
  assert_true(each_group_connected(g, parts))
}

///|
test "leiden keeps a ring of cliques in one piece per clique" {
  // Six triangles joined in a ring: the case where a plain local move can leave a
  // group hanging in two pieces.
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new(directed=false)
  for _ in 0..<18 {
    g.add_node(()) |> ignore
  }
  let built : Array[(Int32, Int32)] = []
  for clique in 0..<6 {
    let base = clique * 3
    built.push((base, base + 1))
    built.push((base + 1, base + 2))
    built.push((base + 2, base))
    built.push((base + 2, (base + 3) % 18))
  }
  for pair in built {
    g.add_edge(pair.0, pair.1, ()) |> ignore
  }
  let parts = leiden(g)
  assert_eq(parts.count, 6)
  assert_true(each_group_connected(g, parts))
}

///|
test "leiden separates the components of a graph that falls apart" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0), (3, 4), (4, 5), (5, 3)],
    node=(),
    edge=(),
    directed=false,
  )
  let parts = leiden(g)
  assert_eq(parts.count, 2)
  assert_eq(parts.label[0], parts.label[2])
  assert_true(parts.label[0] != parts.label[3])
  // A higher resolution asks for smaller groups.
  let fine = leiden(g, resolution=4.0)
  assert_true(fine.count >= parts.count)
}
