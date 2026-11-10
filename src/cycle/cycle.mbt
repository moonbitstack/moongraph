// Cycles and Euler walks.
//
// A cycle here is a node sequence whose first and last node are the same. Every
// function that reports one starts it at its smallest node number and walks it in
// ascending neighbour order, so the same graph always gives the same sequence.

///|
/// Whether the graph has a cycle. A self-loop counts.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   assert_false(@cycle.is_cyclic(g))
///   g.add_edge(2, 0, ()) |> ignore
///   assert_true(@cycle.is_cyclic(g))
/// }
/// ```
pub fn[G : @moongraph.Topology] is_cyclic(graph : G) -> Bool {
  match find_cycle(graph) {
    Some(_) => true
    None => false
  }
}

///|
/// One cycle, as node numbers, first and last equal; `None` when the graph is
/// acyclic.
///
/// For an undirected graph a single edge is not a cycle: two nodes joined by one
/// edge give `None`, while a self-loop does not.
pub fn[G : @moongraph.Topology] find_cycle(graph : G) -> Array[Int32]? {
  let n = @moongraph.Topology::node_count(graph)
  // Colours: 0 unseen, 1 on the walk, 2 finished.
  let state : Array[Int32] = Array::make(n, 0)
  let parent : Array[Int32] = Array::make(n, -1)
  let parent_edge : Array[Int32] = Array::make(n, -1)
  for start in 0..<n {
    if state[start] != 0 {
      continue
    }
    let frames : Array[(Int32, Int32)] = [(start, 0)]
    state[start] = 1
    while frames.length() > 0 {
      let top = frames.length() - 1
      let (node, at) = frames[top]
      let nbrs = @moongraph.Topology::neighbors(graph, node)
      let eids = @moongraph.Topology::incident(graph, node)
      if at < eids.length() {
        frames[top] = (node, at + 1)
        let edge = eids[at]
        let nbr = nbrs[at]
        if edge == parent_edge[node] {
          continue
        }
        if state[nbr] == 0 {
          state[nbr] = 1
          parent[nbr] = node
          parent_edge[nbr] = edge
          frames.push((nbr, 0))
        } else if state[nbr] == 1 {
          // A self-loop is a cycle of one node, written as n, n.
          if nbr == node {
            return Some([node, node])
          }
          // Walk the parent chain back from `node` to `nbr` and close it.
          let out : Array[Int32] = [node]
          let mut at_node = node
          while at_node != nbr && parent[at_node] >= 0 {
            at_node = parent[at_node]
            out.push(at_node)
          }
          out.push(node)
          return Some(out)
        }
      } else {
        state[node] = 2
        frames.pop() |> ignore
      }
    }
  }
  None
}

///|
/// A basis of the cycle space: one fundamental cycle per edge that is not a bridge,
/// enough of them to generate every cycle by symmetric difference.
///
/// The count is `E - V + C`, which is the cycle rank of the graph.
pub fn[G : @moongraph.Topology] cycle_basis(graph : G) -> Array[Array[Int32]] {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Array[Int32]] = []
  let state : Array[Int32] = Array::make(n, 0)
  let parent : Array[Int32] = Array::make(n, -1)
  let parent_edge : Array[Int32] = Array::make(n, -1)
  let depth : Array[Int32] = Array::make(n, 0)
  for start in 0..<n {
    if state[start] != 0 {
      continue
    }
    let frames : Array[(Int32, Int32)] = [(start, 0)]
    state[start] = 1
    while frames.length() > 0 {
      let top = frames.length() - 1
      let (node, at) = frames[top]
      let nbrs = @moongraph.Topology::neighbors(graph, node)
      let eids = @moongraph.Topology::incident(graph, node)
      if at < eids.length() {
        frames[top] = (node, at + 1)
        let edge = eids[at]
        let nbr = nbrs[at]
        if edge == parent_edge[node] {
          continue
        }
        if state[nbr] == 0 {
          state[nbr] = 1
          parent[nbr] = node
          parent_edge[nbr] = edge
          depth[nbr] = depth[node] + 1
          frames.push((nbr, 0))
        } else if state[nbr] == 1 || (state[nbr] == 2 && nbr != node) {
          // A back edge, or an edge to a finished node met from the other side:
          // take the tree path between the two and close it.
          if depth[nbr] < depth[node] {
            let cycle : Array[Int32] = [node]
            let mut walker = node
            while walker != nbr {
              walker = parent[walker]
              if walker < 0 {
                break
              }
              cycle.push(walker)
            }
            cycle.push(node)
            if cycle.length() > 2 || nbr == node {
              out.push(cycle)
            }
          }
        }
      } else {
        state[node] = 2
        frames.pop() |> ignore
      }
    }
  }
  out
}

///|
/// A cycle basis of total length as small as possible.
///
/// Every cycle through a node comes from two shortest routes out of it, so the
/// candidates are generated per node and the shortest independent ones are taken.
pub fn[G : @moongraph.Topology] minimum_cycle_basis(
  graph : G,
  weight? : (Int32) -> Double,
) -> Array[Array[Int32]] {
  let w = @internal.take_weight(weight)
  let n = @moongraph.Topology::node_count(graph)
  let candidates : Array[Array[Int32]] = []
  let lengths : Array[Double] = []
  for root in 0..<n {
    // A shortest-path tree out of the root, then one cycle per non-tree edge.
    let distance : Array[Double?] = Array::make(n, (None : Double?))
    let parent : Array[Int32] = Array::make(n, -1)
    let parent_edge : Array[Int32] = Array::make(n, -1)
    distance[root] = Some(0.0)
    let queue : Array[Int32] = [root]
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
          parent[nbrs[at]] = node
          parent_edge[nbrs[at]] = eids[at]
          queue.push(nbrs[at])
        }
      }
    }
    for node in 0..<n {
      let nbrs = @moongraph.Topology::neighbors(graph, node)
      let eids = @moongraph.Topology::incident(graph, node)
      for at in 0..<eids.length() {
        let nbr = nbrs[at]
        if eids[at] == parent_edge[node] || eids[at] == parent_edge[nbr] {
          continue
        }
        if node > nbr || distance[node] is None || distance[nbr] is None {
          continue
        }
        // Close the two tree paths through the root.
        let left : Array[Int32] = [node]
        let mut walker = node
        while walker != root && parent[walker] >= 0 {
          walker = parent[walker]
          left.push(walker)
        }
        let right : Array[Int32] = []
        let mut other = nbr
        while other != root && parent[other] >= 0 {
          right.push(other)
          other = parent[other]
        }
        if walker != root || other != root {
          continue
        }
        for i in 0..<right.length() {
          left.push(right[right.length() - 1 - i])
        }
        if left.length() > 1 {
          left.push(node)
          candidates.push(left)
          lengths.push(
            distance[node].unwrap() + distance[nbr].unwrap() + w(eids[at]),
          )
        }
      }
    }
  }
  // Take candidates shortest first, keeping only those that add a new dimension.
  let order : Array[Int32] = Array::makei(candidates.length(), fn(i) { i })
  order.sort_by(fn(a, b) {
    if lengths[a] < lengths[b] {
      -1
    } else if lengths[a] > lengths[b] {
      1
    } else {
      a - b
    }
  })
  let rank = cycle_rank(graph)
  let chosen : Array[Array[Int32]] = []
  let basis : Array[Array[Bool]] = []
  for index in order {
    if chosen.length() >= rank {
      break
    }
    let vector = cycle_vector(graph, candidates[index])
    let reduced = reduce(vector, basis)
    if reduced.length() > 0 {
      basis.push(reduced)
      chosen.push(candidates[index])
    }
  }
  chosen
}

///|
/// How many independent cycles the graph has.
fn[G : @moongraph.Topology] cycle_rank(graph : G) -> Int32 {
  let components = count_components(graph)
  let rank = @moongraph.Topology::edge_count(graph) -
    @moongraph.Topology::node_count(graph) +
    components
  if rank > 0 {
    rank
  } else {
    0
  }
}

///|
/// How many pieces the graph has, counting a directed edge as a join in both
/// directions: the number of pieces is a property of the edge set, and a closed walk
/// that used every edge would have to cross each of them.
fn[G : @moongraph.Topology] count_components(graph : G) -> Int32 {
  let n = @moongraph.Topology::node_count(graph)
  // The joins are read from the edge ends rather than from `neighbors`, which follows
  // the arcs of a directed graph one way only and would count its reachability order.
  let links : Array[Array[Int32]] = Array::makei(n, fn(_) {
    ([] : Array[Int32])
  })
  for edge in 0..<@moongraph.Topology::edge_count(graph) {
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    if a >= 0 && a < n && b >= 0 && b < n {
      links[a].push(b)
      if a != b {
        links[b].push(a)
      }
    }
  }
  let seen : Array[Bool] = Array::make(n, false)
  let mut count = 0
  for start in 0..<n {
    if !seen[start] {
      count = count + 1
      let queue : Array[Int32] = [start]
      seen[start] = true
      let mut head = 0
      while head < queue.length() {
        let node = queue[head]
        head = head + 1
        for nbr in links[node] {
          if !seen[nbr] {
            seen[nbr] = true
            queue.push(nbr)
          }
        }
      }
    }
  }
  count
}

///|
/// A cycle as a bit vector over edge numbers.
fn[G : @moongraph.Topology] cycle_vector(
  graph : G,
  cycle : Array[Int32],
) -> Array[Bool] {
  let vector : Array[Bool] = Array::make(
    @moongraph.Topology::edge_count(graph),
    false,
  )
  for i in 1..<cycle.length() {
    for at in 0..<@moongraph.Topology::incident(graph, cycle[i - 1]).length() {
      let edge = @moongraph.Topology::incident(graph, cycle[i - 1])[at]
      if @moongraph.Topology::neighbors(graph, cycle[i - 1])[at] == cycle[i] &&
        !vector[edge] {
        vector[edge] = true
        break
      }
    }
  }
  vector
}

///|
/// Reduces a vector against a basis in row echelon form, adding it to the basis
/// when it is independent.
fn reduce(vector : Array[Bool], basis : Array[Array[Bool]]) -> Array[Bool] {
  let out = vector.copy()
  for row in basis {
    let mut pivot = -1
    for i in 0..<row.length() {
      if row[i] {
        pivot = i
        break
      }
    }
    if pivot >= 0 && out[pivot] {
      for i in 0..<out.length() {
        if row[i] {
          out[i] = !out[i]
        }
      }
    }
  }
  out
}

///|
/// Every simple cycle, each reported once.
///
/// Johnson's walk with the blocking that keeps it from re-walking dead ends, written as
/// a machine that holds its place: a caller that stops after ten cycles never pays for
/// the rest. An undirected cycle and its reverse are the same cycle, and only one of
/// them is reported.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (2, 0)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   assert_eq(@cycle.simple_cycles(g).collect(), [[0, 1, 2, 0]])
/// }
/// ```
pub fn[G : @moongraph.Topology] simple_cycles(graph : G) -> Iter[Array[Int32]] {
  let n = @moongraph.Topology::node_count(graph)
  let walk = CycleWalk::{
    graph,
    total: n,
    round: 0,
    next: 0,
    frames: [],
    path: [],
    blocked: Array::make(n, false),
    blocked_by: Array::makei(n, fn(_) { ([] : Array[Int32]) }),
    seen: [],
  }
  Iter::new(fn() { walk.next() })
}

///|
/// One node of the walk: which node it is, which neighbours it still has to try, and
/// whether anything was found below it.
priv struct CycleFrame {
  node : Int32
  around : Array[Int32]
  mut at : Int32
  mut found : Bool
}

///|
/// The state of the enumeration of simple cycles.
///
/// `start` is the node the current round looks for cycles through, and every cycle is
/// only looked for at its smallest node, which is what makes the rounds disjoint.
priv struct CycleWalk[G] {
  graph : G
  total : Int32
  mut round : Int32
  mut next : Int32
  frames : Array[CycleFrame]
  path : Array[Int32]
  blocked : Array[Bool]
  blocked_by : Array[Array[Int32]]
  seen : Array[String]
}

///|
/// The next cycle, or nothing once every node has had its round.
fn[G : @moongraph.Topology] CycleWalk::next(
  self : CycleWalk[G],
) -> Array[Int32]? {
  let mut out : Array[Int32]? = None
  while true {
    if self.frames.length() == 0 {
      if self.next >= self.total {
        break
      }
      self.round = self.next
      self.next = self.next + 1
      // The blocking is bookkeeping for one round only: a node that was a dead end
      // under one starting node says nothing about the next.
      for node in 0..<self.total {
        self.blocked[node] = false
        self.blocked_by[node] = ([] : Array[Int32])
      }
      self.enter(self.round)
      continue
    }
    let top = self.frames.length() - 1
    if self.frames[top].at >= self.frames[top].around.length() {
      self.leave()
      continue
    }
    let other = self.frames[top].around[self.frames[top].at]
    self.frames[top].at = self.frames[top].at + 1
    if other < self.round {
      continue
    }
    if other == self.round {
      // One edge walked there and back is not a cycle: in an undirected graph the
      // walk would otherwise report every edge as a two-node cycle.
      if self.path.length() == 2 && !@moongraph.Topology::directed(self.graph) {
        continue
      }
      let cycle = self.path.copy()
      cycle.push(self.round)
      self.frames[top].found = true
      let key = canonical_cycle(self.graph, cycle)
      if !self.seen.contains(key) {
        self.seen.push(key)
        out = Some(cycle)
        break
      }
      continue
    }
    if !self.blocked[other] {
      self.enter(other)
    }
  }
  out
}

///|
/// Steps into a node: it joins the path and is blocked until something below it works.
fn[G : @moongraph.Topology] CycleWalk::enter(
  self : CycleWalk[G],
  node : Int32,
) -> Unit {
  self.blocked[node] = true
  self.path.push(node)
  self.frames.push({
    node,
    around: @internal.distinct_neighbors(self.graph, node),
    at: 0,
    found: false,
  })
}

///|
/// Steps back out of the last node, unblocking it when a cycle was found below it.
fn[G] CycleWalk::leave(self : CycleWalk[G]) -> Unit {
  let frame = self.frames.pop().unwrap()
  let node = frame.node
  if frame.found {
    unblock(node, self.blocked, self.blocked_by)
  } else {
    // Nothing below this node leads back to the start, so it is blocked for the rest
    // of the round.
    for other in frame.around {
      if other >= self.round && !self.blocked_by[other].contains(node) {
        self.blocked_by[other].push(node)
      }
    }
  }
  self.path.pop() |> ignore
  self.blocked[node] = false
  if frame.found && self.frames.length() > 0 {
    self.frames[self.frames.length() - 1].found = true
  }
}

///|
/// Clears the block on a node and on every node that was only blocked because of it.
fn unblock(
  node : Int32,
  blocked : Array[Bool],
  blocked_by : Array[Array[Int32]],
) -> Unit {
  blocked[node] = false
  let waiting = blocked_by[node].copy()
  blocked_by[node] = ([] : Array[Int32])
  for other in waiting {
    if blocked[other] {
      unblock(other, blocked, blocked_by)
    }
  }
}

///|
/// A name for a cycle that does not depend on where it starts or which way it runs,
/// so an undirected cycle is reported once rather than once per direction.
fn[G : @moongraph.Topology] canonical_cycle(
  graph : G,
  cycle : Array[Int32],
) -> String {
  let body = if cycle.length() > 1 {
    cycle.exact_view(start=0, end=cycle.length() - 1).to_owned()
  } else {
    cycle.copy()
  }
  if body.length() == 0 {
    return ""
  }
  let mut smallest = 0
  for i in 1..<body.length() {
    if body[i] < body[smallest] {
      smallest = i
    }
  }
  let forward = rotate_text(body, smallest, 1)
  if @moongraph.Topology::directed(graph) {
    return forward
  }
  let backward = rotate_text(body, smallest, -1)
  if backward < forward {
    backward
  } else {
    forward
  }
}

///|
/// The cycle written out from `start`, stepping forward or backward.
fn rotate_text(body : Array[Int32], start : Int32, step : Int32) -> String {
  let n = body.length()
  let mut text = ""
  for i in 0..<n {
    let at = ((start + i * step) % n + n) % n
    text = text + body[at].to_string() + ","
  }
  text
}

///|
/// The cycles with no edge joining two of their own nodes.
///
/// `length_bound` caps how many nodes a cycle may run through; the default of 0 means
/// no cap. This filters the walk above one cycle at a time, so stopping early costs
/// nothing.
pub fn[G : @moongraph.Topology] chordless_cycles(
  graph : G,
  length_bound? : Int32,
) -> Iter[Array[Int32]] {
  let limit = match length_bound {
    Some(bound) => if bound > 2 { bound } else { 3 }
    None => 0
  }
  let inner = simple_cycles(graph)
  Iter::new(fn() { next_chordless(graph, inner, limit) })
}

///|
/// The next cycle from `inner` that has no chord and fits the length bound.
fn[G : @moongraph.Topology] next_chordless(
  graph : G,
  inner : Iter[Array[Int32]],
  limit : Int32,
) -> Array[Int32]? {
  let mut out : Array[Int32]? = None
  while true {
    match inner.next() {
      Some(cycle) =>
        // A reported cycle names its first node twice, so the number of nodes it
        // runs through is one less than its length.
        if (limit == 0 || cycle.length() - 1 <= limit) &&
          is_chordless(graph, cycle) {
          out = Some(cycle)
          break
        }
      None => break
    }
  }
  out
}

///|
/// Whether a cycle has no chord: no edge between two of its nodes that is not one
/// of its own edges.
fn[G : @moongraph.Topology] is_chordless(
  graph : G,
  cycle : Array[Int32],
) -> Bool {
  let body = if cycle.length() > 1 {
    cycle.exact_view(start=0, end=cycle.length() - 1).to_owned()
  } else {
    cycle.copy()
  }
  for i in 0..<body.length() {
    for j in (i + 2)..<body.length() {
      if i == 0 && j == body.length() - 1 {
        continue
      }
      for nbr in @moongraph.Topology::neighbors(graph, body[i]) {
        if nbr == body[j] {
          return false
        }
      }
    }
  }
  true
}

///|
/// The length of the shortest cycle, following the arcs of a directed graph, or `None`
/// when the graph has no closed walk.
///
/// A self-loop makes the girth 1, and two parallel edges make it 2.
///
/// A directed graph is read through its arcs, so its girth is the shortest closed walk
/// that follows them: a graph whose undirected shadow has a cycle but whose arcs never
/// come back has no girth at all. An undirected girth is the shortest cycle seen from
/// every node in turn; for a directed one the walk starts and returns at the same node and
/// the cost is the number of arcs it used.
pub fn[G : @moongraph.Topology] girth(graph : G) -> Int32? {
  if @moongraph.Topology::directed(graph) {
    directed_girth(graph)
  } else {
    undirected_girth(graph)
  }
}

///|
/// The shortest cycle of an undirected graph, by a breadth-first walk from every node.
///
/// The edge a walk arrived on is the one edge that cannot close a cycle: any other edge
/// reaching a node already placed joins two paths and closes a walk of their lengths
/// plus that edge. Reading the arrival by edge rather than by node is what makes a pair
/// of parallel edges a cycle of two.
fn[G : @moongraph.Topology] undirected_girth(graph : G) -> Int32? {
  let n = @moongraph.Topology::node_count(graph)
  let mut best : Int32? = None
  for start in 0..<n {
    let depth : Array[Int32] = Array::make(n, -1)
    let entry : Array[Int32] = Array::make(n, -1)
    let queue : Array[Int32] = [start]
    depth[start] = 0
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      let nbrs = @moongraph.Topology::neighbors(graph, node)
      let edges = @moongraph.Topology::incident(graph, node)
      for at in 0..<nbrs.length() {
        let nbr = nbrs[at]
        if nbr == node {
          return Some(1)
        }
        if depth[nbr] < 0 {
          depth[nbr] = depth[node] + 1
          entry[nbr] = edges[at]
          queue.push(nbr)
        } else if entry[node] != edges[at] {
          let length = depth[node] + depth[nbr] + 1
          best = match best {
            Some(old) => if length < old { Some(length) } else { Some(old) }
            None => Some(length)
          }
        }
      }
    }
  }
  best
}

///|
/// The shortest cycle of a directed graph: a breadth-first walk from every node, and
/// every arc that lands back on the node the walk started from closes one.
///
/// A walk to a node is the cheapest way there, so the arc home closes the cheapest cycle
/// through that start; the cheapest of those is the girth.
fn[G : @moongraph.Topology] directed_girth(graph : G) -> Int32? {
  let n = @moongraph.Topology::node_count(graph)
  let mut best : Int32? = None
  for start in 0..<n {
    let depth : Array[Int32] = Array::make(n, -1)
    let queue : Array[Int32] = [start]
    depth[start] = 0
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      for nbr in @moongraph.Topology::neighbors(graph, node) {
        if nbr == start {
          let length = depth[node] + 1
          best = match best {
            Some(old) => if length < old { Some(length) } else { Some(old) }
            None => Some(length)
          }
        }
        if depth[nbr] < 0 {
          depth[nbr] = depth[node] + 1
          queue.push(nbr)
        }
      }
    }
    match best {
      Some(1) => return best
      _ => ()
    }
  }
  best
}

///|
/// Whether every edge lies on one closed walk: every node is joined to the rest, and
/// every node either has even degree, or — in a directed graph — has as many edges
/// leaving it as entering it.
///
/// The two readings are the two ways an edge can be walked out and back. In an
/// undirected graph a walk through a node uses two of its edges, so all degrees are
/// even; in a directed one it uses one in and one out, so the two counts balance. A
/// directed graph read by degree parity answers yes for shapes that have no closed walk
/// at all, which is why the directed reading counts heads rather than ends.
///
/// A node no edge touches is a piece of its own, so a graph that has one is not
/// Eulerian: the walk would have to visit it, and it has nothing to walk.
pub fn[G : @moongraph.Topology] is_eulerian(graph : G) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  if @moongraph.Topology::directed(graph) {
    let (outs, ins) = directed_degrees(graph)
    for node in 0..<n {
      if outs[node] != ins[node] {
        return false
      }
    }
  } else {
    for node in 0..<n {
      if degree(graph, node) % 2 != 0 {
        return false
      }
    }
  }
  count_components(graph) <= 1
}

///|
/// How many edges leave and enter each node, from one pass over the edges. An arc that
/// is a self loop counts once on each side, which is what a walk through it uses.
fn[G : @moongraph.Topology] directed_degrees(
  graph : G,
) -> (Array[Int32], Array[Int32]) {
  let n = @moongraph.Topology::node_count(graph)
  let outs : Array[Int32] = Array::makei(n, fn(node) {
    @moongraph.Topology::incident(graph, node).length()
  })
  let ins : Array[Int32] = Array::make(n, 0)
  for edge in 0..<@moongraph.Topology::edge_count(graph) {
    let (_, head) = @moongraph.Topology::endpoints(graph, edge)
    if head >= 0 && head < n {
      ins[head] = ins[head] + 1
    }
  }
  (outs, ins)
}

///|
/// The degree of a node, counting an undirected self-loop twice.
fn[G : @moongraph.Topology] degree(graph : G, node : Int32) -> Int32 {
  let mut total = @moongraph.Topology::incident(graph, node).length()
  if !@moongraph.Topology::directed(graph) {
    for edge in @moongraph.Topology::incident(graph, node) {
      let (a, b) = @moongraph.Topology::endpoints(graph, edge)
      if a == b {
        total = total + 1
      }
    }
  }
  total
}

///|
/// Whether every edge can be walked in one trail that is not closed: in an undirected
/// graph exactly two nodes have odd degree and they are the ends, and in a directed one
/// exactly two nodes have their in and out counts one apart, the start leaving one more
/// than it takes and the end taking one more than it leaves.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] has_eulerian_path(
  graph : G,
) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  if @moongraph.Topology::edge_count(graph) == 0 {
    return n <= 1
  }
  if count_components(graph) > 1 {
    return false
  }
  if @moongraph.Topology::directed(graph) {
    let mut starts = 0
    let mut ends = 0
    for node in 0..<n {
      let out_degree = @moongraph.Topology::incident(graph, node).length()
      let in_degree = @moongraph.Inbound::in_incident(graph, node).length()
      if out_degree == in_degree + 1 {
        starts = starts + 1
      } else if in_degree == out_degree + 1 {
        ends = ends + 1
      } else if in_degree != out_degree {
        return false
      }
    }
    starts == 1 && ends == 1
  } else {
    let mut odd = 0
    for node in 0..<n {
      if degree(graph, node) % 2 != 0 {
        odd = odd + 1
      }
    }
    odd == 2
  }
}

///|
/// A closed walk that uses every edge exactly once, as edge numbers.
///
/// Refuses `NotA` when the graph is not Eulerian: the walk exists or it does not,
/// and half a walk is not a useful answer.
pub fn[G : @moongraph.Topology] eulerian_circuit(
  graph : G,
) -> Array[Int32] raise @moongraph.Refused {
  if !is_eulerian(graph) {
    raise @moongraph.Refused::NotA(
      kind="Eulerian",
      what="the degrees leave no way back",
    )
  }
  let n = @moongraph.Topology::node_count(graph)
  let mut start = 0
  for node in 0..<n {
    if @moongraph.Topology::incident(graph, node).length() > 0 {
      start = node
      break
    }
  }
  hierholzer(graph, start)
}

///|
/// The one trail that uses every edge exactly once, or `None` when there is none.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] eulerian_path(
  graph : G,
) -> Array[Int32]? {
  if !has_eulerian_path(graph) {
    return None
  }
  let n = @moongraph.Topology::node_count(graph)
  let mut start = 0
  let mut found_end = false
  if @moongraph.Topology::directed(graph) {
    // The trail has to start where one more edge leaves than enters; starting anywhere
    // else strands the edges behind it.
    for node in 0..<n {
      let out_degree = @moongraph.Topology::incident(graph, node).length()
      if out_degree == @moongraph.Inbound::in_incident(graph, node).length() + 1 {
        start = node
        found_end = true
        break
      }
    }
  } else {
    for node in 0..<n {
      if degree(graph, node) % 2 != 0 {
        start = node
        found_end = true
        break
      }
    }
  }
  if !found_end {
    for node in 0..<n {
      if @moongraph.Topology::incident(graph, node).length() > 0 {
        start = node
        break
      }
    }
  }
  match hierholzer(graph, start) {
    circuit =>
      if circuit.length() == @moongraph.Topology::edge_count(graph) {
        Some(circuit)
      } else {
        None
      }
  }
}

///|
/// Hierholzer's walk: follow unused edges until the walk is stuck, then step back
/// and take a detour from the last node that still has one. The edges come out in
/// post-order, so the trail is that sequence reversed.
fn[G : @moongraph.Topology] hierholzer(
  graph : G,
  start : Int32,
) -> Array[Int32] {
  let used : Array[Bool] = Array::make(
    @moongraph.Topology::edge_count(graph),
    false,
  )
  let nodes : Array[Int32] = [start]
  let edges : Array[Int32] = []
  let out : Array[Int32] = []
  while nodes.length() > 0 {
    let node = nodes[nodes.length() - 1]
    let nbrs = graph.neighbors(node)
    let eids = graph.incident(node)
    let mut next = -1
    let mut next_edge = -1
    for at in 0..<eids.length() {
      if !used[eids[at]] {
        next = nbrs[at]
        next_edge = eids[at]
        break
      }
    }
    if next < 0 {
      nodes.pop() |> ignore
      if edges.length() > 0 {
        out.push(edges[edges.length() - 1])
        edges.pop() |> ignore
      }
    } else {
      used[next_edge] = true
      edges.push(next_edge)
      nodes.push(next)
    }
  }
  out.rev_in_place()
  out
}

///|
/// The edges to duplicate so that the graph becomes Eulerian, as `(from, to)`
/// pairs.
///
/// The odd-degree nodes are paired so that the total weight of the duplicated
/// routes is as small as possible; up to twenty of them are paired exactly, more
/// than that is refused rather than answered approximately.
pub fn[G : @moongraph.Topology] eulerize(
  graph : G,
  weight? : (Int32) -> Double,
) -> Array[(Int32, Int32)] raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let odd : Array[Int32] = []
  for node in 0..<@moongraph.Topology::node_count(graph) {
    if degree(graph, node) % 2 != 0 {
      odd.push(node)
    }
  }
  if odd.length() == 0 {
    return []
  }
  if odd.length() > 20 {
    raise @moongraph.Refused::NotA(
      kind="Eulerian",
      what="more than twenty odd-degree nodes need an approximate pairing",
    )
  }
  let routes = odd_routes(graph, odd, w)
  let pairings = best_pairing(routes, odd.length())
  let out : Array[(Int32, Int32)] = []
  for i in 0..<(odd.length() / 2) {
    let partner = pairings[i]
    let from = odd[i * 2]
    let to = odd[partner]
    out.push((from, to))
  }
  out
}

///|
/// The cheapest route between every pair of odd-degree nodes, as a matrix of costs.
fn[G : @moongraph.Topology] odd_routes(
  graph : G,
  odd : Array[Int32],
  w : (Int32) -> Double,
) -> Array[Array[Double]] {
  let costs : Array[Array[Double]] = []
  for source in odd {
    let distance : Array[Double?] = Array::make(
      @moongraph.Topology::node_count(graph),
      (None : Double?),
    )
    distance[source] = Some(0.0)
    let queue : Array[Int32] = [source]
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
          queue.push(nbrs[at])
        }
      }
    }
    let row : Array[Double] = []
    for other in odd {
      row.push(distance[other].unwrap_or(0.0))
    }
    costs.push(row)
  }
  costs
}

///|
/// A minimum perfect pairing of the odd nodes, as an index per even position.
fn best_pairing(costs : Array[Array[Double]], count : Int32) -> Array[Int32] {
  let full = 1 << count
  let best : Array[Double] = Array::make(full, -1.0)
  let choice : Array[Int32] = Array::make(full, 0)
  best[0] = 0.0
  let scores : Array[Double] = Array::make(full, 0.0)
  scores[0] = 0.0
  for mask in 1..<full {
    let mut first = -1
    for i in 0..<count {
      if (mask & (1 << i)) != 0 {
        first = i
        break
      }
    }
    if first < 0 {
      continue
    }
    let mut best_cost = -1.0
    let mut best_with = 0
    for j in (first + 1)..<count {
      if (mask & (1 << j)) != 0 {
        let rest = mask ^ (1 << first) ^ (1 << j)
        let cost = scores[rest] + costs[first][j]
        if best_cost < 0.0 || cost < best_cost {
          best_cost = cost
          best_with = j
        }
      }
    }
    scores[mask] = best_cost
    choice[mask] = best_with
  }
  let out : Array[Int32] = Array::make(count / 2, 0)
  let mut mask = full - 1
  let mut slot = 0
  while mask > 0 {
    let mut first = -1
    for i in 0..<count {
      if (mask & (1 << i)) != 0 {
        first = i
        break
      }
    }
    let partner = choice[mask]
    out[slot] = partner
    slot = slot + 1
    mask = mask ^ (1 << first) ^ (1 << partner)
  }
  out
}

///|
/// A route that walks every edge at least once, duplicating edges when the graph
/// has odd-degree nodes, as edge numbers in walk order.
///
/// This is the postman's route: the cheapest closed walk that covers the graph. An
/// edge that has to be walked twice appears twice.
pub fn[G : @moongraph.Topology] chinese_postman(
  graph : G,
  weight? : (Int32) -> Double,
) -> Array[Int32] raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  if count_components(graph) > 1 && @moongraph.Topology::edge_count(graph) > 0 {
    raise @moongraph.Refused::Disconnected(from=0, to=0)
  }
  let duplicated = eulerize(graph, weight=w)
  let n = @moongraph.Topology::node_count(graph)
  // Each duplicated pair adds one more traversal of every edge on the cheapest
  // route between them, and that traversal can start at either end.
  let extra : Array[Array[Int32]] = Array::makei(n, fn(_) {
    ([] : Array[Int32])
  })
  let budget : Array[Int32] = Array::make(
    @moongraph.Topology::edge_count(graph),
    1,
  )
  for (from, to) in duplicated {
    let route = route_edges(graph, from, to, w)
    for edge in route {
      budget[edge] = budget[edge] + 1
      let (a, b) = @moongraph.Topology::endpoints(graph, edge)
      extra[a].push(edge)
      extra[b].push(edge)
    }
  }
  let nodes : Array[Int32] = [0]
  let stack : Array[Int32] = []
  let out : Array[Int32] = []
  while nodes.length() > 0 {
    let node = nodes[nodes.length() - 1]
    let nbrs = graph.neighbors(node)
    let eids = graph.incident(node)
    let mut next = -1
    let mut next_edge = -1
    for at in 0..<eids.length() {
      let edge = eids[at]
      if budget[edge] > 0 {
        next = nbrs[at]
        next_edge = edge
        break
      }
    }
    if next < 0 {
      for at in 0..<extra[node].length() {
        let edge = extra[node][at]
        if budget[edge] > 0 {
          let (a, b) = graph.endpoints(edge)
          next = if a == node { b } else { a }
          next_edge = edge
          break
        }
      }
    }
    if next < 0 {
      nodes.pop() |> ignore
      if stack.length() > 0 {
        out.push(stack[stack.length() - 1])
        stack.pop() |> ignore
      }
    } else {
      budget[next_edge] = budget[next_edge] - 1
      stack.push(next_edge)
      nodes.push(next)
    }
  }
  out.rev_in_place()
  out
}

///|
/// The edges of a cheapest route between two nodes, by Dijkstra over the weights.
fn[G : @moongraph.Topology] route_edges(
  graph : G,
  from : Int32,
  to : Int32,
  w : (Int32) -> Double,
) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Int32] = []
  if from < 0 || from >= n || to < 0 || to >= n {
    return out
  }
  let distance : Array[Double?] = Array::make(n, (None : Double?))
  let previous : Array[Int32?] = Array::make(n, (None : Int32?))
  distance[from] = Some(0.0)
  let heap = @moonstl.PairingHeap::new_by(cmp=@internal.entry_cmp)
  heap.insert((0.0, from)) |> ignore
  while heap.pop() is Some((cost, node)) {
    if distance[node] is Some(best) && cost > best {
      continue
    }
    let nbrs = @moongraph.Topology::neighbors(graph, node)
    let eids = @moongraph.Topology::incident(graph, node)
    for at in 0..<eids.length() {
      let next = cost + w(eids[at])
      let better = match distance[nbrs[at]] {
        Some(old) => next < old
        None => true
      }
      if better {
        distance[nbrs[at]] = Some(next)
        previous[nbrs[at]] = Some(eids[at])
        heap.insert((next, nbrs[at])) |> ignore
      }
    }
  }
  if distance[to] is None {
    return out
  }
  let mut at = to
  while previous[at] is Some(edge) {
    out.push(edge)
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    at = if a == at { b } else { a }
  }
  out
}

///|
/// A set of edges whose removal leaves a graph without cycles, chosen greedily.
///
/// Refuses nothing: a graph that is already acyclic gives an empty set. The set is
/// a heuristic answer, not the smallest possible one.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] feedback_arc_set(
  graph : G,
) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  // Ordering by decreasing out-minus-in puts the sources first; every edge that
  // points backwards in that order closes a cycle now or later.
  let order : Array[Int32] = Array::makei(n, fn(i) { i })
  let score = fn(node : Int32) {
    @moongraph.Topology::incident(graph, node).length() -
    @moongraph.Inbound::in_incident(graph, node).length()
  }
  order.sort_by(fn(a, b) {
    let sa = score(a)
    let sb = score(b)
    if sa != sb {
      sb - sa
    } else {
      a - b
    }
  })
  let position : Array[Int32] = Array::make(n, 0)
  for i in 0..<n {
    position[order[i]] = i
  }
  let out : Array[Int32] = []
  for node in 0..<n {
    let nbrs = @moongraph.Topology::neighbors(graph, node)
    let eids = @moongraph.Topology::incident(graph, node)
    for at in 0..<eids.length() {
      if position[nbrs[at]] <= position[node] {
        out.push(eids[at])
      }
    }
  }
  out.sort()
  out
}

///|
/// The smallest cost-to-weight ratio over all cycles.
///
/// Found by binary search: for a candidate ratio `r`, the graph reweighted as
/// `cost - r * weight` has a negative cycle exactly when a cycle beats `r`.
pub fn[G : @moongraph.Topology] min_cycle_ratio(
  graph : G,
  cost~ : (Int32) -> Double,
  weight? : (Int32) -> Double,
) -> Double raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let n = @moongraph.Topology::node_count(graph)
  if n == 0 {
    raise @moongraph.Refused::NoSolution
  }
  let mut low = -1.0e18
  let mut high = 1.0e18
  for edge in 0..<@moongraph.Topology::edge_count(graph) {
    let ratio = cost(edge) / w(edge)
    if ratio < low {
      low = ratio
    }
    if ratio > high {
      high = ratio
    }
  }
  for _ in 0..<100 {
    let mid = (low + high) / 2.0
    if has_negative_cycle(graph, cost, w, mid) {
      high = mid
    } else {
      low = mid
    }
  }
  (low + high) / 2.0
}

///|
/// Whether the graph has a cycle with a negative total under `cost - ratio * weight`.
fn[G : @moongraph.Topology] has_negative_cycle(
  graph : G,
  cost : (Int32) -> Double,
  w : (Int32) -> Double,
  ratio : Double,
) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  let distance : Array[Double] = Array::make(n, 0.0)
  for _ in 0..<n {
    let mut changed : Bool = false
    for node in 0..<n {
      let nbrs = @moongraph.Topology::neighbors(graph, node)
      let eids = @moongraph.Topology::incident(graph, node)
      for at in 0..<eids.length() {
        let step = cost(eids[at]) - ratio * w(eids[at])
        if distance[node] + step < distance[nbrs[at]] - 1.0e-12 {
          distance[nbrs[at]] = distance[node] + step
          changed = true
        }
      }
    }
    if !changed {
      return false
    }
  }
  true
}
