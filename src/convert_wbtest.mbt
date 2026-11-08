///|
test "a directed copy pairs every edge into two arcs" {
  let g : Graph[Unit, Double] = Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=0.0,
    directed=false,
  )
  g.set_edge_data(0, 2.5)
  let d = g.to_directed()
  assert_eq(d.directed(), true)
  assert_eq(d.node_count(), 3)
  assert_eq(d.edge_count(), 6)
  // Edge k becomes arcs 2k and 2k+1, the second pointing back.
  for eid in 0..<3 {
    let (from, to) = g.endpoints(eid)
    assert_eq(d.endpoints(eid * 2), (from, to))
    assert_eq(d.endpoints(eid * 2 + 1), (to, from))
    assert_eq(d.edge_data(eid * 2), g.edge_data(eid))
    assert_eq(d.edge_data(eid * 2 + 1), g.edge_data(eid))
  }
  assert_eq(d.edge_data(0), 2.5)
}

///|
test "a self-loop stays one arc, since it already points both ways" {
  let g : Graph[Unit, Unit] = Graph::new(directed=false)
  g.add_node(()) |> ignore
  g.add_edge(0, 0, ()) |> ignore
  let d = g.to_directed()
  assert_eq(d.edge_count(), 1)
  assert_eq(d.endpoints(0), (0, 0))
}

///|
test "an undirected copy keeps the lowest-numbered arc's payload" {
  let d : Graph[Unit, String] = Graph::new(directed=true)
  for node in 0..<3 {
    d.add_node(()) |> ignore
    ignore(node)
  }
  d.add_edge(0, 1, "there") |> ignore
  d.add_edge(1, 0, "back") |> ignore
  d.add_edge(2, 1, "one way") |> ignore
  let u = d.to_undirected()
  assert_eq(u.directed(), false)
  assert_eq(u.edge_count(), 2)
  // The pair 0-1 keeps "there": it arrived first.
  assert_eq(u.edge_data(u.find_edge(0, 1).unwrap()), "there")
  assert_eq(u.edge_data(u.find_edge(1, 2).unwrap()), "one way")
}

///|
test "directing and then forgetting the direction returns the same nodes" {
  let g : Graph[Unit, Unit] = Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 0), (0, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  let back = g.to_directed().to_undirected()
  assert_eq(back.node_count(), g.node_count())
  assert_eq(back.edge_count(), g.edge_count())
  for eid in g.edges() {
    let (from, to) = g.endpoints(eid)
    assert_true(back.find_edge(from, to) is Some(_))
  }
}

///|
test "relabelling moves payloads with their nodes and edges with their nodes" {
  let g : Graph[String, Double] = Graph::new(directed=false)
  for name in ["a", "b", "c"] {
    g.add_node(name) |> ignore
  }
  g.add_edge(0, 1, 1.0) |> ignore
  g.add_edge(1, 2, 2.0) |> ignore
  // A rotation: 0→2, 1→0, 2→1.
  let turned = g.relabel([2, 0, 1])
  assert_eq(turned.node_data(2), "a")
  assert_eq(turned.node_data(0), "b")
  assert_eq(turned.node_data(1), "c")
  assert_eq(turned.endpoints(0), (2, 0))
  assert_eq(turned.endpoints(1), (0, 1))
  assert_eq(turned.edge_data(1), 2.0)
}

///|
test "a mapping that is not a permutation is refused, and says why" {
  let g : Graph[Unit, Unit] = Graph::from_edges(
    [(0, 1), (1, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  let mut reasons = 0
  try {
    g.relabel([0, 1]) |> ignore
    fail("a mapping of the wrong length was accepted")
  } catch {
    Refused::NotA(..) => reasons = reasons + 1
    _ => fail("the wrong refusal for a short mapping")
  }
  try {
    g.relabel([0, 0, 2]) |> ignore
    fail("a mapping that repeats a number was accepted")
  } catch {
    Refused::NotA(..) => reasons = reasons + 1
    _ => fail("the wrong refusal for a repeated number")
  }
  try {
    g.relabel([0, 1, 3]) |> ignore
    fail("a label outside the graph was accepted")
  } catch {
    Refused::NotA(..) => reasons = reasons + 1
    _ => fail("the wrong refusal for a label outside the range")
  }
  assert_eq(reasons, 3)
}

///|
test "a stable copy keeps its slot numbers, holes included" {
  let s : StableGraph[String, Unit] = StableGraph::new(directed=false)
  for name in ["a", "b", "c", "d"] {
    s.add_node(name) |> ignore
  }
  s.add_edge(0, 1, ()) |> ignore
  s.add_edge(2, 3, ()) |> ignore
  s.remove_node(1)
  assert_eq(s.slot_count(), 4)
  assert_eq(s.vacant_count(), 1)
  let d = s.to_directed()
  assert_eq(d.directed(), true)
  assert_eq(d.slot_count(), 4)
  assert_eq(d.vacant_count(), 1)
  assert_true(d.is_vacant(1))
  assert_eq(d.node_data(2), "c")
  assert_eq(d.edge_count(), 2)
  // The surviving edge 0-2 became a pair; the one that died with node 1 did not.
  assert_eq(d.endpoints(0), (2, 3))
  assert_eq(d.endpoints(1), (3, 2))
}

///|
test "a stable undirected copy merges reciprocal arcs and keeps the holes" {
  let s : StableGraph[Unit, String] = StableGraph::new(directed=true)
  for _ in 0..<3 {
    s.add_node(()) |> ignore
  }
  s.add_edge(0, 2, "there") |> ignore
  s.add_edge(2, 0, "back") |> ignore
  s.remove_node(1)
  let u = s.to_undirected()
  assert_eq(u.directed(), false)
  assert_eq(u.slot_count(), 3)
  assert_eq(u.vacant_count(), 1)
  assert_eq(u.edge_count(), 1)
  assert_eq(u.edge_data(u.find_edge(0, 2).unwrap()), "there")
}
