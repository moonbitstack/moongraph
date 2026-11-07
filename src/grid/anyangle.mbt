// Any-angle pathfinding: a route that is allowed to go in a straight line rather than turn at
// every cell boundary.
//
// A board search is bounded by its grid: the cheapest eight-connected route between two points
// zig-zags along cell diagonals and comes out longer than the straight line between them. Theta*
// keeps the same search but changes one rule — when a node comes up, it tries to reach its
// neighbours straight from its *parent* instead of from itself, and it only does so when the
// straight line between them is clear. The route that comes out has long straight runs and no
// needless corners, which is what a walking robot actually follows.

///|
/// The cost of the straight line between two cells: the octile distance, the length of a route
/// that steps diagonally as far as it can and then straight.
fn Grid::straight_between(self : Grid, from : Int32, to : Int32) -> Double {
  self.estimate(from, to)
}

///|
/// Whether a straight line between two cells stays on the board and off the blocked cells: the
/// test Theta* uses before it lets a route skip a corner.
///
/// The line is walked the way a rasteriser walks it — one cell at a time, choosing which axis to
/// step on each turn so that the walk stays as close to the true line as a grid allows. A blocked
/// cell anywhere along it, its ends included, fails the test.
///
/// ```mbt check
/// test {
///   let board = @grid.Grid::new(5, 5)
///   assert_true(board.line_of_sight(board.node(0, 0), board.node(4, 4)))
///   board.block(2, 2)
///   assert_false(board.line_of_sight(board.node(0, 0), board.node(4, 4)))
/// }
/// ```
pub fn Grid::line_of_sight(self : Grid, from : Int32, to : Int32) -> Bool {
  let mut x = self.x(from)
  let mut y = self.y(from)
  let x_end = self.x(to)
  let y_end = self.y(to)
  let dx = (x_end - x).abs()
  let dy = (y_end - y).abs()
  let step_x = if x < x_end { 1 } else { -1 }
  let step_y = if y < y_end { 1 } else { -1 }
  let mut error = dx - dy
  let mut clear = false
  while true {
    if !self.inside(x, y) || self.is_blocked(x, y) {
      clear = false
      break
    }
    if x == x_end && y == y_end {
      clear = true
      break
    }
    let twice = 2 * error
    if twice > -dy {
      error = error - dy
      x = x + step_x
    }
    if twice < dx {
      error = error + dx
      y = y + step_y
    }
  }
  clear
}

///|
/// The cheapest any-angle route from `start` to `goal`, both included, or `None` when no route
/// exists.
///
/// The walk is A* with one change: a neighbour is reached from the node's parent when the straight
/// line between them is clear, so the route does not bend at a cell boundary it does not have to.
/// The cost of a straight run is its octile length, the same measure the board uses for a step, so
/// a route returned here can be compared with one `a_star` returns.
///
/// ```mbt check
/// test {
///   let board = @grid.Grid::new(6, 6)
///   let route = board.theta_star(board.node(0, 0), board.node(5, 5))
///   match route {
///     // Nothing in the way, so the route is a straight diagonal: two cells, not six.
///     Some(cells) => assert_eq(cells.length(), 2)
///     None => fail("an empty board has a route")
///   }
/// }
/// ```
pub fn Grid::theta_star(
  self : Grid,
  start : Int32,
  goal : Int32,
) -> Array[Int32]? {
  let n = self.width() * self.height()
  if start < 0 || start >= n || goal < 0 || goal >= n {
    return None
  }
  if self.blocked_at(start) || self.blocked_at(goal) {
    return None
  }
  if start == goal {
    return Some([start])
  }
  let cost : Array[Double] = Array::make(n, 1.0e300)
  let parent : Array[Int32] = Array::make(n, -1)
  let settled : Array[Bool] = Array::make(n, false)
  let heap = @moonstl.PairingHeap::new_by(cmp=@internal.entry_cmp)
  cost[start] = 0.0
  parent[start] = start
  heap.insert((self.straight_between(start, goal), start)) |> ignore
  while heap.pop() is Some((_, node)) {
    if settled[node] {
      continue
    }
    settled[node] = true
    if node == goal {
      break
    }
    let from = parent[node]
    for next in self.neighbors(node) {
      if settled[next] {
        continue
      }
      // The two ways to reach a neighbour: on from this node, or straight from the node this one
      // was reached from, which is the relaxation that makes the route any-angle.
      let by_step = cost[node] + self.step_cost(node, next)
      let by_line = cost[from] + self.straight_between(from, next)
      // A tie goes to the straight run: it costs the same and needs no waypoint, so the route
      // comes out with long runs instead of a staircase.
      let straight = self.line_of_sight(from, next) && by_line <= by_step
      let candidate = if straight { by_line } else { by_step }
      if candidate < cost[next] {
        cost[next] = candidate
        parent[next] = if straight { from } else { node }
        heap.insert((candidate + self.straight_between(next, goal), next))
        |> ignore
      }
    }
  }
  if cost[goal] >= 1.0e300 {
    return None
  }
  let reversed : Array[Int32] = [goal]
  let mut node = goal
  while node != start {
    let before = parent[node]
    if before < 0 {
      return None
    }
    reversed.push(before)
    node = before
  }
  let route : Array[Int32] = []
  for at in 0..<reversed.length() {
    route.push(reversed[reversed.length() - 1 - at])
  }
  Some(route)
}

///|
/// The cost of an any-angle route: the octile length of each straight run, added up. Unlike
/// `path_cost`, the stops need not be neighbours, only in sight of each other.
pub fn Grid::straight_cost(self : Grid, route : Array[Int32]) -> Double {
  let mut total = 0.0
  for at in 1..<route.length() {
    total = total + self.straight_between(route[at - 1], route[at])
  }
  total
}
