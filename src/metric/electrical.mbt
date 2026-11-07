// Electrical networks: the graph as a circuit, and how much it resists a current between
// two of its nodes.

///|
/// The conductance of every edge, read as a matrix: the Laplacian. A node's diagonal is the
/// total conductance leaving it, and the off-diagonal entry between two nodes is minus the
/// conductance joining them. An edge weight is read as conductance, so a heavier edge
/// resists less.
fn[G : @moongraph.Topology] laplacian(
  graph : G,
  w : (Int32) -> Double,
) -> Array[Array[Double]] {
  let n = @moongraph.Topology::node_count(graph)
  let lap : Array[Array[Double]] = Array::makei(n, fn(_) { Array::make(n, 0.0) })
  for node in 0..<n {
    let nbrs = @moongraph.Topology::neighbors(graph, node)
    let eids = @moongraph.Topology::incident(graph, node)
    for at in 0..<eids.length() {
      let other = nbrs[at]
      if other == node {
        // A self-loop adds conductance and takes it away again.
        continue
      }
      if @moongraph.Topology::directed(graph) || node < other {
        let conductance = w(eids[at])
        lap[node][node] = lap[node][node] + conductance
        lap[other][other] = lap[other][other] + conductance
        lap[node][other] = lap[node][other] - conductance
        lap[other][node] = lap[other][node] - conductance
      }
    }
  }
  lap
}

///|
/// The Cholesky factor of a symmetric positive definite matrix: the lower triangular `L`
/// with `L·Lᵀ = A`. `None` when the matrix is not positive definite, which is what a graph
/// that falls into pieces looks like from here — a piece with no path to the ground has no
/// resistance to measure.
fn cholesky(a : Array[Array[Double]]) -> Array[Array[Double]]? {
  let n = a.length()
  let low : Array[Array[Double]] = Array::makei(n, fn(_) { Array::make(n, 0.0) })
  for i in 0..<n {
    for j in 0..<=i {
      let mut sum = a[i][j]
      for k in 0..<j {
        sum = sum - low[i][k] * low[j][k]
      }
      if i == j {
        if sum <= 0.0 {
          return None
        }
        low[i][j] = sum.sqrt()
      } else {
        low[i][j] = sum / low[j][j]
      }
    }
  }
  Some(low)
}

///|
/// One column of the inverse of a Cholesky factor's matrix, by forward and back
/// substitution.
fn cholesky_solve(
  low : Array[Array[Double]],
  b : Array[Double],
) -> Array[Double] {
  let n = low.length()
  let y : Array[Double] = Array::make(n, 0.0)
  for i in 0..<n {
    let mut sum = b[i]
    for k in 0..<i {
      sum = sum - low[i][k] * y[k]
    }
    y[i] = sum / low[i][i]
  }
  let x : Array[Double] = Array::make(n, 0.0)
  for step in 0..<n {
    let i = n - 1 - step
    let mut sum = y[i]
    for k in (i + 1)..<n {
      sum = sum - low[k][i] * x[k]
    }
    x[i] = sum / low[i][i]
  }
  x
}

///|
/// The resistance distance between every pair of nodes: what a circuit built from the graph
/// would resist between them. `None` outside the graph, and for a pair in different pieces.
///
/// The graph is grounded at its last node and the resulting system solved once per node,
/// which is the same answer as the pseudo-inverse of the Laplacian but without forming one.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   // Two unit resistors in series: one ohm to the middle, two to the far end.
///   assert_eq(@metric.resistance_distance(g, 0, 1), Some(1.0))
///   assert_eq(@metric.resistance_distance(g, 0, 2), Some(2.0))
/// }
/// ```
pub fn[G : @moongraph.Topology + @moongraph.Inbound] resistance_distance(
  graph : G,
  a : Int32,
  b : Int32,
  weight? : (Int32) -> Double,
) -> Double? {
  let all = resistance_matrix(graph, weight?)
  if a < 0 || b < 0 || a >= all.length() || b >= all.length() {
    return None
  }
  all[a][b]
}

///|
/// Every pair's resistance distance, as a matrix. The answer is symmetric, its diagonal is
/// zero, and a pair in different pieces of a graph that falls apart is `None` — no current
/// can pass between them, which is not the same as a resistance of zero.
///
/// An edge weight is a conductance: a weight of one everywhere makes resistance and hops
/// agree on a tree and disagree everywhere else — a detour of many small resistors can be
/// cheaper than one narrow bridge, which is exactly the difference between counting edges
/// and measuring them.
///
/// Each piece is solved on its own, grounded at one of its own nodes, so a graph made of
/// several pieces still answers inside each of them.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] resistance_matrix(
  graph : G,
  weight? : (Int32) -> Double,
) -> Array[Array[Double?]] {
  let w = @internal.take_weight(weight)
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Array[Double?]] = Array::makei(n, fn(_) {
    Array::make(n, (None : Double?))
  })
  if n == 0 {
    return out
  }
  let lap = laplacian(graph, w)
  // The pieces, walked without regard to direction: a Laplacian is symmetric, so the
  // pieces that matter are the ones the edges hold together.
  let piece : Array[Int32] = Array::make(n, -1)
  let mut pieces = 0
  for start in 0..<n {
    if piece[start] >= 0 {
      continue
    }
    piece[start] = pieces
    let queue : Array[Int32] = [start]
    let mut head = 0
    while head < queue.length() {
      let at = queue[head]
      head = head + 1
      for nbr in @moongraph.Topology::neighbors(graph, at) {
        if piece[nbr] < 0 {
          piece[nbr] = pieces
          queue.push(nbr)
        }
      }
      if @moongraph.Topology::directed(graph) {
        for nbr in @moongraph.Inbound::in_neighbors(graph, at) {
          if piece[nbr] < 0 {
            piece[nbr] = pieces
            queue.push(nbr)
          }
        }
      }
    }
    pieces = pieces + 1
  }
  let groups : Array[Array[Int32]] = Array::makei(pieces, fn(_) { [] })
  for node in 0..<n {
    groups[piece[node]].push(node)
  }
  for group in groups {
    let size = group.length()
    if size == 1 {
      out[group[0]][group[0]] = Some(0.0)
      continue
    }
    // Ground at the last node of the piece: its row and column leave the system, and every
    // solved value is then a voltage relative to it.
    let span = size - 1
    let reduced : Array[Array[Double]] = Array::makei(span, fn(i) {
      Array::makei(span, fn(j) { lap[group[i]][group[j]] })
    })
    let low = match cholesky(reduced) {
      Some(factor) => factor
      None => continue
    }
    let inverse : Array[Array[Double]] = Array::makei(size, fn(_) {
      Array::make(size, 0.0)
    })
    for i in 0..<span {
      let unit : Array[Double] = Array::make(span, 0.0)
      unit[i] = 1.0
      let column = cholesky_solve(low, unit)
      for row in 0..<span {
        inverse[row][i] = column[row]
      }
    }
    for i in 0..<size {
      out[group[i]][group[i]] = Some(0.0)
      for j in (i + 1)..<size {
        let value = inverse[i][i] + inverse[j][j] - 2.0 * inverse[i][j]
        // The arithmetic can land a rounding step below zero on a pair joined directly.
        let clean = if value < 0.0 { 0.0 } else { value }
        out[group[i]][group[j]] = Some(clean)
        out[group[j]][group[i]] = Some(clean)
      }
    }
  }
  out
}
