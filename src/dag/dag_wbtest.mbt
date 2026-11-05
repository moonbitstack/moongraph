///|
fn diamond() -> @moongraph.Graph[Unit, Unit] {
  @moongraph.Graph::from_edges([(0, 1), (0, 2), (1, 3), (2, 3)], node=(), edge=())
}

///|
test "topological_order puts every edge forward" {
  let g = diamond()
  let order = topological_order(g)
  assert_eq(order, [0, 1, 2, 3])
  assert_true(is_dag(g))
}

///|
test "a cycle is refused with a witness" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0)],
    node=(),
    edge=(),
  )
  assert_false(is_dag(g))
  let witness = try {
    topological_order(g) |> ignore
    None
  } catch {
    @moongraph.Refused::Cycle(nodes~) => Some(nodes)
    _ => None
  }
  match witness {
    Some(nodes) => {
      assert_true(nodes.length() >= 3)
      assert_eq(nodes[0], nodes[nodes.length() - 1])
    }
    None => fail("a cycle must be refused")
  }
}

///|
test "generations and the smallest order" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 2), (1, 2), (2, 3)],
    node=(),
    edge=(),
  )
  assert_eq(topological_generations(g), [[0, 1], [2], [3]])
  assert_eq(topological_smallest(g), [0, 1, 2, 3])
}

///|
test "all_topological_orders of a diamond is two orders" {
  let g = diamond()
  assert_eq(all_topological_orders(g).collect(), [[0, 1, 2, 3], [0, 2, 1, 3]])
}

///|
test "ancestors and descendants" {
  let g = diamond()
  assert_eq(ancestors(g, 3), [0, 1, 2])
  assert_eq(descendants(g, 0), [1, 2, 3])
  assert_eq(descendants(g, 3), [])
}

///|
test "transitive closure marks reachability" {
  let g = diamond()
  let closure = transitive_closure(g)
  assert_true(closure[0][3])
  assert_false(closure[3][0])
  assert_true(closure[1][1])
}

///|
test "transitive reduction drops the shortcuts" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (0, 2)],
    node=(),
    edge=(),
  )
  assert_eq(transitive_reduction(g), [(0, 1), (1, 2)])
}

///|
test "longest path follows the weights" {
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (0, 2)],
    node=(),
    edge=1.0,
  )
  g.set_edge_data(0, 5.0)
  assert_eq(longest_path(g, weight=g.weights(fn(w) { w })), [0, 1, 2])
  assert_eq(longest_path_length(g, weight=g.weights(fn(w) { w })), 6.0)
}

///|
test "a fork is a collider and a chain is not" {
  let fork : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 2), (1, 2)],
    node=(),
    edge=(),
  )
  assert_eq(colliders(fork), [2])
  let chain : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2)],
    node=(),
    edge=(),
  )
  assert_eq(colliders(chain), [])
}

///|
test "dominators of a diamond" {
  let g = diamond()
  let idom = dominators(g, 0)
  assert_eq(idom[0], Some(0))
  assert_eq(idom[1], Some(0))
  assert_eq(idom[3], Some(0))
}

///|
test "the sorter hands out ready nodes and takes them back" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 2), (1, 2)],
    node=(),
    edge=(),
  )
  let sorter = Sorter::new(g)
  assert_eq(sorter.ready(), [0, 1])
  sorter.finish([0, 1])
  assert_eq(sorter.ready(), [2])
  sorter.finish([2])
  assert_false(sorter.is_active())
  assert_eq(sorter.order(), [0, 1, 2])
}

///|
test "is_aperiodic sees the common divisor" {
  // A cycle of three and a cycle of two share no factor, so the walk can return
  // at either length and reach every position.
  let mixed : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 0), (1, 0)],
    node=(),
    edge=(),
  )
  assert_true(is_aperiodic(mixed))
  // A single cycle of two only ever returns at even lengths.
  let two : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 0)],
    node=(),
    edge=(),
  )
  assert_false(is_aperiodic(two))
  let four : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2), (2, 3), (3, 0)],
    node=(),
    edge=(),
  )
  assert_false(is_aperiodic(four))
}

///|
test "antichains of a chain are singletons" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
    [(0, 1), (1, 2)],
    node=(),
    edge=(),
  )
  assert_eq(antichains(g), [[0], [1], [2]])
}
