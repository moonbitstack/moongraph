// Approximations with a promised bound.

///|
/// A tour that visits every node and returns to the start, by taking the nearest unvisited
/// node each step and then straightening the result.
///
/// Refuses `Disconnected`: no tour exists through a graph in pieces. The answer is within a
/// logarithmic factor at worst and usually much closer.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (2, 0)],
///     node=(),
///     edge=1.0,
///     directed=false,
///   )
///   let tour = @approx.traveling_salesman(g, start=0, weight=g.weights(fn(w) { w }))
///   assert_eq(tour.length(), 4)
/// }
/// ```
pub fn[G : @moongraph.Topology] traveling_salesman(
  graph : G,
  start~ : Int,
  weight? : (Int) -> Double,
) -> Array[Int] raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let n = @moongraph.Topology::node_count(graph)
  if n == 0 {
    return []
  }
  let tour : Array[Int] = [start]
  let visited : Array[Bool] = Array::make(n, false)
  visited[start] = true
  let mut at = start
  for _ in 1..<n {
    let mut best = -1
    let mut best_cost = 0.0
    for nbr in @internal.distinct_neighbors(graph, at) {
      if visited[nbr] {
        continue
      }
      let cost = match @internal.cheapest(graph, at, nbr, w) {
        Some(edge) => w(edge)
        None => 0.0
      }
      if best < 0 || cost < best_cost {
        best = nbr
        best_cost = cost
      }
    }
    if best < 0 {
      raise @moongraph.Refused::Disconnected(from=at, to=start)
    }
    visited[best] = true
    tour.push(best)
    at = best
  }
  tour.push(start)
  improve(graph, tour, w)
  tour
}

///|
/// Straightens the tour by swapping pairs of stops while the tour gets shorter, which is the
/// two-opt step.
fn[G : @moongraph.Topology] improve(
  graph : G,
  tour : Array[Int],
  w : (Int) -> Double,
) -> Unit {
  let mut rounds = 0
  let size = tour.length()
  while rounds < size * 2 {
    rounds = rounds + 1
    let mut improved = false
    for i in 1..<(size - 2) {
      for j in (i + 1)..<(size - 1) {
        let before = leg(graph, tour[i - 1], tour[i], w) + leg(graph, tour[j], tour[j + 1], w)
        let after = leg(graph, tour[i - 1], tour[j], w) + leg(graph, tour[i], tour[j + 1], w)
        if after + 1.0e-12 < before {
          // Reverse the stretch between the two stops.
          let mut left = i
          let mut right = j
          while left < right {
            let swap = tour[left]
            tour[left] = tour[right]
            tour[right] = swap
            left = left + 1
            right = right - 1
          }
          improved = true
        }
      }
    }
    if !improved {
      break
    }
  }
}

///|
fn[G : @moongraph.Topology] leg(
  graph : G,
  from : Int,
  to : Int,
  w : (Int) -> Double,
) -> Double {
  match @internal.cheapest(graph, from, to, w) {
    Some(edge) => w(edge)
    None => 0.0
  }
}

///|
/// A set of nodes that touches every edge, at most twice the smallest such set.
///
/// Both endpoints of every edge are taken, which is exact for a graph whose edges share no
/// node and never worse than twice the optimum elsewhere.
pub fn[G : @moongraph.Topology] vertex_cover(
  graph : G,
) -> Array[Int] {
  let n = @moongraph.Topology::node_count(graph)
  let taken : Array[Bool] = Array::make(n, false)
  let counted : Array[Bool] = Array::make(@moongraph.Topology::edge_count(graph), false)
  for node in 0..<n {
    let eids = @moongraph.Topology::incident(graph, node)
    for edge in eids {
      if edge >= 0 && edge < counted.length() && !counted[edge] {
        counted[edge] = true
        let (a, b) = @moongraph.Topology::endpoints(graph, edge)
        if a >= 0 && a < n {
          taken[a] = true
        }
        if b >= 0 && b < n {
          taken[b] = true
        }
      }
    }
  }
  let out : Array[Int] = []
  for node in 0..<n {
    if taken[node] {
      out.push(node)
    }
  }
  out
}

///|
/// A set of nodes every other node is joined to or part of, by taking the highest-degree node
/// until none is left uncovered.
pub fn[G : @moongraph.Topology] dominating_set(
  graph : G,
) -> Array[Int] {
  let n = @moongraph.Topology::node_count(graph)
  let covered : Array[Bool] = Array::make(n, false)
  let out : Array[Int] = []
  let mut left = n
  while left > 0 {
    let mut pick = -1
    let mut best = -1
    for node in 0..<n {
      if covered[node] {
        continue
      }
      let mut reach = 1
      for nbr in @internal.distinct_neighbors(graph, node) {
        if !covered[nbr] {
          reach = reach + 1
        }
      }
      if reach > best {
        best = reach
        pick = node
      }
    }
    if pick < 0 {
      break
    }
    out.push(pick)
    if !covered[pick] {
      covered[pick] = true
      left = left - 1
    }
    for nbr in @internal.distinct_neighbors(graph, pick) {
      if !covered[nbr] {
        covered[nbr] = true
        left = left - 1
      }
    }
  }
  out
}

///|
/// The subgraph with the most edges per node, by peeling away the node of least degree until
/// the density stops rising.
pub fn[G : @moongraph.Topology] densest_subgraph(
  graph : G,
) -> Array[Int] {
  let n = @moongraph.Topology::node_count(graph)
  let alive : Array[Bool] = Array::make(n, true)
  let degree : Array[Int] = Array::make(n, 0)
  for node in 0..<n {
    degree[node] = @internal.distinct_neighbors(graph, node).length()
  }
  let mut edges = @moongraph.Topology::edge_count(graph)
  let mut best_density = 0.0
  let mut best : Array[Int] = []
  let mut nodes = n
  for _ in 0..<n {
    if nodes == 0 {
      break
    }
    let density = edges.to_double() / nodes.to_double()
    if density > best_density {
      best_density = density
      best = []
      for node in 0..<n {
        if alive[node] {
          best.push(node)
        }
      }
    }
    let mut pick = -1
    for node in 0..<n {
      if alive[node] && (pick < 0 || degree[node] < degree[pick]) {
        pick = node
      }
    }
    if pick < 0 {
      break
    }
    alive[pick] = false
    nodes = nodes - 1
    edges = edges - degree[pick]
    for nbr in @internal.distinct_neighbors(graph, pick) {
      if alive[nbr] {
        degree[nbr] = degree[nbr] - 1
      }
    }
  }
  best
}

///|
/// A subgraph that keeps every short route short: the distance between any two nodes grows by
/// at most the given factor, and the spanner has far fewer edges than the original.
pub fn[G : @moongraph.Topology] spanner(
  graph : G,
  stretch~ : Int = 2,
) -> @moongraph.Graph[Int, Unit] {
  let n = @moongraph.Topology::node_count(graph)
  let out : @moongraph.Graph[Int, Unit] = @moongraph.Graph::new(
    directed=@moongraph.Topology::directed(graph),
  )
  for node in 0..<n {
    out.add_node(node) |> ignore
  }
  // Breadth-first from each node in turn, keeping the first edge that reaches a node whose
  // current distance is above the stretch.
  let distance : Array[Int] = Array::make(n, -1)
  for start in 0..<n {
    for node in 0..<n {
      distance[node] = -1
    }
    distance[start] = 0
    let queue : Array[Int] = [start]
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      for nbr in @internal.distinct_neighbors(graph, node) {
        if distance[nbr] < 0 {
          distance[nbr] = distance[node] + 1
          queue.push(nbr)
          if out.find_edge(node, nbr) is None {
            out.add_edge(node, nbr, ()) |> ignore
          }
        } else if distance[nbr] == distance[node] + 1 && distance[nbr] <= stretch {
          if out.find_edge(node, nbr) is None {
            out.add_edge(node, nbr, ()) |> ignore
          }
        }
      }
    }
  }
  out
}

///|
/// An upper bound on the treewidth, by eliminating the node of least degree and remembering
/// the largest neighbourhood that had to be made a clique.
pub fn[G : @moongraph.Topology] treewidth_bound(graph : G) -> Int {
  let n = @moongraph.Topology::node_count(graph)
  let alive : Array[Bool] = Array::make(n, true)
  let neighbours : Array[Array[Int]] = Array::makei(n, fn(i) {
    @internal.distinct_neighbors(graph, i)
  })
  let mut width = 0
  for _ in 0..<n {
    let mut pick = -1
    for node in 0..<n {
      if alive[node] && (pick < 0 || neighbours[node].length() < neighbours[pick].length()) {
        pick = node
      }
    }
    if pick < 0 {
      break
    }
    let size = neighbours[pick].length()
    if size > width {
      width = size
    }
    // Eliminating a node makes its neighbours a clique: every pair not yet joined is added.
    let group = neighbours[pick]
    for i in 0..<group.length() {
      for j in (i + 1)..<group.length() {
        if !neighbours[group[i]].contains(group[j]) {
          neighbours[group[i]].push(group[j])
          neighbours[group[j]].push(group[i])
        }
      }
    }
    for other in group {
      neighbours[other] = neighbours[other].filter(fn(node) { node != pick })
    }
    alive[pick] = false
  }
  width
}

///|
/// The graph with every edge cut and reattached somewhere else, keeping the degree sequence.
pub fn[G : @moongraph.Topology] random_rewire(
  graph : G,
  rng~ : &@contract.Rng,
) -> @moongraph.Graph[Int, Unit] {
  let n = @moongraph.Topology::node_count(graph)
  let out : @moongraph.Graph[Int, Unit] = @moongraph.Graph::new(
    directed=@moongraph.Topology::directed(graph),
  )
  for node in 0..<n {
    out.add_node(node) |> ignore
  }
  for edge in 0..<@moongraph.Topology::edge_count(graph) {
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    if a < 0 || b < 0 {
      continue
    }
    // The first endpoint stays, the second is redrawn.
    let target = @moonrand.randint(rng, 0, n.to_int64()).to_int()
    let other = if target != a { target } else { b }
    if out.find_edge(a, other) is None {
      out.add_edge(a, other, ()) |> ignore
    } else {
      out.add_edge(a, b, ()) |> ignore
    }
  }
  out
}
