// The differential test: on random boards, the four searches must agree. A* and the jump-point
// search must return routes of the same cost, that cost must be the one Dijkstra settles on,
// and every route must be a real walk — consecutive cells are neighbours, the ends are where
// they should be, and no step cuts the corner of a blocked cell.

///|
fn close_enough(a : Double, b : Double) -> Bool {
  let diff = a - b
  (if diff < 0.0 { -diff } else { diff }) < 1.0000000001e-9
}

///|
/// Whether a route is a legal walk from `start` to `goal`: each cell is a neighbour of the one
/// before it, which is exactly what `neighbors` admits, corner cutting included in its rules.
fn is_walk(
  grid : Grid,
  route : Array[Int32],
  start : Int32,
  goal : Int32,
) -> Bool {
  if route.length() == 0 {
    return false
  }
  if route[0] != start || route[route.length() - 1] != goal {
    return false
  }
  for at in 1..<route.length() {
    if !grid.neighbors(route[at - 1]).contains(route[at]) {
      return false
    }
  }
  true
}

///|
/// A random board with roughly `percent` of its cells blocked.
fn random_grid(
  rng : &@contract.Rng,
  width : Int32,
  height : Int32,
  percent : Int32,
) -> Grid {
  let grid = Grid::new(width, height)
  for x in 0..<width {
    for y in 0..<height {
      if @moonrand.randint(rng, 0, 99).to_int() < percent {
        grid.block(x, y)
      }
    }
  }
  grid
}

///|
test "the four searches agree on random boards" {
  let rng = @moonrand.seeded(b"grid-diff")
  let width = 8
  let height = 8
  for round in 0..<80 {
    let grid = random_grid(rng, width, height, 22)
    let start = @moonrand.randint(rng, 0, (width * height - 1).to_int64()).to_int()
    let goal = @moonrand.randint(rng, 0, (width * height - 1).to_int64()).to_int()
    // Never start or end inside a wall: clear the two cells.
    grid.unblock(grid.x(start), grid.y(start))
    grid.unblock(grid.x(goal), grid.y(goal))
    let settled = grid.dijkstra(start)
    let by_a = grid.a_star(start, goal)
    let by_j = grid.jps(start, goal)
    let reachable = settled[goal] < 1.0e299
    if reachable {
      match by_a {
        Some(route) => {
          if !is_walk(grid, route, start, goal) {
            fail("round " + round.to_string() + ": the A* route is not a walk")
          }
          if !close_enough(grid.path_cost(route), settled[goal]) {
            fail(
              "round " +
              round.to_string() +
              ": the A* route costs more than Dijkstra's",
            )
          }
        }
        None =>
          fail("round " + round.to_string() + ": A* missed a reachable goal")
      }
      match by_j {
        Some(route) => {
          if !is_walk(grid, route, start, goal) {
            fail(
              "round " +
              round.to_string() +
              ": the jump-point route is not a walk",
            )
          }
          if !close_enough(grid.path_cost(route), settled[goal]) {
            fail(
              "round " +
              round.to_string() +
              ": the jump-point route costs more than Dijkstra's",
            )
          }
        }
        None =>
          fail(
            "round " +
            round.to_string() +
            ": the jump-point search missed a reachable goal",
          )
      }
    } else {
      match by_a {
        Some(_) =>
          fail(
            "round " + round.to_string() + ": A* reached an unreachable goal",
          )
        None => ()
      }
      match by_j {
        Some(_) =>
          fail(
            "round " +
            round.to_string() +
            ": the jump-point search reached an unreachable goal",
          )
        None => ()
      }
    }
  }
}

///|
test "an open board costs the diagonal, four times" {
  let grid = Grid::new(5, 5)
  let goal = grid.node(4, 4)
  let route = grid.a_star(0, goal)
  match route {
    Some(path) => {
      assert_eq(path.length(), 5)
      assert_true(close_enough(grid.path_cost(path), 4.0 * 1.4142135623730951))
    }
    None => fail("an open board is reachable")
  }
  match grid.jps(0, goal) {
    Some(path) =>
      assert_true(close_enough(grid.path_cost(path), 4.0 * 1.4142135623730951))
    None => fail("the jump-point search finds an open board")
  }
}

///|
test "a wall forces the route around it" {
  let grid = Grid::new(5, 5)
  for y in 0..<4 {
    grid.block(2, y)
  }
  // A wall from the top edge to one short of the bottom: the walk goes round its foot.
  let route = grid.a_star(grid.node(0, 0), grid.node(4, 4))
  match route {
    Some(path) => {
      assert_true(is_walk(grid, path, grid.node(0, 0), grid.node(4, 4)))
      assert_eq(
        grid.dijkstra(grid.node(0, 0))[grid.node(4, 4)],
        grid.path_cost(path),
      )
    }
    None => fail("the wall has a gap at its foot")
  }
}

///|
test "breadth first counts cells, not cost" {
  let grid = Grid::new(4, 4)
  let goal = grid.node(3, 3)
  match grid.bfs(0, goal) {
    Some(path) => {
      assert_eq(path[0], 0)
      assert_eq(path[path.length() - 1], goal)
      // Fewest cells: three diagonal steps, so four cells.
      assert_eq(path.length(), 4)
    }
    None => fail("an empty board is reachable")
  }
}

///|
test "a blocked goal is unreachable" {
  let grid = Grid::new(3, 3)
  grid.block(2, 2)
  assert_true(grid.a_star(0, grid.node(2, 2)) == None)
  assert_true(grid.jps(0, grid.node(2, 2)) == None)
  assert_true(grid.bfs(0, grid.node(2, 2)) == None)
}
