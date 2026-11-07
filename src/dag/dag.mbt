// Orders and closures of a directed acyclic graph.

///|
/// A node order in which every edge points forward.
///
/// Refuses `Cycle` carrying a witness, because a partial order that silently drops
/// the edges it cannot place is how a build system ships a broken release order.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (0, 2), (1, 3), (2, 3)],
///     node=(),
///     edge=(),
///   )
///   assert_eq(@dag.topological_order(g), [0, 1, 2, 3])
/// }
/// ```
pub fn[G : @moongraph.Topology] topological_order(
  graph : G,
) -> Array[Int32] raise @moongraph.Refused {
  let n = @moongraph.Topology::node_count(graph)
  let indegree : Array[Int32] = Array::make(n, 0)
  for node in 0..<n {
    for _ in graph.neighbors(node) {
      // Counted below, per edge, so parallel edges are counted separately.
      ()
    }
    let nbrs = graph.neighbors(node)
    for at in 0..<nbrs.length() {
      indegree[nbrs[at]] = indegree[nbrs[at]] + 1
    }
  }
  let queue : Array[Int32] = []
  for node in 0..<n {
    if indegree[node] == 0 {
      queue.push(node)
    }
  }
  let out : Array[Int32] = []
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    out.push(node)
    for nbr in graph.neighbors(node) {
      indegree[nbr] = indegree[nbr] - 1
      if indegree[nbr] == 0 {
        queue.push(nbr)
      }
    }
  }
  if out.length() < n {
    raise @moongraph.Refused::Cycle(nodes=cycle_witness(graph, indegree))
  }
  out
}

///|
/// A cycle among the nodes that were never released, first and last equal.
///
/// Every unreleased node has an unreleased predecessor, so a depth-first walk that
/// stays inside that set must close on itself; the walk is restarted from each
/// unreleased node in turn because the first one tried may only sit downstream of
/// the cycle rather than on it.
fn[G : @moongraph.Topology] cycle_witness(
  graph : G,
  indegree : Array[Int32],
) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  for start in 0..<n {
    if indegree[start] <= 0 {
      continue
    }
    let state : Array[Int32] = Array::make(n, 0)
    let stack : Array[Int32] = []
    let path : Array[Int32] = []
    let witness = walk_for_cycle(graph, start, indegree, state, stack, path)
    if witness.length() > 0 {
      return witness
    }
  }
  [0, 0]
}

///|
fn[G : @moongraph.Topology] walk_for_cycle(
  graph : G,
  start : Int32,
  indegree : Array[Int32],
  state : Array[Int32],
  stack : Array[Int32],
  path : Array[Int32],
) -> Array[Int32] {
  if state[start] == 1 {
    // Found the closing edge: the cycle is the path from where the node was
    // entered down to the current end, closed again by the node itself.
    let out : Array[Int32] = []
    let mut at = 0
    while at < path.length() && path[at] != start {
      at = at + 1
    }
    let mut keep = at
    while keep < path.length() {
      out.push(path[keep])
      keep = keep + 1
    }
    out.push(start)
    return out
  }
  if state[start] == 2 {
    return []
  }
  state[start] = 1
  path.push(start)
  for nbr in graph.neighbors(start) {
    if indegree[nbr] > 0 {
      let found = walk_for_cycle(graph, nbr, indegree, state, stack, path)
      if found.length() > 0 {
        return found
      }
    }
  }
  path.pop() |> ignore
  state[start] = 2
  []
}

///|
/// Whether the graph has no cycle.
pub fn[G : @moongraph.Topology] is_dag(graph : G) -> Bool {
  try {
    topological_order(graph) |> ignore
    true
  } catch {
    @moongraph.Refused::Cycle(_) => false
    _ => false
  }
}

///|
/// The smallest-numbered node that is ready at every step, which is the
/// lexicographically smallest topological order.
pub fn[G : @moongraph.Topology] topological_smallest(
  graph : G,
) -> Array[Int32] raise @moongraph.Refused {
  let n = @moongraph.Topology::node_count(graph)
  let indegree : Array[Int32] = Array::make(n, 0)
  for node in 0..<n {
    let nbrs = graph.neighbors(node)
    for at in 0..<nbrs.length() {
      indegree[nbrs[at]] = indegree[nbrs[at]] + 1
    }
  }
  let heap = @moonstl.PairingHeap::new_by(cmp=@internal.entry_cmp)
  for node in 0..<n {
    if indegree[node] == 0 {
      heap.insert((node.to_double(), node)) |> ignore
    }
  }
  let out : Array[Int32] = []
  while heap.pop() is Some((_, node)) {
    out.push(node)
    for nbr in graph.neighbors(node) {
      indegree[nbr] = indegree[nbr] - 1
      if indegree[nbr] == 0 {
        heap.insert((nbr.to_double(), nbr)) |> ignore
      }
    }
  }
  if out.length() < n {
    raise @moongraph.Refused::Cycle(nodes=cycle_witness(graph, indegree))
  }
  out
}

///|
/// The order cut into generations: every node of a generation has all of its
/// predecessors in earlier generations.
///
/// Each generation is ascending, and the generations are in order, so this is also
/// a valid topological order read row by row.
pub fn[G : @moongraph.Topology] topological_generations(
  graph : G,
) -> Array[Array[Int32]] raise @moongraph.Refused {
  let n = @moongraph.Topology::node_count(graph)
  let indegree : Array[Int32] = Array::make(n, 0)
  for node in 0..<n {
    let nbrs = graph.neighbors(node)
    for at in 0..<nbrs.length() {
      indegree[nbrs[at]] = indegree[nbrs[at]] + 1
    }
  }
  let mut layer : Array[Int32] = []
  for node in 0..<n {
    if indegree[node] == 0 {
      layer.push(node)
    }
  }
  let out : Array[Array[Int32]] = []
  let mut placed = 0
  while layer.length() > 0 {
    layer.sort()
    out.push(layer.copy())
    placed = placed + layer.length()
    let next : Array[Int32] = []
    for node in layer {
      for nbr in graph.neighbors(node) {
        indegree[nbr] = indegree[nbr] - 1
        if indegree[nbr] == 0 {
          next.push(nbr)
        }
      }
    }
    layer = next
  }
  if placed < n {
    raise @moongraph.Refused::Cycle(nodes=cycle_witness(graph, indegree))
  }
  out
}

///|
/// Every topological order, in lexicographic order of the node sequences.
///
/// The count grows factorially, so the walk keeps one order in hand and works out the
/// next one when it is asked for: a caller that stops after ten orders never pays for
/// the rest.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (0, 2)],
///     node=(),
///     edge=(),
///     directed=true,
///   )
///   let orders = @dag.all_topological_orders(g).collect()
///   assert_eq(orders, [[0, 1, 2], [0, 2, 1]])
/// }
/// ```
pub fn[G : @moongraph.Topology] all_topological_orders(
  graph : G,
) -> Iter[Array[Int32]] {
  let n = @moongraph.Topology::node_count(graph)
  if n == 0 {
    return Iter::singleton(([] : Array[Int32]))
  }
  let base : Array[Int32] = Array::make(n, 0)
  for node in 0..<n {
    let nbrs = graph.neighbors(node)
    for at in 0..<nbrs.length() {
      base[nbrs[at]] = base[nbrs[at]] + 1
    }
  }
  let walk = OrderWalk::{
    graph,
    n,
    indegree: base.copy(),
    used: Array::make(n, false),
    prefix: [],
    cursor: Array::make(n, 0),
  }
  Iter::new(fn() { walk.next() })
}

///|
/// The state of the enumeration: the order built so far, how many candidates have been
/// tried at each depth, and the in-degrees that decide who may come next.
priv struct OrderWalk[G] {
  graph : G
  n : Int32
  indegree : Array[Int32]
  used : Array[Bool]
  prefix : Array[Int32]
  cursor : Array[Int32]
}

///|
/// The next order, or nothing when every branch has been tried.
fn[G : @moongraph.Topology] OrderWalk::next(
  self : OrderWalk[G],
) -> Array[Int32]? {
  let mut out : Array[Int32]? = None
  while true {
    if self.prefix.length() == self.n {
      out = Some(self.prefix.copy())
      // Step back one place so that the next call can take the next branch.
      self.rewind()
      break
    }
    let depth = self.prefix.length()
    let mut placed = false
    while self.cursor[depth] < self.n {
      let node = self.cursor[depth]
      self.cursor[depth] = node + 1
      if !self.used[node] && self.indegree[node] == 0 {
        self.used[node] = true
        self.prefix.push(node)
        if depth + 1 < self.n {
          self.cursor[depth + 1] = 0
        }
        for nbr in self.graph.neighbors(node) {
          self.indegree[nbr] = self.indegree[nbr] - 1
        }
        placed = true
        break
      }
    }
    if !placed {
      if depth == 0 {
        break
      }
      self.rewind()
    }
  }
  out
}

///|
/// Takes the last node back out of the order.
fn[G : @moongraph.Topology] OrderWalk::rewind(self : OrderWalk[G]) -> Unit {
  let node = self.prefix.pop().unwrap()
  self.used[node] = false
  for nbr in self.graph.neighbors(node) {
    self.indegree[nbr] = self.indegree[nbr] + 1
  }
}

///|
/// The nodes that reach `node`, ascending, itself excluded.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] ancestors(
  graph : G,
  node : Int32,
) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Int32] = []
  if node < 0 || node >= n {
    return out
  }
  let seen : Array[Bool] = Array::make(n, false)
  seen[node] = true
  let queue : Array[Int32] = [node]
  let mut head = 0
  while head < queue.length() {
    let at = queue[head]
    head = head + 1
    for (nbr, _) in @internal.in_edges(graph, at) {
      if !seen[nbr] {
        seen[nbr] = true
        queue.push(nbr)
      }
    }
  }
  for other in 0..<n {
    if other != node && seen[other] {
      out.push(other)
    }
  }
  out
}

///|
/// The nodes `node` reaches, ascending, itself excluded.
pub fn[G : @moongraph.Topology] descendants(
  graph : G,
  node : Int32,
) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Int32] = []
  if node < 0 || node >= n {
    return out
  }
  let seen : Array[Bool] = Array::make(n, false)
  seen[node] = true
  let queue : Array[Int32] = [node]
  let mut head = 0
  while head < queue.length() {
    let at = queue[head]
    head = head + 1
    for nbr in graph.neighbors(at) {
      if !seen[nbr] {
        seen[nbr] = true
        queue.push(nbr)
      }
    }
  }
  for other in 0..<n {
    if other != node && seen[other] {
      out.push(other)
    }
  }
  out
}

///|
/// The reachability matrix: `closure[from][to]` is true when an edge or a chain of
/// them joins the two. A node reaches itself.
pub fn[G : @moongraph.Topology] transitive_closure(
  graph : G,
) -> Array[Array[Bool]] {
  let n = @moongraph.Topology::node_count(graph)
  let closure : Array[Array[Bool]] = Array::makei(n, fn(_) {
    Array::make(n, false)
  })
  for node in 0..<n {
    closure[node][node] = true
    let queue : Array[Int32] = [node]
    let mut head = 0
    while head < queue.length() {
      let at = queue[head]
      head = head + 1
      for nbr in graph.neighbors(at) {
        if !closure[node][nbr] {
          closure[node][nbr] = true
          queue.push(nbr)
        }
      }
    }
  }
  closure
}

///|
/// The edges that no other route makes redundant, as `(from, to)` pairs.
///
/// Every edge that skips over a longer route is dropped, so the result has the same
/// reachability as the input with as few edges as possible.
pub fn[G : @moongraph.Topology] transitive_reduction(
  graph : G,
) -> Array[(Int32, Int32)] {
  let n = @moongraph.Topology::node_count(graph)
  let keep : Array[(Int32, Int32)] = []
  for node in 0..<n {
    let direct = @internal.distinct_neighbors(graph, node)
    for target in direct {
      // Reachable from `node` without using the direct edge?
      let seen : Array[Bool] = Array::make(n, false)
      seen[node] = true
      let queue : Array[Int32] = [node]
      let mut head = 0
      let mut bypass = false
      while head < queue.length() && !bypass {
        let at = queue[head]
        head = head + 1
        for nbr in graph.neighbors(at) {
          if at == node && nbr == target {
            continue
          }
          if nbr == target {
            bypass = true
            break
          }
          if !seen[nbr] {
            seen[nbr] = true
            queue.push(nbr)
          }
        }
      }
      if !bypass {
        keep.push((node, target))
      }
    }
  }
  keep
}

///|
/// A longest route in the graph, as node numbers, by relaxing in topological order.
///
/// Refuses `Cycle`, because a cycle has no longest route: it can be walked again
/// and again. The route reported is the cheapest in the sense that among equally
/// long routes the one through the smaller node numbers wins.
pub fn[G : @moongraph.Topology] longest_path(
  graph : G,
  weight? : (Int32) -> Double,
) -> Array[Int32] raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let order = topological_order(graph)
  let n = @moongraph.Topology::node_count(graph)
  let best : Array[Double?] = Array::make(n, (None : Double?))
  let from : Array[Int32?] = Array::make(n, (None : Int32?))
  for node in order {
    if best[node] is None {
      best[node] = Some(0.0)
    }
    let base = best[node].unwrap()
    let nbrs = graph.neighbors(node)
    let eids = graph.incident(node)
    for at in 0..<eids.length() {
      let next = base + w(eids[at])
      let better = match best[nbrs[at]] {
        Some(old) => next > old
        None => true
      }
      if better {
        best[nbrs[at]] = Some(next)
        from[nbrs[at]] = Some(node)
      }
    }
  }
  let mut end = -1
  let mut longest = 0.0
  for node in 0..<n {
    match best[node] {
      Some(score) =>
        if end < 0 || score > longest {
          longest = score
          end = node
        }
      None => ()
    }
  }
  if end < 0 {
    return []
  }
  let route : Array[Int32] = [end]
  let mut at = end
  while from[at] is Some(back) {
    route.push(back)
    at = back
  }
  route.rev_in_place()
  route
}

///|
/// The weight of the longest route.
pub fn[G : @moongraph.Topology] longest_path_length(
  graph : G,
  weight? : (Int32) -> Double,
) -> Double raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let route = longest_path(graph, weight=w)
  let mut total = 0.0
  for i in 1..<route.length() {
    let mut best = 0.0
    let mut found = false
    let nbrs = graph.neighbors(route[i - 1])
    let eids = graph.incident(route[i - 1])
    for at in 0..<eids.length() {
      if nbrs[at] == route[i] && (!found || w(eids[at]) > best) {
        best = w(eids[at])
        found = true
      }
    }
    total = total + best
  }
  total
}

///|
/// The maximal antichains of the reachability order: sets of nodes no two of which
/// are comparable.
///
/// A generation of `topological_generations` is one of these, and every maximal
/// antichain falls out of one cut of the order.
pub fn[G : @moongraph.Topology] antichains(graph : G) -> Array[Array[Int32]] {
  let n = @moongraph.Topology::node_count(graph)
  let closure = transitive_closure(graph)
  // A maximal antichain is the set of nodes at one frontier: take each node, and
  // keep every node that is not comparable with it.
  let out : Array[Array[Int32]] = []
  for seed in 0..<n {
    let group : Array[Int32] = [seed]
    for other in 0..<n {
      if other == seed {
        continue
      }
      let mut comparable = false
      for picked in group {
        if closure[picked][other] || closure[other][picked] {
          comparable = true
          break
        }
      }
      if !comparable {
        group.push(other)
      }
    }
    group.sort()
    let mut maximal = true
    for other in 0..<n {
      if !group.contains(other) {
        let mut fits = true
        for picked in group {
          if closure[picked][other] || closure[other][picked] {
            fits = false
            break
          }
        }
        if fits {
          maximal = false
          break
        }
      }
    }
    if maximal && !out.contains(group) {
      out.push(group)
    }
  }
  out
}

///|
/// Whether the lengths of the cycles in the graph have no common divisor above one.
///
/// A walk that can return at any of several lengths in step can reach every
/// sufficiently long position; when every cycle length shares a factor, it can only
/// reach one residue class.
pub fn[G : @moongraph.Topology] is_aperiodic(graph : G) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  if n == 0 {
    return true
  }
  let level : Array[Int32] = Array::make(n, -1)
  level[0] = 0
  let queue : Array[Int32] = [0]
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    for nbr in graph.neighbors(node) {
      if level[nbr] < 0 {
        level[nbr] = level[node] + 1
        queue.push(nbr)
      }
    }
  }
  let mut divisor = 0
  for node in 0..<n {
    if level[node] < 0 {
      continue
    }
    let nbrs = graph.neighbors(node)
    for at in 0..<nbrs.length() {
      if level[nbrs[at]] >= 0 {
        let step = level[node] + 1 - level[nbrs[at]]
        divisor = gcd(divisor, if step < 0 { -step } else { step })
      }
    }
  }
  divisor == 1
}

///|
fn gcd(a : Int32, b : Int32) -> Int32 {
  if b == 0 {
    a
  } else {
    gcd(b, a % b)
  }
}

///|
/// The nodes that sit at the head of a fork: two incoming edges from nodes that are
/// not themselves joined.
///
/// These are the collision points a causal graph shows, and the reason a
/// correlation appears where the graph has none.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] colliders(
  graph : G,
) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Int32] = []
  for node in 0..<n {
    let parents = @internal.in_edges(graph, node)
    if parents.length() < 2 {
      continue
    }
    let mut fork = false
    for i in 0..<parents.length() {
      for j in (i + 1)..<parents.length() {
        let a = parents[i].0
        let b = parents[j].0
        let mut joined = false
        for nbr in @moongraph.Topology::neighbors(graph, a) {
          if nbr == b {
            joined = true
            break
          }
        }
        if !joined {
          fork = true
          break
        }
      }
      if fork {
        break
      }
    }
    if fork {
      out.push(node)
    }
  }
  out
}

///|
/// The immediate dominator of each node from `entry`: the last node every route
/// from the entry must pass through.
///
/// The entry dominates itself, and a node the entry cannot reach has no dominator.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] dominators(
  graph : G,
  entry : Int32,
) -> Array[Int32?] {
  let n = @moongraph.Topology::node_count(graph)
  let idom : Array[Int32?] = Array::make(n, (None : Int32?))
  if entry < 0 || entry >= n {
    return idom
  }
  let order = topological_order(graph) catch {
    _ => {
      // A cycle does not stop dominance: fall back to the reverse post-order of a
      // plain depth-first walk from the entry.
      let walk = post_order(graph, entry)
      return iterate_dominators(graph, entry, walk, idom)
    }
  }
  iterate_dominators(graph, entry, order, idom)
}

///|
fn[G : @moongraph.Inbound] iterate_dominators(
  graph : G,
  entry : Int32,
  order : Array[Int32],
  idom : Array[Int32?],
) -> Array[Int32?] {
  idom[entry] = Some(entry)
  let mut changed = true
  while changed {
    changed = false
    for node in order {
      if node == entry {
        continue
      }
      let mut candidate = -1
      for (parent, _) in @internal.in_edges(graph, node) {
        if idom[parent] is Some(_) {
          candidate = if candidate < 0 {
            parent
          } else {
            intersect(idom, parent, candidate, entry)
          }
        }
      }
      if candidate >= 0 {
        if idom[node] != Some(candidate) {
          idom[node] = Some(candidate)
          changed = true
        }
      }
    }
  }
  idom
}

///|
fn intersect(
  idom : Array[Int32?],
  a : Int32,
  b : Int32,
  entry : Int32,
) -> Int32 {
  let mut left = a
  let mut right = b
  while left != right {
    while left != entry && left > right {
      match idom[left] {
        Some(up) => left = up
        None => return right
      }
    }
    while right != entry && right > left {
      match idom[right] {
        Some(up) => right = up
        None => return left
      }
    }
    if left == entry || right == entry {
      return entry
    }
  }
  left
}

///|
fn[G : @moongraph.Topology] post_order(
  graph : G,
  entry : Int32,
) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let seen : Array[Bool] = Array::make(n, false)
  let out : Array[Int32] = []
  let frames : Array[(Int32, Int32)] = [(entry, 0)]
  seen[entry] = true
  while frames.length() > 0 {
    let top = frames.length() - 1
    let (node, at) = frames[top]
    let edges = @internal.out_edges(graph, node)
    if at < edges.length() {
      frames[top] = (node, at + 1)
      let nbr = edges[at].0
      if !seen[nbr] {
        seen[nbr] = true
        frames.push((nbr, 0))
      }
    } else {
      out.push(node)
      frames.pop() |> ignore
    }
  }
  out
}

///|
/// The dominance frontier of each node: the nodes where its dominance stops.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] dominance_frontiers(
  graph : G,
  entry : Int32,
) -> Array[Array[Int32]] {
  let n = @moongraph.Topology::node_count(graph)
  let idom = dominators(graph, entry)
  let frontier : Array[Array[Int32]] = Array::makei(n, fn(_) {
    ([] : Array[Int32])
  })
  for node in 0..<n {
    let parents = @internal.in_edges(graph, node)
    if parents.length() < 2 {
      continue
    }
    for (parent, _) in parents {
      let mut runner = parent
      while runner != entry && runner >= 0 {
        match idom[runner] {
          Some(_) =>
            if runner != idom[node].unwrap_or(-1) {
              if !frontier[runner].contains(node) {
                frontier[runner].push(node)
              }
            }
          None => break
        }
        if idom[runner] == Some(runner) {
          break
        }
        runner = idom[runner].unwrap_or(-1)
        if runner == parent {
          break
        }
      }
    }
  }
  for node in 0..<n {
    frontier[node].sort()
  }
  frontier
}

///|
/// An incremental topological sorter: nodes are added as they become known, and the
/// caller asks which are ready without restarting the walk.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new()
///   for _ in 0..<3 {
///     g.add_node(()) |> ignore
///   }
///   g.add_edge(0, 2, ()) |> ignore
///   g.add_edge(1, 2, ()) |> ignore
///   let sorter = @dag.Sorter::new(g)
///   assert_eq(sorter.ready(), [0, 1])
/// }
/// ```
pub struct Sorter {
  succ : Array[Array[Int32]]
  pending : Array[Int32]
  finished : Array[Bool]
  mut ready_queue : Array[Int32]
  mut active : Bool
}

///|
/// A sorter holding every node of the graph, with the graph's edges as
/// prerequisites.
pub fn[G : @moongraph.Topology] Sorter::new(graph : G) -> Sorter {
  let n = @moongraph.Topology::node_count(graph)
  let succ : Array[Array[Int32]] = Array::makei(n, fn(_) { ([] : Array[Int32]) })
  let pending : Array[Int32] = Array::make(n, 0)
  for node in 0..<n {
    let nbrs = graph.neighbors(node)
    for at in 0..<nbrs.length() {
      succ[node].push(nbrs[at])
      pending[nbrs[at]] = pending[nbrs[at]] + 1
    }
  }
  let ready_queue : Array[Int32] = []
  for node in 0..<n {
    if pending[node] == 0 {
      ready_queue.push(node)
    }
  }
  Sorter::{
    succ,
    pending,
    finished: Array::make(n, false),
    ready_queue,
    active: true,
  }
}

///|
/// Declares that `node` must come after every node in `after`. The node may be one
/// the graph did not have.
pub fn Sorter::add(
  self : Sorter,
  node : Int32,
  after : Array[Int32],
) -> Unit raise @moongraph.Refused {
  if node < 0 {
    raise @moongraph.Refused::OutOfRange(node~)
  }
  if node >= self.succ.length() {
    raise @moongraph.Refused::OutOfRange(node~)
  }
  if self.ready_queue.contains(node) && after.length() > 0 {
    self.ready_queue = self.ready_queue.filter(fn(n) { n != node })
  }
  for parent in after {
    if parent < 0 || parent >= self.succ.length() {
      raise @moongraph.Refused::OutOfRange(node=parent)
    }
    if !self.succ[parent].contains(node) {
      self.succ[parent].push(node)
      self.pending[node] = self.pending[node] + 1
    }
  }
  if self.pending[node] == 0 &&
    !self.ready_queue.contains(node) &&
    !self.finished[node] {
    self.ready_queue.push(node)
  }
}

///|
/// The nodes whose prerequisites are all finished, ascending. Each node is handed
/// out once until it is finished.
pub fn Sorter::ready(self : Sorter) -> Array[Int32] raise @moongraph.Refused {
  if !self.active {
    raise @moongraph.Refused::NotA(kind="sorter", what="the sort is over")
  }
  let out = self.ready_queue.copy()
  out.sort()
  self.ready_queue = out.copy()
  out
}

///|
/// Marks nodes as done, which may release the nodes that were waiting on them.
pub fn Sorter::finish(
  self : Sorter,
  nodes : Array[Int32],
) -> Unit raise @moongraph.Refused {
  for node in nodes {
    if node < 0 || node >= self.finished.length() {
      raise @moongraph.Refused::OutOfRange(node~)
    }
    if self.finished[node] {
      continue
    }
    if self.pending[node] > 0 {
      raise @moongraph.Refused::NotA(
        kind="sorter",
        what="the node still has prerequisites",
      )
    }
    self.finished[node] = true
    self.ready_queue = self.ready_queue.filter(fn(n) { n != node })
    for child in self.succ[node] {
      self.pending[child] = self.pending[child] - 1
      if self.pending[child] == 0 && !self.finished[child] {
        self.ready_queue.push(child)
      }
    }
  }
  let mut remaining = false
  for node in 0..<self.finished.length() {
    if !self.finished[node] {
      remaining = true
    }
  }
  self.active = remaining
}

///|
/// Whether any node is still waiting.
pub fn Sorter::is_active(self : Sorter) -> Bool {
  self.active
}

///|
/// The full order, as the sorter sees it from the start, which is the same as
/// `topological_order` on the graph plus every node added since.
pub fn Sorter::order(self : Sorter) -> Array[Int32] raise @moongraph.Refused {
  let n = self.succ.length()
  let indegree = self.pending.copy()
  let queue : Array[Int32] = []
  for node in 0..<n {
    if indegree[node] == 0 {
      queue.push(node)
    }
  }
  let out : Array[Int32] = []
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    out.push(node)
    for child in self.succ[node] {
      indegree[child] = indegree[child] - 1
      if indegree[child] == 0 {
        queue.push(child)
      }
    }
  }
  if out.length() < n {
    raise @moongraph.Refused::Cycle(nodes=[0, 0])
  }
  out
}
