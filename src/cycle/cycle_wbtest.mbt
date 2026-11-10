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
  let seen : Array[Int32] = []
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

///|
test "cycles are handed out one at a time" {
  // A kite: two triangles sharing the edge 0-2, plus the four-cycle around them.
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0), (2, 3), (3, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  assert_eq(simple_cycles(g).take(1).collect().length(), 1)
  assert_eq(simple_cycles(g).count(), 3)
  // The four-cycle has a chord, so only the two triangles are chordless.
  assert_eq(chordless_cycles(g).count(), 2)
  // A cap of three leaves only the triangles as well.
  assert_eq(chordless_cycles(g, length_bound=3).count(), 2)
}

///|
test "a directed cycle is eulerian, a fan is not" {
  let ring : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=true,
  )
  assert_true(is_eulerian(ring))
  assert_eq(eulerian_circuit(ring).length(), 3)

  // Two arcs leave 0 and none enter it: every degree is even, and the graph still has
  // no way back from 1 or 2.
  let fan : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (0, 2)],
    node=(),
    edge=(),
    directed=true,
  )
  assert_false(is_eulerian(fan))
  assert_eq(
    try {
      eulerian_circuit(fan) |> ignore
      ""
    } catch {
      @moongraph.Refused::NotA(kind~, ..) => kind
      _ => "another refusal"
    },
    "Eulerian",
  )
}

///|
test "arcs that balance are still not enough without one piece" {
  let split : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 0), (2, 3), (3, 2)],
    node=(),
    edge=(),
    directed=true,
  )
  assert_false(is_eulerian(split))
  assert_eq(girth(split), Some(2))
  // The two pieces have trails, but no single trail crosses both.
  assert_false(has_eulerian_path(split))
}

///|
test "the girth of a directed graph follows the arcs" {
  // Three nodes the shadow joins in a triangle — 2, 3 and 0 — and one way round them:
  // the arcs close the outer ring of five and the short way from 1 to 3, so the shortest
  // closed walk is four arcs. A reading that ignored direction would answer three.
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 4), (4, 0), (0, 2)],
    node=(),
    edge=(),
    directed=true,
  )
  assert_eq(girth(g), Some(4))

  // A directed tree has no girth at all, however its shadow is drawn.
  let dag : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (0, 2)],
    node=(),
    edge=(),
    directed=true,
  )
  assert_eq(girth(dag), None)
  assert_false(is_cyclic(dag))
}

///|
test "a directed trail starts where one more arc leaves" {
  // The trail is 2 -> 0 -> 1: a walk that starts anywhere else leaves it half-walked.
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(2, 0), (0, 1)],
    node=(),
    edge=(),
    directed=true,
  )
  assert_true(has_eulerian_path(g))
  assert_eq(eulerian_path(g), Some([0, 1]))
}

///|
test "parallel edges are a girth of two" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new(directed=false)
  g.add_node(()) |> ignore
  g.add_node(()) |> ignore
  g.add_edge(0, 1, ()) |> ignore
  g.add_edge(0, 1, ()) |> ignore
  assert_eq(girth(g), Some(2))
}

///|
test "a node no edge touches keeps the graph from being eulerian" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
    directed=false,
  )
  g.add_node(()) |> ignore
  assert_false(is_eulerian(g))
  assert_eq(girth(g), Some(3))
}
