///|
test "add_node numbers densely from zero" {
  let g : Graph[String, Unit] = Graph::new()
  assert_eq(g.add_node("a"), 0)
  assert_eq(g.add_node("b"), 1)
  assert_eq(g.node_count(), 2)
  assert_eq(g.node_data(1), "b")
  assert_eq(g.nodes().collect(), [0, 1])
}

///|
test "a directed edge is reported from the source only" {
  let g : Graph[Unit, Unit] = Graph::new()
  g.add_node(()) |> ignore
  g.add_node(()) |> ignore
  let eid = g.add_edge(0, 1, ())
  assert_eq(g.neighbors(0), [1][:])
  assert_eq(g.neighbors(1), [][:])
  assert_eq(g.in_neighbors(1), [0][:])
  assert_eq(g.incident(0), [eid][:])
  assert_eq(g.in_incident(1), [eid][:])
  assert_eq(g.endpoints(eid), (0, 1))
  assert_eq(g.edge_count(), 1)
}

///|
test "an undirected edge is reported from both endpoints" {
  let g : Graph[Unit, Unit] = Graph::new(directed=false)
  g.add_node(()) |> ignore
  g.add_node(()) |> ignore
  let eid = g.add_edge(0, 1, ())
  assert_eq(g.neighbors(0), [1][:])
  assert_eq(g.neighbors(1), [0][:])
  assert_eq(g.in_neighbors(1), [0][:])
  assert_eq(g.find_edge(1, 0), Some(eid))
}

///|
test "an undirected self-loop appears once at its endpoint" {
  let g : Graph[Unit, Unit] = Graph::new(directed=false)
  g.add_node(()) |> ignore
  g.add_edge(0, 0, ()) |> ignore
  assert_eq(g.neighbors(0).length(), 1)
  assert_eq(g.in_neighbors(0).length(), 1)
}

///|
test "parallel edges keep their own numbers" {
  let g : Graph[Unit, String] = Graph::new()
  g.add_node(()) |> ignore
  g.add_node(()) |> ignore
  let first = g.add_edge(0, 1, "x")
  let second = g.add_edge(0, 1, "y")
  assert_eq(g.find_edge(0, 1), Some(first))
  assert_eq(g.find_edges(0, 1), [first, second])
  assert_eq(g.neighbors(0), [1, 1][:])
  assert_eq(g.edge_data(second), "y")
}

///|
test "removing an edge leaves the numbers of the others alone" {
  let g : Graph[Unit, Unit] = Graph::new()
  for _ in 0..<3 {
    g.add_node(()) |> ignore
  }
  let a = g.add_edge(0, 1, ())
  let b = g.add_edge(1, 2, ())
  g.remove_edge(a)
  assert_eq(g.contains_edge(a), false)
  assert_eq(g.contains_edge(b), true)
  assert_eq(g.edge_count(), 1)
  assert_eq(g.neighbors(1), [2][:])
  assert_eq(g.edges().collect(), [b])
}

///|
test "removing a node renumbers the ones above it" {
  let g : Graph[String, Unit] = Graph::new()
  for name in ["a", "b", "c", "d"] {
    g.add_node(name) |> ignore
  }
  g.add_edge(0, 1, ()) |> ignore
  g.add_edge(2, 3, ()) |> ignore
  g.remove_node(1)
  assert_eq(g.node_count(), 3)
  assert_eq(g.nodes().map(fn(n) { g.node_data(n) }).collect(), ["a", "c", "d"])
  assert_eq(g.edge_count(), 1)
  assert_eq(g.neighbors(1), [2][:])
}

///|
test "clear_edges keeps the nodes and clear removes both" {
  let g : Graph[Unit, Unit] = Graph::from_edges([(0, 1)], node=(), edge=())
  g.clear_edges()
  assert_eq(g.node_count(), 2)
  assert_eq(g.edge_count(), 0)
  g.clear()
  assert_eq(g.node_count(), 0)
}

///|
test "a copy is independent of its source" {
  let g : Graph[Unit, Unit] = Graph::from_edges([(0, 1)], node=(), edge=())
  let h = g.copy()
  h.add_node(()) |> ignore
  h.add_edge(0, 2, ()) |> ignore
  assert_eq(g.node_count(), 2)
  assert_eq(g.edge_count(), 1)
  assert_eq(h.node_count(), 3)
  assert_eq(h.edge_count(), 2)
}

///|
test "from_edges creates every node below the highest number" {
  let g : Graph[Unit, Unit] = Graph::from_edges([(2, 4)], node=(), edge=())
  assert_eq(g.node_count(), 5)
  assert_eq(g.neighbors(2), [4][:])
}

///|
test "an out of range node gives an empty view" {
  let g : Graph[Unit, Unit] = Graph::from_edges([(0, 1)], node=(), edge=())
  assert_eq(g.neighbors(7).length(), 0)
  assert_eq(g.neighbors(-1).length(), 0)
  assert_eq(g.endpoints(99), (-1, -1))
}

///|
test "weights adapts a payload function to edge numbers" {
  let g : Graph[Unit, Double] = Graph::from_edges([(0, 1), (1, 2)], node=(), edge=2.0)
  let w = g.weights(fn(cost) { cost * 3.0 })
  assert_eq(w(1), 6.0)
}

///|
test "a node added after a deletion keeps the dense numbering" {
  let g : Graph[Int, Unit] = Graph::new()
  for i in 0..<3 {
    g.add_node(i) |> ignore
  }
  g.remove_node(0)
  assert_eq(g.add_node(9), 2)
  assert_eq(g.node_data(0), 1)
}
