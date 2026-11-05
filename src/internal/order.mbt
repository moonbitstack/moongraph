// The order a walk visits edges in when several answers are equally good.
//
// Adjacency lists keep edges in the order they were added, which is what makes
// insertion O(1). Algorithms that must agree with each other therefore sort the
// handful of edges at one node instead: by the other endpoint's number, then by
// edge number. That is the tie-break the whole library promises.

///|
/// The edges leaving a node as `(neighbour, edge)`, sorted by neighbour and then
/// by edge number.
pub fn[G : @moongraph.Topology] out_edges(g : G, node : Int) -> Array[(Int, Int)] {
  let nbrs = g.neighbors(node)
  let eids = g.incident(node)
  let limit = if nbrs.length() < eids.length() {
    nbrs.length()
  } else {
    eids.length()
  }
  let out : Array[(Int, Int)] = Array::makei(limit, fn(i) { (nbrs[i], eids[i]) })
  out.sort_by(fn(a, b) {
    if a.0 != b.0 {
      a.0 - b.0
    } else {
      a.1 - b.1
    }
  })
  out
}

///|
/// The edges entering a node as `(neighbour, edge)`, sorted the same way.
pub fn[G : @moongraph.Inbound] in_edges(g : G, node : Int) -> Array[(Int, Int)] {
  let nbrs = g.in_neighbors(node)
  let eids = g.in_incident(node)
  let limit = if nbrs.length() < eids.length() {
    nbrs.length()
  } else {
    eids.length()
  }
  let out : Array[(Int, Int)] = Array::makei(limit, fn(i) { (nbrs[i], eids[i]) })
  out.sort_by(fn(a, b) {
    if a.0 != b.0 {
      a.0 - b.0
    } else {
      a.1 - b.1
    }
  })
  out
}

///|
/// The neighbours of a node, ascending and without repeats. `neighbors` repeats a
/// node once per parallel edge; the algorithms that only care about reachability
/// want each neighbour once.
pub fn[G : @moongraph.Topology] distinct_neighbors(g : G, node : Int) -> Array[Int] {
  let nbrs = g.neighbors(node)
  let out : Array[Int] = Array::makei(nbrs.length(), fn(i) { nbrs[i] })
  out.sort()
  let unique : Array[Int] = []
  for nbr in out {
    if unique.length() == 0 || unique[unique.length() - 1] != nbr {
      unique.push(nbr)
    }
  }
  unique
}

///|
/// The weight of an edge when the caller did not give one.
pub let unit_weight : (Int) -> Double = fn(_) { 1.0 }

///|
/// A weight function with the default filled in.
pub fn take_weight(weight : ((Int) -> Double)?) -> (Int) -> Double {
  weight.unwrap_or(unit_weight)
}

///|
/// Lexicographic order of a cost and a node number: the number that decides a
/// tie, in one place.
pub fn ahead(cost_a : Double, node_a : Int, cost_b : Double, node_b : Int) -> Bool {
  if cost_a < cost_b {
    true
  } else if cost_a > cost_b {
    false
  } else {
    node_a < node_b
  }
}
