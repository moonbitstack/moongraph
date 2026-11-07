// A grid is a board of cells, some blocked, the rest free; a walk steps to a neighbour, and
// the cost of a diagonal step is the square root of two, the exact length of the diagonal of a
// unit square.
//
// The searches here answer the same question three ways — breadth first when every step costs
// one, Dijkstra when it does not, A* when there is a target to steer by, and the jump-point
// search when the board is large and mostly open. The corner of a blocked cell is not a
// doorway: a diagonal step needs both of the cells it squeezes between to be free.

///|
/// A board of `width × height` cells, each free or blocked, numbered `y * width + x`.
pub struct Grid {
  width : Int32
  height : Int32
  blocked : Array[Bool]
}

///|
/// The length of a diagonal step: the diagonal of a unit square.
const DIAGONAL : Double = 1.4142135623730951

///|
/// A board with every cell free.
pub fn Grid::new(width : Int32, height : Int32) -> Grid {
  { width, height, blocked: Array::make(width * height, false), }
}

///|
/// How wide the board is.
pub fn Grid::width(self : Grid) -> Int32 {
  self.width
}

///|
/// How tall the board is.
pub fn Grid::height(self : Grid) -> Int32 {
  self.height
}

///|
/// The number the cell `(x, y)` carries.
pub fn Grid::node(self : Grid, x : Int32, y : Int32) -> Int32 {
  y * self.width + x
}

///|
/// The column of a cell number.
pub fn Grid::x(self : Grid, node : Int32) -> Int32 {
  node % self.width
}

///|
/// The row of a cell number.
pub fn Grid::y(self : Grid, node : Int32) -> Int32 {
  node / self.width
}

///|
/// Whether a cell is on the board.
pub fn Grid::inside(self : Grid, x : Int32, y : Int32) -> Bool {
  x >= 0 && y >= 0 && x < self.width && y < self.height
}

///|
/// Blocks a cell. Blocking a cell already blocked changes nothing.
pub fn Grid::block(self : Grid, x : Int32, y : Int32) -> Unit {
  if self.inside(x, y) {
    self.blocked[self.node(x, y)] = true
  }
}

///|
/// Frees a cell that was blocked.
pub fn Grid::unblock(self : Grid, x : Int32, y : Int32) -> Unit {
  if self.inside(x, y) {
    self.blocked[self.node(x, y)] = false
  }
}

///|
/// Whether a cell is blocked, or off the board.
pub fn Grid::is_blocked(self : Grid, x : Int32, y : Int32) -> Bool {
  if !self.inside(x, y) {
    true
  } else {
    self.blocked[self.node(x, y)]
  }
}

///|
/// Whether the cell a number names is blocked, or off the board.
pub fn Grid::blocked_at(self : Grid, node : Int32) -> Bool {
  self.blocked[node]
}

///|
/// The free neighbours of a cell, in the order up, down, left, right, then the four diagonals.
///
/// A diagonal neighbour counts only when both cells the step squeezes between are free, so a
/// walk never cuts the corner of a blocked cell.
pub fn Grid::neighbors(self : Grid, node : Int32) -> Array[Int32] {
  let x = self.x(node)
  let y = self.y(node)
  let out : Array[Int32] = []
  let up = self.is_blocked(x, y - 1)
  let down = self.is_blocked(x, y + 1)
  let left = self.is_blocked(x - 1, y)
  let right = self.is_blocked(x + 1, y)
  if !up {
    out.push(self.node(x, y - 1))
  }
  if !down {
    out.push(self.node(x, y + 1))
  }
  if !left {
    out.push(self.node(x - 1, y))
  }
  if !right {
    out.push(self.node(x + 1, y))
  }
  if !self.is_blocked(x - 1, y - 1) {
    out.push(self.node(x - 1, y - 1))
  }
  if !self.is_blocked(x + 1, y - 1) {
    out.push(self.node(x + 1, y - 1))
  }
  if !self.is_blocked(x - 1, y + 1) {
    out.push(self.node(x - 1, y + 1))
  }
  if !self.is_blocked(x + 1, y + 1) {
    out.push(self.node(x + 1, y + 1))
  }
  out
}

///|
/// The cost of one step between two neighbouring cells: one straight, the diagonal otherwise.
pub fn Grid::step_cost(self : Grid, from : Int32, to : Int32) -> Double {
  if self.x(from) != self.x(to) && self.y(from) != self.y(to) {
    DIAGONAL
  } else {
    1.0
  }
}

///|
/// The octile distance between two cells: the cheapest a walk could possibly be, which is what
/// A* steers by. It never overestimates, so A* still finds a cheapest route.
pub fn Grid::estimate(self : Grid, from : Int32, to : Int32) -> Double {
  let dx = (self.x(from) - self.x(to)).abs().to_double()
  let dy = (self.y(from) - self.y(to)).abs().to_double()
  let straight = if dx > dy { dx - dy } else { dy - dx }
  straight + DIAGONAL * (if dx > dy { dy } else { dx })
}

///|
/// The cost of walking a route, cell by cell; zero for a route of fewer than two cells.
pub fn Grid::path_cost(self : Grid, path : Array[Int32]) -> Double {
  let mut total = 0.0
  for at in 0..<path.length() {
    if at > 0 {
      total = total + self.step_cost(path[at - 1], path[at])
    }
  }
  total
}

///|
/// A cheapest route from `start` to `goal` when every step costs one, or `None` when the goal
/// cannot be reached. Breadth first, so the route has the fewest cells.
pub fn Grid::bfs(self : Grid, start : Int32, goal : Int32) -> Array[Int32]? {
  let total = self.width * self.height
  if start < 0 || start >= total || goal < 0 || goal >= total {
    return None
  }
  if self.blocked_at(start) || self.blocked_at(goal) {
    return None
  }
  let previous : Array[Int32] = Array::make(total, -1)
  let seen : Array[Bool] = Array::make(total, false)
  let queue : Array[Int32] = [start]
  seen[start] = true
  let mut head = 0
  let mut found = false
  while head < queue.length() && !found {
    let at = queue[head]
    head = head + 1
    if at == goal {
      found = true
    } else {
      for nbr in self.neighbors(at) {
        if !seen[nbr] {
          seen[nbr] = true
          previous[nbr] = at
          queue.push(nbr)
        }
      }
    }
  }
  if !found {
    None
  } else {
    Some(rebuilt(previous, start, goal))
  }
}

///|
/// The cheapest cost of reaching every cell from `start`, `1.0e300` where a cell cannot be
/// reached. Dijkstra over the eight-connected board.
pub fn Grid::dijkstra(self : Grid, start : Int32) -> Array[Double] {
  let total = self.width * self.height
  let best : Array[Double] = Array::make(total, 1.0e300)
  if start < 0 || start >= total || self.blocked_at(start) {
    return best
  }
  best[start] = 0.0
  let done : Array[Bool] = Array::make(total, false)
  let open : Array[Int32] = [start]
  while open.length() > 0 {
    // The smallest unsettled cost. A heap would be faster; a scan keeps the code plain.
    let mut pick = 0
    let mut pick_cost = 1.0e300
    for at in 0..<open.length() {
      if best[open[at]] < pick_cost {
        pick_cost = best[open[at]]
        pick = at
      }
    }
    let node = open[pick]
    open.remove(pick) |> ignore
    if !done[node] {
      done[node] = true
      for nbr in self.neighbors(node) {
        let step = self.step_cost(node, nbr)
        if best[node] + step < best[nbr] {
          best[nbr] = best[node] + step
          open.push(nbr)
        }
      }
    }
  }
  best
}

///|
/// A cheapest route from `start` to `goal`, or `None` when the goal cannot be reached.
///
/// A* with the octile distance as its estimate: it expands the cells the cheapest route plausibly
/// crosses, and because the estimate never overestimates, the route it finds is a cheapest one.
pub fn Grid::a_star(self : Grid, start : Int32, goal : Int32) -> Array[Int32]? {
  let total = self.width * self.height
  if start < 0 || start >= total || goal < 0 || goal >= total {
    return None
  }
  if self.blocked_at(start) || self.blocked_at(goal) {
    return None
  }
  let best : Array[Double] = Array::make(total, 1.0e300)
  let previous : Array[Int32] = Array::make(total, -1)
  let done : Array[Bool] = Array::make(total, false)
  best[start] = 0.0
  let open : Array[Int32] = [start]
  let mut reached = false
  while open.length() > 0 && !reached {
    let mut pick = 0
    let mut pick_score = 1.0e300
    for at in 0..<open.length() {
      let node = open[at]
      let score = best[node] + self.estimate(node, goal)
      if score < pick_score {
        pick_score = score
        pick = at
      }
    }
    let node = open[pick]
    open.remove(pick) |> ignore
    if node == goal {
      reached = true
    } else if !done[node] {
      done[node] = true
      for nbr in self.neighbors(node) {
        let step = self.step_cost(node, nbr)
        if best[node] + step < best[nbr] {
          best[nbr] = best[node] + step
          previous[nbr] = node
          open.push(nbr)
        }
      }
    }
  }
  if !reached {
    None
  } else {
    Some(rebuilt(previous, start, goal))
  }
}

///|
/// The route a `previous` table spells out, from `start` to `goal`.
fn rebuilt(
  previous : Array[Int32],
  start : Int32,
  goal : Int32,
) -> Array[Int32] {
  let reversed : Array[Int32] = []
  let mut at = goal
  while at != start && at >= 0 {
    reversed.push(at)
    at = previous[at]
  }
  reversed.push(start)
  let out : Array[Int32] = []
  for step in 0..<reversed.length() {
    out.push(reversed[reversed.length() - 1 - step])
  }
  out
}

///|
/// A cheapest route from `start` to `goal` found by the jump-point search, or `None` when the
/// goal cannot be reached.
///
/// The search is A* that does not expand a cell whose parent can be reached from a cell before
/// it by the same step: along an open straight or diagonal run it jumps straight to the next
/// cell that matters, a corner of a blocked cell or the goal itself. The route it returns is
/// cell by cell, and it costs the same as the one A* returns.
pub fn Grid::jps(self : Grid, start : Int32, goal : Int32) -> Array[Int32]? {
  let total = self.width * self.height
  if start < 0 || start >= total || goal < 0 || goal >= total {
    return None
  }
  if self.blocked_at(start) || self.blocked_at(goal) {
    return None
  }
  if start == goal {
    return Some([start])
  }
  let best : Array[Double] = Array::make(total, 1.0e300)
  let previous : Array[Int32] = Array::make(total, -1)
  let done : Array[Bool] = Array::make(total, false)
  best[start] = 0.0
  let open : Array[Int32] = [start]
  let mut reached = false
  while open.length() > 0 && !reached {
    let mut pick = 0
    let mut pick_score = 1.0e300
    for at in 0..<open.length() {
      let node = open[at]
      let score = best[node] + self.estimate(node, goal)
      if score < pick_score {
        pick_score = score
        pick = at
      }
    }
    let node = open[pick]
    open.remove(pick) |> ignore
    if node == goal {
      reached = true
    } else if !done[node] {
      done[node] = true
      for (dx, dy) in directions() {
        match self.jump(node, dx, dy, start, goal) {
          Some(found) => {
            let add = self.path_cost(self.straight(node, found))
            if best[node] + add < best[found] {
              best[found] = best[node] + add
              previous[found] = node
              open.push(found)
            }
          }
          None => ()
        }
      }
    }
  }
  if !reached {
    None
  } else {
    // Expand the jump points back into every cell the walk crosses.
    let waypoints = rebuilt(previous, start, goal)
    let out : Array[Int32] = [waypoints[0]]
    for at in 1..<waypoints.length() {
      let from = waypoints[at - 1]
      let to = waypoints[at]
      let dx = sign(self.x(to) - self.x(from))
      let dy = sign(self.y(to) - self.y(from))
      let mut x = self.x(from) + dx
      let mut y = self.y(from) + dy
      while x != self.x(to) || y != self.y(to) {
        out.push(self.node(x, y))
        x = x + dx
        y = y + dy
      }
      out.push(to)
    }
    Some(out)
  }
}

///|
/// The eight directions a step can take.
fn directions() -> Array[(Int32, Int32)] {
  [(0, -1), (0, 1), (-1, 0), (1, 0), (-1, -1), (1, -1), (-1, 1), (1, 1)]
}

///|
/// The sign of a number: -1, 0, or 1.
fn sign(value : Int32) -> Int32 {
  if value > 0 {
    1
  } else if value < 0 {
    -1
  } else {
    0
  }
}

///|
/// Whether the cell is free and on the board.
fn Grid::free(self : Grid, x : Int32, y : Int32) -> Bool {
  !self.is_blocked(x, y)
}

///|
/// The cells a straight walk between two jump points crosses, both ends included.
fn Grid::straight(self : Grid, from : Int32, to : Int32) -> Array[Int32] {
  let dx = sign(self.x(to) - self.x(from))
  let dy = sign(self.y(to) - self.y(from))
  let out : Array[Int32] = [from]
  let mut x = self.x(from) + dx
  let mut y = self.y(from) + dy
  while x != self.x(to) || y != self.y(to) {
    out.push(self.node(x, y))
    x = x + dx
    y = y + dy
  }
  out.push(to)
  out
}

///|
/// Whether a cell has a forced neighbour in the direction a walk came from: a free cell a
/// straight walk could not have reached, which is what makes the run worth stopping at.
fn Grid::forced(
  self : Grid,
  x : Int32,
  y : Int32,
  dx : Int32,
  dy : Int32,
) -> Bool {
  if dx != 0 && dy == 0 {
    // Walking left or right: a blocked cell above or below with a free diagonal past it.
    let above = self.is_blocked(x, y - 1) && self.free(x + dx, y - 1)
    let below = self.is_blocked(x, y + 1) && self.free(x + dx, y + 1)
    above || below
  } else if dx == 0 && dy != 0 {
    let before = self.is_blocked(x - 1, y) && self.free(x - 1, y + dy)
    let after = self.is_blocked(x + 1, y) && self.free(x + 1, y + dy)
    before || after
  } else {
    // Walking diagonally: a blocked cell beside the start with a free cell past it.
    let side_a = self.is_blocked(x - dx, y) && self.free(x - dx, y + dy)
    let side_b = self.is_blocked(x, y - dy) && self.free(x + dx, y - dy)
    side_a || side_b
  }
}

///|
/// Jumps from `node` in direction `(dx, dy)` and answers the next jump point, or `None` when the
/// path runs into a wall or leaves the board.
fn Grid::jump(
  self : Grid,
  node : Int32,
  dx : Int32,
  dy : Int32,
  start : Int32,
  goal : Int32,
) -> Int32? {
  let mut x = self.x(node) + dx
  let mut y = self.y(node) + dy
  while self.free(x, y) {
    let at = self.node(x, y)
    if at == goal {
      return Some(at)
    }
    if self.forced(x, y, dx, dy) {
      return Some(at)
    }
    if dx != 0 && dy != 0 {
      // A diagonal run can be entered from either of its two sides.
      match self.jump(at, dx, 0, start, goal) {
        Some(_) => return Some(at)
        None => ()
      }
      match self.jump(at, 0, dy, start, goal) {
        Some(_) => return Some(at)
        None => ()
      }
    }
    x = x + dx
    y = y + dy
  }
  None
}
