// The reference cost of a route across each board, replayed: every search has to find a route
// that costs what the reference's A* costs, or none when the reference found none, and the
// route itself has to be a walk the board admits.

///|
test "the searches cost what the reference's A* costs" {
  for case in @internal.board_cases() {
    let grid = Grid::new(case.width, case.height)
    for cell in case.blocked {
      grid.block(grid.x(cell), grid.y(cell))
    }
    let start = case.start
    let goal = case.goal
    let spot = case.name + ": "
    let jump = grid.jps(start, goal)
    let guided = grid.a_star(start, goal)
    if case.cost < 0.0 {
      if jump is Some(_) {
        fail(spot + "the jump-point search found a route where there is none")
      }
      if guided is Some(_) {
        fail(spot + "A* found a route where there is none")
      }
      if grid.bfs(start, goal) is Some(_) {
        fail(spot + "the breadth-first walk found a route where there is none")
      }
      continue
    }
    match jump {
      Some(route) => {
        if !is_walk(grid, route, start, goal) {
          fail(spot + "the jump-point route is not a walk")
        }
        if !@internal.close(grid.path_cost(route), case.cost) {
          let want = case.cost.to_string()
          let got = grid.path_cost(route).to_string()
          fail(spot + "the jump-point route costs " + got + ", not " + want)
        }
      }
      None => fail(spot + "the jump-point search found no route")
    }
    match guided {
      Some(route) => {
        if !is_walk(grid, route, start, goal) {
          fail(spot + "A* returned a route that is not a walk")
        }
        if !@internal.close(grid.path_cost(route), case.cost) {
          let got = grid.path_cost(route).to_string()
          fail(
            spot + "A*'s route costs " + got + ", not " + case.cost.to_string(),
          )
        }
      }
      None => fail(spot + "A* found no route")
    }
    let settled = grid.dijkstra(start)
    if !@internal.close(settled[goal], case.cost) {
      let got = settled[goal].to_string()
      fail(spot + "Dijkstra settles on " + got)
    }
    if grid.bfs(start, goal) is None {
      fail(spot + "the breadth-first walk found no route")
    }
  }
}

///|
test "the estimate never overestimates what a route costs" {
  for case in @internal.board_cases() {
    let grid = Grid::new(case.width, case.height)
    for cell in case.blocked {
      grid.block(grid.x(cell), grid.y(cell))
    }
    let goal = case.goal
    if grid.blocked_at(goal) {
      continue
    }
    // The cost of the cheapest walk from every cell to the goal, read backwards.
    let settled = grid.dijkstra(goal)
    for cell in 0..<(case.width * case.height) {
      if grid.blocked_at(cell) || settled[cell] >= 1.0e299 {
        continue
      }
      // An estimate above the cost would let A* settle a cell too late to find a cheapest
      // route, which is the one thing the estimate exists to prevent.
      if grid.estimate(cell, goal) > settled[cell] + 1.0e-9 {
        let spot = case.name + ": cell " + cell.to_string()
        fail(spot + " is estimated above its cost")
      }
    }
  }
}
