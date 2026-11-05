// Matchings, assignments and edge covers.

///|
/// A maximal matching: no two pairs share a node and no further pair can be added.
///
/// Built by taking the edges in number order and keeping the ones whose endpoints are
/// both free, which is O(E) and gives the same answer every run.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   let m = @matching.matching_maximal(g)
///   assert_eq(m.pairs, [(0, 1)])
/// }
/// ```
pub fn[G : @moongraph.Topology] matching_maximal(
  graph : G,
) -> @moongraph.Matching {
  let n = @moongraph.Topology::node_count(graph)
  let taken : Array[Bool] = Array::make(n, false)
  let pairs : Array[(Int, Int)] = []
  for node in 0..<n {
    if taken[node] {
      continue
    }
    let nbrs = @moongraph.Topology::neighbors(graph, node)
    let eids = @moongraph.Topology::incident(graph, node)
    for at in 0..<eids.length() {
      let other = nbrs[at]
      if other != node && !taken[other] {
        taken[node] = true
        taken[other] = true
        pairs.push((if node < other { node } else { other }, if node < other { other } else { node }))
        break
      }
    }
  }
  { pairs, weight: pairs.length().to_double() }
}

///|
/// A matching of the largest number of pairs, by Edmonds' blossom walk.
///
/// The walk is the general one: it handles an odd cycle by contracting it, which is
/// what separates a matching on a general graph from one on a bipartite graph.
pub fn[G : @moongraph.Topology] matching_maximum(
  graph : G,
  weight? : (Int) -> Double,
) -> @moongraph.Matching {
  let n = @moongraph.Topology::node_count(graph)
  let mate : Array[Int] = Array::make(n, -1)
  let adjacency : Array[Array[Int]] = Array::makei(n, fn(_) { ([] : Array[Int]) })
  for node in 0..<n {
    for nbr in @internal.distinct_neighbors(graph, node) {
      if nbr != node {
        adjacency[node].push(nbr)
      }
    }
  }
  for node in 0..<n {
    if mate[node] < 0 {
      augment(node, mate, adjacency) |> ignore
    }
  }
  let pairs : Array[(Int, Int)] = []
  let mut total = 0.0
  for node in 0..<n {
    let other = mate[node]
    if other > node {
      pairs.push((node, other))
      total = total + pair_weight(graph, node, other, weight)
    }
  }
  { pairs, weight: total }
}

///|
/// The weight of the cheapest edge between a matched pair.
fn[G : @moongraph.Topology] pair_weight(
  graph : G,
  a : Int,
  b : Int,
  weight : ((Int) -> Double)?,
) -> Double {
  match weight {
    None => 1.0
    Some(w) =>
      match @internal.cheapest(graph, a, b, w) {
        Some(edge) => w(edge)
        None => 0.0
      }
  }
}

///|
/// One augmenting walk from a free node, contracting odd cycles as they appear.
fn augment(
  root : Int,
  mate : Array[Int],
  adjacency : Array[Array[Int]],
) -> Bool {
  let n = mate.length()
  let parent : Array[Int] = Array::make(n, -1)
  let base : Array[Int] = Array::makei(n, fn(i) { i })
  let used : Array[Bool] = Array::make(n, false)
  let blossom : Array[Bool] = Array::make(n, false)
  let queue : Array[Int] = [root]
  used[root] = true
  let mut head = 0
  let mut endpoint = -1
  while head < queue.length() && endpoint < 0 {
    let node = queue[head]
    head = head + 1
    for nbr in adjacency[node] {
      if base[node] == base[nbr] || mate[node] == nbr {
        continue
      }
      if nbr == root || (mate[nbr] >= 0 && parent[mate[nbr]] >= 0) {
        // An odd cycle: contract it and carry on from the contracted node.
        let current = lca(node, nbr, parent, base, mate)
        blossom.fill(false)
        mark_blossom(current, node, parent, base, mate, blossom)
        mark_blossom(current, nbr, parent, base, mate, blossom)
        for at in 0..<n {
          if blossom[base[at]] {
            base[at] = current
            if !used[at] {
              used[at] = true
              queue.push(at)
            }
          }
        }
      } else if parent[nbr] < 0 {
        parent[nbr] = node
        if mate[nbr] < 0 {
          endpoint = nbr
          break
        }
        used[mate[nbr]] = true
        queue.push(mate[nbr])
      }
    }
  }
  if endpoint < 0 {
    return false
  }
  // Flip the matching along the route we found.
  let mut at = endpoint
  while at >= 0 {
    let back = parent[at]
    if back < 0 {
      break
    }
    let next = mate[back]
    mate[at] = back
    mate[back] = at
    at = next
  }
  true
}

///|
/// The lowest common ancestor of two nodes in the alternate tree, following the base
/// of each node so a contracted blossom counts as one.
fn lca(
  a : Int,
  b : Int,
  parent : Array[Int],
  base : Array[Int],
  mate : Array[Int],
) -> Int {
  let seen : Array[Bool] = Array::make(parent.length(), false)
  let mut left = a
  let mut steps = 0
  while steps <= parent.length() {
    left = base[left]
    seen[left] = true
    if mate[left] < 0 {
      break
    }
    left = parent[mate[left]]
    if left < 0 {
      break
    }
    steps = steps + 1
  }
  let mut right = b
  let mut steps2 = 0
  while steps2 <= parent.length() {
    right = base[right]
    if seen[right] {
      return right
    }
    if mate[right] < 0 || parent[mate[right]] < 0 {
      break
    }
    right = parent[mate[right]]
    steps2 = steps2 + 1
  }
  right
}

///|
/// Marks the nodes of the blossom from a node up to its base.
fn mark_blossom(
  current : Int,
  node : Int,
  parent : Array[Int],
  base : Array[Int],
  mate : Array[Int],
  blossom : Array[Bool],
) -> Unit {
  let mut at = node
  let mut steps = 0
  while base[at] != current && steps <= parent.length() {
    blossom[base[at]] = true
    blossom[base[mate[at]]] = true
    if parent[mate[at]] < 0 {
      break
    }
    at = parent[mate[at]]
    steps = steps + 1
  }
}

///|
/// The matching of a bipartite graph, by the augmenting walk of König's theorem.
///
/// Refuses `NotA` when the graph does not have two colours, because the walk assumes
/// it does and would otherwise return a smaller matching without saying so.
pub fn[G : @moongraph.Topology] matching_bipartite(
  graph : G,
  weight? : (Int) -> Double,
) -> @moongraph.Matching raise @moongraph.Refused {
  let n = @moongraph.Topology::node_count(graph)
  let side = bipartition(graph)
  match side {
    None =>
      raise @moongraph.Refused::NotA(
        kind="bipartite",
        what="the graph has an odd cycle",
      )
    Some(colour) =>
      match weight {
        None => {
          let mate : Array[Int] = Array::make(n, -1)
          let adjacency : Array[Array[Int]] = Array::makei(n, fn(_) { ([] : Array[Int]) })
          for node in 0..<n {
            for nbr in @internal.distinct_neighbors(graph, node) {
              if colour[node] == 0 && colour[nbr] == 1 {
                adjacency[node].push(nbr)
              }
            }
          }
          for node in 0..<n {
            if colour[node] == 0 && mate[node] < 0 {
              augment_bipartite(node, adjacency, mate, Array::make(n, false)) |> ignore
            }
          }
          collect(n, mate, graph, None)
        }
        Some(w) => assignment_on(graph, colour, w)
      }
  }
}

///|
/// One augmenting walk that only moves from the left side to the right.
fn augment_bipartite(
  node : Int,
  adjacency : Array[Array[Int]],
  mate : Array[Int],
  seen : Array[Bool],
) -> Bool {
  for nbr in adjacency[node] {
    if seen[nbr] {
      continue
    }
    seen[nbr] = true
    if mate[nbr] < 0 || augment_bipartite(mate[nbr], adjacency, mate, seen) {
      mate[nbr] = node
      mate[node] = nbr
      return true
    }
  }
  false
}

///|
/// A two-colouring of the graph, or `None` when an odd cycle makes one impossible.
pub fn[G : @moongraph.Topology] bipartition(graph : G) -> Array[Int]? {
  let n = @moongraph.Topology::node_count(graph)
  let colour : Array[Int] = Array::make(n, -1)
  for start in 0..<n {
    if colour[start] >= 0 {
      continue
    }
    colour[start] = 0
    let queue : Array[Int] = [start]
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      for nbr in @moongraph.Topology::neighbors(graph, node) {
        if nbr == node {
          return None
        }
        if colour[nbr] < 0 {
          colour[nbr] = 1 - colour[node]
          queue.push(nbr)
        } else if colour[nbr] == colour[node] {
          return None
        }
      }
    }
  }
  Some(colour)
}

///|
/// An assignment of the left side to the right side with the least total cost, by the
/// Hungarian method.
///
/// The graph is read as bipartite and each pair costs the weight of the edge between
/// them; a pair with no edge costs more than any real route, so it is chosen only when
/// nothing else is left.
pub fn[G : @moongraph.Topology] assignment(
  graph : G,
  weight~ : (Int) -> Double,
) -> @moongraph.Matching raise @moongraph.Refused {
  let side = bipartition(graph)
  match side {
    None =>
      raise @moongraph.Refused::NotA(
        kind="bipartite",
        what="an assignment needs two sides",
      )
    Some(colour) => assignment_on(graph, colour, weight)
  }
}

///|
/// The Hungarian method over the two sides of a colouring.
fn[G : @moongraph.Topology] assignment_on(
  graph : G,
  colour : Array[Int],
  weight : (Int) -> Double,
) -> @moongraph.Matching {
  let n = @moongraph.Topology::node_count(graph)
  let left : Array[Int] = []
  for node in 0..<n {
    if colour[node] == 0 {
      left.push(node)
    }
  }
  let size = left.length()
  if size == 0 {
    return { pairs: [], weight: 0.0 }
  }
  let huge = 1.0e12
  let cost : Array[Array[Double]] = Array::makei(size, fn(i) {
    let row : Array[Double] = []
    for node in 0..<n {
      if colour[node] == 1 {
        row.push(match @internal.cheapest(graph, left[i], node, weight) {
          Some(edge) => weight(edge)
          None => huge
        })
      }
    }
    row
  })
  let nodes : Array[Int] = []
  for node in 0..<n {
    if colour[node] == 1 {
      nodes.push(node)
    }
  }
  let columns = nodes.length()
  if columns == 0 {
    return { pairs: [], weight: 0.0 }
  }
  // The pairing of rows to columns, grown one row at a time along the cheapest
  // augmenting chain, which is the Hungarian method written out.
  let match_of : Array[Int] = Array::make(columns, -1)
  let row_of : Array[Int] = Array::make(size, -1)
  for agent in 0..<size {
    let value : Array[Double] = Array::make(columns, @double.infinity)
    let via : Array[Int] = Array::make(columns, -1)
    let used_col : Array[Bool] = Array::make(columns, false)
    for column_index in 0..<columns {
      value[column_index] = if column_index < cost[agent].length() {
        cost[agent][column_index]
      } else {
        huge
      }
      via[column_index] = agent
    }
    let mut column = -1
    let mut rounds = 0
    while column < 0 && rounds <= columns {
      rounds = rounds + 1
      let mut pick = -1
      for column_index in 0..<columns {
        if !used_col[column_index] && (pick < 0 || value[column_index] < value[pick]) {
          pick = column_index
        }
      }
      if pick < 0 {
        break
      }
      used_col[pick] = true
      if match_of[pick] < 0 {
        column = pick
        break
      }
      let next_row = match_of[pick]
      for column_index in 0..<columns {
        if !used_col[column_index] && column_index < cost[next_row].length() {
          let candidate = cost[next_row][column_index]
          if candidate < value[column_index] {
            value[column_index] = candidate
            via[column_index] = next_row
          }
        }
      }
    }
    if column < 0 {
      continue
    }
    // Reassign along the chain that ends at the free column.
    let mut at = column
    let mut steps = 0
    while at >= 0 && steps <= columns {
      let from = via[at]
      if from < 0 {
        break
      }
      let previous = row_of[from]
      match_of[at] = from
      row_of[from] = at
      at = previous
      steps = steps + 1
    }
  }
  let pairs : Array[(Int, Int)] = []
  let mut total = 0.0
  for row in 0..<size {
    let column = row_of[row]
    if column >= 0 {
      if column < nodes.length() {
        let other = nodes[column]
        pairs.push((if left[row] < other { left[row] } else { other }, if left[row] < other { other } else { left[row] }))
        total = total + cost[row][column]
      }
    }
  }
  { pairs, weight: total }
}

///|
/// A minimum-weight matching of the largest size, by the same assignment step with the
/// weights turned around.
pub fn[G : @moongraph.Topology] matching_min_weight(
  graph : G,
  weight~ : (Int) -> Double,
) -> @moongraph.Matching raise @moongraph.Refused {
  assignment(graph, weight=weight)
}

///|
/// Whether the pairs form a matching: no node appears twice and every pair is an edge.
pub fn[G : @moongraph.Topology] is_matching(
  graph : G,
  pairs : Array[(Int, Int)],
) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  let taken : Array[Bool] = Array::make(n, false)
  for (a, b) in pairs {
    if a < 0 || a >= n || b < 0 || b >= n || a == b {
      return false
    }
    if taken[a] || taken[b] {
      return false
    }
    if !@internal.adjacent(graph, a, b) {
      return false
    }
    taken[a] = true
    taken[b] = true
  }
  true
}

///|
/// Whether no further pair could be added to the matching.
pub fn[G : @moongraph.Topology] is_maximal_matching(
  graph : G,
  pairs : Array[(Int, Int)],
) -> Bool {
  if !is_matching(graph, pairs) {
    return false
  }
  let n = @moongraph.Topology::node_count(graph)
  let taken : Array[Bool] = Array::make(n, false)
  for (a, b) in pairs {
    taken[a] = true
    taken[b] = true
  }
  for node in 0..<n {
    if taken[node] {
      continue
    }
    for nbr in @moongraph.Topology::neighbors(graph, node) {
      if nbr != node && !taken[nbr] {
        return false
      }
    }
  }
  true
}

///|
/// Whether every node is paired.
pub fn[G : @moongraph.Topology] is_perfect_matching(
  graph : G,
  pairs : Array[(Int, Int)],
) -> Bool {
  if !is_matching(graph, pairs) {
    return false
  }
  pairs.length() * 2 == @moongraph.Topology::node_count(graph)
}

///|
/// A smallest set of edges that touches every node.
///
/// A maximum matching covers every node but a few; each node left out then needs one
/// edge of its own, which is the smallest addition that finishes the cover.
pub fn[G : @moongraph.Topology] edge_cover(graph : G) -> @moongraph.Cover {
  let n = @moongraph.Topology::node_count(graph)
  let matching = matching_maximum(graph)
  let edges : Array[Int] = []
  let touched : Array[Bool] = Array::make(n, false)
  for (a, b) in matching.pairs {
    match @internal.first_edge(graph, a, b) {
      Some(edge) => {
        edges.push(edge)
        touched[a] = true
        touched[b] = true
      }
      None => ()
    }
  }
  for node in 0..<n {
    if !touched[node] {
      let eids = @moongraph.Topology::incident(graph, node)
      if eids.length() > 0 {
        let edge = eids[0]
        if !edges.contains(edge) {
          edges.push(edge)
        }
      }
    }
  }
  edges.sort()
  { edges, }
}

///|
/// Whether the cover leaves no node untouched.
pub fn[G : @moongraph.Topology] is_edge_cover(
  graph : G,
  cover : @moongraph.Cover,
) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  let touched : Array[Bool] = Array::make(n, false)
  for edge in cover.edges {
    if edge < 0 || edge >= @moongraph.Topology::edge_count(graph) {
      return false
    }
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    if a >= 0 && a < n {
      touched[a] = true
    }
    if b >= 0 && b < n {
      touched[b] = true
    }
  }
  for node in 0..<n {
    if !touched[node] {
      return false
    }
  }
  true
}

///|
/// A smallest set of nodes that touches every edge of a bipartite graph, read off a
/// maximum matching: the nodes on one side of a König cover.
pub fn[G : @moongraph.Topology] vertex_cover_bipartite(
  graph : G,
) -> Array[Int] {
  let n = @moongraph.Topology::node_count(graph)
  let matching = matching_bipartite(graph) catch {
    _ => return []
  }
  let mate : Array[Int] = Array::make(n, -1)
  for (a, b) in matching.pairs {
    mate[a] = b
    mate[b] = a
  }
  let colour = match bipartition(graph) {
    Some(colour) => colour
    None => return []
  }
  // Alternating walk from the unmatched left nodes: what it cannot reach on the left,
  // together with what it can reach on the right, is a cover of the same size.
  let reached : Array[Bool] = Array::make(n, false)
  let queue : Array[Int] = []
  for node in 0..<n {
    if colour[node] == 0 && mate[node] < 0 {
      reached[node] = true
      queue.push(node)
    }
  }
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    for nbr in @moongraph.Topology::neighbors(graph, node) {
      if !reached[nbr] {
        reached[nbr] = true
        queue.push(nbr)
        if mate[nbr] >= 0 && !reached[mate[nbr]] {
          reached[mate[nbr]] = true
          queue.push(mate[nbr])
        }
      }
    }
  }
  let out : Array[Int] = []
  for node in 0..<n {
    if (colour[node] == 0 && !reached[node]) || (colour[node] == 1 && reached[node]) {
      out.push(node)
    }
  }
  out
}

///|
/// Turns a mate array into the pair list, cheapest edge first inside each pair.
fn[G : @moongraph.Topology] collect(
  n : Int,
  mate : Array[Int],
  graph : G,
  weight : ((Int) -> Double)?,
) -> @moongraph.Matching {
  let pairs : Array[(Int, Int)] = []
  let mut total = 0.0
  for node in 0..<n {
    let other = mate[node]
    if other > node {
      pairs.push((node, other))
      total = total + pair_weight(graph, node, other, weight)
    }
  }
  { pairs, weight: total }
}
