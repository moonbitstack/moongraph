// The differential test for D* Lite: after every change to the board, the cost it reports is
// checked against a search that starts from nothing on the same board.
//
// That is the only thing worth checking about a repair. It is easy to make a replanner that is
// fast and wrong — it keeps stale estimates and quietly reports the old route — and the way to
// catch that is to compare it with the answer that knows nothing about the past.

///|
/// Whether two costs are the same number, up to the rounding of adding `√2` in different orders.
fn same_cost(a : Double, b : Double) -> Bool {
  if a >= 1.0e300 && b >= 1.0e300 {
    return true
  }
  let gap = (a - b).abs()
  let scale = if a.abs() > b.abs() { a.abs() } else { b.abs() }
  gap <= 1.0e-9 * (1.0 + scale)
}

///|
/// The cheapest route the board admits, asked from scratch: what the repair has to match.
fn fresh_cost(board : Grid, start : Int32, goal : Int32) -> Double {
  match board.a_star(start, goal) {
    Some(route) => board.path_cost(route)
    None => 1.0e300
  }
}

///|
test "the first plan is the straight line, and the route is a walk" {
  let board = Grid::new(6, 6)
  let start = board.node(0, 0)
  let goal = board.node(5, 5)
  let walker = board.d_star_lite(start, goal)
  assert_true(same_cost(walker.cost(), board.estimate(start, goal)))
  match walker.path() {
    Some(route) => {
      assert_eq(route[0], start)
      assert_eq(route[route.length() - 1], goal)
      // Every step is a step the board allows, and they add up to the cost reported.
      assert_true(same_cost(board.path_cost(route), walker.cost()))
    }
    None => fail("an empty board has a route")
  }
}

///|
test "a wall it was told about costs more, and the repair agrees with a fresh search" {
  let board = Grid::new(7, 5)
  let start = board.node(0, 0)
  let goal = board.node(6, 4)
  let walker = board.d_star_lite(start, goal)
  let open_cost = walker.cost()
  // A wall down the middle, open only at the bottom.
  let changed : Array[Int32] = []
  for y in 0..<4 {
    board.block(3, y)
    changed.push(board.node(3, y))
  }
  walker.replan(start, changed)
  assert_true(walker.cost() > open_cost)
  assert_true(same_cost(walker.cost(), fresh_cost(board, start, goal)))
  // And the route it hands back is the same price and still walkable.
  match walker.path() {
    Some(route) => {
      assert_true(same_cost(board.path_cost(route), walker.cost()))
      for at in 1..<route.length() {
        assert_true(board.neighbors(route[at - 1]).contains(route[at]))
      }
    }
    None => fail("the wall has a way round")
  }
}

///|
test "the wall comes down again and the route goes back to straight" {
  let board = Grid::new(7, 5)
  let start = board.node(0, 0)
  let goal = board.node(6, 4)
  let walker = board.d_star_lite(start, goal)
  let straight = walker.cost()
  let changed : Array[Int32] = []
  for y in 0..<4 {
    board.block(3, y)
    changed.push(board.node(3, y))
  }
  walker.replan(start, changed)
  assert_true(walker.cost() > straight)
  for y in 0..<4 {
    board.unblock(3, y)
  }
  walker.replan(start, changed)
  // Opening cells back up sharpens the estimate to the shortest route again.
  assert_true(same_cost(walker.cost(), board.estimate(start, goal)))
}

///|
test "walking part of the route keeps the rest of the work" {
  let board = Grid::new(8, 8)
  let start = board.node(0, 0)
  let goal = board.node(7, 7)
  let walker = board.d_star_lite(start, goal)
  let whole = walker.cost()
  let route = match walker.path() {
    Some(route) => route
    None => fail("an empty board has a route")
  }
  // Take three steps along the route and ask for the rest.
  let moved = route[3]
  walker.replan(moved, [])
  let rest = walker.cost()
  assert_true(same_cost(rest, fresh_cost(board, moved, goal)))
  // Three diagonal steps are three times the diagonal, so the whole is three steps shorter.
  assert_true(same_cost(whole - rest, board.estimate(start, moved)))
}

///|
test "random boards, random changes, checked every time against a fresh search" {
  let rng = @moonrand.seeded(b"dstar-diff")
  for round in 0..<6 {
    let width = @moonrand.randint(rng, 5, 9).to_int()
    let height = @moonrand.randint(rng, 5, 9).to_int()
    let board = Grid::new(width, height)
    let start = board.node(0, 0)
    let goal = board.node(width - 1, height - 1)
    let walker = board.d_star_lite(start, goal)
    assert_true(same_cost(walker.cost(), fresh_cost(board, start, goal)))
    // Toggle a handful of cells a few times, each time asking the repair and a fresh search the
    // same question.
    for _ in 0..<6 {
      let x = @moonrand.randint(rng, 0, (width - 1).to_int64()).to_int()
      let y = @moonrand.randint(rng, 0, (height - 1).to_int64()).to_int()
      let cell = board.node(x, y)
      if cell == start || cell == goal {
        continue
      }
      if board.is_blocked(x, y) {
        board.unblock(x, y)
      } else {
        board.block(x, y)
      }
      walker.replan(start, [cell])
      let repaired = walker.cost()
      let fresh = fresh_cost(board, start, goal)
      if !same_cost(repaired, fresh) {
        let counts = repaired.to_string() + " vs " + fresh.to_string()
        fail(
          "repair and fresh search disagree on board " +
          round.to_string() +
          ": " +
          counts,
        )
      }
    }
  }
}

///|
test "a sealed board has no route, and opening it finds one" {
  let board = Grid::new(5, 5)
  let start = board.node(0, 2)
  let goal = board.node(4, 2)
  let wall : Array[Int32] = []
  for y in 0..<5 {
    board.block(2, y)
    wall.push(board.node(2, y))
  }
  let walker = board.d_star_lite(start, goal)
  assert_true(walker.path() is None)
  assert_true(walker.cost() >= 1.0e300)
  board.unblock(2, 2)
  walker.replan(start, wall)
  assert_true(same_cost(walker.cost(), fresh_cost(board, start, goal)))
  assert_true(walker.path() is Some(_))
}
