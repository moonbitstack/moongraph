// The measures of how much a node matters.

///|
/// The share of nodes a node is joined to.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (0, 2)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   let scores = @centrality.degree_centrality(g)
///   assert_eq(scores.score[0], 1.0)
/// }
/// ```
pub fn[G : @moongraph.Topology] degree_centrality(
  graph : G,
) -> @moongraph.Scores {
  let n = @moongraph.Topology::node_count(graph)
  let score : Array[Double] = Array::make(n, 0.0)
  let scale = if n > 1 { n - 1 } else { 1 }
  for node in 0..<n {
    score[node] = @internal.distinct_neighbors(graph, node).length().to_double() /
      scale.to_double()
  }
  { score, }
}

///|
/// One over the total distance from a node to every other, so a node at the middle of the
/// graph scores highest.
pub fn[G : @moongraph.Topology] closeness_centrality(
  graph : G,
) -> @moongraph.Scores {
  let n = @moongraph.Topology::node_count(graph)
  let score : Array[Double] = Array::make(n, 0.0)
  for start in 0..<n {
    let depth = hops(graph, start)
    let mut total = 0
    let mut reached = 0
    for other in 0..<n {
      if other != start && depth[other] > 0 {
        total = total + depth[other]
        reached = reached + 1
      }
    }
    if total > 0 {
      // Scaled by the share of the graph that was reached, so a sparse graph is not
      // rewarded for having little to walk.
      let reach = reached.to_double() / (n - 1).to_double()
      score[start] = reach * reach * (n - 1).to_double() / total.to_double()
    }
  }
  { score, }
}

///|
/// The number of shortest routes that pass through each node, halved for an undirected
/// graph so that a route counts once.
pub fn[G : @moongraph.Topology] betweenness_centrality(
  graph : G,
) -> @moongraph.Scores {
  let n = @moongraph.Topology::node_count(graph)
  let score : Array[Double] = Array::make(n, 0.0)
  for source in 0..<n {
    let stack : Array[Int32] = []
    let paths : Array[Double] = Array::make(n, 0.0)
    let depth : Array[Int32] = Array::make(n, -1)
    let parents : Array[Array[Int32]] = Array::makei(n, fn(_) {
      ([] : Array[Int32])
    })
    paths[source] = 1.0
    depth[source] = 0
    let queue : Array[Int32] = [source]
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      stack.push(node)
      for nbr in @internal.distinct_neighbors(graph, node) {
        if depth[nbr] < 0 {
          depth[nbr] = depth[node] + 1
          queue.push(nbr)
        }
        if depth[nbr] == depth[node] + 1 {
          paths[nbr] = paths[nbr] + paths[node]
          parents[nbr].push(node)
        }
      }
    }
    let credit : Array[Double] = Array::make(n, 0.0)
    let mut at = stack.length() - 1
    while at >= 0 {
      let node = stack[at]
      at = at - 1
      for parent in parents[node] {
        if paths[node] > 0.0 {
          credit[parent] = credit[parent] +
            paths[parent] / paths[node] * (1.0 + credit[node])
        }
      }
      if node != source {
        score[node] = score[node] + credit[node]
      }
    }
  }
  if !@moongraph.Topology::directed(graph) {
    for node in 0..<n {
      score[node] = score[node] / 2.0
    }
  } else {
    ()
  }
  { score, }
}

///|
/// The number of shortest routes that use each edge.
pub fn[G : @moongraph.Topology] edge_betweenness(graph : G) -> Array[Double] {
  let n = @moongraph.Topology::node_count(graph)
  let edge_count = @moongraph.Topology::edge_count(graph)
  let score : Array[Double] = Array::make(edge_count, 0.0)
  for source in 0..<n {
    let paths : Array[Double] = Array::make(n, 0.0)
    let depth : Array[Int32] = Array::make(n, -1)
    let parents : Array[Array[Int32]] = Array::makei(n, fn(_) {
      ([] : Array[Int32])
    })
    let parent_edge : Array[Array[Int32]] = Array::makei(n, fn(_) {
      ([] : Array[Int32])
    })
    paths[source] = 1.0
    depth[source] = 0
    let queue : Array[Int32] = [source]
    let stack : Array[Int32] = []
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      stack.push(node)
      let nbrs = @moongraph.Topology::neighbors(graph, node)
      let eids = @moongraph.Topology::incident(graph, node)
      let seen_here : Array[Int32] = []
      for at in 0..<eids.length() {
        let nbr = nbrs[at]
        if seen_here.contains(nbr) {
          continue
        }
        seen_here.push(nbr)
        if depth[nbr] < 0 {
          depth[nbr] = depth[node] + 1
          queue.push(nbr)
        }
        if depth[nbr] == depth[node] + 1 {
          paths[nbr] = paths[nbr] + paths[node]
          parents[nbr].push(node)
          parent_edge[nbr].push(eids[at])
        }
      }
    }
    let credit : Array[Double] = Array::make(n, 0.0)
    let mut at = stack.length() - 1
    while at >= 0 {
      let node = stack[at]
      at = at - 1
      // The route from the source to this node is one path an edge can carry; the
      // source itself is not a route, so it contributes nothing above the credit it
      // already has.
      let own = if node == source { 0.0 } else { 1.0 }
      for i in 0..<parents[node].length() {
        let parent = parents[node][i]
        let edge = parent_edge[node][i]
        if paths[node] > 0.0 {
          let share = paths[parent] / paths[node] * (own + credit[node])
          credit[parent] = credit[parent] + share
          score[edge] = score[edge] + share
        }
      }
    }
  }
  if !@moongraph.Topology::directed(graph) {
    for edge in 0..<edge_count {
      score[edge] = score[edge] / 2.0
    }
  } else {
    ()
  }
  score
}

///|
/// The score a walk that keeps stepping to a neighbour settles on, by power iteration
/// over the adjacency matrix.
pub fn[G : @moongraph.Topology] eigenvector_centrality(
  graph : G,
  iterations~ : Int32 = 100,
  tolerance~ : Double = 1.0e-9,
) -> @moongraph.Scores {
  let n = @moongraph.Topology::node_count(graph)
  let score : Array[Double] = Array::make(n, 0.0)
  if n == 0 {
    return { score, }
  }
  for node in 0..<n {
    score[node] = 1.0
  }
  for _ in 0..<iterations {
    let next : Array[Double] = Array::make(n, 0.0)
    for node in 0..<n {
      for nbr in @internal.distinct_neighbors(graph, node) {
        next[nbr] = next[nbr] + score[node]
      }
    }
    let norm = magnitude(next)
    if norm == 0.0 {
      break
    }
    let mut moved = 0.0
    for node in 0..<n {
      let value = next[node] / norm
      let delta = value - score[node]
      moved = moved + (if delta < 0.0 { -delta } else { delta })
      score[node] = value
    }
    if moved < tolerance {
      break
    }
  }
  { score, }
}

///|
fn magnitude(values : Array[Double]) -> Double {
  let mut total = 0.0
  for value in values {
    total = total + value * value
  }
  square_root(total)
}

///|
fn square_root(value : Double) -> Double {
  if value <= 0.0 {
    return 0.0
  }
  let mut guess = if value > 1.0 { value } else { 1.0 }
  for _ in 0..<60 {
    guess = 0.5 * (guess + value / guess)
  }
  guess
}

///|
/// PageRank: the share of a walk's time each node holds, with a jump back to a random
/// node now and then.
///
/// `damping` is the chance of following an edge instead of jumping, 0.85 by default,
/// which is the value the original paper settled on.
pub fn[G : @moongraph.Topology] pagerank(
  graph : G,
  damping~ : Double = 0.85,
  iterations~ : Int32 = 100,
  tolerance~ : Double = 1.0e-9,
) -> @moongraph.Scores {
  let n = @moongraph.Topology::node_count(graph)
  let score : Array[Double] = Array::make(n, 0.0)
  if n == 0 {
    return { score, }
  }
  let uniform = 1.0 / n.to_double()
  for node in 0..<n {
    score[node] = uniform
  }
  let out_degree : Array[Int32] = Array::make(n, 0)
  for node in 0..<n {
    out_degree[node] = @internal.distinct_neighbors(graph, node).length()
  }
  for _ in 0..<iterations {
    let next : Array[Double] = Array::make(n, 0.0)
    let mut dangling = 0.0
    for node in 0..<n {
      if out_degree[node] == 0 {
        dangling = dangling + score[node]
      } else {
        let share = score[node] / out_degree[node].to_double()
        for nbr in @internal.distinct_neighbors(graph, node) {
          next[nbr] = next[nbr] + share
        }
      }
    }
    let mut moved = 0.0
    for node in 0..<n {
      let value = (1.0 - damping) * uniform +
        damping * (next[node] + dangling * uniform)
      let delta = value - score[node]
      moved = moved + (if delta < 0.0 { -delta } else { delta })
      score[node] = value
    }
    if moved < tolerance {
      break
    }
  }
  { score, }
}

///|
/// The hub and authority scores a link graph implies, by the iteration that gives each
/// node the sum of its neighbours' authority and the other way round.
pub fn[G : @moongraph.Topology] hits(
  graph : G,
  iterations~ : Int32 = 100,
) -> (@moongraph.Scores, @moongraph.Scores) {
  let n = @moongraph.Topology::node_count(graph)
  let hub : Array[Double] = Array::make(n, 1.0)
  let authority : Array[Double] = Array::make(n, 1.0)
  for _ in 0..<iterations {
    let next_authority : Array[Double] = Array::make(n, 0.0)
    for node in 0..<n {
      for nbr in @internal.distinct_neighbors(graph, node) {
        next_authority[nbr] = next_authority[nbr] + hub[node]
      }
    }
    let authority_norm = magnitude(next_authority)
    if authority_norm > 0.0 {
      for node in 0..<n {
        authority[node] = next_authority[node] / authority_norm
      }
    }
    let next_hub : Array[Double] = Array::make(n, 0.0)
    for node in 0..<n {
      for nbr in @internal.distinct_neighbors(graph, node) {
        next_hub[node] = next_hub[node] + authority[nbr]
      }
    }
    let hub_norm = magnitude(next_hub)
    if hub_norm > 0.0 {
      for node in 0..<n {
        hub[node] = next_hub[node] / hub_norm
      }
    }
  }
  ({ score: hub, }, { score: authority, })
}

///|
/// Katz centrality: every route between two nodes counts, with longer routes counting
/// less, which makes it work on graphs a power iteration would stall on.
pub fn[G : @moongraph.Topology] katz(
  graph : G,
  alpha~ : Double = 0.1,
  beta~ : Double = 1.0,
  iterations~ : Int32 = 100,
) -> @moongraph.Scores {
  let n = @moongraph.Topology::node_count(graph)
  let mut score : Array[Double] = Array::make(n, 0.0)
  for _ in 0..<iterations {
    let next : Array[Double] = Array::make(n, 0.0)
    for node in 0..<n {
      let mut total = 0.0
      for nbr in @internal.distinct_neighbors(graph, node) {
        total = total + score[nbr]
      }
      next[node] = beta + alpha * total
    }
    score = next
  }
  { score, }
}

///|
/// Harmonic centrality: the sum of one over the distance to every other node, which is
/// defined even when the graph is not connected.
pub fn[G : @moongraph.Topology] harmonic_centrality(
  graph : G,
) -> @moongraph.Scores {
  let n = @moongraph.Topology::node_count(graph)
  let score : Array[Double] = Array::make(n, 0.0)
  for start in 0..<n {
    let depth = hops(graph, start)
    for other in 0..<n {
      if other != start && depth[other] > 0 {
        score[start] = score[start] + 1.0 / depth[other].to_double()
      }
    }
  }
  { score, }
}

///|
/// Load centrality: the share of the shortest routes through each node when every pair
/// sends one unit, counted without halving.
pub fn[G : @moongraph.Topology] load_centrality(graph : G) -> @moongraph.Scores {
  let scores = betweenness_centrality(graph)
  let score = scores.score.copy()
  if !@moongraph.Topology::directed(graph) {
    for node in 0..<score.length() {
      score[node] = score[node] * 2.0
    }
  }
  { score, }
}

///|
/// Subgraph centrality: the weighted count of closed routes from a node back to itself,
/// longer ones counting less.
pub fn[G : @moongraph.Topology] subgraph_centrality(
  graph : G,
) -> @moongraph.Scores {
  let n = @moongraph.Topology::node_count(graph)
  let score : Array[Double] = Array::make(n, 0.0)
  // Walking the matrix powers for a few steps is enough for the order of the nodes to
  // settle, and it keeps the cost linear in the edges per step.
  let mut vector : Array[Double] = Array::make(n, 1.0)
  let mut fact = 1.0
  for step in 0..<12 {
    if step > 0 {
      fact = fact * step.to_double()
    }
    for node in 0..<n {
      score[node] = score[node] + vector[node] / fact
    }
    let next : Array[Double] = Array::make(n, 0.0)
    for node in 0..<n {
      for nbr in @internal.distinct_neighbors(graph, node) {
        next[nbr] = next[nbr] + vector[node]
      }
    }
    vector = next
  }
  { score, }
}

///|
/// How central a whole set is, read as the routes that pass through any member.
pub fn[G : @moongraph.Topology] group_betweenness(
  graph : G,
  group : Array[Int32],
) -> Double {
  let n = @moongraph.Topology::node_count(graph)
  let inside : Array[Bool] = Array::make(n, false)
  for node in group {
    if node >= 0 && node < n {
      inside[node] = true
    }
  }
  let mut total = 0.0
  for source in 0..<n {
    if inside[source] {
      continue
    }
    let paths : Array[Double] = Array::make(n, 0.0)
    let depth : Array[Int32] = Array::make(n, -1)
    let parents : Array[Array[Int32]] = Array::makei(n, fn(_) {
      ([] : Array[Int32])
    })
    paths[source] = 1.0
    depth[source] = 0
    let queue : Array[Int32] = [source]
    let stack : Array[Int32] = []
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      stack.push(node)
      for nbr in @internal.distinct_neighbors(graph, node) {
        if depth[nbr] < 0 {
          depth[nbr] = depth[node] + 1
          queue.push(nbr)
        }
        if depth[nbr] == depth[node] + 1 {
          paths[nbr] = paths[nbr] + paths[node]
          parents[nbr].push(node)
        }
      }
    }
    let credit : Array[Double] = Array::make(n, 0.0)
    let mut at = stack.length() - 1
    while at >= 0 {
      let node = stack[at]
      at = at - 1
      for parent in parents[node] {
        if paths[node] > 0.0 {
          credit[parent] = credit[parent] +
            paths[parent] / paths[node] * (1.0 + credit[node])
        }
      }
      if !inside[node] && node != source {
        total = total + credit[node]
      }
    }
  }
  total
}

///|
/// How close a whole set is to everything else: one over the summed distance from the set.
pub fn[G : @moongraph.Topology] group_closeness(
  graph : G,
  group : Array[Int32],
) -> Double {
  let n = @moongraph.Topology::node_count(graph)
  let best : Array[Int32] = Array::make(n, -1)
  for node in group {
    if node < 0 || node >= n {
      continue
    }
    let depth = hops(graph, node)
    for other in 0..<n {
      if depth[other] >= 0 && (best[other] < 0 || depth[other] < best[other]) {
        best[other] = depth[other]
      }
    }
  }
  let mut total = 0.0
  for other in 0..<n {
    if best[other] > 0 {
      total = total + best[other].to_double()
    }
  }
  if total == 0.0 {
    0.0
  } else {
    let outside = n - group.length()
    outside.to_double() / total
  }
}

///|
/// The hops from a node to every other, `-1` where there is no route.
fn[G : @moongraph.Topology] hops(graph : G, start : Int32) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let depth : Array[Int32] = Array::make(n, -1)
  if start < 0 || start >= n {
    return depth
  }
  depth[start] = 0
  let queue : Array[Int32] = [start]
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    for nbr in @internal.distinct_neighbors(graph, node) {
      if depth[nbr] < 0 {
        depth[nbr] = depth[node] + 1
        queue.push(nbr)
      }
    }
  }
  depth
}
