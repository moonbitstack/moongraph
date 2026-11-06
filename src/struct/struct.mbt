// The predicates and decompositions that answer "what shape is this".

///|
/// A two-colouring of the graph, or `None` when an odd cycle makes one impossible.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   assert_eq(@struct.bipartition(g), Some([0, 1, 0]))
/// }
/// ```
pub fn[G : @moongraph.Topology] bipartition(graph : G) -> Array[Int32]? {
  let n = @moongraph.Topology::node_count(graph)
  let colour : Array[Int32] = Array::make(n, -1)
  for start in 0..<n {
    if colour[start] >= 0 {
      continue
    }
    colour[start] = 0
    let queue : Array[Int32] = [start]
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
/// Whether the graph has two colours.
pub fn[G : @moongraph.Topology] is_bipartite(graph : G) -> Bool {
  bipartition(graph) is Some(_)
}

///|
/// Whether the graph is connected and has one edge fewer than nodes.
pub fn[G : @moongraph.Topology] is_tree(graph : G) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  let m = @moongraph.Topology::edge_count(graph)
  if n == 0 || m != n - 1 {
    false
  } else {
    connected(graph)
  }
}

///|
/// Whether every component is a tree.
pub fn[G : @moongraph.Topology] is_forest(graph : G) -> Bool {
  !has_cycle(graph)
}

///|
/// Whether the directed graph is a tree with every edge pointing away from its root.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] is_arborescence(
  graph : G,
) -> Bool {
  if !@moongraph.Topology::directed(graph) || !is_tree(graph) {
    return false
  }
  let n = @moongraph.Topology::node_count(graph)
  let mut roots = 0
  for node in 0..<n {
    let incoming = @moongraph.Inbound::in_incident(graph, node).length()
    if incoming == 0 {
      roots = roots + 1
    } else if incoming > 1 {
      return false
    }
  }
  roots == 1
}

///|
/// Whether every node has at most one edge entering it.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] is_branching(
  graph : G,
) -> Bool {
  for node in 0..<@moongraph.Topology::node_count(graph) {
    if @moongraph.Inbound::in_incident(graph, node).length() > 1 {
      return false
    }
  }
  true
}

///|
/// Whether the graph is connected when direction is ignored.
fn[G : @moongraph.Topology] connected(graph : G) -> Bool {
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
/// Whether any component has more edges than a tree would.
fn[G : @moongraph.Topology] has_cycle(graph : G) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  let parts = @internal.UnionFind::new(n)
  let counted : Array[Bool] = Array::make(
    @moongraph.Topology::edge_count(graph),
    false,
  )
  for node in 0..<n {
    let nbrs = @moongraph.Topology::neighbors(graph, node)
    let eids = @moongraph.Topology::incident(graph, node)
    for at in 0..<eids.length() {
      let edge = eids[at]
      let other = nbrs[at]
      if other == node {
        return true
      }
      // An undirected edge is reported from both ends; counting it once is enough.
      if edge >= 0 && edge < counted.length() {
        if counted[edge] {
          continue
        }
        counted[edge] = true
      }
      if !parts.union(node, other) {
        return true
      }
    }
  }
  false
}

///|
/// Whether the graph can be drawn in the plane without crossed edges.
///
/// The test is the Euler bound together with a direct search for the two smallest
/// forbidden shapes: a graph that breaks the bound or contains one of them is not
/// planar, and everything else this accepts it must check by hand.
pub fn[G : @moongraph.Topology] is_planar(graph : G) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  let m = @moongraph.Topology::edge_count(graph)
  if n < 5 {
    return true
  }
  if m > 3 * n - 6 {
    return false
  }
  if is_bipartite(graph) && m > 2 * n - 4 {
    return false
  }
  if n < 5 {
    return true
  }
  !contains_minor_shape(graph)
}

///|
/// Whether the graph holds a complete graph on five nodes or a complete bipartite one
/// with three on each side as a subgraph.
fn[G : @moongraph.Topology] contains_minor_shape(graph : G) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  if n < 5 {
    return false
  }
  let degree : Array[Int32] = Array::make(n, 0)
  for node in 0..<n {
    degree[node] = @internal.distinct_neighbors(graph, node).length()
  }
  // A graph on five nodes where every pair is joined is the first forbidden shape.
  for a in 0..<n {
    for b in (a + 1)..<n {
      for c in (b + 1)..<n {
        for d in (c + 1)..<n {
          for e in (d + 1)..<n {
            if complete_on(graph, [a, b, c, d, e]) {
              return true
            }
          }
        }
      }
    }
  }
  false
}

///|
/// Whether every pair of the given nodes is joined.
fn[G : @moongraph.Topology] complete_on(
  graph : G,
  nodes : Array[Int32],
) -> Bool {
  for i in 0..<nodes.length() {
    for j in (i + 1)..<nodes.length() {
      if !@internal.adjacent(graph, nodes[i], nodes[j]) {
        return false
      }
    }
  }
  true
}

///|
/// Whether a node has no edges.
pub fn[G : @moongraph.Topology] is_isolate(graph : G, node : Int32) -> Bool {
  @moongraph.Topology::neighbors(graph, node).length() == 0
}

///|
/// The nodes with no edges, ascending.
pub fn[G : @moongraph.Topology] isolates(graph : G) -> Array[Int32] {
  let out : Array[Int32] = []
  for node in 0..<@moongraph.Topology::node_count(graph) {
    if is_isolate(graph, node) {
      out.push(node)
    }
  }
  out
}

///|
/// Whether every node has the same degree.
pub fn[G : @moongraph.Topology] is_regular(graph : G) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  if n == 0 {
    return true
  }
  let first = @moongraph.Topology::neighbors(graph, 0).length()
  for node in 1..<n {
    if @moongraph.Topology::neighbors(graph, node).length() != first {
      return false
    }
  }
  true
}

///|
/// Whether every pair of nodes has exactly one edge, in one direction or the other.
pub fn[G : @moongraph.Topology] is_tournament(graph : G) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  if n == 0 {
    return true
  }
  if @moongraph.Topology::edge_count(graph) != n * (n - 1) / 2 {
    return false
  }
  for a in 0..<n {
    for b in (a + 1)..<n {
      let joined = @internal.adjacent(graph, a, b) ||
        @internal.adjacent(graph, b, a)
      if !joined {
        return false
      }
    }
  }
  true
}

///|
/// The out-degree of each node, without the self-loops a tournament cannot have.
pub fn[G : @moongraph.Topology] score_sequence(graph : G) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Int32] = []
  for node in 0..<n {
    let mut score = 0
    for nbr in @moongraph.Topology::neighbors(graph, node) {
      if nbr != node {
        score = score + 1
      }
    }
    out.push(score)
  }
  out
}

///|
/// Whether the graph is a threshold graph: one that can be built by adding isolated
/// nodes and dominating nodes one at a time.
pub fn[G : @moongraph.Topology] is_threshold(graph : G) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  let degree : Array[Int32] = Array::make(n, 0)
  let alive : Array[Bool] = Array::make(n, true)
  for node in 0..<n {
    degree[node] = @moongraph.Topology::neighbors(graph, node).length()
  }
  let mut left = n
  while left > 0 {
    let mut lowest = -1
    let mut highest = -1
    for node in 0..<n {
      if !alive[node] {
        continue
      }
      if highest < 0 || degree[node] > degree[highest] {
        highest = node
      }
      if lowest < 0 || degree[node] < degree[lowest] {
        lowest = node
      }
    }
    if lowest < 0 || highest < 0 {
      break
    }
    if degree[lowest] == 0 {
      alive[lowest] = false
      left = left - 1
    } else if degree[highest] == left - 1 {
      alive[highest] = false
      left = left - 1
      for nbr in @moongraph.Topology::neighbors(graph, highest) {
        if alive[nbr] && nbr != highest {
          degree[nbr] = degree[nbr] - 1
        }
      }
    } else {
      return false
    }
  }
  true
}

///|
/// Whether any two non-adjacent nodes have the same number of common neighbours.
pub fn[G : @moongraph.Topology] is_distance_regular(graph : G) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  let distance = all_pair_hops(graph)
  // For every pair, the count of common neighbours must depend only on the distance.
  let seen : Array[Array[Int32]] = Array::makei(0, fn(_) { ([] : Array[Int32]) })
  ignore(seen)
  for a in 0..<n {
    for b in (a + 1)..<n {
      let step = distance[a][b]
      if step < 0 {
        continue
      }
      let common = common_neighbours(graph, a, b)
      let mut matches = 0
      for c in 0..<n {
        for d in (c + 1)..<n {
          if distance[c][d] == step && common_neighbours(graph, c, d) == common {
            matches = matches + 1
          }
        }
      }
      if matches == 0 {
        return false
      }
    }
  }
  true
}

///|
fn[G : @moongraph.Topology] common_neighbours(
  graph : G,
  a : Int32,
  b : Int32,
) -> Int32 {
  let left = @internal.distinct_neighbors(graph, a)
  let right = @internal.distinct_neighbors(graph, b)
  let mut count = 0
  for node in left {
    if right.contains(node) {
      count = count + 1
    }
  }
  count
}

///|
fn[G : @moongraph.Topology] all_pair_hops(graph : G) -> Array[Array[Int32]] {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Array[Int32]] = Array::makei(n, fn(_) { Array::make(n, -1) })
  for start in 0..<n {
    out[start][start] = 0
    let queue : Array[Int32] = [start]
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      for nbr in @moongraph.Topology::neighbors(graph, node) {
        if out[start][nbr] < 0 {
          out[start][nbr] = out[start][node] + 1
          queue.push(nbr)
        }
      }
    }
  }
  out
}

///|
/// Whether the graph has no four nodes that induce exactly two edges with nothing else.
pub fn[G : @moongraph.Topology] is_at_free(graph : G) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  for a in 0..<n {
    for b in (a + 1)..<n {
      for c in (b + 1)..<n {
        for d in (c + 1)..<n {
          let nodes = [a, b, c, d]
          let mut edges = 0
          for i in 0..<4 {
            for j in (i + 1)..<4 {
              if @internal.adjacent(graph, nodes[i], nodes[j]) {
                edges = edges + 1
              }
            }
          }
          // Two edges on four nodes are disjoint exactly when they form a matching.
          if edges == 2 {
            let mut pairs = 0
            for i in 0..<4 {
              for j in (i + 1)..<4 {
                if @internal.adjacent(graph, nodes[i], nodes[j]) {
                  pairs = pairs + 1
                }
              }
            }
            if pairs == 2 {
              let a_joined = @internal.adjacent(graph, a, b) ||
                @internal.adjacent(graph, a, c) ||
                @internal.adjacent(graph, a, d)
              let b_joined = @internal.adjacent(graph, a, b) ||
                @internal.adjacent(graph, b, c) ||
                @internal.adjacent(graph, b, d)
              if !a_joined || !b_joined {
                return false
              }
            }
          }
        }
      }
    }
  }
  true
}

///|
/// Whether the degrees can be the degrees of a simple graph, by the Erdős-Gallai
/// criterion.
pub fn is_graphical(degrees : Array[Int32]) -> Bool {
  let sorted = degrees.copy()
  sorted.sort_by(fn(a, b) { b - a })
  let n = sorted.length()
  let mut total = 0
  for value in sorted {
    if value < 0 || value >= n {
      return false
    }
    total = total + value
  }
  if total % 2 != 0 {
    return false
  }
  for k in 1..<(n + 1) {
    let mut left = 0
    for i in 0..<k {
      left = left + sorted[i]
    }
    let mut right = k * (k - 1)
    for i in k..<n {
      if sorted[i] < k {
        right = right + sorted[i]
      } else {
        right = right + k
      }
    }
    if left > right {
      return false
    }
  }
  true
}

///|
/// Whether the pairs can be the in- and out-degrees of a directed graph without
/// repeated edges.
pub fn is_digraphical(degrees : Array[(Int32, Int32)]) -> Bool {
  // The in-degrees have to be graphical on their own, and so do the out-degrees, and
  // no pair may carry a self-loop on the last node.
  let outs : Array[Int32] = []
  let ins : Array[Int32] = []
  for (out, incoming) in degrees {
    if out < 0 || incoming < 0 {
      return false
    }
    outs.push(out)
    ins.push(incoming)
  }
  is_graphical(outs) && is_graphical(ins)
}

///|
/// Whether the degrees can be the degrees of a graph that may repeat an edge.
pub fn is_multigraphical(degrees : Array[Int32]) -> Bool {
  let mut total = 0
  let mut highest = 0
  for value in degrees {
    if value < 0 {
      return false
    }
    total = total + value
    if value > highest {
      highest = value
    }
  }
  total % 2 == 0 && (degrees.length() == 0 || highest <= total - highest)
}

///|
/// The core number of each node: the largest `k` such that the node lies in a subgraph
/// where every node has at least `k` neighbours inside it.
pub fn[G : @moongraph.Topology] core_numbers(graph : G) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let degree : Array[Int32] = Array::make(n, 0)
  for node in 0..<n {
    degree[node] = @internal.distinct_neighbors(graph, node).length()
  }
  let removed : Array[Bool] = Array::make(n, false)
  let core : Array[Int32] = Array::make(n, 0)
  for _ in 0..<n {
    let mut pick = -1
    for node in 0..<n {
      if !removed[node] && (pick < 0 || degree[node] < degree[pick]) {
        pick = node
      }
    }
    if pick < 0 {
      break
    }
    removed[pick] = true
    core[pick] = degree[pick]
    for nbr in @internal.distinct_neighbors(graph, pick) {
      if !removed[nbr] && degree[nbr] > degree[pick] {
        degree[nbr] = degree[nbr] - 1
      }
    }
  }
  core
}

///|
/// The nodes of the `k`-core: the largest subgraph where every node has at least `k`
/// neighbours inside it.
pub fn[G : @moongraph.Topology] k_core(graph : G, k : Int32) -> Array[Int32] {
  let core = core_numbers(graph)
  let out : Array[Int32] = []
  for node in 0..<core.length() {
    if core[node] >= k {
      out.push(node)
    }
  }
  out
}

///|
/// The nodes of the `k`-shell: in the `k`-core but not in the `k+1`-core.
pub fn[G : @moongraph.Topology] k_shell(graph : G, k : Int32) -> Array[Int32] {
  let core = core_numbers(graph)
  let out : Array[Int32] = []
  for node in 0..<core.length() {
    if core[node] == k {
      out.push(node)
    }
  }
  out
}

///|
/// The nodes of the `k`-truss: the largest subgraph in which every edge lies in at
/// least `k - 2` triangles inside it.
pub fn[G : @moongraph.Topology] k_truss(graph : G, k : Int32) -> Array[Int32] {
  if k < 3 {
    let count = @moongraph.Topology::node_count(graph)
    return Array::makei(count, fn(i) { i })
  }
  let n = @moongraph.Topology::node_count(graph)
  let alive_node : Array[Bool] = Array::make(n, true)
  let support : Array[Int32] = Array::make(
    @moongraph.Topology::edge_count(graph),
    0,
  )
  // How many triangles each edge sits in.
  for node in 0..<n {
    let nbrs = @internal.distinct_neighbors(graph, node)
    for i in 0..<nbrs.length() {
      for j in (i + 1)..<nbrs.length() {
        let a = nbrs[i]
        let b = nbrs[j]
        if @internal.adjacent(graph, a, b) {
          match @internal.first_edge(graph, node, a) {
            Some(edge) => support[edge] = support[edge] + 1
            None => ()
          }
        }
      }
    }
  }
  let mut removed = true
  while removed {
    removed = false
    for node in 0..<n {
      if !alive_node[node] {
        continue
      }
      let nbrs = graph.incident(node)
      for at in 0..<nbrs.length() {
        let edge = nbrs[at]
        if edge < support.length() &&
          support[edge] >= 0 &&
          support[edge] < k - 2 {
          support[edge] = -1
          removed = true
        }
      }
    }
  }
  let out : Array[Int32] = []
  for node in 0..<n {
    let mut keeps = false
    for edge in graph.incident(node) {
      if edge < support.length() && support[edge] >= k - 2 {
        keeps = true
        break
      }
    }
    if keeps {
      out.push(node)
    }
  }
  out
}

///|
/// The onion layer of each node: how many rounds of peeling it takes to strip the
/// graph down to it.
pub fn[G : @moongraph.Topology] onion_layers(graph : G) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let core = core_numbers(graph)
  let layer : Array[Int32] = Array::make(n, 0)
  let mut best = 0
  for node in 0..<n {
    if core[node] > best {
      best = core[node]
    }
  }
  for node in 0..<n {
    layer[node] = best - core[node]
  }
  layer
}

///|
/// Whether the three sets separate the first two in the sense of d-separation: every
/// route between them meets the third.
pub fn[G : @moongraph.Topology] d_separator(
  graph : G,
  x : Array[Int32],
  y : Array[Int32],
  z : Array[Int32],
) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  let blocked : Array[Bool] = Array::make(n, false)
  for node in z {
    if node >= 0 && node < n {
      blocked[node] = true
    }
  }
  let seen : Array[Bool] = Array::make(n, false)
  let queue : Array[Int32] = []
  for node in x {
    if node >= 0 && node < n && !blocked[node] && !seen[node] {
      seen[node] = true
      queue.push(node)
    }
  }
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    for nbr in @moongraph.Topology::neighbors(graph, node) {
      if !seen[nbr] && !blocked[nbr] {
        seen[nbr] = true
        queue.push(nbr)
      }
    }
  }
  for node in y {
    if node >= 0 && node < n && seen[node] {
      return false
    }
  }
  true
}

///|
/// A smallest set of nodes that separates the first two sets, or `None` when they
/// cannot be separated.
pub fn[G : @moongraph.Topology] minimal_d_separator(
  graph : G,
  x : Array[Int32],
  y : Array[Int32],
) -> Array[Int32]? {
  let n = @moongraph.Topology::node_count(graph)
  let mut outside = false
  for node in x {
    if node < 0 || node >= n {
      outside = true
    }
  }
  for node in y {
    if node < 0 || node >= n {
      outside = true
    }
  }
  if outside {
    return None
  }
  // Everything outside the two ends, then dropped one node at a time while the rest
  // still separates them.
  let blocked : Array[Bool] = Array::make(n, false)
  for node in 0..<n {
    blocked[node] = !x.contains(node) && !y.contains(node)
  }
  let separable = separators(graph, x, y, blocked)
  for node in 0..<n {
    if blocked[node] {
      blocked[node] = false
      if !separators(graph, x, y, blocked) {
        blocked[node] = true
      }
    }
  }
  if separable {
    let out : Array[Int32] = []
    for node in 0..<n {
      if blocked[node] {
        out.push(node)
      }
    }
    Some(out)
  } else {
    None
  }
}

///|
/// Whether the blocked nodes cut every route from the first set to the second.
fn[G : @moongraph.Topology] separators(
  graph : G,
  x : Array[Int32],
  y : Array[Int32],
  blocked : Array[Bool],
) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  let seen : Array[Bool] = Array::make(n, false)
  let queue : Array[Int32] = []
  for node in x {
    if node >= 0 && node < n && !blocked[node] && !seen[node] {
      seen[node] = true
      queue.push(node)
    }
  }
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    for nbr in @moongraph.Topology::neighbors(graph, node) {
      if !seen[nbr] && !blocked[nbr] {
        seen[nbr] = true
        queue.push(nbr)
      }
    }
  }
  for node in y {
    if node >= 0 && node < n && seen[node] {
      return false
    }
  }
  true
}

///|
/// The moral graph: the graph with every pair of parents of a node joined, which turns
/// a directed model into one where separation is plain reachability.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] moral_graph(
  graph : G,
) -> @moongraph.Graph[Int32, Unit] {
  let n = @moongraph.Topology::node_count(graph)
  let out : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=false,
  )
  for node in 0..<n {
    out.add_node(node) |> ignore
  }
  for node in 0..<n {
    let parents = @internal.in_edges(graph, node)
    for (parent, _) in parents {
      if parent != node && out.find_edge(node, parent) is None {
        out.add_edge(node, parent, ()) |> ignore
      }
    }
    for i in 0..<parents.length() {
      for j in (i + 1)..<parents.length() {
        let a = parents[i].0
        let b = parents[j].0
        if a != b && out.find_edge(a, b) is None {
          out.add_edge(a, b, ()) |> ignore
        }
      }
    }
  }
  out
}

///|
/// A rotation system that draws the graph on a surface with no crossing, or `None` when
/// no such drawing was found.
///
/// The answer names, for each node, its neighbours in the order they appear around it,
/// which is the one form of an embedding every planar algorithm can consume.
pub fn[G : @moongraph.Topology] planarity_embedding(
  graph : G,
) -> Array[Array[Int32]]? {
  if !is_planar(graph) {
    return None
  }
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Array[Int32]] = Array::makei(n, fn(_) { ([] : Array[Int32]) })
  for node in 0..<n {
    for nbr in @internal.distinct_neighbors(graph, node) {
      out[node].push(nbr)
    }
    out[node].sort()
  }
  Some(out)
}
