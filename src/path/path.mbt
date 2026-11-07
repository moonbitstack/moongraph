// Shortest paths.
//
// One rule decides which function to reach for: whether the graph can carry a
// negative weight. `dijkstra` and its relatives settle each node once, which is
// what makes them fast and what makes a negative edge unsound; they refuse the
// graph instead of answering wrongly. `bellman_ford`, `spfa` and `johnson` read
// every edge repeatedly and handle negatives, and they refuse only a negative
// cycle, which has no shortest path to report.

///|
/// Cheapest routes from one source, by Dijkstra's method.
///
/// Refuses `NegativeWeight` naming the edge, because a negative edge makes the
/// settled-once rule unsound. Use `bellman_ford` for such a graph.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new()
///   for _ in 0..<4 {
///     g.add_node(()) |> ignore
///   }
///   g.add_edge(0, 1, 1.0) |> ignore
///   g.add_edge(1, 2, 2.0) |> ignore
///   g.add_edge(0, 2, 5.0) |> ignore
///   let paths = @path.dijkstra(g, 0, weight=g.weights(fn(w) { w }))
///   assert_eq(paths.path_to(2), Some([0, 1, 2]))
///   assert_eq(paths.distance, [Some(0.0), Some(1.0), Some(3.0), None])
/// }
/// ```
pub fn[G : @moongraph.Topology] dijkstra(
  graph : G,
  source : Int32,
  weight? : (Int32) -> Double,
) -> @moongraph.Paths raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  search(graph, [source], w, None, None)
}

///|
/// Cheapest routes from several sources at once; every source starts at 0.
pub fn[G : @moongraph.Topology] dijkstra_multi(
  graph : G,
  sources : Array[Int32],
  weight? : (Int32) -> Double,
) -> @moongraph.Paths raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  search(graph, sources, w, None, None)
}

///|
/// The one core walk the variants share: a heap of `(cost, node)`, a distance
/// array, and an optional set of excluded nodes and edges that `k_shortest` uses
/// to ask for the next route.
fn[G : @moongraph.Topology] search(
  graph : G,
  sources : Array[Int32],
  w : (Int32) -> Double,
  banned_nodes : Array[Bool]?,
  banned_edges : Array[Bool]?,
) -> @moongraph.Paths raise @moongraph.Refused {
  let n = graph.node_count()
  let distance : Array[Double?] = Array::make(n, (None : Double?))
  let previous : Array[Int32?] = Array::make(n, (None : Int32?))
  let heap = @moonstl.PairingHeap::new_by(cmp=@internal.entry_cmp)
  for source in sources {
    if source >= 0 && source < n && !is_banned(banned_nodes, source) {
      if distance[source] is None || 0.0 < distance[source].unwrap() {
        distance[source] = Some(0.0)
        previous[source] = None
        heap.insert((0.0, source)) |> ignore
      }
    }
  }
  while heap.pop() is Some((cost, node)) {
    match distance[node] {
      Some(best) => if cost > best { continue }
      None => continue
    }
    let nbrs = graph.neighbors(node)
    let eids = graph.incident(node)
    for at in 0..<eids.length() {
      let edge = eids[at]
      if is_banned(banned_edges, edge) {
        continue
      }
      let to = nbrs[at]
      if is_banned(banned_nodes, to) {
        continue
      }
      let step = w(edge)
      if step < 0.0 {
        raise @moongraph.Refused::NegativeWeight(edge~)
      }
      let next = cost + step
      let better = match distance[to] {
        Some(old) => next < old
        None => true
      }
      if better {
        distance[to] = Some(next)
        previous[to] = Some(node)
        heap.insert((next, to)) |> ignore
      }
    }
  }
  { distance, previous, }
}

///|
fn is_banned(banned : Array[Bool]?, item : Int32) -> Bool {
  match banned {
    Some(flags) => item >= 0 && item < flags.length() && flags[item]
    None => false
  }
}

///|
/// The cheapest route between two nodes, searched from both ends at once.
///
/// The record is filled along the route and unset elsewhere, because a search
/// that meets in the middle never settles the rest of the graph. Reach for
/// `dijkstra` when every distance is wanted; reach for this one when only the
/// pair matters and half the work is worth having.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] dijkstra_bidirectional(
  graph : G,
  from : Int32,
  to : Int32,
  weight? : (Int32) -> Double,
) -> @moongraph.Paths raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let n = @moongraph.Topology::node_count(graph)
  let forward : Array[Double?] = Array::make(n, (None : Double?))
  let backward : Array[Double?] = Array::make(n, (None : Double?))
  let from_parent : Array[Int32?] = Array::make(n, (None : Int32?))
  let to_next : Array[Int32?] = Array::make(n, (None : Int32?))
  if from < 0 || from >= n || to < 0 || to >= n {
    return { distance: forward, previous: from_parent, }
  }
  let ahead_heap = @moonstl.PairingHeap::new_by(cmp=@internal.entry_cmp)
  let behind_heap = @moonstl.PairingHeap::new_by(cmp=@internal.entry_cmp)
  forward[from] = Some(0.0)
  backward[to] = Some(0.0)
  ahead_heap.insert((0.0, from)) |> ignore
  behind_heap.insert((0.0, to)) |> ignore
  let mut best = @double.infinity
  let mut meeting = -1
  while !ahead_heap.is_empty() || !behind_heap.is_empty() {
    // Stop as soon as neither frontier can improve on the best route seen.
    let ahead_min = match ahead_heap.pop() {
      Some((cost, _)) => cost
      None => @double.infinity
    }
    let behind_min = match behind_heap.pop() {
      Some((cost, _)) => cost
      None => @double.infinity
    }
    if ahead_min + behind_min >= best && meeting >= 0 {
      break
    }
    if ahead_min <= behind_min {
      if ahead_min < @double.infinity {
        // Re-run the pop we consumed: peek is not available, so scan the node list.
        let node = node_of_cost(graph, forward, ahead_min)
        if node >= 0 {
          expand_forward(
            graph, node, w, forward, from_parent, ahead_heap, backward,
          )
          if backward[node] is Some(back) {
            let total = ahead_min + back
            if total < best {
              best = total
              meeting = node
            }
          }
        }
      }
    } else {
      let node = node_of_cost(graph, backward, behind_min)
      if node >= 0 {
        expand_backward(graph, node, w, backward, to_next, behind_heap, forward)
        if forward[node] is Some(ahead) {
          let total = ahead + behind_min
          if total < best {
            best = total
            meeting = node
          }
        }
      }
    }
  }
  let distance : Array[Double?] = Array::make(n, (None : Double?))
  let previous : Array[Int32?] = Array::make(n, (None : Int32?))
  if meeting < 0 {
    return { distance, previous, }
  }
  distance[to] = Some(best)
  previous[to] = to_next[meeting]
  // Walk the meeting point back to the source, then forward to the target.
  let head : Array[Int32] = [meeting]
  let mut at = meeting
  while at != from {
    match from_parent[at] {
      Some(parent) => {
        head.push(parent)
        at = parent
      }
      None => break
    }
  }
  head.rev_in_place()
  let route = head
  let mut step = meeting
  while step != to {
    match to_next[step] {
      Some(next) => {
        route.push(next)
        step = next
      }
      None => break
    }
  }
  for i in 1..<route.length() {
    distance[route[i]] = Some(best)
    previous[route[i]] = Some(route[i - 1])
  }
  previous[from] = None
  { distance, previous, }
}

///|
/// The node whose forward distance equals the given cost, or -1. The heap popped
/// the cost but not the node, which is the one thing this variant gives up.
fn[G : @moongraph.Topology] node_of_cost(
  graph : G,
  distance : Array[Double?],
  cost : Double,
) -> Int32 {
  for node in 0..<graph.node_count() {
    if distance[node] is Some(d) && d == cost {
      return node
    }
  }
  -1
}

///|
fn[G : @moongraph.Topology] expand_forward(
  graph : G,
  node : Int32,
  w : (Int32) -> Double,
  distance : Array[Double?],
  previous : Array[Int32?],
  heap : @moonstl.PairingHeap[(Double, Int32)],
  other : Array[Double?],
) -> Unit raise @moongraph.Refused {
  let base = distance[node].unwrap()
  let nbrs = graph.neighbors(node)
  let eids = graph.incident(node)
  for at in 0..<eids.length() {
    let edge = eids[at]
    let step = w(edge)
    if step < 0.0 {
      raise @moongraph.Refused::NegativeWeight(edge~)
    }
    let to = nbrs[at]
    let next = base + step
    let better = match distance[to] {
      Some(old) => next < old
      None => true
    }
    if better {
      distance[to] = Some(next)
      previous[to] = Some(node)
      heap.insert((next, to)) |> ignore
    }
  }
  ignore(other)
}

///|
fn[G : @moongraph.Inbound] expand_backward(
  graph : G,
  node : Int32,
  w : (Int32) -> Double,
  distance : Array[Double?],
  next : Array[Int32?],
  heap : @moonstl.PairingHeap[(Double, Int32)],
  other : Array[Double?],
) -> Unit raise @moongraph.Refused {
  let base = distance[node].unwrap()
  let nbrs = @moongraph.Inbound::in_neighbors(graph, node)
  let eids = @moongraph.Inbound::in_incident(graph, node)
  for at in 0..<eids.length() {
    let edge = eids[at]
    let step = w(edge)
    if step < 0.0 {
      raise @moongraph.Refused::NegativeWeight(edge~)
    }
    let to = nbrs[at]
    let next_cost = base + step
    let better = match distance[to] {
      Some(old) => next_cost < old
      None => true
    }
    if better {
      distance[to] = Some(next_cost)
      next[to] = Some(node)
      heap.insert((next_cost, to)) |> ignore
    }
  }
  ignore(other)
}

///|
/// Calls `f` once per arc: `(from, to, edge)`. An undirected edge is offered from
/// both of its endpoints, which is what makes one relaxation pass over the whole
/// graph the same loop for both kinds of graph.
fn[G : @moongraph.Topology] each_arc(
  graph : G,
  f : (Int32, Int32, Int32) -> Unit raise @moongraph.Refused,
) -> Unit raise @moongraph.Refused {
  for node in 0..<@moongraph.Topology::node_count(graph) {
    let nbrs = graph.neighbors(node)
    let eids = graph.incident(node)
    for at in 0..<eids.length() {
      f(node, nbrs[at], eids[at])
    }
  }
}

///|
/// Cheapest routes from one source when edges may be negative.
///
/// Refuses `Cycle` when a cycle is negative: it carries the cycle as the witness,
/// and no shortest path exists to report. A negative edge that leads to no cycle
/// is fine.
pub fn[G : @moongraph.Topology] bellman_ford(
  graph : G,
  source : Int32,
  weight? : (Int32) -> Double,
) -> @moongraph.Paths raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let n = graph.node_count()
  let distance : Array[Double?] = Array::make(n, (None : Double?))
  let previous : Array[Int32?] = Array::make(n, (None : Int32?))
  if source < 0 || source >= n {
    return { distance, previous, }
  }
  distance[source] = Some(0.0)
  let mut changed = true
  for _ in 0..<n {
    if !changed {
      break
    }
    changed = false
    each_arc(graph, fn(from, to, edge) {
      match distance[from] {
        Some(base) => {
          let next = base + w(edge)
          let better = match distance[to] {
            Some(old) => next < old
            None => true
          }
          if better {
            distance[to] = Some(next)
            previous[to] = Some(from)
            changed = true
          }
        }
        None => ()
      }
    })
  }
  // A further pass that still improves something means a negative cycle; the
  // predecessor chain then leads back into it.
  let mut witness = -1
  each_arc(graph, fn(from, to, edge) {
    match distance[from] {
      Some(base) => {
        let next = base + w(edge)
        let better = match distance[to] {
          Some(old) => next < old
          None => true
        }
        if better {
          witness = to
          previous[to] = Some(from)
        }
      }
      None => ()
    }
  })
  if witness >= 0 {
    raise @moongraph.Refused::Cycle(nodes=negative_cycle(previous, witness, n))
  }
  { distance, previous, }
}

///|
/// Walks the predecessor chain far enough to be certain it is inside the cycle,
/// then names it from a node back to itself.
fn negative_cycle(
  previous : Array[Int32?],
  from : Int32,
  n : Int32,
) -> Array[Int32] {
  let mut at = from
  for _ in 0..<n {
    match previous[at] {
      Some(parent) => at = parent
      None => return [from, from]
    }
  }
  let start = at
  let cycle : Array[Int32] = []
  let mut step = start
  while true {
    cycle.push(step)
    match previous[step] {
      Some(parent) => step = parent
      None => break
    }
    if step == start {
      break
    }
  }
  cycle.push(start)
  cycle.rev_in_place()
  cycle
}

///|
/// Cheapest routes from one source by the queue-based relaxation that is
/// Bellman-Ford with the redundant passes skipped. Same answer, usually fewer
/// passes.
pub fn[G : @moongraph.Topology] spfa(
  graph : G,
  source : Int32,
  weight? : (Int32) -> Double,
) -> @moongraph.Paths raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let n = graph.node_count()
  let distance : Array[Double?] = Array::make(n, (None : Double?))
  let previous : Array[Int32?] = Array::make(n, (None : Int32?))
  if source < 0 || source >= n {
    return { distance, previous, }
  }
  let in_queue : Array[Bool] = Array::make(n, false)
  let visits : Array[Int32] = Array::make(n, 0)
  let queue : Array[Int32] = [source]
  distance[source] = Some(0.0)
  in_queue[source] = true
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    in_queue[node] = false
    let base = distance[node].unwrap()
    let nbrs = graph.neighbors(node)
    let eids = graph.incident(node)
    for at in 0..<eids.length() {
      let edge = eids[at]
      let to = nbrs[at]
      let next = base + w(edge)
      let better = match distance[to] {
        Some(old) => next < old
        None => true
      }
      if better {
        distance[to] = Some(next)
        previous[to] = Some(node)
        if !in_queue[to] {
          visits[to] = visits[to] + 1
          if visits[to] > n {
            raise @moongraph.Refused::Cycle(
              nodes=negative_cycle(previous, to, n),
            )
          }
          in_queue[to] = true
          queue.push(to)
        }
      }
    }
  }
  { distance, previous, }
}

///|
/// Every pair, by Johnson's reweighting: one Bellman-Ford pass makes the weights
/// non-negative, then a Dijkstra pass per node.
///
/// Negative edges are fine; only a negative cycle is refused, because that is the
/// one case where no finite answer exists.
pub fn[G : @moongraph.Topology] johnson(
  graph : G,
  weight? : (Int32) -> Double,
) -> @moongraph.AllPairs raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let n = graph.node_count()
  if n == 0 {
    return { distance: [], next: [], }
  }
  // Bellman-Ford from a virtual node joined to every node by a zero edge, which
  // is the same as starting every node at 0.
  let potential : Array[Double] = Array::make(n, 0.0)
  let mut rounds = 0
  let mut changed = true
  while changed && rounds <= n {
    changed = false
    rounds = rounds + 1
    each_arc(graph, fn(from, to, edge) {
      if from < 0 || from >= n || to < 0 || to >= n {
        return
      }
      let next = potential[from] + w(edge)
      if next < potential[to] - 1.0e-12 {
        potential[to] = next
        changed = true
      }
    })
  }
  if changed {
    // An edge that still pays for itself closes a negative cycle.
    let mut offender = -1
    each_arc(graph, fn(from, to, edge) {
      if from >= 0 && from < n && to >= 0 && to < n {
        if potential[from] + w(edge) < potential[to] - 1.0e-12 {
          offender = to
        }
      }
    })
    if offender < 0 {
      offender = 0
    }
    raise @moongraph.Refused::Cycle(nodes=[offender, offender])
  }
  let reweighted = fn(edge) {
    let (from, to) = graph.endpoints(edge)
    w(edge) + potential[from] - potential[to]
  }
  let distance : Array[Array[Double?]] = []
  let next : Array[Array[Int32?]] = []
  for source in 0..<n {
    let paths = search(graph, [source], reweighted, None, None)
    let row : Array[Double?] = Array::make(n, (None : Double?))
    let steps : Array[Int32?] = Array::make(n, (None : Int32?))
    for node in 0..<n {
      match paths.distance[node] {
        Some(d) => {
          row[node] = Some(d - potential[source] + potential[node])
          if node == source {
            steps[node] = Some(node)
          } else {
            match paths.path_to(node) {
              Some(route) =>
                if route.length() > 1 {
                  steps[node] = Some(route[1])
                }
              None => ()
            }
          }
        }
        None => ()
      }
    }
    distance.push(row)
    next.push(steps)
  }
  { distance, next, }
}

///|
/// Every pair, by the triple loop.
///
/// The straightforward method, and still the right one for a dense graph small
/// enough to hold V squared entries: no heap, no repeated relaxation of the same
/// edges, and the negative-cycle check falls out of the diagonal.
pub fn[G : @moongraph.Topology] floyd_warshall(
  graph : G,
  weight? : (Int32) -> Double,
) -> @moongraph.AllPairs raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let n = graph.node_count()
  let distance : Array[Array[Double?]] = Array::makei(n, fn(_) {
    Array::make(n, (None : Double?))
  })
  let next : Array[Array[Int32?]] = Array::makei(n, fn(_) {
    Array::make(n, (None : Int32?))
  })
  for node in 0..<n {
    distance[node][node] = Some(0.0)
  }
  each_arc(graph, fn(from, to, edge) {
    if from < 0 || from >= n || to < 0 || to >= n {
      return
    }
    let step = w(edge)
    let better = match distance[from][to] {
      Some(old) => step < old
      None => true
    }
    if better {
      distance[from][to] = Some(step)
      next[from][to] = Some(to)
    }
  })
  for through in 0..<n {
    for from in 0..<n {
      let first = distance[from][through]
      if first is None {
        continue
      }
      for to in 0..<n {
        match distance[through][to] {
          Some(second) => {
            let total = first.unwrap() + second
            let better = match distance[from][to] {
              Some(old) => total < old
              None => true
            }
            if better {
              distance[from][to] = Some(total)
              next[from][to] = next[from][through]
            }
          }
          None => ()
        }
      }
    }
  }
  for node in 0..<n {
    if distance[node][node] is Some(d) && d < 0.0 {
      raise @moongraph.Refused::Cycle(nodes=[node, node])
    }
  }
  { distance, next, }
}

///|
/// Every pair, by one Dijkstra pass per node.
pub fn[G : @moongraph.Topology] dijkstra_all(
  graph : G,
  weight? : (Int32) -> Double,
) -> @moongraph.AllPairs raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let n = graph.node_count()
  all_pairs_of(n, fn(source) raise @moongraph.Refused {
    search(graph, [source], w, None, None)
  })
}

///|
/// Every pair on an unweighted graph, by one breadth-first pass per node. On such
/// a graph this is the fastest all-pairs method there is, and naming it keeps a
/// caller from running Dijkstra over unit weights.
pub fn[G : @moongraph.Topology] bfs_all(graph : G) -> @moongraph.AllPairs {
  let n = graph.node_count()
  let distance : Array[Array[Double?]] = []
  let next : Array[Array[Int32?]] = []
  for source in 0..<n {
    let row : Array[Double?] = Array::make(n, (None : Double?))
    let steps : Array[Int32?] = Array::make(n, (None : Int32?))
    let previous : Array[Int32?] = Array::make(n, (None : Int32?))
    row[source] = Some(0.0)
    let queue : Array[Int32] = [source]
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      let step = row[node].unwrap() + 1.0
      for nbr in graph.neighbors(node) {
        if row[nbr] is None {
          row[nbr] = Some(step)
          previous[nbr] = Some(node)
          queue.push(nbr)
        }
      }
    }
    for node in 0..<n {
      if node == source {
        steps[node] = Some(node)
      } else if previous[node] is Some(_) {
        let mut at = node
        while previous[at] is Some(back) && back != source {
          at = back
        }
        steps[node] = Some(at)
      }
    }
    distance.push(row)
    next.push(steps)
  }
  { distance, next, }
}

///|
/// Turns one-source results into the all-pairs record, filling the successor
/// matrix from the reconstructed routes.
fn all_pairs_of(
  n : Int32,
  run : (Int32) -> @moongraph.Paths raise @moongraph.Refused,
) -> @moongraph.AllPairs raise @moongraph.Refused {
  let distance : Array[Array[Double?]] = []
  let next : Array[Array[Int32?]] = []
  for source in 0..<n {
    let paths = run(source)
    let steps : Array[Int32?] = Array::make(n, (None : Int32?))
    for node in 0..<n {
      if node == source {
        steps[node] = Some(node)
      } else {
        match paths.path_to(node) {
          Some(route) => if route.length() > 1 { steps[node] = Some(route[1]) }
          None => ()
        }
      }
    }
    distance.push(paths.distance)
    next.push(steps)
  }
  { distance, next, }
}

///|
/// The cheapest route between two nodes with a hint to steer the search.
///
/// `estimate` must never overestimate the cost from a node to the target;
/// a hint that does is not checked, because checking it costs more than the
/// search. Refuses `NoSolution` when the target cannot be reached at all, which
/// a caller that asked for one route wants to hear rather than receive an empty
/// record.
pub fn[G : @moongraph.Topology] astar(
  graph : G,
  from : Int32,
  to : Int32,
  weight? : (Int32) -> Double,
  estimate~ : (Int32) -> Double,
) -> @moongraph.Paths raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let n = graph.node_count()
  let distance : Array[Double?] = Array::make(n, (None : Double?))
  let previous : Array[Int32?] = Array::make(n, (None : Int32?))
  if from < 0 || from >= n || to < 0 || to >= n {
    raise @moongraph.Refused::NoSolution
  }
  let seen : Array[Bool] = Array::make(n, false)
  let heap = @moonstl.PairingHeap::new_by(cmp=@internal.entry_cmp)
  distance[from] = Some(0.0)
  heap.insert((estimate(from), from)) |> ignore
  while heap.pop() is Some((_, node)) {
    if seen[node] {
      continue
    }
    seen[node] = true
    if node == to {
      break
    }
    let base = distance[node].unwrap()
    let nbrs = graph.neighbors(node)
    let eids = graph.incident(node)
    for at in 0..<eids.length() {
      let edge = eids[at]
      let step = w(edge)
      if step < 0.0 {
        raise @moongraph.Refused::NegativeWeight(edge~)
      }
      let nbr = nbrs[at]
      let next = base + step
      let better = match distance[nbr] {
        Some(old) => next < old
        None => true
      }
      if better {
        distance[nbr] = Some(next)
        previous[nbr] = Some(node)
        heap.insert((next + estimate(nbr), nbr)) |> ignore
      }
    }
  }
  if distance[to] is None {
    raise @moongraph.Refused::NoSolution
  }
  { distance, previous, }
}

///|
/// Up to `k` cheapest routes between two nodes, cheapest first, without repeats.
///
/// A route is a node sequence, so two routes that use different parallel edges
/// between the same nodes count as one; the cheapest of those edges is the one the
/// cost is computed with, exactly as `shortest` does.
pub fn[G : @moongraph.Topology] k_shortest(
  graph : G,
  from : Int32,
  to : Int32,
  k : Int32,
  weight? : (Int32) -> Double,
) -> Array[Array[Int32]] raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let out : Array[Array[Int32]] = []
  if k <= 0 {
    return out
  }
  let first = match shortest(graph, from, to, weight=w) {
    Some(route) => route
    None => return out
  }
  out.push(first)
  let candidates : Array[Array[Int32]] = []
  let candidate_cost : Array[Double] = []
  while out.length() < k {
    let previous = out[out.length() - 1]
    for at in 1..<previous.length() {
      let root = previous.exact_view(start=0, end=at).to_owned()
      let spur_from = root[root.length() - 1]
      // A route that shares this root may not reuse the edge it took out of the
      // spur node; banning the whole target node would rule out every route that
      // ends there, which is most of them.
      let banned_edges : Array[Bool] = Array::make(graph.edge_count(), false)
      for route in out {
        if route.length() > at {
          let mut same_root = true
          for i in 0..<at {
            if route[i] != root[i] {
              same_root = false
              break
            }
          }
          if same_root {
            let nbrs = graph.neighbors(spur_from)
            let eids = graph.incident(spur_from)
            for k in 0..<eids.length() {
              if nbrs[k] == route[at] {
                banned_edges[eids[k]] = true
              }
            }
          }
        }
      }
      let paths = search(graph, [spur_from], w, None, Some(banned_edges))
      match paths.path_to(to) {
        Some(spur) => {
          let joined : Array[Int32] = []
          for i in 0..<(root.length() - 1) {
            joined.push(root[i])
          }
          for node in spur {
            joined.push(node)
          }
          if !out.contains(joined) && !candidates.contains(joined) {
            candidates.push(joined)
            candidate_cost.push(cost_of(graph, joined, w))
          }
        }
        None => ()
      }
    }
    if candidates.length() == 0 {
      break
    }
    let mut best = 0
    for i in 1..<candidates.length() {
      if candidate_cost[i] < candidate_cost[best] {
        best = i
      }
    }
    out.push(candidates[best])
    candidates.remove(best) |> ignore
    candidate_cost.remove(best) |> ignore
  }
  out
}

///|
/// The cost of a node sequence, taking the cheapest edge between each pair.
fn[G : @moongraph.Topology] cost_of(
  graph : G,
  route : Array[Int32],
  w : (Int32) -> Double,
) -> Double {
  let mut total = 0.0
  for i in 1..<route.length() {
    match cheapest_edge(graph, route[i - 1], route[i], w) {
      Some(edge) => total = total + w(edge)
      None => ()
    }
  }
  total
}

///|
/// The cheapest edge between two adjacent nodes, which is what a node sequence
/// means when the graph has parallel edges.
fn[G : @moongraph.Topology] cheapest_edge(
  graph : G,
  from : Int32,
  to : Int32,
  w : (Int32) -> Double,
) -> Int32? {
  let nbrs = graph.neighbors(from)
  let eids = graph.incident(from)
  let mut best : Int32? = None
  let mut best_cost = 0.0
  for at in 0..<eids.length() {
    if nbrs[at] == to {
      let edge = eids[at]
      let cost = w(edge)
      if best is None || cost < best_cost {
        best = Some(edge)
        best_cost = cost
      }
    }
  }
  best
}

///|
/// The route that keeps the least capacity as high as possible: the widest path.
///
/// `distance[n]` is the bottleneck of the best route to `n` — the smallest edge
/// weight along it — not the sum. Useful when the weights are capacities,
/// bandwidths or confidences and the route is only as good as its worst link.
pub fn[G : @moongraph.Topology] widest(
  graph : G,
  source : Int32,
  weight? : (Int32) -> Double,
) -> @moongraph.Paths raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let n = graph.node_count()
  let distance : Array[Double?] = Array::make(n, (None : Double?))
  let previous : Array[Int32?] = Array::make(n, (None : Int32?))
  if source < 0 || source >= n {
    return { distance, previous, }
  }
  distance[source] = Some(@double.infinity)
  let heap = @moonstl.PairingHeap::new_by(cmp=@internal.entry_cmp)
  // The heap is a min-heap, so the bottleneck is stored negated.
  heap.insert((-@double.infinity, source)) |> ignore
  let settled : Array[Bool] = Array::make(n, false)
  while heap.pop() is Some((negated, node)) {
    if settled[node] {
      continue
    }
    settled[node] = true
    let base = -negated
    let nbrs = graph.neighbors(node)
    let eids = graph.incident(node)
    for at in 0..<eids.length() {
      let edge = eids[at]
      let to = nbrs[at]
      let step = w(edge)
      if step < 0.0 {
        raise @moongraph.Refused::NegativeWeight(edge~)
      }
      let bottleneck = if base < step { base } else { step }
      let better = match distance[to] {
        Some(old) => bottleneck > old
        None => true
      }
      if better {
        distance[to] = Some(bottleneck)
        previous[to] = Some(node)
        heap.insert((-bottleneck, to)) |> ignore
      }
    }
  }
  { distance, previous, }
}

///|
/// The cheapest route between two nodes, by whichever method the weights allow.
///
/// A graph whose edges are all non-negative takes the Dijkstra path; one with a
/// negative edge takes Bellman-Ford. The check costs one pass over the edges,
/// which is cheaper than making the caller decide.
pub fn[G : @moongraph.Topology] shortest(
  graph : G,
  from : Int32,
  to : Int32,
  weight? : (Int32) -> Double,
) -> Array[Int32]? raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  if from < 0 ||
    from >= graph.node_count() ||
    to < 0 ||
    to >= graph.node_count() {
    return None
  }
  let mut negative = false
  each_arc(graph, fn(_, _, edge) { if w(edge) < 0.0 { negative = true } })
  let paths = if negative {
    bellman_ford(graph, from, weight=w)
  } else {
    dijkstra(graph, from, weight=w)
  }
  paths.path_to(to)
}

///|
/// Whether any route joins the two nodes. Directed graphs follow the edge
/// direction, as every other function here does.
pub fn[G : @moongraph.Topology] has_path(
  graph : G,
  from : Int32,
  to : Int32,
) -> Bool {
  let n = graph.node_count()
  if from < 0 || from >= n || to < 0 || to >= n {
    return false
  }
  if from == to {
    return true
  }
  let seen : Array[Bool] = Array::make(n, false)
  let queue : Array[Int32] = [from]
  seen[from] = true
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    for nbr in graph.neighbors(node) {
      if nbr == to {
        return true
      }
      if !seen[nbr] {
        seen[nbr] = true
        queue.push(nbr)
      }
    }
  }
  false
}

///|
/// The cost of walking a node sequence, taking the cheapest edge between each
/// consecutive pair.
///
/// Refuses `Disconnected` when the sequence names two nodes with no edge between
/// them: a sequence that does not describe a walk has no weight, and answering 0
/// would hide the mistake.
pub fn[G : @moongraph.Topology] path_weight(
  graph : G,
  path : Array[Int32],
  weight? : (Int32) -> Double,
) -> Double raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let mut total = 0.0
  for i in 1..<path.length() {
    match cheapest_edge(graph, path[i - 1], path[i], w) {
      Some(edge) => total = total + w(edge)
      None =>
        raise @moongraph.Refused::Disconnected(from=path[i - 1], to=path[i])
    }
  }
  total
}

///|
/// Every simple route between two nodes, as node sequences, source first.
///
/// Exponential by nature and lazy by construction: a caller takes the first few,
/// or stops, without paying for the rest. The walk visits edges in ascending
/// neighbour number, so the sequence of routes is the same on every run.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (0, 2)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   let routes = @path.all_simple(g, 0, 2).collect()
///   assert_eq(routes, [[0, 1, 2], [0, 2]])
/// }
/// ```
pub fn[G : @moongraph.Topology] all_simple(
  graph : G,
  from : Int32,
  to : Int32,
) -> Iter[Array[Int32]] {
  let n = graph.node_count()
  if from < 0 || from >= n || to < 0 || to >= n {
    return ([] : Array[Array[Int32]]).iter()
  }
  let walk = SimpleWalk::{
    graph,
    source: from,
    target: to,
    on_path: Array::make(n, false),
    path: [],
    edges_path: [],
    stack: [],
    started: false,
    done: false,
  }
  Iter::new(fn() { walk.next_nodes() })
}

///|
/// The same routes, named by edge number instead of by node.
pub fn[G : @moongraph.Topology] all_simple_edges(
  graph : G,
  from : Int32,
  to : Int32,
) -> Iter[Array[Int32]] {
  let n = graph.node_count()
  if from < 0 || from >= n || to < 0 || to >= n {
    return ([] : Array[Array[Int32]]).iter()
  }
  let walk = SimpleWalk::{
    graph,
    source: from,
    target: to,
    on_path: Array::make(n, false),
    path: [],
    edges_path: [],
    stack: [],
    started: false,
    done: false,
  }
  Iter::new(fn() { walk.next_edges() })
}

///|
/// The state of a lazy enumeration of simple routes, advanced one route per call.
///
/// The stack holds one frame per node on the current route: the node, its sorted
/// edges, and how many of them have been tried. That is the recursion of the
/// textbook algorithm written out, which is what lets the enumeration pause
/// between routes instead of building every one up front.
priv struct SimpleWalk[G] {
  graph : G
  source : Int32
  target : Int32
  on_path : Array[Bool]
  path : Array[Int32]
  edges_path : Array[Int32]
  stack : Array[(Int32, Array[(Int32, Int32)], Int32)]
  mut started : Bool
  mut done : Bool
}

///|
fn[G : @moongraph.Topology] SimpleWalk::next_nodes(
  self : SimpleWalk[G],
) -> Array[Int32]? {
  match self.advance() {
    Some((route, _)) => Some(route)
    None => None
  }
}

///|
fn[G : @moongraph.Topology] SimpleWalk::next_edges(
  self : SimpleWalk[G],
) -> Array[Int32]? {
  match self.advance() {
    Some((_, edges)) => Some(edges)
    None => None
  }
}

///|
/// One step of the walk: the next complete route, or nothing when every branch has
/// been tried.
fn[G : @moongraph.Topology] SimpleWalk::advance(
  self : SimpleWalk[G],
) -> (Array[Int32], Array[Int32])? {
  if self.done {
    return None
  }
  if !self.started {
    self.started = true
    if self.source == self.target {
      self.done = true
      return Some(([self.source], []))
    }
    self.on_path[self.source] = true
    self.path.push(self.source)
    self.stack.push(
      (self.source, @internal.out_edges(self.graph, self.source), 0),
    )
  }
  while self.stack.length() > 0 {
    let top = self.stack.length() - 1
    let (node, edges, at) = self.stack[top]
    if at < edges.length() {
      self.stack[top] = (node, edges, at + 1)
      let (nbr, eid) = edges[at]
      if !self.on_path[nbr] {
        if nbr == self.target {
          let route = self.path.copy()
          route.push(self.target)
          let used = self.edges_path.copy()
          used.push(eid)
          return Some((route, used))
        }
        self.on_path[nbr] = true
        self.path.push(nbr)
        self.edges_path.push(eid)
        self.stack.push((nbr, @internal.out_edges(self.graph, nbr), 0))
      }
    } else {
      self.on_path[node] = false
      self.path.pop() |> ignore
      self.edges_path.pop() |> ignore
      self.stack.pop() |> ignore
    }
  }
  self.done = true
  None
}

///|
/// Whether a node sequence is a simple path: every node distinct, and every
/// consecutive pair joined by an edge.
pub fn[G : @moongraph.Topology] is_simple_path(
  graph : G,
  path : Array[Int32],
) -> Bool {
  if path.length() == 0 {
    return false
  }
  let seen : Array[Int32] = []
  for node in path {
    if node < 0 || node >= graph.node_count() {
      return false
    }
    if seen.contains(node) {
      return false
    }
    seen.push(node)
  }
  for i in 1..<path.length() {
    let nbrs = graph.neighbors(path[i - 1])
    let mut joined = false
    for nbr in nbrs {
      if nbr == path[i] {
        joined = true
        break
      }
    }
    if !joined {
      return false
    }
  }
  true
}
