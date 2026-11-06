// Spanning trees and the structure of trees.

///|
/// How a spanning tree is grown.
pub(all) enum SpanningMethod {
  /// Cheapest edge first, joining pieces. The default: it needs no node index.
  Kruskal
  /// Grow one piece outward from a node, taking the cheapest edge that leaves it.
  Prim
  /// Repeatedly add the cheapest edge out of every piece at once.
  Boruvka
}

///|
/// A minimum spanning tree.
///
/// Refuses `Disconnected`: a forest is not a spanning tree. A caller that wants the
/// forest asks for `components` first and runs this per component.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (0, 2)],
///     node=(),
///     edge=1.0,
///     directed=false,
///   )
///   g.set_edge_data(2, 5.0)
///   let tree = @tree.minimum_spanning(g, weight=g.weights(fn(w) { w }))
///   assert_eq(tree.edges, [0, 1])
///   assert_eq(tree.weight, 2.0)
/// }
/// ```
pub fn[G : @moongraph.Topology] minimum_spanning(
  graph : G,
  weight? : (Int32) -> Double,
  kind~ : SpanningMethod = Kruskal,
) -> @moongraph.Spanning raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  match kind {
    Kruskal => kruskal(graph, w, true)
    Prim => prim(graph, w)
    Boruvka => boruvka(graph, w)
  }
}

///|
/// A maximum spanning tree, by the same walk with the comparison turned around.
pub fn[G : @moongraph.Topology] maximum_spanning(
  graph : G,
  weight? : (Int32) -> Double,
) -> @moongraph.Spanning raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  kruskal(graph, w, false)
}

///|
/// The edges sorted by weight, then by edge number, so the walk is reproducible.
fn[G : @moongraph.Topology] ordered_edges(
  graph : G,
  w : (Int32) -> Double,
  ascending : Bool,
) -> Array[Int32] {
  let out : Array[Int32] = []
  for node in 0..<@moongraph.Topology::node_count(graph) {
    for edge in @moongraph.Topology::incident(graph, node) {
      if !out.contains(edge) {
        out.push(edge)
      }
    }
  }
  out.sort_by(fn(a, b) {
    let wa = w(a)
    let wb = w(b)
    if wa < wb {
      if ascending {
        -1
      } else {
        1
      }
    } else if wa > wb {
      if ascending {
        1
      } else {
        -1
      }
    } else {
      a - b
    }
  })
  out
}

///|
fn[G : @moongraph.Topology] kruskal(
  graph : G,
  w : (Int32) -> Double,
  ascending : Bool,
) -> @moongraph.Spanning raise @moongraph.Refused {
  let n = @moongraph.Topology::node_count(graph)
  let parts = @internal.UnionFind::new(n)
  let chosen : Array[Int32] = []
  let mut total = 0.0
  for edge in ordered_edges(graph, w, ascending) {
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    if a < 0 || b < 0 || a >= n || b >= n {
      continue
    }
    if parts.union(a, b) {
      chosen.push(edge)
      total = total + w(edge)
    }
  }
  if n > 1 && chosen.length() != n - 1 {
    raise @moongraph.Refused::Disconnected(from=0, to=0)
  }
  { edges: chosen, weight: total, }
}

///|
fn[G : @moongraph.Topology] prim(
  graph : G,
  w : (Int32) -> Double,
) -> @moongraph.Spanning raise @moongraph.Refused {
  let n = @moongraph.Topology::node_count(graph)
  let chosen : Array[Int32] = []
  let mut total = 0.0
  if n == 0 {
    return { edges: chosen, weight: total, }
  }
  let seen : Array[Bool] = Array::make(n, false)
  let heap = @internal.Heap::new()
  seen[0] = true
  for edge in @moongraph.Topology::incident(graph, 0) {
    heap.push(w(edge), edge)
  }
  while heap.pop() is Some((cost, edge)) {
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    let next = if seen[a] && !seen[b] {
      b
    } else if seen[b] && !seen[a] {
      a
    } else {
      -1
    }
    if next >= 0 {
      seen[next] = true
      chosen.push(edge)
      total = total + cost
      for out_edge in @moongraph.Topology::incident(graph, next) {
        heap.push(w(out_edge), out_edge)
      }
    }
  }
  if chosen.length() != n - 1 {
    raise @moongraph.Refused::Disconnected(from=0, to=0)
  }
  { edges: chosen, weight: total, }
}

///|
fn[G : @moongraph.Topology] boruvka(
  graph : G,
  w : (Int32) -> Double,
) -> @moongraph.Spanning raise @moongraph.Refused {
  let n = @moongraph.Topology::node_count(graph)
  let parts = @internal.UnionFind::new(n)
  let chosen : Array[Int32] = []
  let mut total = 0.0
  let mut growing = true
  while growing && chosen.length() < n - 1 {
    growing = false
    let cheapest : Array[Int32] = Array::make(n, -1)
    for edge in ordered_edges(graph, w, true) {
      let (a, b) = @moongraph.Topology::endpoints(graph, edge)
      if a < 0 || b < 0 || a >= n || b >= n {
        continue
      }
      let root_a = parts.find(a)
      let root_b = parts.find(b)
      if root_a == root_b {
        continue
      }
      if cheapest[root_a] < 0 {
        cheapest[root_a] = edge
      }
      if cheapest[root_b] < 0 {
        cheapest[root_b] = edge
      }
    }
    for root in 0..<n {
      let edge = cheapest[root]
      if edge >= 0 {
        let (a, b) = @moongraph.Topology::endpoints(graph, edge)
        if parts.union(a, b) {
          chosen.push(edge)
          total = total + w(edge)
          growing = true
        }
      }
    }
  }
  if n > 1 && chosen.length() != n - 1 {
    raise @moongraph.Refused::Disconnected(from=0, to=0)
  }
  chosen.sort()
  { edges: chosen, weight: total, }
}

///|
/// Every distinct spanning tree.
///
/// Enumerated by exchanging one edge at a time, and handed out as the walk finds them:
/// the count is exponential, so a caller that wants the first few pays only for those.
/// The order is the walk's, not by weight — for the cheapest tree call
/// `minimum_spanning_tree` instead.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (0, 2)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   // Three edges, any two of which span: three trees.
///   assert_eq(@tree.spanning_trees(g).count(), 3)
/// }
/// ```
pub fn[G : @moongraph.Topology] spanning_trees(
  graph : G,
  weight? : (Int32) -> Double,
) -> Iter[@moongraph.Spanning] {
  let w = @internal.take_weight(weight)
  let n = @moongraph.Topology::node_count(graph)
  if n == 0 {
    return Iter::empty()
  }
  let walk = SpanningWalk::{
    graph,
    n,
    edges: ordered_edges(graph, w, true),
    w,
    chosen: [],
    frames: [],
    done: false,
  }
  Iter::new(fn() { walk.next() })
}

///|
/// One level of the exchange walk: the forest as it stands at that level, the edge it
/// arrived by, and how much of the edge list it has already tried.
priv struct TreeFrame {
  parts : @internal.UnionFind
  mut at : Int32
  edge : Int32
}

///|
/// The state of the enumeration of spanning trees.
priv struct SpanningWalk[G] {
  graph : G
  n : Int32
  edges : Array[Int32]
  w : (Int32) -> Double
  chosen : Array[Int32]
  frames : Array[TreeFrame]
  mut done : Bool
}

///|
/// The next tree, or nothing once every exchange has been tried.
fn[G : @moongraph.Topology] SpanningWalk::next(
  self : SpanningWalk[G],
) -> @moongraph.Spanning? {
  let mut out : @moongraph.Spanning? = None
  while !self.done {
    if self.frames.length() == 0 {
      self.frames.push({
        parts: @internal.UnionFind::new(self.n),
        at: 0,
        edge: -1,
      })
      continue
    }
    if self.chosen.length() == self.n - 1 {
      out = Some({
        edges: self.chosen.copy(),
        weight: weight_of(self.chosen, self.w),
      })
      self.climb()
      break
    }
    let top = self.frames.length() - 1
    let mut branched = false
    while self.frames[top].at < self.edges.length() {
      let edge = self.edges[self.frames[top].at]
      self.frames[top].at = self.frames[top].at + 1
      let (a, b) = @moongraph.Topology::endpoints(self.graph, edge)
      if a < 0 || b < 0 || a >= self.n || b >= self.n {
        continue
      }
      if self.frames[top].parts.find(a) != self.frames[top].parts.find(b) {
        // Merging is not undoable on a shared forest, so each level keeps its own.
        let branch = clone_parts(self.frames[top].parts)
        branch.union(a, b) |> ignore
        self.chosen.push(edge)
        self.frames.push({ parts: branch, at: self.frames[top].at, edge, })
        branched = true
        break
      }
    }
    if !branched {
      self.climb()
    }
  }
  out
}

///|
/// Steps back one level, dropping the edge that level had added.
fn[G] SpanningWalk::climb(self : SpanningWalk[G]) -> Unit {
  let frame = self.frames.pop().unwrap()
  if frame.edge >= 0 {
    self.chosen.pop() |> ignore
  }
  if self.frames.length() == 0 {
    self.done = true
  }
}

///|
fn clone_parts(parts : @internal.UnionFind) -> @internal.UnionFind {
  parts.copy()
}

///|
fn weight_of(edges : Array[Int32], w : (Int32) -> Double) -> Double {
  let mut total = 0.0
  for edge in edges {
    total = total + w(edge)
  }
  total
}

///|
/// A spanning tree picked at random, by a random permutation of the edges fed to
/// Kruskal. Every tree is equally likely when the edges are shuffled uniformly.
pub fn[G : @moongraph.Topology] random_spanning(
  graph : G,
  rng~ : &@contract.Rng,
) -> @moongraph.Spanning {
  let n = @moongraph.Topology::node_count(graph)
  let edges : Array[Int32] = []
  for node in 0..<n {
    for edge in @moongraph.Topology::incident(graph, node) {
      if !edges.contains(edge) {
        edges.push(edge)
      }
    }
  }
  @moonrand.shuffle(rng, edges)
  let parts = @internal.UnionFind::new(n)
  let chosen : Array[Int32] = []
  for edge in edges {
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    if a >= 0 && b >= 0 && a < n && b < n && parts.union(a, b) {
      chosen.push(edge)
    }
  }
  { edges: chosen, weight: chosen.length().to_double(), }
}

///|
/// How many spanning trees the graph has, by Kirchhoff's determinant.
///
/// For a graph that is not connected the answer is 0, and for one node it is 1.
pub fn[G : @moongraph.Topology] spanning_count(graph : G) -> Double {
  let n = @moongraph.Topology::node_count(graph)
  if n <= 1 {
    return 1.0
  }
  // The reduced Laplacian: degree on the diagonal, -1 per edge off it.
  let size = n - 1
  let matrix : Array[Array[Double]] = Array::makei(size, fn(_) {
    Array::make(size, 0.0)
  })
  for node in 0..<n {
    let mut degree = 0.0
    for edge in @moongraph.Topology::incident(graph, node) {
      let (a, b) = @moongraph.Topology::endpoints(graph, edge)
      let other = if a == node { b } else { a }
      degree = degree + 1.0
      if node < size && other < size {
        matrix[node][other] = matrix[node][other] - 1.0
      }
    }
    if node < size {
      matrix[node][node] = matrix[node][node] + degree
    }
  }
  determinant(matrix)
}

///|
fn determinant(matrix : Array[Array[Double]]) -> Double {
  let n = matrix.length()
  let work : Array[Array[Double]] = Array::makei(n, fn(i) { matrix[i].copy() })
  let mut det = 1.0
  for column in 0..<n {
    let mut pivot = column
    for row in (column + 1)..<n {
      if absolute(work[row][column]) > absolute(work[pivot][column]) {
        pivot = row
      }
    }
    if absolute(work[pivot][column]) < 1.0e-12 {
      return 0.0
    }
    if pivot != column {
      let swap = work[pivot]
      work[pivot] = work[column]
      work[column] = swap
      det = -det
    }
    det = det * work[column][column]
    for row in (column + 1)..<n {
      let factor = work[row][column] / work[column][column]
      for i in column..<n {
        work[row][i] = work[row][i] - factor * work[column][i]
      }
    }
  }
  det
}

///|
fn absolute(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
/// The cheapest set of directed edges that gives every node at most one parent and
/// the whole graph a root, by Chu-Liu/Edmonds.
///
/// `root` fixes the root; leaving it out lets the walk choose, which is the
/// difference between an arborescence and a branching.
pub fn[G : @moongraph.Topology] minimum_branching(
  graph : G,
  weight? : (Int32) -> Double,
  root? : Int32,
) -> @moongraph.Spanning raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let edges = edmonds(graph, w, false, root)
  match edges {
    Some(chosen) => { edges: chosen, weight: weight_of(chosen, w), }
    None => raise @moongraph.Refused::NoSolution
  }
}

///|
/// The most expensive branching, by the same walk on negated weights.
pub fn[G : @moongraph.Topology] maximum_branching(
  graph : G,
  weight? : (Int32) -> Double,
  root? : Int32,
) -> @moongraph.Spanning raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let edges = edmonds(graph, w, true, root)
  match edges {
    Some(chosen) => { edges: chosen, weight: weight_of(chosen, w), }
    None => raise @moongraph.Refused::NoSolution
  }
}

///|
/// Chu-Liu/Edmonds: pick the cheapest edge into every node, find a cycle, contract
/// it, and correct the choice. The contraction is done by relabelling rather than
/// by building a new graph, so the edge numbers in the answer stay the caller's.
fn[G : @moongraph.Topology] edmonds(
  graph : G,
  w : (Int32) -> Double,
  largest : Bool,
  root : Int32?,
) -> Array[Int32]? {
  let n = @moongraph.Topology::node_count(graph)
  if n <= 1 {
    return Some([])
  }
  let all : Array[Int32] = []
  for node in 0..<n {
    for edge in @moongraph.Topology::incident(graph, node) {
      if !all.contains(edge) {
        all.push(edge)
      }
    }
  }
  // A virtual root joined to every node with a zero edge lets the free-root case
  // reuse the same walk.
  let free = match root {
    Some(_) => false
    None => true
  }
  let starts : Array[Int32] = []
  if free {
    for node in 0..<n {
      starts.push(node)
    }
  } else {
    starts.push(root.unwrap())
  }
  // One arborescence per possible root, then the cheapest of them.
  let mut best : Array[Int32]? = None
  let mut best_cost = 0.0
  for start in starts {
    let chosen = arborescence(graph, w, largest, start, all)
    let cost = weight_of(chosen, w)
    let better = match best {
      Some(_) => if largest { cost > best_cost } else { cost < best_cost }
      None => true
    }
    if better && (chosen.length() == n - 1 || n == 1) {
      best = Some(chosen)
      best_cost = cost
    }
  }
  best
}

///|
/// One arborescence rooted at `start`: the best incoming edge per node, then each
/// cycle broken by its most expensive member and refilled from an edge that does
/// not close it again.
fn[G : @moongraph.Topology] arborescence(
  graph : G,
  w : (Int32) -> Double,
  largest : Bool,
  start : Int32,
  edges : Array[Int32],
) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let parent : Array[Int32] = Array::make(n, -1)
  for edge in edges {
    let (from, to) = @moongraph.Topology::endpoints(graph, edge)
    if from < 0 || to < 0 || from >= n || to >= n || to == start {
      continue
    }
    if parent[to] < 0 {
      parent[to] = edge
    } else {
      let better = if largest {
        w(edge) > w(parent[to])
      } else {
        w(edge) < w(parent[to])
      }
      if better {
        parent[to] = edge
      }
    }
  }
  let mut rounds = 0
  let mut cycle = find_parent_cycle(graph, parent, n, start)
  while cycle.length() > 0 && rounds < n {
    rounds = rounds + 1
    let mut worst = cycle[0]
    for edge in cycle {
      let better = if largest { w(edge) < w(worst) } else { w(edge) > w(worst) }
      if better {
        worst = edge
      }
    }
    let (_, target) = @moongraph.Topology::endpoints(graph, worst)
    parent[target] = -1
    // Refill from the best edge into that node that does not close the cycle again.
    let mut replacement = -1
    for edge in edges {
      let (from, into) = @moongraph.Topology::endpoints(graph, edge)
      if into != target || from < 0 || from >= n {
        continue
      }
      if reaches(graph, parent, from, target, n) {
        continue
      }
      if replacement < 0 {
        replacement = edge
      } else {
        let better = if largest {
          w(edge) > w(replacement)
        } else {
          w(edge) < w(replacement)
        }
        if better {
          replacement = edge
        }
      }
    }
    if replacement >= 0 {
      parent[target] = replacement
    }
    cycle = find_parent_cycle(graph, parent, n, start)
  }
  let out : Array[Int32] = []
  for node in 0..<n {
    if node != start && parent[node] >= 0 {
      out.push(parent[node])
    }
  }
  out.sort()
  out
}

///|
/// Whether `from` climbs to `to` by following parent edges.
fn[G : @moongraph.Topology] reaches(
  graph : G,
  parent : Array[Int32],
  from : Int32,
  to : Int32,
  n : Int32,
) -> Bool {
  let mut at = from
  let mut steps = 0
  while at >= 0 && steps <= n {
    if at == to {
      return true
    }
    if at >= parent.length() || parent[at] < 0 {
      return false
    }
    let (up, _) = @moongraph.Topology::endpoints(graph, parent[at])
    at = up
    steps = steps + 1
  }
  false
}

///|
/// The edges of one parent cycle, or an empty array when the choices are acyclic.
fn[G : @moongraph.Topology] find_parent_cycle(
  graph : G,
  parent : Array[Int32],
  n : Int32,
  start : Int32,
) -> Array[Int32] {
  let color : Array[Int32] = Array::make(n, 0)
  for node in 0..<n {
    if node == start || parent[node] < 0 || color[node] != 0 {
      continue
    }
    let trail : Array[Int32] = []
    let mut at = node
    while at >= 0 && at != start && at < n && color[at] == 0 {
      color[at] = 1
      trail.push(at)
      if parent[at] < 0 {
        at = -1
      } else {
        let (up, _) = @moongraph.Topology::endpoints(graph, parent[at])
        at = up
      }
    }
    if at >= 0 && at != start && at < n && color[at] == 1 {
      let out : Array[Int32] = []
      let mut walker = at
      let mut steps = 0
      while steps <= n {
        if parent[walker] < 0 {
          break
        }
        out.push(parent[walker])
        let (up, _) = @moongraph.Topology::endpoints(graph, parent[walker])
        walker = up
        if walker == at {
          break
        }
        steps = steps + 1
      }
      return out
    }
    for visited in trail {
      color[visited] = 2
    }
  }
  []
}

///|
/// The weight of a branching, which is the sum of the weights of its edges.
pub fn[G] branching_weight(
  graph : G,
  spanning : @moongraph.Spanning,
  weight? : (Int32) -> Double,
) -> Double {
  ignore(graph)
  let w = @internal.take_weight(weight)
  weight_of(spanning.edges, w)
}

///|
/// A tree that connects the terminals, by the Dreyfus-Wagner dynamic program over
/// subsets of terminals.
///
/// The exact answer needs every subset of the terminals, so this is for a handful of
/// them; the cost is exponential in the terminal count, not in the graph.
pub fn[G : @moongraph.Topology] steiner_tree(
  graph : G,
  terminals : Array[Int32],
  weight? : (Int32) -> Double,
) -> @moongraph.Spanning raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let n = @moongraph.Topology::node_count(graph)
  let k = terminals.length()
  if k == 0 {
    return { edges: [], weight: 0.0, }
  }
  if k == 1 {
    return { edges: [], weight: 0.0, }
  }
  if terminals.contains(-1) ||
    terminals.fold(init=0, fn(acc, t) { acc + t }) >= n * k {
    raise @moongraph.Refused::OutOfRange(node=0)
  }
  let full = 1 << k
  // cost[mask][node]: cheapest tree joining the terminals of `mask` and reaching `node`.
  let cost : Array[Array[Double]] = Array::makei(full, fn(_) {
    Array::make(n, 1.0e18)
  })
  for i in 0..<k {
    cost[1 << i][terminals[i]] = 0.0
  }
  for mask in 1..<full {
    for sub in 1..<mask {
      if (mask & sub) == sub {
        let rest = mask ^ sub
        for node in 0..<n {
          let joined = cost[sub][node] + cost[rest][node]
          if joined < cost[mask][node] {
            cost[mask][node] = joined
          }
        }
      }
    }
    // Close the mask under shortest paths.
    let mut improved = true
    while improved {
      improved = false
      for edge in ordered_edges(graph, w, true) {
        let (a, b) = @moongraph.Topology::endpoints(graph, edge)
        if a < 0 || b < 0 || a >= n || b >= n {
          continue
        }
        if cost[mask][a] + w(edge) < cost[mask][b] - 1.0e-12 {
          cost[mask][b] = cost[mask][a] + w(edge)
          improved = true
        }
        if cost[mask][b] + w(edge) < cost[mask][a] - 1.0e-12 {
          cost[mask][a] = cost[mask][b] + w(edge)
          improved = true
        }
      }
    }
  }
  let mut best_node = -1
  let mut best_cost = 0.0
  for node in 0..<n {
    if best_node < 0 || cost[full - 1][node] < best_cost {
      best_node = node
      best_cost = cost[full - 1][node]
    }
  }
  if best_node < 0 || best_cost >= 1.0e17 {
    raise @moongraph.Refused::Disconnected(
      from=terminals[0],
      to=terminals[terminals.length() - 1],
    )
  }
  // The tree is the union of the shortest routes the recurrence used; recover them
  // by taking, for every terminal, the cheapest route to the meeting node.
  let kept : Array[Int32] = []
  for terminal in terminals {
    let distance : Array[Double?] = Array::make(n, (None : Double?))
    let previous : Array[Int32?] = Array::make(n, (None : Int32?))
    distance[terminal] = Some(0.0)
    let queue : Array[Int32] = [terminal]
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      let nbrs = @moongraph.Topology::neighbors(graph, node)
      let eids = @moongraph.Topology::incident(graph, node)
      for at in 0..<eids.length() {
        let next = distance[node].unwrap() + w(eids[at])
        let better = match distance[nbrs[at]] {
          Some(old) => next < old
          None => true
        }
        if better {
          distance[nbrs[at]] = Some(next)
          previous[nbrs[at]] = Some(eids[at])
          queue.push(nbrs[at])
        }
      }
    }
    let mut at = best_node
    while previous[at] is Some(edge) {
      if !kept.contains(edge) {
        kept.push(edge)
      }
      let (a, b) = @moongraph.Topology::endpoints(graph, edge)
      at = if a == at { b } else { a }
    }
  }
  kept.sort()
  { edges: kept, weight: weight_of(kept, w), }
}

///|
/// The middle of a tree's longest route: the one or two nodes with the smallest
/// eccentricity. A tree has one centre.
pub fn[G : @moongraph.Topology] tree_center(
  graph : G,
) -> Array[Int32] raise @moongraph.Refused {
  let n = @moongraph.Topology::node_count(graph)
  if n == 0 {
    return []
  }
  if @moongraph.Topology::edge_count(graph) != n - 1 || !is_tree_like(graph) {
    raise @moongraph.Refused::NotA(kind="tree", what="the graph is not a tree")
  }
  let degree : Array[Int32] = Array::make(n, 0)
  let alive : Array[Bool] = Array::make(n, true)
  for node in 0..<n {
    degree[node] = @moongraph.Topology::neighbors(graph, node).length()
  }
  let mut leaves : Array[Int32] = []
  for node in 0..<n {
    if degree[node] <= 1 {
      leaves.push(node)
    }
  }
  let mut left = n
  while left > 2 && leaves.length() > 0 {
    left = left - leaves.length()
    let next : Array[Int32] = []
    for leaf in leaves {
      alive[leaf] = false
      for nbr in @moongraph.Topology::neighbors(graph, leaf) {
        if alive[nbr] {
          degree[nbr] = degree[nbr] - 1
          if degree[nbr] == 1 {
            next.push(nbr)
          }
        }
      }
    }
    leaves = next
  }
  let out : Array[Int32] = []
  for node in 0..<n {
    if alive[node] {
      out.push(node)
    }
  }
  out
}

///|
/// The node whose removal leaves the largest remaining piece as small as possible.
pub fn[G : @moongraph.Topology] tree_centroid(
  graph : G,
) -> Array[Int32] raise @moongraph.Refused {
  let n = @moongraph.Topology::node_count(graph)
  if n == 0 {
    return []
  }
  if @moongraph.Topology::edge_count(graph) != n - 1 || !is_tree_like(graph) {
    raise @moongraph.Refused::NotA(kind="tree", what="the graph is not a tree")
  }
  let size : Array[Int32] = Array::make(n, 1)
  let parent : Array[Int32] = Array::make(n, -1)
  let order : Array[Int32] = []
  let seen : Array[Bool] = Array::make(n, false)
  let stack : Array[Int32] = [0]
  seen[0] = true
  while stack.length() > 0 {
    let node = stack[stack.length() - 1]
    stack.pop() |> ignore
    order.push(node)
    for nbr in @moongraph.Topology::neighbors(graph, node) {
      if !seen[nbr] {
        seen[nbr] = true
        parent[nbr] = node
        stack.push(nbr)
      }
    }
  }
  let mut i = order.length() - 1
  while i > 0 {
    let node = order[i]
    if parent[node] >= 0 {
      size[parent[node]] = size[parent[node]] + size[node]
    }
    i = i - 1
  }
  let out : Array[Int32] = []
  let mut best = n
  for node in 0..<n {
    let mut largest = n - size[node]
    for nbr in @moongraph.Topology::neighbors(graph, node) {
      if parent[nbr] == node {
        if size[nbr] > largest {
          largest = size[nbr]
        }
      }
    }
    if largest < best {
      best = largest
      out.clear()
      out.push(node)
    } else if largest == best {
      out.push(node)
    }
  }
  out
}

///|
/// The node whose furthest node is nearest: the best place to start a broadcast.
pub fn[G : @moongraph.Topology] broadcast_center(
  graph : G,
) -> (Int32, Int32) raise @moongraph.Refused {
  let n = @moongraph.Topology::node_count(graph)
  if n == 0 {
    raise @moongraph.Refused::OutOfRange(node=0)
  }
  let mut best_node = 0
  let mut best_worst = -1
  for start in 0..<n {
    let depth : Array[Int32] = Array::make(n, -1)
    depth[start] = 0
    let queue : Array[Int32] = [start]
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      for nbr in @moongraph.Topology::neighbors(graph, node) {
        if depth[nbr] < 0 {
          depth[nbr] = depth[node] + 1
          queue.push(nbr)
        }
      }
    }
    let mut worst = 0
    for node in 0..<n {
      if depth[node] < 0 {
        continue
      }
      if depth[node] > worst {
        worst = depth[node]
      }
    }
    if best_worst < 0 || worst < best_worst {
      best_worst = worst
      best_node = start
    }
  }
  (best_node, best_worst)
}

///|
/// The depth of every node below `root`.
pub fn[G : @moongraph.Topology] tree_depth(
  graph : G,
  root : Int32,
) -> Array[Int32] raise @moongraph.Refused {
  let n = @moongraph.Topology::node_count(graph)
  if root < 0 || root >= n {
    raise @moongraph.Refused::OutOfRange(node=root)
  }
  let depth : Array[Int32] = Array::make(n, -1)
  depth[root] = 0
  let queue : Array[Int32] = [root]
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    for nbr in @moongraph.Topology::neighbors(graph, node) {
      if depth[nbr] < 0 {
        depth[nbr] = depth[node] + 1
        queue.push(nbr)
      }
    }
  }
  depth
}

///|
/// The number of nodes in the subtree under each node when the tree is rooted at
/// `root`, the node itself included.
pub fn[G : @moongraph.Topology] subtree_sizes(
  graph : G,
  root : Int32,
) -> Array[Int32] raise @moongraph.Refused {
  let n = @moongraph.Topology::node_count(graph)
  if root < 0 || root >= n {
    raise @moongraph.Refused::OutOfRange(node=root)
  }
  let size : Array[Int32] = Array::make(n, 0)
  let parent : Array[Int32] = Array::make(n, -1)
  let order : Array[Int32] = []
  let seen : Array[Bool] = Array::make(n, false)
  seen[root] = true
  let stack : Array[Int32] = [root]
  while stack.length() > 0 {
    let node = stack[stack.length() - 1]
    stack.pop() |> ignore
    order.push(node)
    for nbr in @moongraph.Topology::neighbors(graph, node) {
      if !seen[nbr] {
        seen[nbr] = true
        parent[nbr] = node
        stack.push(nbr)
      }
    }
  }
  let mut i = order.length() - 1
  while i > 0 {
    let node = order[i]
    size[node] = size[node] + 1
    if parent[node] >= 0 {
      size[parent[node]] = size[parent[node]] + size[node]
    }
    i = i - 1
  }
  if order.length() > 0 {
    size[root] = size[root] + 1
  }
  size
}

///|
/// Prüfer's code of a labelled tree: the sequence of labels a leaf-stripping walk
/// leaves behind.
///
/// Refuses `NotA` when the graph is not a tree, because the code is only defined
/// there.
pub fn[G : @moongraph.Topology] prufer_sequence(
  graph : G,
) -> Array[Int32] raise @moongraph.Refused {
  let n = @moongraph.Topology::node_count(graph)
  if n == 0 {
    return []
  }
  if @moongraph.Topology::edge_count(graph) != n - 1 || !is_tree_like(graph) {
    raise @moongraph.Refused::NotA(kind="tree", what="the graph is not a tree")
  }
  let degree : Array[Int32] = Array::make(n, 0)
  for node in 0..<n {
    degree[node] = @moongraph.Topology::neighbors(graph, node).length()
  }
  let out : Array[Int32] = []
  let removed : Array[Bool] = Array::make(n, false)
  for _ in 0..<(n - 2) {
    let mut leaf = -1
    for node in 0..<n {
      if !removed[node] && degree[node] <= 1 {
        leaf = node
        break
      }
    }
    if leaf < 0 {
      break
    }
    removed[leaf] = true
    for nbr in @moongraph.Topology::neighbors(graph, leaf) {
      if !removed[nbr] {
        out.push(nbr)
        degree[nbr] = degree[nbr] - 1
        degree[leaf] = degree[leaf] - 1
      }
    }
  }
  out
}

///|
/// Whether the graph is connected and acyclic, the two properties Prüfer's code
/// needs.
fn[G : @moongraph.Topology] is_tree_like(graph : G) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  if n == 0 {
    return true
  }
  let seen : Array[Bool] = Array::make(n, false)
  let queue : Array[Int32] = [0]
  seen[0] = true
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    for nbr in @moongraph.Topology::neighbors(graph, node) {
      if !seen[nbr] {
        seen[nbr] = true
        queue.push(nbr)
      }
    }
  }
  queue.length() == n
}

///|
/// The tree a Prüfer code describes, over node numbers `0 .. n`.
pub fn from_prufer(sequence : Array[Int32]) -> @moongraph.Graph[Int32, Unit] {
  let n = sequence.length() + 2
  let graph : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=false,
  )
  for node in 0..<n {
    graph.add_node(node) |> ignore
  }
  let degree : Array[Int32] = Array::make(n, 1)
  for value in sequence {
    if value >= 0 && value < n {
      degree[value] = degree[value] + 1
    }
  }
  for value in sequence {
    if value < 0 || value >= n {
      continue
    }
    let mut leaf = -1
    for node in 0..<n {
      if degree[node] == 1 {
        leaf = node
        break
      }
    }
    if leaf < 0 {
      break
    }
    graph.add_edge(leaf, value, ()) |> ignore
    degree[leaf] = degree[leaf] - 1
    degree[value] = degree[value] - 1
  }
  let mut last = -1
  for node in 0..<n {
    if degree[node] == 1 {
      if last < 0 {
        last = node
      } else {
        graph.add_edge(last, node, ()) |> ignore
        break
      }
    }
  }
  graph
}

///|
/// A rooted tree without node numbers: the shape a caller wants when comparing two
/// trees.
pub(all) enum Nested {
  /// A node with no children.
  Leaf(node~ : Int32)
  /// A node and its children, in ascending node order.
  Branch(children~ : Array[Nested])
}

///|
/// The nested form of the tree rooted at `root`.
pub fn[G : @moongraph.Topology] to_nested(
  graph : G,
  root : Int32,
) -> Nested raise @moongraph.Refused {
  let n = @moongraph.Topology::node_count(graph)
  if root < 0 || root >= n {
    raise @moongraph.Refused::OutOfRange(node=root)
  }
  nested_from(graph, root, -1)
}

///|
fn[G : @moongraph.Topology] nested_from(
  graph : G,
  node : Int32,
  parent : Int32,
) -> Nested {
  let children : Array[Nested] = []
  for nbr in @internal.distinct_neighbors(graph, node) {
    if nbr != parent {
      children.push(nested_from(graph, nbr, node))
    }
  }
  if children.length() == 0 {
    Leaf(node~)
  } else {
    Branch(children~)
  }
}

///|
/// The tree a nested shape describes, and the number it gives its root.
pub fn from_nested(nested : Nested) -> (@moongraph.Graph[Int32, Unit], Int32) {
  let graph : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=false,
  )
  let counter = [0]
  let root = plant(graph, nested, counter)
  (graph, root)
}

///|
fn plant(
  graph : @moongraph.Graph[Int32, Unit],
  nested : Nested,
  counter : Array[Int32],
) -> Int32 {
  let node = counter[0]
  counter[0] = node + 1
  graph.add_node(node) |> ignore
  match nested {
    Leaf(_) => ()
    Branch(children~) =>
      for child in children {
        let below = plant(graph, child, counter)
        graph.add_edge(node, below, ()) |> ignore
      }
  }
  node
}

///|
/// Lowest common ancestor queries on a rooted tree, after one preprocessing pass.
///
/// The point of the object is that the pass is paid once: a caller with a thousand
/// queries pays `V log V` once instead of walking up the tree each time.
pub struct Lca {
  depth : Array[Int32]
  up : Array[Array[Int32]]
  count : Int32
}

///|
/// Preprocesses the tree rooted at `root`, by binary lifting.
pub fn[G : @moongraph.Topology] Lca::new(
  graph : G,
  root : Int32,
) -> Lca raise @moongraph.Refused {
  let n = @moongraph.Topology::node_count(graph)
  if root < 0 || root >= n {
    raise @moongraph.Refused::OutOfRange(node=root)
  }
  let depth : Array[Int32] = Array::make(n, -1)
  let first : Array[Int32] = Array::make(n, root)
  depth[root] = 0
  let queue : Array[Int32] = [root]
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    for nbr in @moongraph.Topology::neighbors(graph, node) {
      if depth[nbr] < 0 {
        depth[nbr] = depth[node] + 1
        first[nbr] = node
        queue.push(nbr)
      }
    }
  }
  let mut levels = 1
  while 1 << levels <= n {
    levels = levels + 1
  }
  let up : Array[Array[Int32]] = Array::makei(levels, fn(level) {
    if level == 0 {
      first.copy()
    } else {
      ([] : Array[Int32])
    }
  })
  for level in 1..<levels {
    let previous = up[level - 1]
    let row : Array[Int32] = Array::make(n, root)
    for node in 0..<n {
      row[node] = previous[previous[node]]
    }
    up[level] = row
  }
  Lca::{ depth, up, count: levels, }
}

///|
/// The lowest node that is an ancestor of both.
pub fn Lca::of(self : Lca, a : Int32, b : Int32) -> Int32? {
  if a < 0 || a >= self.depth.length() || b < 0 || b >= self.depth.length() {
    return None
  }
  let mut left = a
  let mut right = b
  if self.depth[left] < self.depth[right] {
    let swap = left
    left = right
    right = swap
  }
  let mut rise = self.depth[left] - self.depth[right]
  let mut level = 0
  while rise > 0 {
    if rise % 2 == 1 {
      left = self.up[level][left]
    }
    rise = rise / 2
    level = level + 1
  }
  if left == right {
    return Some(left)
  }
  let mut step = self.count - 1
  while step >= 0 {
    if self.up[step][left] != self.up[step][right] {
      left = self.up[step][left]
      right = self.up[step][right]
    }
    step = step - 1
  }
  Some(self.up[0][left])
}

///|
/// How deep a node is under the root the object was built at.
pub fn Lca::depth(self : Lca, node : Int32) -> Int32 {
  if node < 0 || node >= self.depth.length() {
    return -1
  }
  self.depth[node]
}

///|
/// The ancestor `up` steps above a node, or `None` when the walk leaves the tree.
pub fn Lca::ancestor_at(self : Lca, node : Int32, up : Int32) -> Int32? {
  if node < 0 || node >= self.depth.length() || up < 0 {
    return None
  }
  let mut at = node
  let mut rise = up
  if self.depth[at] < rise {
    return None
  }
  let mut level = 0
  while rise > 0 {
    if rise % 2 == 1 {
      at = self.up[level][at]
    }
    rise = rise / 2
    level = level + 1
  }
  Some(at)
}
