// Ways of cutting a graph into groups that hang together.

///|
/// Groups grown by local search on modularity: every node starts alone, moves to the group
/// that raises modularity most, and the groups are then treated as nodes and the walk
/// repeats.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (2, 0), (3, 4), (4, 5), (5, 3)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   let parts = @community.louvain(g)
///   assert_eq(parts.count, 2)
/// }
/// ```
pub fn[G : @moongraph.Topology] louvain(
  graph : G,
  resolution~ : Double = 1.0,
  rounds~ : Int32 = 8,
) -> @moongraph.Partition {
  let n = @moongraph.Topology::node_count(graph)
  let label : Array[Int32] = Array::makei(n, fn(i) { i })
  let mut count = n
  for _ in 0..<rounds {
    let moved = louvain_pass(graph, label, count, resolution)
    count = moved
    if count == 0 {
      break
    }
  }
  relabel(label, count)
}

///|
/// One pass: for each node, the group that raises modularity most, in place.
///
/// The gain is computed from the edges to each neighbouring group against the group's own
/// weight, which is what makes the pass linear in the edges per round.
fn[G : @moongraph.Topology] louvain_pass(
  graph : G,
  label : Array[Int32],
  count : Int32,
  resolution : Double,
) -> Int32 {
  let n = @moongraph.Topology::node_count(graph)
  let m = @moongraph.Topology::edge_count(graph)
  if m == 0 {
    return 0
  }
  let degrees = Array::make(n, 0)
  for edge in 0..<m {
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    if a >= 0 && a < n {
      degrees[a] = degrees[a] + 1
    }
    if b >= 0 && b < n {
      degrees[b] = degrees[b] + 1
    }
  }
  let totals : Array[Int32] = Array::make(count, 0)
  for node in 0..<n {
    totals[label[node]] = totals[label[node]] + degrees[node]
  }
  let edges = m.to_double()
  let square = 2.0 * edges * edges
  for node in 0..<n {
    let current = label[node]
    // The node is taken out of its group before the gains are compared, so that staying
    // put is scored the same way as moving.
    totals[current] = totals[current] - degrees[node]
    let weights : Array[Int32] = Array::make(count, 0)
    for nbr in @internal.distinct_neighbors(graph, node) {
      if nbr != node {
        weights[label[nbr]] = weights[label[nbr]] + 1
      }
    }
    let mut best = current
    let mut best_gain = -1.0e18
    for group in 0..<count {
      let gain = weights[group].to_double() / edges -
        resolution *
        totals[group].to_double() *
        degrees[node].to_double() /
        square
      if gain > best_gain {
        best_gain = gain
        best = group
      }
    }
    totals[best] = totals[best] + degrees[node]
    label[node] = best
  }
  // A group that lost all its members is folded away by the relabelling at the end.
  compact(label, count)
}

///|
/// Renumbers the labels to a dense range and answers how many groups are left.
fn compact(label : Array[Int32], count : Int32) -> Int32 {
  let remap : Array[Int32] = Array::make(count, -1)
  let mut next = 0
  for node in 0..<label.length() {
    let group = label[node]
    if group >= 0 && group < count {
      if remap[group] < 0 {
        remap[group] = next
        next = next + 1
      }
      label[node] = remap[group]
    }
  }
  next
}

///|
/// The labels as they stand, with the count of distinct ones.
fn relabel(label : Array[Int32], count : Int32) -> @moongraph.Partition {
  let remap : Array[Int32] = Array::make(count, -1)
  let out : Array[Int32] = Array::make(label.length(), 0)
  let mut next = 0
  for node in 0..<label.length() {
    let group = label[node]
    if remap[group] < 0 {
      remap[group] = next
      next = next + 1
    }
    out[node] = remap[group]
  }
  { label: out, count: next, }
}

///|
/// Groups grown by the Leiden walk: local moving, then a refinement that cuts every
/// group into connected pieces, then a fold that treats those pieces as nodes.
///
/// The difference from `louvain` is the refinement. Louvain moves one node at a time
/// and can leave a group split in two, and a group held together only through another
/// group falls apart when that group moves away. Here a node only joins a piece that
/// one of its own neighbours is already in, and the graph is folded along those pieces
/// rather than along the coarse groups, so what comes back is always a set of connected
/// groups — a property the last pass checks on the graph the caller passed in.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (2, 0), (2, 3), (3, 4), (4, 5), (5, 3)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   let parts = @community.leiden(g)
///   assert_eq(parts.count, 2)
/// }
/// ```
pub fn[G : @moongraph.Topology] leiden(
  graph : G,
  resolution~ : Double = 1.0,
  rounds~ : Int32 = 8,
) -> @moongraph.Partition {
  leiden_walk(graph, resolution, rounds)
}

///|
/// Groups found by letting every node shout its label and take the most common one among
/// its neighbours until nothing changes.
///
/// The nodes are visited from the highest number down: visited the other way, the first
/// node to speak owns everything it can reach, and a graph with one bridge would collapse
/// into a single group.
pub fn[G : @moongraph.Topology] label_propagation(
  graph : G,
  rounds~ : Int32 = 20,
) -> @moongraph.Partition {
  let n = @moongraph.Topology::node_count(graph)
  let label : Array[Int32] = Array::makei(n, fn(i) { i })
  for _ in 0..<rounds {
    let mut changed = false
    for step in 0..<n {
      let node = n - 1 - step
      let votes : Array[Int32] = []
      for nbr in @internal.distinct_neighbors(graph, node) {
        votes.push(label[nbr])
      }
      if votes.length() == 0 {
        continue
      }
      votes.sort()
      let mut best = votes[0]
      let mut best_count = 0
      let mut at = 0
      while at < votes.length() {
        let mut stop = at
        while stop < votes.length() && votes[stop] == votes[at] {
          stop = stop + 1
        }
        if stop - at > best_count {
          best_count = stop - at
          best = votes[at]
        }
        at = stop
      }
      if best_count > 0 && label[node] != best {
        // A tie keeps the current label, which stops the whole graph drifting onto one
        // label through a single bridge.
        let own = votes.fold(init=0, fn(acc, value) {
          if value == label[node] {
            acc + 1
          } else {
            acc
          }
        })
        if best_count > own {
          label[node] = best
          changed = true
        }
      }
    }
    if !changed {
      break
    }
  }
  relabel(label, n)
}

///|
/// Groups formed by taking out the edges that carry the most routes, one at a time, and
/// stopping when the graph falls into `count` pieces. The pieces are what comes back.
pub fn[G : @moongraph.Topology] girvan_newman(
  graph : G,
  count : Int32,
) -> @moongraph.Partition {
  let n = @moongraph.Topology::node_count(graph)
  let work : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=@moongraph.Topology::directed(graph),
  )
  for node in 0..<n {
    work.add_node(node) |> ignore
  }
  for edge in 0..<@moongraph.Topology::edge_count(graph) {
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    if a >= 0 && b >= 0 && a < n && b < n {
      work.add_edge(a, b, ()) |> ignore
    }
  }
  let mut parts = pieces(work)
  let mut rounds = 0
  while parts.count < count && parts.count > 0 && rounds < n * n {
    rounds = rounds + 1
    if work.edge_count() == 0 {
      break
    }
    let scores = community_betweenness(work)
    let mut worst = 0
    for edge in 0..<scores.length() {
      if scores[edge] > scores[worst] {
        worst = edge
      }
    }
    work.remove_edge(worst)
    parts = pieces(work)
  }
  parts
}

///|
/// The edge betweenness of a graph, so that the removal above needs no other package.
fn[G : @moongraph.Topology] community_betweenness(graph : G) -> Array[Double] {
  let n = @moongraph.Topology::node_count(graph)
  let score : Array[Double] = Array::make(
    @moongraph.Topology::edge_count(graph),
    0.0,
  )
  for source in 0..<n {
    let paths : Array[Double] = Array::make(n, 0.0)
    let depth : Array[Int32] = Array::make(n, -1)
    let parent_edge : Array[Array[Int32]] = Array::makei(n, fn(_) {
      ([] : Array[Int32])
    })
    let stack : Array[Int32] = []
    paths[source] = 1.0
    depth[source] = 0
    let queue : Array[Int32] = [source]
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      stack.push(node)
      let nbrs = @moongraph.Topology::neighbors(graph, node)
      let eids = @moongraph.Topology::incident(graph, node)
      for at in 0..<eids.length() {
        let nbr = nbrs[at]
        if depth[nbr] < 0 {
          depth[nbr] = depth[node] + 1
          queue.push(nbr)
        }
        if depth[nbr] == depth[node] + 1 {
          paths[nbr] = paths[nbr] + paths[node]
          parent_edge[nbr].push(eids[at])
        }
      }
    }
    let credit : Array[Double] = Array::make(n, 0.0)
    let mut at = stack.length() - 1
    while at >= 0 {
      let node = stack[at]
      at = at - 1
      let own = if node == source { 0.0 } else { 1.0 }
      for i in 0..<parent_edge[node].length() {
        let edge = parent_edge[node][i]
        let (a, b) = @moongraph.Topology::endpoints(graph, edge)
        let parent = if a == node { b } else { a }
        if parent >= 0 && parent < n && paths[node] > 0.0 {
          let share = paths[parent] / paths[node] * (own + credit[node])
          credit[parent] = credit[parent] + share
          score[edge] = score[edge] + share
        }
      }
    }
  }
  if !@moongraph.Topology::directed(graph) {
    for edge in 0..<score.length() {
      score[edge] = score[edge] / 2.0
    }
  }
  score
}

///|
/// The components of the graph, as a partition.
fn[G : @moongraph.Topology] pieces(graph : G) -> @moongraph.Partition {
  let n = @moongraph.Topology::node_count(graph)
  let label : Array[Int32] = Array::make(n, -1)
  let mut count = 0
  for start in 0..<n {
    if label[start] >= 0 {
      continue
    }
    label[start] = count
    let queue : Array[Int32] = [start]
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      for nbr in @moongraph.Topology::neighbors(graph, node) {
        if label[nbr] < 0 {
          label[nbr] = count
          queue.push(nbr)
        }
      }
    }
    count = count + 1
  }
  { label, count, }
}

///|
/// Groups grown greedily on modularity: start from every node alone and merge the pair of
/// groups that raises modularity most, until no merge helps.
pub fn[G : @moongraph.Topology] greedy_modularity(
  graph : G,
) -> @moongraph.Partition {
  let n = @moongraph.Topology::node_count(graph)
  let m = @moongraph.Topology::edge_count(graph)
  let label : Array[Int32] = Array::makei(n, fn(i) { i })
  if n == 0 || m == 0 {
    return { label, count: n, }
  }
  let degrees = Array::make(n, 0)
  for edge in 0..<m {
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    if a >= 0 && a < n {
      degrees[a] = degrees[a] + 1
    }
    if b >= 0 && b < n {
      degrees[b] = degrees[b] + 1
    }
  }
  let connected : Array[Array[Int32]] = Array::makei(n, fn(_) {
    Array::make(n, 0)
  })
  for edge in 0..<m {
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    if a >= 0 && b >= 0 && a < n && b < n && a != b {
      connected[a][b] = connected[a][b] + 1
      connected[b][a] = connected[b][a] + 1
    }
  }
  let totals : Array[Int32] = degrees.copy()
  let mut merge = true
  let scale = 2.0 * m.to_double()
  while merge {
    merge = false
    let mut best_gain = 1.0e-12
    let mut best_pair = (0, 0)
    for a in 0..<n {
      if label[a] != a {
        continue
      }
      for b in (a + 1)..<n {
        if label[b] != b || label[a] == label[b] {
          continue
        }
        if connected[a][b] > 0 {
          let gain = connected[a][b].to_double() -
            totals[a].to_double() * totals[b].to_double() / scale
          if gain > best_gain {
            best_gain = gain
            best_pair = (a, b)
          }
        }
      }
    }
    if best_gain > 1.0e-12 {
      let (a, b) = best_pair
      let from = label[b]
      let into = label[a]
      for node in 0..<n {
        if label[node] == from {
          label[node] = into
        }
      }
      totals[a] = totals[a] + totals[b]
      totals[b] = 0
      for node in 0..<n {
        connected[a][node] = connected[a][node] + connected[b][node]
        connected[node][a] = connected[a][node]
      }
      merge = true
    }
  }
  relabel(label, n)
}

///|
/// The groups of a graph that overlap: the maximal cliques of size at least `k`, merged
/// when they share `k - 1` nodes.
pub fn[G : @moongraph.Topology] k_clique_communities(
  graph : G,
  k : Int32,
) -> @moongraph.Partition {
  let n = @moongraph.Topology::node_count(graph)
  if k < 2 {
    return { label: Array::makei(n, fn(i) { i }), count: n, }
  }
  let cliques = community_cliques(graph, k)
  let parts = @internal.disjoint_new(cliques.length())
  for i in 0..<cliques.length() {
    for j in (i + 1)..<cliques.length() {
      let mut shared = 0
      for node in cliques[i] {
        if cliques[j].contains(node) {
          shared = shared + 1
        }
      }
      if shared >= k - 1 {
        parts.union(i, j) |> ignore
      }
    }
  }
  let label : Array[Int32] = Array::make(n, -1)
  for i in 0..<cliques.length() {
    let group = parts.find(i)
    for node in cliques[i] {
      if label[node] < 0 {
        label[node] = group
      }
    }
  }
  let out : Array[Int32] = Array::make(n, 0)
  for node in 0..<n {
    out[node] = if label[node] < 0 { n + node } else { label[node] }
  }
  relabel(out, n * 2)
}

///|
/// The maximal cliques of at least `size` nodes, which the community walk needs without
/// pulling in another package.
fn[G : @moongraph.Topology] community_cliques(
  graph : G,
  size : Int32,
) -> Array[Array[Int32]] {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Array[Int32]] = []
  for a in 0..<n {
    for b in (a + 1)..<n {
      if size == 2 && @internal.adjacent(graph, a, b) {
        out.push([a, b])
      }
    }
  }
  if size > 2 {
    // Longer cliques are grown one node at a time from the pairs.
    let pairs = community_cliques(graph, 2)
    for pair in pairs {
      let clique = pair.copy()
      for candidate in 0..<n {
        if candidate <= clique[clique.length() - 1] {
          continue
        }
        let mut fits = true
        for node in clique {
          if !@internal.adjacent(graph, node, candidate) {
            fits = false
            break
          }
        }
        if fits {
          clique.push(candidate)
          if clique.length() >= size {
            out.push(clique.copy())
          }
        }
      }
    }
  }
  out
}
