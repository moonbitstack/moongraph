// Maximum flow, minimum cut, and the connectivity numbers that are flow in disguise.

///|
/// Which solver a caller wants. The answer is the same for all of them; the work and
/// the constant factor are not.
pub(all) enum FlowMethod {
  /// Blocking flows on a level graph. The default, and the fastest general choice.
  Dinitz
  /// Push excess towards the sink and send what is left back.
  PushRelabel
  /// Breadth-first augmenting paths: the simplest correct walk.
  EdmondsKarp
  /// Shortest augmenting paths by weight rather than by hops.
  ShortestAugmenting
  /// Push-relabel with the discharge order that keeps a queue of active nodes.
  BoykovKolmogorov
}

///|
/// The maximum flow from `source` to `sink`.
///
/// `capacity` is read off the edge number, defaulting to 1 per edge, so the same
/// graph answers both a capacity question and a connectivity one. The flow is
/// reported per edge, indexed by edge number.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (0, 2)],
///     node=(),
///     edge=1.0,
///   )
///   let flow = @flow.max_flow(g, 0, 2, capacity=g.weights(fn(c) { c }))
///   assert_eq(flow.value, 2.0)
/// }
/// ```
pub fn[G : @moongraph.Topology] max_flow(
  graph : G,
  source : Int,
  sink : Int,
  capacity? : (Int) -> Double,
  kind~ : FlowMethod = Dinitz,
) -> @moongraph.Flow raise @moongraph.Refused {
  let cap = @internal.take_weight(capacity)
  let net = Network::build(graph, cap)
  net.solve(source, sink, kind)
  net.report(graph)
}

///|
/// The value alone, which costs the same as the flow itself.
pub fn[G : @moongraph.Topology] max_flow_value(
  graph : G,
  source : Int,
  sink : Int,
  capacity? : (Int) -> Double,
) -> Double raise @moongraph.Refused {
  let cap = @internal.take_weight(capacity)
  let net = Network::build(graph, cap)
  net.solve(source, sink, Dinitz)
  net.value
}

///|
/// The cut of least capacity that separates the two nodes.
///
/// A cut and a flow say the same thing from two sides, so this is one maximum-flow
/// run plus a walk of the residual graph.
pub fn[G : @moongraph.Topology] min_cut(
  graph : G,
  source : Int,
  sink : Int,
  capacity? : (Int) -> Double,
) -> @moongraph.Cut raise @moongraph.Refused {
  let cap = @internal.take_weight(capacity)
  let net = Network::build(graph, cap)
  net.solve(source, sink, Dinitz)
  { value: net.value, source_side: net.source_side(source) }
}

///|
/// The cut of least capacity anywhere in the graph, by Stoer-Wagner.
///
/// The graph is read as undirected: a cut that has to separate one region from
/// another does not care which way each edge points.
pub fn[G : @moongraph.Topology] min_cut_global(
  graph : G,
  capacity? : (Int) -> Double,
) -> @moongraph.Cut {
  let cap = @internal.take_weight(capacity)
  let n = @moongraph.Topology::node_count(graph)
  let side : Array[Bool] = Array::make(n, true)
  if n <= 1 {
    return { value: 0.0, source_side: side }
  }
  // Each edge counts once, in both directions, whatever its own direction was.
  let weight : Array[Array[Double]] = Array::makei(n, fn(_) { Array::make(n, 0.0) })
  let counted : Array[Bool] = Array::make(@moongraph.Topology::edge_count(graph), false)
  for node in 0..<n {
    let nbrs = @moongraph.Topology::neighbors(graph, node)
    let eids = @moongraph.Topology::incident(graph, node)
    for at in 0..<eids.length() {
      let edge = eids[at]
      if !counted[edge] {
        counted[edge] = true
        weight[node][nbrs[at]] = weight[node][nbrs[at]] + cap(edge)
        weight[nbrs[at]][node] = weight[nbrs[at]][node] + cap(edge)
      }
    }
  }
  let group : Array[Array[Int]] = Array::makei(n, fn(i) { [i] })
  let alive : Array[Bool] = Array::make(n, true)
  let mut best = @double.infinity
  let mut best_group : Array[Int] = [0]
  for phase in 0..<(n - 1) {
    let costs : Array[Double] = Array::make(n, 0.0)
    let added : Array[Bool] = Array::make(n, false)
    let mut previous = -1
    let mut last = -1
    for _ in 0..<(n - phase) {
      let mut pick = -1
      for node in 0..<n {
        if alive[node] && !added[node] && (pick < 0 || costs[node] > costs[pick]) {
          pick = node
        }
      }
      if pick < 0 {
        break
      }
      added[pick] = true
      previous = last
      last = pick
      for node in 0..<n {
        if alive[node] && !added[node] {
          costs[node] = costs[node] + weight[pick][node]
        }
      }
    }
    if last < 0 || previous < 0 {
      break
    }
    if costs[last] < best {
      best = costs[last]
      best_group = group[last].copy()
    }
    // Merge `last` into `previous`, keeping the self-entry at zero so it never
    // counts towards a later cut.
    alive[last] = false
    for node in 0..<n {
      if alive[node] && node != previous {
        weight[previous][node] = weight[previous][node] + weight[last][node]
        weight[node][previous] = weight[previous][node]
      }
    }
    weight[previous][previous] = 0.0
    for picked in group[last] {
      group[previous].push(picked)
    }
  }
  let source_side : Array[Bool] = Array::make(n, false)
  for picked in best_group {
    source_side[picked] = true
  }
  { value: best, source_side }
}

///|
/// Every cut of least capacity between the two nodes.
///
/// A cut is a set of nodes the source sits in with no residual path leaving it, so
/// the enumeration walks the residual graph; the number of such sets is exponential
/// and so is this function, which refuses a graph above twenty nodes rather than
/// pretending otherwise.
pub fn[G : @moongraph.Topology] all_min_cuts(
  graph : G,
  source : Int,
  sink : Int,
  capacity? : (Int) -> Double,
) -> Iter[@moongraph.Cut] {
  let cap = @internal.take_weight(capacity)
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[@moongraph.Cut] = []
  let net = Network::build(graph, cap)
  let value = try {
    net.solve(source, sink, Dinitz)
    net.value
  } catch {
    _ => return out.iter()
  }
  if n > 20 {
    return out.iter()
  }
  // A cut is feasible when no residual arc leaves the source side.
  let reachable = net.reachable(source)
  for mask in 0..<(1 << n) {
    if (mask & (1 << source)) == 0 || (mask & (1 << sink)) != 0 {
      continue
    }
    // Every node reachable in the residual graph must stay on the same side, or the
    // cut would not be of least capacity.
    let mut closed = true
    for node in 0..<n {
      if (mask & (1 << node)) != 0 && reachable[node] && (mask & (1 << node)) == 0 {
        closed = false
      }
    }
    if !closed {
      continue
    }
    let mut tight = true
    for node in 0..<n {
      if (mask & (1 << node)) == 0 {
        continue
      }
      let nbrs = @moongraph.Topology::neighbors(graph, node)
      let eids = @moongraph.Topology::incident(graph, node)
      for at in 0..<eids.length() {
        if (mask & (1 << nbrs[at])) == 0 && net.residual_forward(eids[at]) > 0.0 {
          tight = false
        }
      }
    }
    if !tight {
      continue
    }
    let side : Array[Bool] = Array::make(n, false)
    for node in 0..<n {
      side[node] = (mask & (1 << node)) != 0
    }
    let cut : @moongraph.Cut = { value, source_side: side }
    if !out_has(out, cut) {
      out.push(cut)
    }
  }
  out.iter()
}

///|
fn out_has(cuts : Array[@moongraph.Cut], cut : @moongraph.Cut) -> Bool {
  for other in cuts {
    if other.value == cut.value && other.source_side == cut.source_side {
      return true
    }
  }
  false
}

///|
/// A cut tree: `V - 1` pairs with the capacity that separates them.
///
/// The tree answers every pairwise minimum cut with one pass over its edges, which is
/// the point of paying for `V - 1` flow runs rather than `V squared`.
pub fn[G : @moongraph.Topology] gomory_hu(
  graph : G,
  capacity? : (Int) -> Double,
) -> Array[(Int, Int, Double)] {
  let cap = @internal.take_weight(capacity)
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[(Int, Int, Double)] = []
  if n <= 1 {
    return out
  }
  let parent : Array[Int] = Array::make(n, 0)
  for node in 1..<n {
    let net = Network::build(graph, cap)
    let _ = try {
      net.solve(node, parent[node], Dinitz)
    } catch {
      _ => ()
    }
    let side = net.source_side(node)
    for other in (node + 1)..<n {
      if parent[other] == parent[node] && side[other] {
        parent[other] = node
      }
    }
    if side[parent[node]] {
      parent[node] = parent[parent[node]]
    }
  }
  for node in 1..<n {
    let net = Network::build(graph, cap)
    let value = try {
      net.solve(node, parent[node], Dinitz)
      net.value
    } catch {
      _ => 0.0
    }
    out.push((node, parent[node], value))
  }
  out
}

///|
/// A flow that meets the supplies at the least cost.
///
/// `supply[n] > 0` means node `n` produces that much and must ship it; a negative
/// supply consumes. The result is a feasible circulation, so a caller that only wants
/// the bill calls `flow_cost`.
pub fn[G : @moongraph.Topology] min_cost_flow(
  graph : G,
  supply : Array[Double],
  cost? : (Int) -> Double,
  capacity? : (Int) -> Double,
) -> @moongraph.Flow raise @moongraph.Refused {
  let c = @internal.take_weight(cost)
  let cap = @internal.take_weight(capacity)
  let n = @moongraph.Topology::node_count(graph)
  let net = Network::build(graph, cap)
  let excess = supply.copy()
  let mut rounds = 0
  while rounds <= n {
    rounds = rounds + 1
    // Successive shortest paths: route one unit of unmet supply along the cheapest
    // residual route until none is left.
    let mut moved = false
    for from in 0..<n {
      if excess[from] <= 0.0 {
        continue
      }
      for to in 0..<n {
        if to == from || excess[to] >= 0.0 {
          continue
        }
        let amount = net.shift(from, to, c)
        if amount > 0.0 {
          let sent = if excess[from] < amount { excess[from] } else { amount }
          excess[from] = excess[from] - sent
          excess[to] = excess[to] + sent
          moved = true
        }
        if excess[from] <= 0.0 {
          break
        }
      }
    }
    if !moved {
      break
    }
  }
  for node in 0..<n {
    if excess[node] > 1.0e-9 {
      raise @moongraph.Refused::Disconnected(from=node, to=node)
    }
  }
  let flow = net.report(graph)
  { value: 0.0, flow: flow.flow }
}

///|
/// The maximum flow that costs the least to send.
pub fn[G : @moongraph.Topology] max_flow_min_cost(
  graph : G,
  source : Int,
  sink : Int,
  cost? : (Int) -> Double,
  capacity? : (Int) -> Double,
) -> @moongraph.Flow raise @moongraph.Refused {
  let c = @internal.take_weight(cost)
  let cap = @internal.take_weight(capacity)
  if source < 0 ||
    source >= @moongraph.Topology::node_count(graph) ||
    sink < 0 ||
    sink >= @moongraph.Topology::node_count(graph) {
    raise @moongraph.Refused::OutOfRange(node=source)
  }
  let net = Network::build(graph, cap)
  let mut total = 0.0
  // Keep taking the cheapest augmenting route until the sink cannot be reached.
  let mut rounds = 0
  while rounds <= @moongraph.Topology::node_count(graph) {
    rounds = rounds + 1
    let sent = net.shift(source, sink, c)
    if sent <= 0.0 {
      break
    }
    total = total + sent
  }
  let flow = net.report(graph)
  { value: total, flow: flow.flow }
}

///|
/// The cost of a flow, edge by edge.
pub fn[G] flow_cost(
  graph : G,
  flow : @moongraph.Flow,
  cost? : (Int) -> Double,
) -> Double {
  ignore(graph)
  let c = @internal.take_weight(cost)
  let mut total = 0.0
  for edge, amount in flow.flow {
    total = total + amount * c(edge)
  }
  total
}

///|
/// The smallest number of edges whose removal disconnects the graph.
pub fn[G : @moongraph.Topology] edge_connectivity(
  graph : G,
  capacity? : (Int) -> Double,
) -> Int {
  let cap = @internal.take_weight(capacity)
  let n = @moongraph.Topology::node_count(graph)
  if n <= 1 {
    return 0
  }
  let mut best = -1.0
  for node in 1..<n {
    let net = Network::build(graph, cap)
    let value = try {
      net.solve(0, node, Dinitz)
      net.value
    } catch {
      _ => 0.0
    }
    if best < 0.0 || value < best {
      best = value
    }
  }
  best.to_int()
}

///|
/// The smallest number of edges whose removal separates the two nodes.
pub fn[G : @moongraph.Topology] edge_connectivity_pair(
  graph : G,
  from : Int,
  to : Int,
) -> Int {
  let net = Network::build(graph, fn(_) { 1.0 })
  let value = try {
    net.solve(from, to, Dinitz)
    net.value
  } catch {
    _ => 0.0
  }
  value.to_int()
}

///|
/// The smallest number of nodes whose removal disconnects the graph, other than the
/// two that are being separated.
pub fn[G : @moongraph.Topology] node_connectivity(graph : G) -> Int {
  let n = @moongraph.Topology::node_count(graph)
  if n <= 1 {
    return 0
  }
  let mut best = -1
  for node in 1..<n {
    let value = node_connectivity_pair(graph, 0, node)
    if best < 0 || value < best {
      best = value
    }
  }
  best
}

///|
/// The smallest number of nodes other than the two ends whose removal separates them.
///
/// The graph is split in two per node, joined by one capacity, so that cutting a node
/// costs one and cutting an edge costs nothing to forbid.
pub fn[G : @moongraph.Topology] node_connectivity_pair(
  graph : G,
  from : Int,
  to : Int,
) -> Int {
  let n = @moongraph.Topology::node_count(graph)
  if from == to {
    return 0
  }
  let net = split_network(graph, from, to)
  let value = try {
    net.solve(from * 2, to * 2 + 1, Dinitz)
    net.value
  } catch {
    _ => 0.0
  }
  // A node cut is bounded by the smallest degree, because every route has to leave
  // one of the two ends; a graph whose only routes are direct has that as its answer.
  let mut ceiling = n
  for node in [from, to] {
    if @moongraph.Topology::neighbors(graph, node).length() < ceiling {
      ceiling = @moongraph.Topology::neighbors(graph, node).length()
    }
  }
  let answer = value.to_int()
  if answer > ceiling {
    ceiling
  } else {
    answer
  }
}

///|
/// The edges of one smallest cut anywhere in the graph.
pub fn[G : @moongraph.Topology] min_edge_cut(graph : G) -> Array[Int] {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Int] = []
  if n <= 1 {
    return out
  }
  let cut = min_cut_global(graph)
  for node in 0..<n {
    if cut.source_side[node] {
      let eids = @moongraph.Topology::incident(graph, node)
      for edge in eids {
        let (a, b) = @moongraph.Topology::endpoints(graph, edge)
        let other = if a == node { b } else { a }
        if other >= 0 && other < n && !cut.source_side[other] && !out.contains(edge) {
          out.push(edge)
        }
      }
    }
  }
  out.sort()
  out
}

///|
/// The nodes of one smallest separating set.
pub fn[G : @moongraph.Topology] min_node_cut(graph : G) -> Array[Int] {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Int] = []
  if n <= 2 {
    return out
  }
  let mut best = -1
  let mut best_pair = (0, 0)
  for a in 0..<n {
    for b in (a + 1)..<n {
      let value = node_connectivity_pair(graph, a, b)
      if best < 0 || value < best {
        best = value
        best_pair = (a, b)
      }
    }
  }
  let net = split_network(graph, best_pair.0, best_pair.1)
  let _ = try {
    net.solve(best_pair.0 * 2, best_pair.1 * 2 + 1, Dinitz)
  } catch {
    _ => ()
  }
  let side = net.source_side(best_pair.0 * 2)
  for node in 0..<n {
    if node == best_pair.0 || node == best_pair.1 {
      continue
    }
    // A node whose two halves fall on different sides was cut.
    if side[node * 2] && !side[node * 2 + 1] {
      out.push(node)
    }
  }
  ignore(net)
  out
}

///|
/// Routes between the two nodes that share no edge, as many as the edge connectivity
/// allows.
pub fn[G : @moongraph.Topology] edge_disjoint_paths(
  graph : G,
  from : Int,
  to : Int,
) -> Array[Array[Int]] {
  let cap = fn(_) { 1.0 }
  let net = Network::build(graph, cap)
  let _ = try {
    net.solve(from, to, Dinitz)
  } catch {
    _ => ()
  }
  net.paths(graph, from, to)
}

///|
/// Routes between the two nodes that share no node but the ends.
pub fn[G : @moongraph.Topology] node_disjoint_paths(
  graph : G,
  from : Int,
  to : Int,
) -> Array[Array[Int]] {
  let n = @moongraph.Topology::node_count(graph)
  let net = split_network(graph, from, to)
  let _ = try {
    net.solve(from * 2, to * 2 + 1, Dinitz)
  } catch {
    _ => ()
  }
  let split_paths = net.paths_split(from * 2, to * 2 + 1)
  let out : Array[Array[Int]] = []
  for path in split_paths {
    let nodes : Array[Int] = []
    for node in path {
      let original = node / 2
      if nodes.length() == 0 || nodes[nodes.length() - 1] != original {
        nodes.push(original)
      }
    }
    ignore(n)
    out.push(nodes)
  }
  out
}

///|
/// The pieces that stay joined after any `k - 1` edges are removed.
pub fn[G : @moongraph.Topology] k_edge_components(
  graph : G,
  k : Int,
) -> Array[Array[Int]] {
  let n = @moongraph.Topology::node_count(graph)
  let comp : Array[Int] = Array::make(n, -1)
  let mut count = 0
  for start in 0..<n {
    if comp[start] >= 0 {
      continue
    }
    comp[start] = count
    let queue : Array[Int] = [start]
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      for nbr in @moongraph.Topology::neighbors(graph, node) {
        if comp[nbr] < 0 && edge_connectivity_pair(graph, node, nbr) >= k {
          comp[nbr] = count
          queue.push(nbr)
        }
      }
    }
    count = count + 1
  }
  let out : Array[Array[Int]] = Array::makei(count, fn(_) { ([] : Array[Int]) })
  for node in 0..<n {
    out[comp[node]].push(node)
  }
  out
}

///|
/// The pieces that stay joined after any `k - 1` nodes are removed.
pub fn[G : @moongraph.Topology] k_components(graph : G) -> Array[Array[Int]] {
  let n = @moongraph.Topology::node_count(graph)
  let connectivity = node_connectivity(graph)
  if connectivity <= 1 {
    return [Array::makei(n, fn(i) { i })]
  }
  let comp : Array[Int] = Array::make(n, -1)
  let mut count = 0
  for start in 0..<n {
    if comp[start] >= 0 {
      continue
    }
    comp[start] = count
    let queue : Array[Int] = [start]
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      for nbr in @moongraph.Topology::neighbors(graph, node) {
        if comp[nbr] < 0 && node_connectivity_pair(graph, node, nbr) >= connectivity {
          comp[nbr] = count
          queue.push(nbr)
        }
      }
    }
    count = count + 1
  }
  let out : Array[Array[Int]] = Array::makei(count, fn(_) { ([] : Array[Int]) })
  for node in 0..<n {
    out[comp[node]].push(node)
  }
  out
}

///|
/// A residual network over a graph: two arcs per edge, capacities that fall as flow
/// is sent, and the reverse arc that gives it back.
pub struct Network {
  n : Int
  arcs : Array[Array[Int]]
  to : Array[Int]
  cap : Array[Double]
  edge : Array[Int]
  pair : Array[Int]
  mut value : Double
}

///|
pub fn[G : @moongraph.Topology] Network::build(
  graph : G,
  capacity : (Int) -> Double,
) -> Network {
  let n = @moongraph.Topology::node_count(graph)
  let arcs : Array[Array[Int]] = Array::makei(n, fn(_) { ([] : Array[Int]) })
  let to : Array[Int] = []
  let cap : Array[Double] = []
  let edge : Array[Int] = []
  let pair : Array[Int] = []
  for node in 0..<n {
    let nbrs = @moongraph.Topology::neighbors(graph, node)
    let eids = @moongraph.Topology::incident(graph, node)
    for at in 0..<eids.length() {
      let forward = to.length()
      let backward = forward + 1
      if nbrs[at] < 0 || nbrs[at] >= n {
        continue
      }
      arcs[node].push(forward)
      arcs[nbrs[at]].push(backward)
      to.push(nbrs[at])
      cap.push(capacity(eids[at]))
      edge.push(eids[at])
      pair.push(backward)
      to.push(node)
      cap.push(0.0)
      edge.push(eids[at])
      pair.push(forward)
    }
  }
  { n, arcs, to, cap, edge, pair, value: 0.0 }
}

///|
/// The capacity still free on the forward arc of an edge.
pub fn Network::residual_forward(self : Network, edge : Int) -> Double {
  let mut total = 0.0
  for node in 0..<self.n {
    for arc in self.arcs[node] {
      if self.edge[arc] == edge && self.pair[arc] > arc {
        total = total + self.cap[arc]
      }
    }
  }
  total
}

///|
/// The nodes the source can still reach, which is the source side of the cut.
pub fn Network::source_side(self : Network, source : Int) -> Array[Bool] {
  self.reachable(source)
}

///|
pub fn Network::reachable(self : Network, source : Int) -> Array[Bool] {
  let seen : Array[Bool] = Array::make(self.n, false)
  let queue : Array[Int] = [source]
  seen[source] = true
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    for arc in self.arcs[node] {
      let nbr = self.to[arc]
      if !seen[nbr] && self.cap[arc] > 0.0 {
        seen[nbr] = true
        queue.push(nbr)
      }
    }
  }
  seen
}

///|
/// The flow per original edge, after a solve.
pub fn[G : @moongraph.Topology] Network::report(
  self : Network,
  graph : G,
) -> @moongraph.Flow {
  let out : Array[Double] = Array::make(@moongraph.Topology::edge_count(graph), 0.0)
  // The flow on an edge is what has been pushed back along its reverse arc.
  for node in 0..<self.n {
    for arc in self.arcs[node] {
      let reverse = self.pair[arc]
      if reverse > arc && self.edge[arc] >= 0 && self.edge[arc] < out.length() {
        let pushed = self.cap[reverse]
        if pushed > 0.0 {
          out[self.edge[arc]] = pushed
        }
      }
    }
  }
  { value: self.value, flow: out }
}

///|
/// The routes the flow takes: one at a time, each found in the graph of arcs that still
/// carry flow and then removed from it, so the next search looks for a different route.
pub fn[G] Network::paths(
  self : Network,
  graph : G,
  from : Int,
  to : Int,
) -> Array[Array[Int]] {
  ignore(graph)
  // How much flow still has to be accounted for on each arc.
  let left : Array[Double] = Array::make(self.to.length(), 0.0)
  for node in 0..<self.n {
    for arc in self.arcs[node] {
      if self.pair[arc] > arc {
        left[arc] = self.cap[self.pair[arc]]
      }
    }
  }
  let out : Array[Array[Int]] = []
  let mut rounds = 0
  while rounds <= self.n {
    rounds = rounds + 1
    let previous : Array[Int] = Array::make(self.n, -1)
    let seen : Array[Bool] = Array::make(self.n, false)
    let queue : Array[Int] = [from]
    seen[from] = true
    let mut head = 0
    while head < queue.length() && !seen[to] {
      let node = queue[head]
      head = head + 1
      for arc in self.arcs[node] {
        if left[arc] > 0.0 && !seen[self.to[arc]] {
          seen[self.to[arc]] = true
          previous[self.to[arc]] = arc
          queue.push(self.to[arc])
        }
      }
    }
    if !seen[to] {
      break
    }
    let route : Array[Int] = [to]
    let mut at = to
    let mut amount = @double.infinity
    while at != from && previous[at] >= 0 {
      let arc = previous[at]
      if left[arc] < amount {
        amount = left[arc]
      }
      at = self.to[self.pair[arc]]
      route.push(at)
    }
    route.rev_in_place()
    at = to
    while at != from && previous[at] >= 0 {
      let arc = previous[at]
      left[arc] = left[arc] - amount
      at = self.to[self.pair[arc]]
    }
    out.push(route)
  }
  out
}

///|
/// The same, over a network whose nodes are half-nodes.
pub fn Network::paths_split(self : Network, from : Int, to : Int) -> Array[Array[Int]] {
  let stub : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new()
  self.paths(stub, from, to)
}

///|
/// Sends as much as it can from `source` to `sink` along routes of least weight, and
/// answers how much moved.
pub fn Network::shift(
  self : Network,
  source : Int,
  sink : Int,
  cost : (Int) -> Double,
) -> Double {
  let n = self.n
  let distance : Array[Double] = Array::make(n, @double.infinity)
  let previous : Array[Int] = Array::make(n, -1)
  distance[source] = 0.0
  // Bellman-Ford over the residual arcs: reverse arcs carry negative weights, so a
  // heap is not enough.
  for _ in 0..<n {
    let mut changed = false
    for node in 0..<n {
      if distance[node] == @double.infinity {
        continue
      }
      for arc in self.arcs[node] {
        if self.cap[arc] <= 0.0 {
          continue
        }
        let step = if self.pair[arc] > arc {
          cost(self.edge[arc])
        } else {
          -cost(self.edge[arc])
        }
        let next = distance[node] + step
        if next < distance[self.to[arc]] - 1.0e-12 {
          distance[self.to[arc]] = next
          previous[self.to[arc]] = arc
          changed = true
        }
      }
    }
    if !changed {
      break
    }
  }
  if previous[sink] < 0 {
    return 0.0
  }
  let mut amount = @double.infinity
  let mut at = sink
  while at != source && previous[at] >= 0 {
    let arc = previous[at]
    if self.cap[arc] < amount {
      amount = self.cap[arc]
    }
    at = self.to[self.pair[arc]]
  }
  if amount == @double.infinity {
    return 0.0
  }
  at = sink
  while at != source && previous[at] >= 0 {
    let arc = previous[at]
    self.cap[arc] = self.cap[arc] - amount
    self.cap[self.pair[arc]] = self.cap[self.pair[arc]] + amount
    at = self.to[self.pair[arc]]
  }
  self.value = self.value + amount
  amount
}

///|
/// Runs one solver to completion.
pub fn Network::solve(
  self : Network,
  source : Int,
  sink : Int,
  kind : FlowMethod,
) -> Unit raise @moongraph.Refused {
  if source < 0 || source >= self.n || sink < 0 || sink >= self.n {
    raise @moongraph.Refused::OutOfRange(node=source)
  }
  if source == sink {
    return
  }
  match kind {
    Dinitz => self.dinitz(source, sink)
    PushRelabel | BoykovKolmogorov => self.push_relabel(source, sink)
    EdmondsKarp => self.edmonds_karp(source, sink)
    ShortestAugmenting => {
      // One route at a time along the cheapest residual route, until none is left.
      let mut rounds = 0
      while rounds <= self.n * self.n {
        rounds = rounds + 1
        if self.shift(source, sink, fn(_) { 1.0 }) <= 0.0 {
          break
        }
      }
    }
  }
}

///|
/// Dinitz: build a level graph by breadth-first search, then push a blocking flow
/// through it, and repeat while the sink is still reachable.
pub fn Network::dinitz(self : Network, source : Int, sink : Int) -> Unit {
  let n = self.n
  let level : Array[Int] = Array::make(n, -1)
  while true {
    for node in 0..<n {
      level[node] = -1
    }
    level[source] = 0
    let queue : Array[Int] = [source]
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      for arc in self.arcs[node] {
        if self.cap[arc] > 0.0 && level[self.to[arc]] < 0 {
          level[self.to[arc]] = level[node] + 1
          queue.push(self.to[arc])
        }
      }
    }
    if level[sink] < 0 {
      break
    }
    let cursor : Array[Int] = Array::make(n, 0)
    while true {
      let pushed = self.push_along(source, sink, @double.infinity, level, cursor)
      if pushed <= 0.0 {
        break
      }
      self.value = self.value + pushed
    }
  }
}

///|
/// Pushes what it can along one route of the level graph, resuming from the cursor so
/// an arc that is full is never looked at twice in one phase.
pub fn Network::push_along(
  self : Network,
  node : Int,
  sink : Int,
  limit : Double,
  level : Array[Int],
  cursor : Array[Int],
) -> Double {
  if node == sink {
    return limit
  }
  while cursor[node] < self.arcs[node].length() {
    let arc = self.arcs[node][cursor[node]]
    let nbr = self.to[arc]
    if self.cap[arc] > 0.0 && level[nbr] == level[node] + 1 {
      let room = if self.cap[arc] < limit { self.cap[arc] } else { limit }
      let pushed = self.push_along(nbr, sink, room, level, cursor)
      if pushed > 0.0 {
        self.cap[arc] = self.cap[arc] - pushed
        self.cap[self.pair[arc]] = self.cap[self.pair[arc]] + pushed
        return pushed
      }
    }
    cursor[node] = cursor[node] + 1
  }
  0.0
}

///|
/// Edmonds-Karp: the same walk with a plain breadth-first search for the route.
pub fn Network::edmonds_karp(self : Network, source : Int, sink : Int) -> Unit {
  while true {
    let previous : Array[Int] = Array::make(self.n, -1)
    let seen : Array[Bool] = Array::make(self.n, false)
    let queue : Array[Int] = [source]
    seen[source] = true
    let mut head = 0
    while head < queue.length() && !seen[sink] {
      let node = queue[head]
      head = head + 1
      for arc in self.arcs[node] {
        if self.cap[arc] > 0.0 && !seen[self.to[arc]] {
          previous[self.to[arc]] = arc
          seen[self.to[arc]] = true
          queue.push(self.to[arc])
        }
      }
    }
    if previous[sink] < 0 {
      break
    }
    let mut amount = @double.infinity
    let mut at = sink
    while at != source {
      let arc = previous[at]
      if self.cap[arc] < amount {
        amount = self.cap[arc]
      }
      at = self.to[self.pair[arc]]
    }
    at = sink
    while at != source {
      let arc = previous[at]
      self.cap[arc] = self.cap[arc] - amount
      self.cap[self.pair[arc]] = self.cap[self.pair[arc]] + amount
      at = self.to[self.pair[arc]]
    }
    self.value = self.value + amount
  }
}

///|
/// Push-relabel: keep an excess at every node and push it towards the sink, lifting a
/// node only when it has nowhere to push.
pub fn Network::push_relabel(self : Network, source : Int, sink : Int) -> Unit {
  let n = self.n
  let excess : Array[Double] = Array::make(n, 0.0)
  let height : Array[Int] = Array::make(n, 0)
  let current : Array[Int] = Array::make(n, 0)
  height[source] = n
  for arc in self.arcs[source] {
    let push = self.cap[arc]
    if push > 0.0 {
      self.cap[arc] = 0.0
      self.cap[self.pair[arc]] = self.cap[self.pair[arc]] + push
      excess[self.to[arc]] = excess[self.to[arc]] + push
      excess[source] = excess[source] - push
    }
  }
  let active : Array[Int] = []
  for node in 0..<n {
    if node != source && node != sink && excess[node] > 0.0 {
      active.push(node)
    }
  }
  let mut rounds = 0
  let limit = n * n * 4 + 16
  while active.length() > 0 && rounds < limit * 4 {
    rounds = rounds + 1
    let node = active[active.length() - 1]
    active.pop() |> ignore
    let mut stalled = true
    while excess[node] > 0.0 && current[node] < self.arcs[node].length() {
      let arc = self.arcs[node][current[node]]
      let nbr = self.to[arc]
      if self.cap[arc] > 0.0 && height[node] == height[nbr] + 1 {
        let push = if self.cap[arc] < excess[node] {
          self.cap[arc]
        } else {
          excess[node]
        }
        self.cap[arc] = self.cap[arc] - push
        self.cap[self.pair[arc]] = self.cap[self.pair[arc]] + push
        excess[node] = excess[node] - push
        let before = excess[nbr]
        excess[nbr] = excess[nbr] + push
        if nbr != source && nbr != sink && before == 0.0 {
          active.push(nbr)
        }
        stalled = false
        if excess[node] <= 0.0 {
          break
        }
      } else {
        current[node] = current[node] + 1
      }
    }
    if excess[node] > 0.0 {
      // Lift and try the whole arc list again.
      height[node] = height[node] + 1
      current[node] = 0
      active.push(node)
    }
    ignore(stalled)
  }
  self.value = excess[sink]
}

///|
/// The graph split into two nodes per node, joined by a capacity of one, so that a
/// minimum cut through it names a set of nodes rather than a set of edges.
pub fn[G : @moongraph.Topology] split_network(
  graph : G,
  source : Int,
  sink : Int,
) -> Network {
  let n = @moongraph.Topology::node_count(graph)
  let arcs : Array[Array[Int]] = Array::makei(n * 2, fn(_) { ([] : Array[Int]) })
  let to : Array[Int] = []
  let cap : Array[Double] = []
  let edge : Array[Int] = []
  let pair : Array[Int] = []
  let link = fn(from : Int, into : Int, capacity : Double, tag : Int) {
    let forward = to.length()
    let backward = forward + 1
    arcs[from].push(forward)
    arcs[into].push(backward)
    to.push(into)
    cap.push(capacity)
    edge.push(tag)
    pair.push(backward)
    to.push(from)
    cap.push(0.0)
    edge.push(tag)
    pair.push(forward)
  }
  for node in 0..<n {
    // The ends are never cut, so their halves are joined by an infinite capacity.
    let capacity = if node == source || node == sink {
      1.0e18
    } else {
      1.0
    }
    link(node * 2, node * 2 + 1, capacity, -1)
  }
  for node in 0..<n {
    let nbrs = @moongraph.Topology::neighbors(graph, node)
    let eids = @moongraph.Topology::incident(graph, node)
    for at in 0..<eids.length() {
      // An edge costs nothing to cut, so it gets an infinite capacity.
      link(node * 2 + 1, nbrs[at] * 2, 1.0e18, eids[at])
    }
  }
  { n: n * 2, arcs, to, cap, edge, pair, value: 0.0 }
}
