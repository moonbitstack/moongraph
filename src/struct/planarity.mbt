// The left-right planarity test.
//
// The predicate in `struct.mbt` is one line of this file's entry point: everything
// below is the machinery that answers it. The test orients the graph with a depth
// first search, gives every edge a nesting depth, and then decides, edge by edge,
// whether the return edges that climb back up the DFS tree can be placed on the two
// sides of the tree without two of them crossing. Two edges that must be on the same
// side but return to different ancestors form a conflict pair; an interval that ends
// up needing both sides is the proof that the graph is not planar.

///|
/// One conflict pair: the return edges pushed to the left and to the right of the
/// tree, each as an interval of edges. `-1` is an empty interval.
priv struct ConflictPair {
  mut left_high : Int32
  mut left_low : Int32
  mut right_high : Int32
  mut right_low : Int32
}

///|
/// A pair with nothing on either side.
fn empty_pair() -> ConflictPair {
  { left_high: -1, left_low: -1, right_high: -1, right_low: -1, }
}

///|
/// Swaps the two sides of a pair.
fn swap_sides(pair : ConflictPair) -> Unit {
  let high = pair.left_high
  let low = pair.left_low
  pair.left_high = pair.right_high
  pair.left_low = pair.right_low
  pair.right_high = high
  pair.right_low = low
}

///|
/// The smaller of two numbers.
fn lesser(a : Int32, b : Int32) -> Int32 {
  if a < b {
    a
  } else {
    b
  }
}

///|
/// The state of one run of the test.
///
/// Every edge is numbered once, and oriented from the node the search reached it
/// from: `tail` and `head` are filled in as the search runs, so an edge whose head
/// is still `-1` has not been oriented yet.
priv struct Planarity {
  count : Int32
  height : Array[Int32]
  lowpt : Array[Int32]
  lowpt2 : Array[Int32]
  nesting : Array[Int32]
  tail : Array[Int32]
  head : Array[Int32]
  parent : Array[Int32]
  out_edges : Array[Array[Int32]]
  ordered : Array[Array[Int32]]
  lowpt_edge : Array[Int32]
  bottom : Array[Int32]
  up : Array[Int32]
  roots : Array[Int32]
  pairs : Array[ConflictPair]
  stack : Array[Int32]
}

///|
/// A run with nothing measured yet.
fn Planarity::new(count : Int32, edges : Int32) -> Planarity {
  {
    count,
    height: Array::make(count, -1),
    lowpt: Array::make(edges, 0),
    lowpt2: Array::make(edges, 0),
    nesting: Array::make(edges, 0),
    tail: Array::make(edges, -1),
    head: Array::make(edges, -1),
    parent: Array::make(count, -1),
    out_edges: Array::makei(count, fn(_) { ([] : Array[Int32]) }),
    ordered: Array::makei(count, fn(_) { ([] : Array[Int32]) }),
    lowpt_edge: Array::make(edges, -1),
    bottom: Array::make(edges, -1),
    up: Array::make(edges, -1),
    roots: [],
    pairs: [],
    stack: [],
  }
}

///|
/// A fresh conflict pair, and its number.
fn Planarity::new_pair(self : Planarity) -> Int32 {
  let at = self.pairs.length()
  self.pairs.push(empty_pair())
  at
}

///|
/// The pair on top of the stack, or `-1` when the stack is empty.
fn Planarity::top(self : Planarity) -> Int32 {
  if self.stack.length() == 0 {
    -1
  } else {
    self.stack[self.stack.length() - 1]
  }
}

///|
/// Points the interval ending at `from` at `to`, which is what the trimming below
/// follows when an interval is cut short.
fn Planarity::link(self : Planarity, from : Int32, to : Int32) -> Unit {
  if from >= 0 {
    self.up[from] = to
  }
}

///|
/// Whether the right side of a pair climbs above the given edge.
fn Planarity::right_conflicts(
  self : Planarity,
  pair : Int32,
  edge : Int32,
) -> Bool {
  let held = self.pairs[pair]
  held.right_low >= 0 && self.lowpt[held.right_high] > self.lowpt[edge]
}

///|
/// Whether the left side of a pair climbs above the given edge.
fn Planarity::left_conflicts(
  self : Planarity,
  pair : Int32,
  edge : Int32,
) -> Bool {
  let held = self.pairs[pair]
  held.left_low >= 0 && self.lowpt[held.left_high] > self.lowpt[edge]
}

///|
/// The lowest return point of a pair.
fn Planarity::lowest(self : Planarity, pair : Int32) -> Int32 {
  let held = self.pairs[pair]
  if held.left_low < 0 {
    return self.lowpt[held.right_low]
  }
  if held.right_low < 0 {
    return self.lowpt[held.left_low]
  }
  lesser(self.lowpt[held.left_low], self.lowpt[held.right_low])
}

///|
/// Orients the graph along a depth first search and measures every edge: the lowest
/// and second lowest node a return edge from its subtree reaches, and how deeply the
/// edge nests inside its parent.
fn Planarity::orient(
  self : Planarity,
  adjacency : Array[Array[(Int32, Int32)]],
) -> Unit {
  let at : Array[Int32] = Array::make(self.count, 0)
  for root in 0..<self.count {
    if self.height[root] >= 0 {
      continue
    }
    self.height[root] = 0
    self.roots.push(root)
    // A frame is a node and, when it is a revisit, the edge it went down by.
    let work : Array[(Int32, Int32)] = [(root, -1)]
    while work.length() > 0 {
      let (node, pending) = work.pop().unwrap()
      let taken = self.parent[node]
      let mut skip = pending
      while at[node] < adjacency[node].length() {
        let (other, edge) = adjacency[node][at[node]]
        if skip == edge {
          // Back from the subtree: the edge is already oriented and measured up to
          // this point, so only its contribution to the parent is left.
          skip = -1
        } else {
          if self.head[edge] >= 0 {
            at[node] = at[node] + 1
            continue
          }
          self.tail[edge] = node
          self.head[edge] = other
          self.out_edges[node].push(edge)
          self.lowpt[edge] = self.height[node]
          self.lowpt2[edge] = self.height[node]
          if self.height[other] < 0 {
            self.parent[other] = edge
            self.height[other] = self.height[node] + 1
            work.push((node, edge))
            work.push((other, -1))
            break
          }
          // An edge to a node already on the search is a return edge.
          self.lowpt[edge] = self.height[other]
        }
        self.nesting[edge] = 2 * self.lowpt[edge]
        if self.lowpt2[edge] < self.height[node] {
          self.nesting[edge] = self.nesting[edge] + 1
        }
        if taken >= 0 {
          if self.lowpt[edge] < self.lowpt[taken] {
            self.lowpt2[taken] = lesser(self.lowpt[taken], self.lowpt2[edge])
            self.lowpt[taken] = self.lowpt[edge]
          } else if self.lowpt[edge] > self.lowpt[taken] {
            self.lowpt2[taken] = lesser(self.lowpt2[taken], self.lowpt[edge])
          } else {
            self.lowpt2[taken] = lesser(self.lowpt2[taken], self.lowpt2[edge])
          }
        }
        at[node] = at[node] + 1
      }
    }
  }
}

///|
/// Sorts every node's oriented edges by nesting depth, deepest first inside the walk
/// order, so that an edge is tested before the edges it contains.
fn Planarity::order(self : Planarity) -> Unit {
  for node in 0..<self.count {
    let list = self.out_edges[node].copy()
    let mut at = 1
    while at < list.length() {
      let keep = list[at]
      let mut back = at
      while back > 0 && self.nesting[list[back - 1]] > self.nesting[keep] {
        list[back] = list[back - 1]
        back = back - 1
      }
      list[back] = keep
      at = at + 1
    }
    self.ordered[node] = list
  }
}

///|
/// Integrates the return edges of `edge` into the pair of its parent, and answers
/// whether they fit.
fn Planarity::add_constraints(
  self : Planarity,
  edge : Int32,
  parent : Int32,
) -> Bool {
  let made = self.new_pair()
  let joined = self.pairs[made]
  // The return edges of `edge` are merged into the right side of the new pair.
  while self.stack.length() > 0 {
    let other = self.stack.pop().unwrap()
    if self.pairs[other].left_low >= 0 {
      swap_sides(self.pairs[other])
    }
    if self.pairs[other].left_low >= 0 {
      // A pair that needs both sides is a crossing that cannot be drawn away.
      return false
    }
    if self.lowpt[self.pairs[other].right_low] > self.lowpt[parent] {
      if joined.right_low < 0 {
        joined.right_high = self.pairs[other].right_high
      } else {
        self.link(joined.right_low, self.pairs[other].right_high)
      }
      joined.right_low = self.pairs[other].right_low
    } else {
      // The interval stops at the parent: everything below it stays where it is.
      self.link(self.pairs[other].right_low, self.lowpt_edge[parent])
    }
    if self.top() == self.bottom[edge] {
      break
    }
  }
  // Return edges of the earlier children that conflict with this one go to the left.
  while self.stack.length() > 0 &&
        (
          self.left_conflicts(self.top(), edge) ||
          self.right_conflicts(self.top(), edge)
        ) {
    let other = self.stack.pop().unwrap()
    if self.right_conflicts(other, edge) {
      swap_sides(self.pairs[other])
    }
    if self.right_conflicts(other, edge) {
      return false
    }
    self.link(joined.right_low, self.pairs[other].right_high)
    if self.pairs[other].right_low >= 0 {
      joined.right_low = self.pairs[other].right_low
    }
    if joined.left_low < 0 {
      joined.left_high = self.pairs[other].left_high
    } else {
      self.link(joined.left_low, self.pairs[other].left_high)
    }
    joined.left_low = self.pairs[other].left_low
  }
  if joined.left_low >= 0 || joined.right_low >= 0 {
    self.stack.push(made)
  }
  true
}

///|
/// Drops the return edges that end at the parent of `edge`, which is finished once
/// its whole subtree has been tested.
fn Planarity::remove_back_edges(self : Planarity, edge : Int32) -> Unit {
  let parent = self.tail[edge]
  while self.stack.length() > 0 &&
        self.lowest(self.top()) == self.height[parent] {
    self.stack.pop() |> ignore
  }
  if self.stack.length() > 0 {
    let picked = self.stack.pop().unwrap()
    let held = self.pairs[picked]
    // Cut the left interval short where it ends at the parent.
    while held.left_high >= 0 && self.head[held.left_high] == parent {
      held.left_high = self.up[held.left_high]
    }
    if held.left_high < 0 && held.left_low >= 0 {
      self.link(held.left_low, held.right_low)
      held.left_low = -1
    }
    while held.right_high >= 0 && self.head[held.right_high] == parent {
      held.right_high = self.up[held.right_high]
    }
    if held.right_high < 0 && held.right_low >= 0 {
      self.link(held.right_low, held.left_low)
      held.right_low = -1
    }
    self.stack.push(picked)
  }
  if self.lowpt[edge] < self.height[parent] {
    // The side of an edge is the side of its highest return edge.
    let top = self.top()
    let left = if top >= 0 { self.pairs[top].left_high } else { -1 }
    let right = if top >= 0 { self.pairs[top].right_high } else { -1 }
    if left >= 0 && (right < 0 || self.lowpt[left] > self.lowpt[right]) {
      self.up[edge] = left
    } else {
      self.up[edge] = right
    }
  }
}

///|
/// The test itself, from one root of the search.
fn Planarity::walk(self : Planarity, root : Int32, at : Array[Int32]) -> Bool {
  let work : Array[(Int32, Int32)] = [(root, -1)]
  while work.length() > 0 {
    let (node, pending) = work.pop().unwrap()
    let taken = self.parent[node]
    let mut skip = pending
    let mut descended = false
    while at[node] < self.ordered[node].length() {
      let edge = self.ordered[node][at[node]]
      if skip == edge {
        skip = -1
      } else {
        self.bottom[edge] = self.top()
        let child = self.head[edge]
        if edge == self.parent[child] {
          // Test the subtree before the edge that leads into it.
          work.push((node, edge))
          work.push((child, -1))
          descended = true
          break
        }
        self.lowpt_edge[edge] = edge
        let pair = self.new_pair()
        self.pairs[pair].right_high = edge
        self.pairs[pair].right_low = edge
        self.stack.push(pair)
      }
      if self.lowpt[edge] < self.height[node] {
        if at[node] == 0 {
          // The first edge keeps the side of the whole subtree.
          self.lowpt_edge[taken] = self.lowpt_edge[edge]
        } else if !self.add_constraints(edge, taken) {
          return false
        }
      }
      at[node] = at[node] + 1
    }
    if !descended && taken >= 0 {
      self.remove_back_edges(taken)
    }
  }
  true
}

///|
/// Runs the orientation and the test, and answers whether the graph is planar.
///
/// `adjacency` holds one entry per edge, `(neighbour, edge number)`, sorted by
/// neighbour, and every node must appear in it even when it has no edges.
fn planar_with(adjacency : Array[Array[(Int32, Int32)]], edges : Int32) -> Bool {
  let count = adjacency.length()
  let state = Planarity::new(count, edges)
  state.orient(adjacency)
  state.order()
  let at : Array[Int32] = Array::make(count, 0)
  for root in state.roots {
    if !state.walk(root, at) {
      return false
    }
  }
  true
}
