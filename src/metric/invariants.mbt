// Invariants and spectra: what two graphs share, and what a graph's adjacency does when it
// is exponentiated.

///|
/// The Weisfeiler-Lehman hash of a graph: a fingerprint that isomorphic graphs always share.
///
/// Each node starts with its degree — or, for a directed graph, its in and out degree
/// together. Each round replaces every node's label with the hash of its neighbours' labels,
/// sorted so that the order the edges were read in cannot matter. The final fingerprint is
/// the hash of the histogram of labels after every round, which is why two graphs that agree
/// locally for `iterations` steps get the same string.
///
/// `iterations` counts rounds of refinement, and the degree labels are the first of them, as
/// in the reference: the default of three means two hashing rounds after the degrees.
///
/// The refinement is the reference's `weisfeiler_lehman_graph_hash`, round for round: the
/// node's own label leads its neighbours', a directed node reads its successors before its
/// predecessors, and each list is sorted so the order the edges were added cannot matter.
/// The digest is blake2b narrowed to sixteen bytes, which is the width the reference takes,
/// so the two fingerprints of one graph are the same string.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (2, 0)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   // The same graph numbered differently is the same graph.
///   let turned = g.relabel([2, 0, 1])
///   assert_eq(@metric.wl_hash(g), @metric.wl_hash(turned))
/// }
/// ```
pub fn[G : @moongraph.Topology + @moongraph.Inbound] wl_hash(
  graph : G,
  iterations~ : Int32 = 3,
) -> String {
  let n = @moongraph.Topology::node_count(graph)
  let directed = @moongraph.Topology::directed(graph)
  let mut labels : Array[String] = Array::makei(n, fn(node) {
    if directed {
      let inside = @moongraph.Inbound::in_incident(graph, node).length()
      let outside = @moongraph.Topology::incident(graph, node).length()
      inside.to_string() + "_" + outside.to_string()
    } else {
      @moongraph.Topology::incident(graph, node).length().to_string()
    }
  })
  // The degrees are the first round; the caller's count includes them.
  let rounds = iterations - 1
  let history : Array[(String, Int32)] = []
  for _ in 0..<rounds {
    let next : Array[String] = Array::make(n, "")
    for node in 0..<n {
      let around : Array[String] = []
      let behind : Array[String] = []
      for nbr in @internal.distinct_neighbors(graph, node) {
        around.push(if directed { "s_" + labels[nbr] } else { labels[nbr] })
      }
      around.sort()
      if directed {
        // A node of a directed graph is told apart by what it points at and what points
        // at it, and the two lists cannot merge: an arc one way is not the arc back.
        for nbr in @internal.distinct_in_neighbors(graph, node) {
          behind.push("p_" + labels[nbr])
        }
        behind.sort()
      }
      // The node's own label leads the sorted neighbour labels, as in the reference: the
      // round has to be able to tell two neighbourhoods apart that share every neighbour.
      let mut blob = labels[node]
      for label in around {
        blob = blob + label
      }
      for label in behind {
        blob = blob + label
      }
      next[node] = digest16(blob)
    }
    labels = next
    // The histogram of this round, sorted, is what the final hash is taken over.
    let seen : Array[String] = labels.copy()
    seen.sort()
    let mut at = 0
    while at < seen.length() {
      let label = seen[at]
      let mut count = 0
      while at < seen.length() && seen[at] == label {
        count = count + 1
        at = at + 1
      }
      history.push((label, count))
    }
  }
  digest16(tuple_text(history))
}

///|
/// The digest a label is folded with: blake2b narrowed to sixteen bytes, in lowercase hex.
///
/// Sixteen is the width the reference takes, so a fingerprint from this library and one
/// from that one are the same text for the same graph, not merely two strings that agree
/// on which graphs are isomorphic.
fn digest16(text : String) -> String {
  @hex.encode(
    @blake2.hash(@utf8.encode(text), kind=@blake2.Kind::Blake2b, len=16),
  )
}

///|
/// A list of counted labels written the way Python writes a tuple of pairs, because the last
/// hash is taken over that text: the reference hashes a tuple's `repr`, and matching it byte
/// for byte is what makes the two fingerprints comparable.
fn tuple_text(history : Array[(String, Int32)]) -> String {
  if history.length() == 0 {
    return "()"
  }
  let mut out = "("
  for i in 0..<history.length() {
    if i > 0 {
      out = out + ", "
    }
    out = out + "('" + history[i].0 + "', " + history[i].1.to_string() + ")"
  }
  if history.length() == 1 {
    out = out + ",)"
  } else {
    out = out + ")"
  }
  out
}

///|
/// How many routes of every length join each pair of nodes, summed into one number: the
/// entry `(u,v)` of `exp(A)`, where `A` is the adjacency matrix. The diagonal is the number of
/// closed walks from a node back to itself, and the off-diagonal is the count of walks of any
/// length — a measure of how many ways the two nodes can reach each other, which is the
/// matrix counterpart of "how well connected" in a network with cycles.
///
/// The matrix exponential is taken by scaling and squaring with a Taylor series, since the
/// degree of the graph is what bounds the norm and the series converges quickly after the
/// scaling. Weights, when given, are the adjacency entries.
pub fn[G : @moongraph.Topology] communicability(
  graph : G,
  weight? : (Int32) -> Double,
) -> Array[Array[Double]] {
  let w = @internal.take_weight(weight)
  let n = @moongraph.Topology::node_count(graph)
  let a : Array[Array[Double]] = Array::makei(n, fn(_) { Array::make(n, 0.0) })
  for node in 0..<n {
    let nbrs = @moongraph.Topology::neighbors(graph, node)
    let eids = @moongraph.Topology::incident(graph, node)
    for at in 0..<eids.length() {
      let other = nbrs[at]
      if other != node {
        a[node][other] = a[node][other] + w(eids[at])
      }
    }
  }
  matrix_exp(a)
}

///|
/// The exponential of a square matrix, by scaling and squaring: halve the matrix until its
/// norm is below one, sum the Taylor series there, then square the result back up.
fn matrix_exp(a : Array[Array[Double]]) -> Array[Array[Double]] {
  let n = a.length()
  let mut norm = 0.0
  for row in 0..<n {
    let mut sum = 0.0
    for col in 0..<n {
      sum = sum + (if a[row][col] < 0.0 { -a[row][col] } else { a[row][col] })
    }
    if sum > norm {
      norm = sum
    }
  }
  let mut squarings = 0
  let mut scaled = a
  while norm > 1.0 && squarings < 64 {
    scaled = matrix_scale(scaled, 0.5)
    norm = norm * 0.5
    squarings = squarings + 1
  }
  // Twenty terms are far past the precision a measurement needs once the norm is below one.
  let mut total = matrix_identity(n)
  let mut term = matrix_identity(n)
  for step in 1..<=20 {
    term = matrix_scale(matrix_multiply(term, scaled), 1.0 / step.to_double())
    total = matrix_add(total, term)
  }
  for _ in 0..<squarings {
    total = matrix_multiply(total, total)
  }
  total
}

///|
/// The identity of a size.
fn matrix_identity(n : Int32) -> Array[Array[Double]] {
  Array::makei(n, fn(row) {
    Array::makei(n, fn(col) { if row == col { 1.0 } else { 0.0 } })
  })
}

///|
fn matrix_scale(
  a : Array[Array[Double]],
  factor : Double,
) -> Array[Array[Double]] {
  Array::makei(a.length(), fn(row) {
    Array::makei(a.length(), fn(col) { a[row][col] * factor })
  })
}

///|
fn matrix_add(
  a : Array[Array[Double]],
  b : Array[Array[Double]],
) -> Array[Array[Double]] {
  Array::makei(a.length(), fn(row) {
    Array::makei(a.length(), fn(col) { a[row][col] + b[row][col] })
  })
}

///|
fn matrix_multiply(
  a : Array[Array[Double]],
  b : Array[Array[Double]],
) -> Array[Array[Double]] {
  let n = a.length()
  Array::makei(n, fn(row) {
    Array::makei(n, fn(col) {
      let mut sum = 0.0
      for k in 0..<n {
        sum = sum + a[row][k] * b[k][col]
      }
      sum
    })
  })
}

///|
/// Current-flow closeness: how close a node is to the rest when distance is measured as
/// electrical resistance rather than as the length of a route. A node with many parallel
/// paths scores better than one behind a single bridge, even when both are the same number of
/// hops from everything, which is the difference between counting routes and measuring how
/// much they can carry.
///
/// The score is `(n-1) / Σ R(u,v)`, the reciprocal of the total resistance to every other
/// node. A node that cannot reach another has no finite score and answers zero.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] current_flow_closeness(
  graph : G,
  weight? : (Int32) -> Double,
) -> @moongraph.Scores {
  let n = @moongraph.Topology::node_count(graph)
  let score : Array[Double] = Array::make(n, 0.0)
  if n < 2 {
    return { score, }
  }
  let resistance = resistance_matrix(graph, weight?)
  for node in 0..<n {
    let mut total = 0.0
    let mut whole = true
    for other in 0..<n {
      if other == node {
        continue
      }
      match resistance[node][other] {
        Some(value) => total = total + value
        None => whole = false
      }
    }
    if whole && total > 0.0 {
      score[node] = (n - 1).to_double() / total
    }
  }
  { score, }
}

///|
/// The nodes a spreading process should start from, by the VoteRank rule: every node starts
/// with a vote of one and a score of zero, the score of a node is the abilities of its
/// neighbours, the best score is elected, and the elected node's neighbours lose a little
/// ability — a share of `1/avg(degree)` each — so that a cluster cannot elect itself twice.
///
/// The answer is the order in which nodes were elected: a small set of spreaders that between
/// them reach the graph, with close neighbours losing their say as soon as one of them is
/// chosen. Ties go to the smaller node number, so the order does not depend on how the nodes
/// happened to be stored.
pub fn[G : @moongraph.Topology] voterank(graph : G) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Int32] = []
  if n == 0 {
    return out
  }
  let mut degree_total = 0
  for node in 0..<n {
    degree_total = degree_total +
      @internal.distinct_neighbors(graph, node).length()
  }
  let average = degree_total.to_double() / n.to_double()
  let score : Array[Double] = Array::make(n, 0.0)
  let ability : Array[Double] = Array::make(n, 1.0)
  let elected : Array[Bool] = Array::make(n, false)
  for _ in 0..<n {
    for node in 0..<n {
      score[node] = 0.0
    }
    for node in 0..<n {
      for nbr in @internal.distinct_neighbors(graph, node) {
        score[node] = score[node] + ability[nbr]
      }
    }
    // A node already elected has no say in the next round.
    let mut best = -1
    for node in 0..<n {
      if elected[node] {
        score[node] = 0.0
      }
      if score[node] > 0.0 && (best < 0 || score[node] > score[best]) {
        best = node
      }
    }
    if best < 0 {
      break
    }
    out.push(best)
    elected[best] = true
    ability[best] = 0.0
    let share = if average > 0.0 { 1.0 / average } else { 0.0 }
    for nbr in @internal.distinct_neighbors(graph, best) {
      let weaker = ability[nbr] - share
      ability[nbr] = if weaker > 0.0 { weaker } else { 0.0 }
    }
  }
  out
}
