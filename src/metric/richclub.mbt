// The rich-club coefficient: do the nodes with the most edges also know each other?

///|
/// Whether the well-connected nodes of a graph are connected to each other. For each degree
/// `k`, `phi(k)` is the share of the edges that could join the nodes of degree above `k`
/// that actually do: `2·E_k / (N_k·(N_k - 1))`.
///
/// A value near `1` says the rich form a club — the graph is hierarchical, with a dense
/// core and a thin fringe. A value near the graph's density says degree tells you nothing
/// about who knows whom. The coefficient is undefined, and reported as `None`, for the
/// thresholds where fewer than two nodes are above it.
///
/// Entry `i` of the answer is `phi(i)`, so the array stops at the largest degree: there is
/// nothing above it to form a club with. Weights are ignored, as they are in the
/// reference, and self-loops are not counted.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (0, 2), (1, 2), (2, 3)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   // Nodes 0, 1 and 2 have degree 2; 3 has degree 1. Above degree 0 sit all four, and
///   // four of the six possible edges are present.
///   assert_eq(@metric.rich_club(g)[0], Some(4.0 / 6.0))
/// }
/// ```
pub fn[G : @moongraph.Topology] rich_club(graph : G) -> Array[Double?] {
  let n = @moongraph.Topology::node_count(graph)
  let degrees = degree(graph)
  let mut max_degree = 0
  for value in degrees {
    if value > max_degree {
      max_degree = value
    }
  }
  let out : Array[Double?] = []
  for threshold in 0..<max_degree {
    // The club: every node above this degree.
    let in_club : Array[Bool] = Array::make(n, false)
    let mut inside = 0
    for node in 0..<n {
      if degrees[node] > threshold {
        in_club[node] = true
        inside = inside + 1
      }
    }
    if inside < 2 {
      out.push(None)
      continue
    }
    let mut edges = 0
    for node in 0..<n {
      if !in_club[node] {
        continue
      }
      for nbr in @internal.distinct_neighbors(graph, node) {
        if nbr > node && in_club[nbr] {
          edges = edges + 1
        }
      }
    }
    out.push(
      Some(2.0 * edges.to_double() / (inside * (inside - 1)).to_double()),
    )
  }
  out
}

///|
/// The coefficient at one threshold, by name rather than by walking the whole array.
pub fn[G : @moongraph.Topology] rich_club_at(
  graph : G,
  degree : Int32,
) -> Double? {
  let all = rich_club(graph)
  if degree < 0 || degree >= all.length() {
    None
  } else {
    all[degree]
  }
}
