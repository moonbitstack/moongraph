// The differential test for the any-angle search: its route is checked against the board's own
// A*, and against the line-of-sight rule it claims to follow.
//
// Two things have to hold. The route must be walkable — every straight run must be clear, which
// `line_of_sight` decides, and its length must be the sum of those runs. And it must not be
// longer than what the grid-bound search finds: Theta* is allowed to do better, never worse.

///|
/// A board with roughly one cell in five blocked, never the two ends.
fn random_board(width : Int32, height : Int32, rng : &@contract.Rng) -> Grid {
  let board = Grid::new(width, height)
  for y in 0..<height {
    for x in 0..<width {
      if @moonrand.randint(rng, 0, 4).to_int() == 0 {
        board.block(x, y)
      }
    }
  }
  board
}

///|
test "an empty board gives a straight line, two cells long" {
  let board = Grid::new(6, 6)
  let start = board.node(0, 0)
  let goal = board.node(5, 5)
  let theta = board.theta_star(start, goal)
  let grid = board.a_star(start, goal)
  match (theta, grid) {
    (Some(straight), Some(bent)) => {
      assert_eq(straight.length(), 2)
      // Five across and five down, so five diagonal steps.
      assert_eq(straight_cost_of(board, straight), board.path_cost(bent))
    }
    _ => fail("an empty board has a route both ways")
  }
}

///|
/// The cost of an any-angle route, spelled out here so the test does not lean on the function it
/// is checking.
fn straight_cost_of(board : Grid, route : Array[Int32]) -> Double {
  let mut total = 0.0
  for at in 1..<route.length() {
    total = total + board.estimate(route[at - 1], route[at])
  }
  total
}

///|
test "the route is walkable and no longer than the grid-bound one" {
  let rng = @moonrand.seeded(b"theta-diff")
  for round in 0..<40 {
    let width = @moonrand.randint(rng, 4, 9).to_int()
    let height = @moonrand.randint(rng, 4, 9).to_int()
    let board = random_board(width, height, rng)
    let start = board.node(0, 0)
    let goal = board.node(width - 1, height - 1)
    board.unblock(0, 0)
    board.unblock(width - 1, height - 1)
    let theta = board.theta_star(start, goal)
    let grid = board.a_star(start, goal)
    match (theta, grid) {
      (Some(route), Some(bound)) => {
        // The ends are the ends.
        assert_eq(route[0], start)
        assert_eq(route[route.length() - 1], goal)
        // Every run is clear, so a robot could follow it.
        for at in 1..<route.length() {
          if !board.line_of_sight(route[at - 1], route[at]) {
            fail(
              "run " +
              at.to_string() +
              " is not in sight on board " +
              round.to_string(),
            )
          }
        }
        // Never worse than the grid-bound route.
        let mine = straight_cost_of(board, route)
        let theirs = board.path_cost(bound)
        if mine > theirs + 1.0e-9 {
          let counts = mine.to_string() + " > " + theirs.to_string()
          fail(
            "any-angle is longer than A* on board " +
            round.to_string() +
            ": " +
            counts,
          )
        }
      }
      (None, None) => ()
      (None, Some(_)) => fail("any-angle found no route where A* found one")
      (Some(_), None) => fail("any-angle found a route where A* found none")
    }
  }
}

///|
test "a wall with one gap: the route goes through the gap" {
  let board = Grid::new(7, 5)
  // A wall down the middle with a single opening at the top.
  for y in 1..<5 {
    board.block(3, y)
  }
  let start = board.node(0, 4)
  let goal = board.node(6, 4)
  match board.theta_star(start, goal) {
    Some(route) => {
      let mut through_gap = false
      for cell in route {
        if board.y(cell) == 0 && board.x(cell) == 3 {
          through_gap = true
        }
      }
      assert_true(through_gap)
      // Going round a wall costs more than open ground, and no more than the grid-bound route.
      match board.a_star(start, goal) {
        Some(bent) =>
          assert_true(
            straight_cost_of(board, route) <= board.path_cost(bent) + 1.0e-9,
          )
        None => fail("A* walks the gap too")
      }
    }
    None => fail("the gap is a route")
  }
}

///|
test "a sealed board has no route, and neither search invents one" {
  let board = Grid::new(5, 5)
  for y in 0..<5 {
    board.block(2, y)
  }
  let start = board.node(0, 2)
  let goal = board.node(4, 2)
  assert_true(board.theta_star(start, goal) is None)
  assert_true(board.a_star(start, goal) is None)
  // A route from a cell to itself is that cell, at no cost.
  assert_eq(board.theta_star(start, start), Some([start]))
}

///|
test "a blocked end has no route" {
  let board = Grid::new(4, 4)
  board.block(1, 1)
  assert_true(board.theta_star(board.node(0, 0), board.node(1, 1)) is None)
  assert_true(board.theta_star(board.node(1, 1), board.node(0, 0)) is None)
}

///|
test "line of sight is symmetric and takes the direct route" {
  let board = Grid::new(6, 6)
  let a = board.node(0, 0)
  let b = board.node(4, 3)
  assert_eq(board.line_of_sight(a, b), board.line_of_sight(b, a))
  let forward = board.line_of_sight(a, b)
  assert_true(forward)
  // A cell on the line blocks it, and the test sees that from either end.
  board.block(2, 2)
  assert_false(board.line_of_sight(board.node(0, 0), board.node(4, 4)))
  assert_false(board.line_of_sight(board.node(4, 4), board.node(0, 0)))
  // A cell that is not on the line does not.
  assert_true(board.line_of_sight(board.node(0, 5), board.node(5, 5)))
}
