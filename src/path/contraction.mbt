// Contraction hierarchies: one preprocessing pass, then queries that only climb.
//
// The idea is the one ch-router and every road-network router is built on. Contract the nodes
// one at a time, always the one that costs least to remove — the one whose removal forces the
// fewest shortcuts. When a node goes, every route that used to pass through it becomes a
// shortcut between its neighbours, so the route survives without the node. Order the
// contractions and every remaining arc points up or down that order, and a query that only
// walks upward from both ends meets in the middle after settling a fraction of the graph.
//
// The preprocessing here is the simple one: a linear scan picks the next node rather than a
// priority queue repairing the order, and the witness search is an exact Dijkstra pruned at the
// shortcut's cost. That keeps the code short and the result correct; on a country-sized road
// network one would want the queue and a hop-limited witness search.

///|
/// The working arcs, with the shortcut tree each one came from, and the two incidence lists the
/// contraction keeps up to date.
priv struct Arcs {
  froms : Array[Int32]
  tos : Array[Int32]
  costs : Array[Double]
  /// The arc this one replaces on the way in, or `-1` when it is one of the graph's own.
  left : Array[Int32]
  /// The arc this one replaces on the way out, or `-1`.
  right : Array[Int32]
  alive : Array[Bool]
  out : Array[Array[Int32]]
  inn : Array[Array[Int32]]
}

///|
fn arcs_new(n : Int32) -> Arcs {
  let out : Array[Array[Int32]] = []
  let inn : Array[Array[Int32]] = []
  for _ in 0..<n {
    out.push([])
    inn.push([])
  }
  { froms: [], tos: [], costs: [], left: [], right: [], alive: [], out, inn, }
}

///|
fn Arcs::arcs_add(
  self : Arcs,
  from : Int32,
  to : Int32,
  cost : Double,
  left : Int32,
  right : Int32,
) -> Int32 {
  let id = self.froms.length()
  self.froms.push(from)
  self.tos.push(to)
  self.costs.push(cost)
  self.left.push(left)
  self.right.push(right)
  self.alive.push(true)
  self.out[from].push(id)
  self.inn[to].push(id)
  id
}

///|
/// How many arcs a contraction of this node would touch: the product of its live in- and
/// out-degrees is the number of pairs that may need a shortcut, and the sum is what the
/// contraction takes away. Lower is cheaper, and the node is contracted first.
fn Arcs::contract_priority(self : Arcs, node : Int32) -> Int32 {
  let mut ins = 0
  for arc in self.inn[node] {
    if self.alive[arc] {
      ins = ins + 1
    }
  }
  let mut outs = 0
  for arc in self.out[node] {
    if self.alive[arc] {
      outs = outs + 1
    }
  }
  ins * outs + ins + outs
}

///|
/// Whether the working graph already has a route from `from` to `to` no more expensive than
/// `limit` that does not pass through `banned`: the witness that makes a shortcut unnecessary.
///
/// The walk is an exact Dijkstra over the live arcs, cut off at `limit`. Cut off at that cost it
/// can only miss a witness that is no cheaper than the shortcut, which is not a witness at all,
/// so the answer agrees with a full search.
fn Arcs::has_witness(
  self : Arcs,
  from : Int32,
  to : Int32,
  limit : Double,
  banned : Int32,
) -> Bool {
  if from == to {
    return true
  }
  let n = self.out.length()
  let distance : Array[Double?] = Array::make(n, (None : Double?))
  let heap = @moonstl.PairingHeap::new_by(cmp=@internal.entry_cmp)
  distance[from] = Some(0.0)
  heap.insert((0.0, from)) |> ignore
  while heap.pop() is Some((cost, node)) {
    match distance[node] {
      Some(best) => if cost > best { continue }
      None => continue
    }
    if cost > limit {
      return false
    }
    if node == to {
      return true
    }
    for arc in self.out[node] {
      if !self.alive[arc] {
        continue
      }
      let next = self.tos[arc]
      if next == banned {
        continue
      }
      let step = cost + self.costs[arc]
      if step > limit {
        continue
      }
      let better = match distance[next] {
        Some(old) => step < old
        None => true
      }
      if better {
        distance[next] = Some(step)
        heap.insert((step, next)) |> ignore
      }
    }
  }
  false
}

///|
/// Whether some live arc already joins `from` to `to` at no more than `cost`, in which case a
/// new shortcut would only be a longer duplicate.
fn Arcs::has_cheaper_arc(
  self : Arcs,
  from : Int32,
  to : Int32,
  cost : Double,
) -> Bool {
  for arc in self.out[from] {
    if self.alive[arc] && self.tos[arc] == to && self.costs[arc] <= cost {
      return true
    }
  }
  false
}

///|
/// Take one node out of the working graph, adding the shortcuts that keep every route through
/// it, and retire the arcs that touched it.
fn Arcs::contract(self : Arcs, node : Int32) -> Unit {
  let ins : Array[Int32] = []
  for arc in self.inn[node] {
    if self.alive[arc] {
      ins.push(arc)
    }
  }
  let outs : Array[Int32] = []
  for arc in self.out[node] {
    if self.alive[arc] {
      outs.push(arc)
    }
  }
  for incoming in ins {
    let from = self.froms[incoming]
    for outgoing in outs {
      let to = self.tos[outgoing]
      if from == to {
        continue
      }
      let cost = self.costs[incoming] + self.costs[outgoing]
      if self.has_witness(from, to, cost, node) {
        continue
      }
      if self.has_cheaper_arc(from, to, cost) {
        continue
      }
      self.arcs_add(from, to, cost, incoming, outgoing) |> ignore
    }
  }
  // The node is gone, so the arcs that ran into or out of it are gone with it. They stay in the
  // structure — the query graph keeps every arc — but the preprocessing never walks them again.
  for arc in ins {
    self.alive[arc] = false
  }
  for arc in outs {
    self.alive[arc] = false
  }
}

///|
/// A graph prepared for repeated cheapest-route queries: the contraction order, and the two
/// halves of every arc, arranged so that a query only ever climbs.
///
/// Building one costs a preprocessing pass; after that a query settles far fewer nodes than
/// Dijkstra would, because it never walks down the order. It is worth it when the same graph is
/// asked many times — a road network answering route requests.
pub(all) struct ContractionHierarchy {
  /// The order each node was contracted in, `0` first. The upward search only climbs it.
  rank : Array[Int32]
  /// The arcs that climb: `(to, cost, arc)` for each arc whose target ranks higher.
  up : Array[Array[(Int32, Double, Int32)]]
  /// The same arcs seen from the other end: `(from, cost, arc)` for each arc whose source
  /// ranks higher. The backward search walks these.
  down : Array[Array[(Int32, Double, Int32)]]
  /// The source of each arc.
  froms : Array[Int32]
  /// The target of each arc.
  tos : Array[Int32]
  /// The cost of each arc.
  costs : Array[Double]
  /// For a shortcut, the arc it replaces on the way in; `-1` for an arc of the graph's own.
  left : Array[Int32]
  /// For a shortcut, the arc it replaces on the way out; `-1` for an arc of the graph's own.
  right : Array[Int32]
}

///|
/// Prepare a graph for repeated cheapest-route queries.
///
/// The arcs of an undirected graph are read both ways, so a shortcut can always be walked in
/// either direction, as the graph itself allows. Negative costs are refused, for the same reason
/// `dijkstra` refuses them: the contraction is only sound when a walk that arrives later cannot
/// be cheaper.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Int32, Double] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (0, 2)],
///     node=0,
///     edge=1.0,
///     directed=false,
///   )
///   let ch = @path.contraction_hierarchy(g)
///   assert_eq(ch.query(0, 2), Some(1.0))
///   assert_eq(ch.query(2, 0), Some(1.0))
/// }
/// ```
pub fn[G : @moongraph.Topology] contraction_hierarchy(
  graph : G,
  weight? : (Int32) -> Double,
) -> ContractionHierarchy raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let n = graph.node_count()
  let arcs = arcs_new(n)
  for edge in 0..<graph.edge_count() {
    let (from, to) = graph.endpoints(edge)
    let cost = w(edge)
    if cost < 0.0 {
      raise @moongraph.Refused::NegativeWeight(edge~)
    }
    arcs.arcs_add(from, to, cost, -1, -1) |> ignore
    if !graph.directed() && from != to {
      arcs.arcs_add(to, from, cost, -1, -1) |> ignore
    }
  }
  let rank : Array[Int32] = Array::make(n, -1)
  let contracted : Array[Bool] = Array::make(n, false)
  for step in 0..<n {
    // The cheapest node still standing, by the count of arcs a contraction would touch.
    let mut next = -1
    let mut next_priority = 0
    for node in 0..<n {
      if contracted[node] {
        continue
      }
      let priority = arcs.contract_priority(node)
      if next < 0 || priority < next_priority {
        next = node
        next_priority = priority
      }
    }
    if next < 0 {
      break
    }
    arcs.contract(next)
    contracted[next] = true
    rank[next] = step
  }
  // Every arc — the graph's own and every shortcut — is filed by the half of the query that can
  // walk it. An arc that climbs the rank order is a forward arc: the search from the source
  // leaves its low end and arrives at its high end. An arc that falls is a backward arc: the
  // search from the target reads it the other way round, leaving its low end and arriving at its
  // high end. An arc is never dropped from the query graph — a contraction drops it from the
  // preprocessing graph only.
  let up : Array[Array[(Int32, Double, Int32)]] = []
  let down : Array[Array[(Int32, Double, Int32)]] = []
  for _ in 0..<n {
    up.push([])
    down.push([])
  }
  for arc in 0..<arcs.froms.length() {
    let from = arcs.froms[arc]
    let to = arcs.tos[arc]
    let cost = arcs.costs[arc]
    if rank[from] < rank[to] {
      up[from].push((to, cost, arc))
    } else if rank[to] < rank[from] {
      down[to].push((from, cost, arc))
    }
  }
  {
    rank,
    up,
    down,
    froms: arcs.froms,
    tos: arcs.tos,
    costs: arcs.costs,
    left: arcs.left,
    right: arcs.right,
  }
}

///|
/// What one query found: where the two searches met, what it cost, and the arcs each of them
/// walked to get there.
priv struct Meeting {
  node : Int32
  cost : Double
  forward : Array[Int32?]
  backward : Array[Int32?]
}

///|
/// Both searches at once, each walking only arcs that climb the rank order, and the cheapest
/// place they overlap. The forward search leaves, for each node it settles, the arc it arrived
/// on; the backward search does the same from the other end. Together they are the route.
fn ContractionHierarchy::search(
  self : ContractionHierarchy,
  source : Int32,
  target : Int32,
) -> Meeting? {
  let n = self.rank.length()
  if source < 0 || source >= n || target < 0 || target >= n {
    return None
  }
  let ahead : Array[Double?] = Array::make(n, (None : Double?))
  let behind : Array[Double?] = Array::make(n, (None : Double?))
  let forward : Array[Int32?] = Array::make(n, (None : Int32?))
  let backward : Array[Int32?] = Array::make(n, (None : Int32?))
  let ahead_heap = @moonstl.PairingHeap::new_by(cmp=@internal.entry_cmp)
  let behind_heap = @moonstl.PairingHeap::new_by(cmp=@internal.entry_cmp)
  ahead[source] = Some(0.0)
  ahead_heap.insert((0.0, source)) |> ignore
  behind[target] = Some(0.0)
  behind_heap.insert((0.0, target)) |> ignore
  while ahead_heap.pop() is Some((cost, node)) {
    match ahead[node] {
      Some(best) => if cost > best { continue }
      None => continue
    }
    for step in self.up[node] {
      let (next, price, arc) = step
      let reached = cost + price
      let better = match ahead[next] {
        Some(old) => reached < old
        None => true
      }
      if better {
        ahead[next] = Some(reached)
        forward[next] = Some(arc)
        ahead_heap.insert((reached, next)) |> ignore
      }
    }
  }
  while behind_heap.pop() is Some((cost, node)) {
    match behind[node] {
      Some(best) => if cost > best { continue }
      None => continue
    }
    for step in self.down[node] {
      let (next, price, arc) = step
      let reached = cost + price
      let better = match behind[next] {
        Some(old) => reached < old
        None => true
      }
      if better {
        behind[next] = Some(reached)
        backward[next] = Some(arc)
        behind_heap.insert((reached, next)) |> ignore
      }
    }
  }
  let mut meeting = -1
  let mut best = 1.0e300
  for node in 0..<n {
    match (ahead[node], behind[node]) {
      (Some(a), Some(b)) =>
        if a + b < best {
          best = a + b
          meeting = node
        }
      _ => ()
    }
  }
  if meeting < 0 {
    None
  } else {
    Some({ node: meeting, cost: best, forward, backward, })
  }
}

///|
/// The cheapest cost from `source` to `target` through the prepared graph, or `None` when the
/// one cannot reach the other.
///
/// Two searches run, the forward one climbing the rank order from `source` and the backward one
/// climbing it from `target`, and the answer is the cheapest place they meet. No arc going down
/// the order is ever walked, which is what makes the query small.
pub fn ContractionHierarchy::query(
  self : ContractionHierarchy,
  source : Int32,
  target : Int32,
) -> Double? {
  match self.search(source, target) {
    Some(found) => Some(found.cost)
    None => None
  }
}

///|
/// The route itself, both ends included, or `None` when `source` cannot reach `target`.
///
/// The two searches leave a trail of arcs; each shortcut on it is unpacked into the two arcs it
/// stands for, and those into theirs, until every arc left is one of the graph's own edges. What
/// comes back is a walk in the graph, not in the prepared structure.
pub fn ContractionHierarchy::path(
  self : ContractionHierarchy,
  source : Int32,
  target : Int32,
) -> Array[Int32]? {
  let found = match self.search(source, target) {
    Some(found) => found
    None => return None
  }
  let ahead : Array[Int32] = []
  let mut node = found.node
  let mut climbing = true
  while climbing {
    match found.forward[node] {
      Some(arc) => {
        ahead.push(arc)
        node = self.froms[arc]
      }
      None => climbing = false
    }
  }
  let behind : Array[Int32] = []
  let mut back = found.node
  let mut descending = true
  while descending {
    match found.backward[back] {
      Some(arc) => {
        behind.push(arc)
        back = self.tos[arc]
      }
      None => descending = false
    }
  }
  // The forward trail runs meeting-first, so read it backwards; the backward one already runs
  // towards the target.
  let trail : Array[Int32] = []
  for at in 0..<ahead.length() {
    trail.push(ahead[ahead.length() - 1 - at])
  }
  for arc in behind {
    trail.push(arc)
  }
  let edges : Array[Int32] = []
  for arc in trail {
    self.unpack(arc, edges)
  }
  if edges.length() == 0 {
    return Some([source])
  }
  let route : Array[Int32] = [self.froms[edges[0]]]
  for arc in edges {
    route.push(self.tos[arc])
  }
  Some(route)
}

///|
/// Unpack one arc into the graph's own edges, depth first: a shortcut is its two halves, and
/// each half may be a shortcut in turn. The contraction order guarantees the recursion ends,
/// because a shortcut's halves always point at nodes contracted earlier.
fn ContractionHierarchy::unpack(
  self : ContractionHierarchy,
  arc : Int32,
  out : Array[Int32],
) -> Unit {
  if self.left[arc] < 0 {
    out.push(arc)
  } else {
    self.unpack(self.left[arc], out)
    self.unpack(self.right[arc], out)
  }
}

///|
/// How many shortcuts the preprocessing added: the arcs beyond the graph's own edges, counting
/// each undirected edge once per direction.
pub fn ContractionHierarchy::shortcut_count(
  self : ContractionHierarchy,
) -> Int32 {
  let mut count = 0
  for arc in 0..<self.left.length() {
    if self.left[arc] >= 0 {
      count = count + 1
    }
  }
  count
}

///|
/// The position of a node in the contraction order, or `-1` for a number the graph does not
/// have.
pub fn ContractionHierarchy::rank_of(
  self : ContractionHierarchy,
  node : Int32,
) -> Int32 {
  if node < 0 || node >= self.rank.length() {
    -1
  } else {
    self.rank[node]
  }
}
