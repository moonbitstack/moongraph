///|
test "a path has no cycle, a triangle has one" {
  let path : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_false(is_cyclic(path))
  assert_eq(find_cycle(path), None)
  path.add_edge(2, 0, ()) |> ignore
  assert_true(is_cyclic(path))
  match find_cycle(path) {
    Some(cycle) => {
      assert_eq(cycle[0], cycle[cycle.length() - 1])
      assert_eq(cycle.length(), 4)
    }
    None => fail("a triangle has a cycle")
  }
}

///|
test "a self loop is a cycle" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new()
  g.add_node(()) |> ignore
  g.add_edge(0, 0, ()) |> ignore
  assert_eq(find_cycle(g), Some([0, 0]))
  assert_eq(girth(g), Some(1))
}

///|
test "cycle basis has the cycle rank of the graph" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0), (2, 3), (3, 4), (4, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(cycle_basis(g).length(), 2)
  assert_eq(minimum_cycle_basis(g).length(), 2)
}

///|
test "girth finds the shortest cycle" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 0), (0, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(girth(g), Some(3))
}

///|
test "simple_cycles lists each directed cycle once" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
  )
  let cycles = simple_cycles(g).collect()
  assert_eq(cycles.length(), 1)
  assert_eq(cycles[0], [0, 1, 2, 0])
}

///|
test "chordless cycles drop the ones with a shortcut" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 0), (0, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  let cycles = chordless_cycles(g).collect()
  // The four-cycle has a chord, so only the two triangles survive.
  assert_eq(cycles.length(), 2)
}

///|
test "an eulerian circuit uses every edge once" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_true(is_eulerian(g))
  let circuit = eulerian_circuit(g)
  assert_eq(circuit.length(), 3)
  let seen : Array[Int] = []
  for edge in circuit {
    assert_false(seen.contains(edge))
    seen.push(edge)
  }
}

///|
test "a path has an eulerian trail but no circuit" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_false(is_eulerian(g))
  assert_true(has_eulerian_path(g))
  assert_eq(eulerian_path(g), Some([0, 1]))
}

///|
test "eulerize adds one duplicate to a path" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2)],
    node=(),
    edge=(),
    directed=false,
  )
  let doubled = eulerize(g)
  assert_eq(doubled.length(), 1)
  // Covering a two-edge path and coming back walks four edge traversals.
  let route = chinese_postman(g)
  assert_eq(route.length(), 4)
}

///|
test "feedback_arc_set breaks every cycle" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
  )
  let removed = feedback_arc_set(g)
  assert_true(removed.length() >= 1)
}

///|
test "min_cycle_ratio of a single cycle is its ratio" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
  )
  let ratio = min_cycle_ratio(g, cost=fn(e) { if e == 0 { 4.0 } else { 2.0 } })
  assert_true(ratio > 1.0 && ratio < 3.0)
}
