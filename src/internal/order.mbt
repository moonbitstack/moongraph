// The order a walk visits edges in when several answers are equally good.
//
// Adjacency lists keep edges in the order they were added, which is what makes
// insertion O(1). Algorithms that must agree with each other therefore sort the
// handful of edges at one node instead: by the other endpoint's number, then by
// edge number. That is the tie-break the whole library promises.

///|
/// The edges leaving a node as `(neighbour, edge)`, sorted by neighbour and then
/// by edge number.
pub fn[G : @moongraph.Topology] out_edges(
  g : G,
  node : Int32,
) -> Array[(Int32, Int32)] {
  let nbrs = g.neighbors(node)
  let eids = g.incident(node)
  let limit = if nbrs.length() < eids.length() {
    nbrs.length()
  } else {
    eids.length()
  }
  let out : Array[(Int32, Int32)] = Array::makei(limit, fn(i) {
    (nbrs[i], eids[i])
  })
  out.sort_by(fn(a, b) { if a.0 != b.0 { a.0 - b.0 } else { a.1 - b.1 } })
  out
}

///|
/// The edges entering a node as `(neighbour, edge)`, sorted the same way.
pub fn[G : @moongraph.Inbound] in_edges(
  g : G,
  node : Int32,
) -> Array[(Int32, Int32)] {
  let nbrs = g.in_neighbors(node)
  let eids = g.in_incident(node)
  let limit = if nbrs.length() < eids.length() {
    nbrs.length()
  } else {
    eids.length()
  }
  let out : Array[(Int32, Int32)] = Array::makei(limit, fn(i) {
    (nbrs[i], eids[i])
  })
  out.sort_by(fn(a, b) { if a.0 != b.0 { a.0 - b.0 } else { a.1 - b.1 } })
  out
}

///|
/// The neighbours of a node, ascending and without repeats. `neighbors` repeats a
/// node once per parallel edge; the algorithms that only care about reachability
/// want each neighbour once.
pub fn[G : @moongraph.Topology] distinct_neighbors(
  g : G,
  node : Int32,
) -> Array[Int32] {
  let nbrs = g.neighbors(node)
  let out : Array[Int32] = Array::makei(nbrs.length(), fn(i) { nbrs[i] })
  out.sort()
  let unique : Array[Int32] = []
  for nbr in out {
    if unique.length() == 0 || unique[unique.length() - 1] != nbr {
      unique.push(nbr)
    }
  }
  unique
}

///|
/// The predecessors of a node, ascending and without repeats: the same reading as
/// `distinct_neighbors`, for the arcs that come in.
pub fn[G : @moongraph.Inbound] distinct_in_neighbors(
  g : G,
  node : Int32,
) -> Array[Int32] {
  let nbrs = g.in_neighbors(node)
  let out : Array[Int32] = Array::makei(nbrs.length(), fn(i) { nbrs[i] })
  out.sort()
  let unique : Array[Int32] = []
  for nbr in out {
    if unique.length() == 0 || unique[unique.length() - 1] != nbr {
      unique.push(nbr)
    }
  }
  unique
}

///|
/// The weight of an edge when the caller did not give one.
pub let unit_weight : (Int32) -> Double = fn(_) { 1.0 }

///|
/// A weight function with the default filled in.
pub fn take_weight(weight : ((Int32) -> Double)?) -> (Int32) -> Double {
  weight.unwrap_or(unit_weight)
}

///|
/// Lexicographic order of a cost and a node number: the number that decides a
/// tie, in one place.
pub fn ahead(
  cost_a : Double,
  node_a : Int32,
  cost_b : Double,
  node_b : Int32,
) -> Bool {
  if cost_a < cost_b {
    true
  } else if cost_a > cost_b {
    false
  } else {
    node_a < node_b
  }
}

///|
/// The compare a heap of `(cost, item)` entries needs so that it pops by cost,
/// then by item: the tie-break a search settles nodes by, in the same one place
/// `ahead` keeps it. Negative means the first entry pops first.
pub fn entry_cmp(a : (Double, Int32), b : (Double, Int32)) -> Int32 {
  if a.0 < b.0 {
    -1
  } else if a.0 > b.0 {
    1
  } else {
    a.1 - b.1
  }
}

///|
/// The cheapest edge between two adjacent nodes, or `None` when they are not adjacent.
pub fn[G : @moongraph.Topology] cheapest(
  g : G,
  from : Int32,
  to : Int32,
  w : (Int32) -> Double,
) -> Int32? {
  let nbrs = g.neighbors(from)
  let eids = g.incident(from)
  let mut best : Int32? = None
  let mut best_cost = 0.0
  for at in 0..<eids.length() {
    if nbrs[at] == to {
      let cost = w(eids[at])
      match best {
        Some(_) =>
          if cost < best_cost {
            best = Some(eids[at])
            best_cost = cost
          }
        None => {
          best = Some(eids[at])
          best_cost = cost
        }
      }
    }
  }
  best
}

///|
/// The lowest-numbered edge between two adjacent nodes.
pub fn[G : @moongraph.Topology] first_edge(
  g : G,
  from : Int32,
  to : Int32,
) -> Int32? {
  let nbrs = g.neighbors(from)
  let eids = g.incident(from)
  for at in 0..<eids.length() {
    if nbrs[at] == to {
      return Some(eids[at])
    }
  }
  None
}

///|
/// Whether an edge joins the two nodes.
pub fn[G : @moongraph.Topology] adjacent(g : G, a : Int32, b : Int32) -> Bool {
  match first_edge(g, a, b) {
    Some(_) => true
    None => false
  }
}

///|
/// Whether the graph can be two-coloured, by a breadth-first walk that fails when an
/// edge joins two nodes of the same colour.
pub fn[G : @moongraph.Topology] is_bipartite(g : G) -> Bool {
  let n = @moongraph.Topology::node_count(g)
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
      for nbr in g.neighbors(node) {
        if nbr == node {
          return false
        }
        if colour[nbr] < 0 {
          colour[nbr] = 1 - colour[node]
          queue.push(nbr)
        } else if colour[nbr] == colour[node] {
          return false
        }
      }
    }
  }
  true
}
