// D* Lite: the search that keeps its work when the board changes.
//
// A robot walking a corridor does not get to plan once. It plans, takes a step, sees further than
// it did, finds the corridor blocked, and has to plan again — and the second plan is almost the
// same as the first, so redoing the whole search is waste. D* Lite keeps the distances it has
// already worked out, repairs only the part the change touched, and hands back a new route.
//
// It is the search ros_motion_planning and most of the field-robotics stack reach for. The state
// it keeps is two estimates per cell: `g`, what the cell is believed to cost to the goal, and
// `rhs`, what one step taken from the cell plus its best successor's `g` says it should cost.
// While the two agree the cell is settled; the queue holds the ones where they do not.

///|
/// The order two queue keys come in: the first number decides, then the second.
fn key_order(a : (Double, Double, Int32), b : (Double, Double, Int32)) -> Int32 {
  if a.0 < b.0 {
    -1
  } else if b.0 < a.0 {
    1
  } else if a.1 < b.1 {
    -1
  } else if b.1 < a.1 {
    1
  } else {
    0
  }
}

///|
/// A board search that has been planned once and can be repaired: it holds the distance estimate
/// of every cell, the queue of cells whose estimate is unsettled, and the offset that keeps the
/// heuristic honest as the start moves.
pub struct DStar {
  /// The board this search reads. It is the caller's board, so blocking a cell on it is what the
  /// next `replan` sees.
  grid : Grid
  /// Where the walk starts now.
  mut start : Int32
  /// Where it is going.
  goal : Int32
  /// The cost a cell is believed to carry to the goal.
  g : Array[Double]
  /// The cost one step from the cell, plus the best successor's `g`.
  rhs : Array[Double]
  /// The heuristic offset, raised as the start moves so old keys stay comparable.
  mut km : Double
  /// Cells whose estimates disagree, keyed by `(min(g, rhs) + h + km, min(g, rhs))`.
  open : @moonstl.PairingHeap[(Double, Double, Int32)]
}

///|
/// Plan a route from `start` to `goal`, keeping the work so the next plan can reuse it.
///
/// The first plan is already computed when this returns: `path` on the result is the route, and
/// `cost` is what it costs. Block a cell, call `replan` with the cells that changed, and `path`
/// is the new route — the search repairs what the change touched instead of starting over.
///
/// ```mbt check
/// test {
///   let board = @grid.Grid::new(6, 6)
///   let walker = board.d_star_lite(board.node(0, 0), board.node(5, 5))
///   // Five across and five down, all diagonal: the octile distance.
///   assert_eq(walker.cost(), board.estimate(board.node(0, 0), board.node(5, 5)))
///   // A wall across the middle, with the walker still at the start.
///   for y in 0..<5 {
///     board.block(3, y)
///   }
///   walker.replan(board.node(0, 0), [
///     board.node(3, 0),
///     board.node(3, 1),
///     board.node(3, 2),
///     board.node(3, 3),
///     board.node(3, 4),
///   ])
///   // The only way across is the bottom row, so the route is longer than the straight line.
///   assert_true(
///     walker.cost() > board.estimate(board.node(0, 0), board.node(5, 5)),
///   )
/// }
/// ```
pub fn Grid::d_star_lite(self : Grid, start : Int32, goal : Int32) -> DStar {
  let n = self.width() * self.height()
  let g : Array[Double] = Array::make(n, 1.0e300)
  let rhs : Array[Double] = Array::make(n, 1.0e300)
  let walker = {
    grid: self,
    start,
    goal,
    g,
    rhs,
    km: 0.0,
    open: @moonstl.PairingHeap::new_by(cmp=key_order),
  }
  if start < 0 || start >= n || goal < 0 || goal >= n {
    return walker
  }
  if self.blocked_at(start) || self.blocked_at(goal) {
    return walker
  }
  walker.rhs[goal] = 0.0
  walker.push(goal)
  walker.repair()
  walker
}

///|
/// The key a cell is filed under: the smaller of its two estimates, the estimate of the distance
/// still to walk from the start, and the offset.
fn DStar::key(self : DStar, node : Int32) -> (Double, Double, Int32) {
  let lowest = if self.g[node] < self.rhs[node] {
    self.g[node]
  } else {
    self.rhs[node]
  }
  (lowest + self.grid.estimate(self.start, node) + self.km, lowest, node)
}

///|
/// File a cell in the queue under its current key.
fn DStar::push(self : DStar, node : Int32) -> Unit {
  self.open.insert(self.key(node)) |> ignore
}

///|
/// Bring one cell's estimate up to date: what one step from it can reach, and whether that leaves
/// it settled or still in the queue.
fn DStar::update(self : DStar, node : Int32) -> Unit {
  if node == self.goal {
    // The goal is where the walk stops, so nothing is left to pay.
    self.rhs[node] = 0.0
  } else if self.grid.blocked_at(node) {
    self.rhs[node] = 1.0e300
  } else {
    let mut best = 1.0e300
    for next in self.grid.neighbors(node) {
      let through = self.grid.step_cost(node, next) + self.g[next]
      if through < best {
        best = through
      }
    }
    self.rhs[node] = best
  }
  if self.g[node] != self.rhs[node] {
    self.push(node)
  }
}

///|
/// Work the queue until the start is settled and no key in it is smaller than the start's: the
/// repair loop every D* Lite variant shares.
fn DStar::repair(self : DStar) -> Unit {
  let mut working = true
  while working {
    let popped = match self.open.pop() {
      Some(entry) => entry
      None => break
    }
    let (first, second, node) = popped
    if self.g[node] == self.rhs[node] {
      // The cell is settled already: this is an older entry that was never taken out, because
      // the queue has no way to remove one.
      continue
    }
    let current = self.key(node)
    let start_key = self.key(self.start)
    let key_smaller = first < start_key.0 ||
      (first == start_key.0 && second < start_key.1)
    // The loop runs while the start's two estimates disagree — either way round. A start whose
    // `g` is still infinite and whose `rhs` is not has work left in it, even though `rhs` is the
    // smaller of the two.
    let start_unsettled = self.rhs[self.start] != self.g[self.start]
    let worth_doing = key_smaller || start_unsettled
    if !worth_doing {
      // The queue's best is no better than the start's own key, so the start is settled. The
      // entry that was popped goes back, because the queue has no way to look without taking.
      self.open.insert(popped) |> ignore
      working = false
    } else if first < current.0 || (first == current.0 && second < current.1) {
      // The cell's key has moved since it was filed: file it again and carry on.
      self.push(node)
    } else if self.g[node] > self.rhs[node] {
      // The cell has just become reachable more cheaply than believed: settle it and tell the
      // cells that can step into it.
      self.g[node] = self.rhs[node]
      for before in self.grid.neighbors(node) {
        self.update(before)
      }
    } else {
      // The cell was settled and is not any more: forget the estimate and tell its neighbours,
      // itself included, to work theirs out again.
      self.g[node] = 1.0e300
      for before in self.grid.neighbors(node) {
        self.update(before)
      }
      self.update(node)
    }
  }
}

///|
/// The cost of the route from the start to the goal as last planned, or a very large number when
/// there is none.
pub fn DStar::cost(self : DStar) -> Double {
  if self.start < 0 || self.start >= self.g.length() {
    return 1.0e300
  }
  if self.g[self.start] >= 1.0e300 {
    return 1.0e300
  }
  self.g[self.start]
}

///|
/// The route as last planned, both ends included, or `None` when the goal cannot be reached.
///
/// The route is read off the settled estimates greedily: from each cell, take the neighbour that
/// leaves the least to pay. Because the estimates are settled, that walk is a cheapest route.
pub fn DStar::path(self : DStar) -> Array[Int32]? {
  if self.start == self.goal {
    return Some([self.start])
  }
  if self.cost() >= 1.0e300 {
    return None
  }
  let route : Array[Int32] = [self.start]
  let mut node = self.start
  let steps = self.g.length()
  for _ in 0..<steps {
    if node == self.goal {
      return Some(route)
    }
    let mut next = -1
    let mut best = 1.0e300
    for after in self.grid.neighbors(node) {
      let through = self.grid.step_cost(node, after) + self.g[after]
      if through < best {
        best = through
        next = after
      }
    }
    if next < 0 || best >= 1.0e300 {
      return None
    }
    route.push(next)
    node = next
  }
  None
}

///|
/// Repair the plan after the board changed and the walker moved.
///
/// `changed` lists the cells whose blocked state the caller just flipped — what a sensor update
/// would report — and `start` is where the walker is now. The offset is raised by the distance
/// walked, every cell the change touched is re-estimated, and the queue is worked until the new
/// start is settled. Nothing else is thrown away, which is the whole point.
pub fn DStar::replan(
  self : DStar,
  start : Int32,
  changed : Array[Int32],
) -> Unit {
  let n = self.grid.width() * self.grid.height()
  if start < 0 || start >= n {
    return
  }
  self.km = self.km + self.grid.estimate(self.start, start)
  self.start = start
  for cell in changed {
    if cell < 0 || cell >= n {
      continue
    }
    // The cell itself and everything that could step into or out of it.
    for around in self.grid.neighbors(cell) {
      self.update(around)
    }
    self.update(cell)
  }
  self.repair()
}
