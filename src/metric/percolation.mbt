// Percolation centrality: betweenness weighted by how infected the source of each route is.

///|
/// Percolation centrality: betweenness where a route counts for how much of the graph it
/// starts in. Each node carries a state — the share of it that is "percolated", one for a
/// node already infected, zero for one untouched — and a pair `(s,t)` contributes to a node
/// in proportion to `x(s) / (Σx − x(v))`, the infected share of the source over the infected
/// share available beside the node being measured.
///
/// This is the measure a spreading process needs and plain betweenness cannot give: the same
/// crossroads matter enormously while the infection is in one corner of the network and not
/// at all once it is everywhere.
///
/// The answer is normalised by `n−2`, as in the reference, so it reads as an average over the
/// routes a source has rather than as a count.
pub fn[G : @moongraph.Topology] percolation_centrality(
  graph : G,
  states : Array[Double],
) -> @moongraph.Scores {
  let n = @moongraph.Topology::node_count(graph)
  let score : Array[Double] = Array::make(n, 0.0)
  if n < 3 || states.length() != n {
    return { score, }
  }
  let mut total_state = 0.0
  for value in states {
    total_state = total_state + value
  }
  // Brandes' accumulation, once per source, with the source's state as the weight.
  for source in 0..<n {
    let order : Array[Int32] = []
    let distance : Array[Int32] = Array::make(n, -1)
    let paths : Array[Double] = Array::make(n, 0.0)
    let predecessors : Array[Array[Int32]] = Array::makei(n, fn(_) { [] })
    distance[source] = 0
    paths[source] = 1.0
    let queue : Array[Int32] = [source]
    let mut head = 0
    while head < queue.length() {
      let at = queue[head]
      head = head + 1
      order.push(at)
      for nbr in @internal.distinct_neighbors(graph, at) {
        if distance[nbr] < 0 {
          distance[nbr] = distance[at] + 1
          queue.push(nbr)
        }
        if distance[nbr] == distance[at] + 1 {
          paths[nbr] = paths[nbr] + paths[at]
          predecessors[nbr].push(at)
        }
      }
    }
    let weight : Array[Double] = Array::make(n, 0.0)
    let mut step = order.length()
    while step > 0 {
      step = step - 1
      let node = order[step]
      for previous in predecessors[node] {
        let share = paths[previous] / paths[node]
        weight[previous] = weight[previous] + share * (1.0 + weight[node])
      }
      if node != source {
        score[node] = score[node] + states[source] * weight[node]
      }
    }
  }
  let scale = (n - 2).to_double()
  for node in 0..<n {
    let beside = total_state - states[node]
    if beside > 0.0 {
      score[node] = score[node] / scale / beside
    } else {
      score[node] = 0.0
    }
  }
  { score, }
}
