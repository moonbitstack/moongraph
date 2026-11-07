// Two ways to ask how far apart a graph holds itself: the total distance between every
// pair, and the node that sits closest to all of them on average.

///|
/// The Wiener index: the sum of the shortest-path distances over every pair of nodes. It is
/// the one number a chemist asks of a molecule's graph — how spread out it is — and the one
/// number a network planner asks of a road graph, summed over all the trips there are.
///
/// Undirected graphs count each pair once; directed graphs count both directions, which is
/// the natural reading. `None` when some pair cannot reach the other: the sum would be
/// infinite, and an infinite answer is not a measurement.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (2, 3)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   // 1 + 2 + 3 + 1 + 2 + 1
///   assert_eq(@metric.wiener_index(g), Some(10.0))
/// }
/// ```
pub fn[G : @moongraph.Topology] wiener_index(
  graph : G,
  weight? : (Int32) -> Double,
) -> Double? {
  let w = @internal.take_weight(weight)
  let n = @moongraph.Topology::node_count(graph)
  if n < 2 {
    return Some(0.0)
  }
  let pairs = @path.dijkstra_all(graph, weight=w) catch { _ => return None }
  let directed = @moongraph.Topology::directed(graph)
  let mut total = 0.0
  for from in 0..<n {
    let first = if directed { 0 } else { from + 1 }
    for to in first..<n {
      if from == to {
        continue
      }
      match pairs.distance[from][to] {
        Some(cost) => total = total + cost
        None => return None
      }
    }
  }
  Some(total)
}

///|
/// The nodes that sit closest to everything else put together: the ones with the smallest
/// total distance to the rest of the graph, not the smallest worst case. A centre minimises
/// the worst trip; a barycentre minimises the sum of all of them, which is the node to put a
/// depot on when every trip happens once.
///
/// Two nodes can tie, so the answer is every minimiser, ascending. A graph that is not
/// connected has no such node and the answer is empty.
pub fn[G : @moongraph.Topology] barycenter(
  graph : G,
  weight? : (Int32) -> Double,
) -> Array[Int32] {
  let w = @internal.take_weight(weight)
  let n = @moongraph.Topology::node_count(graph)
  let none : Array[Int32] = []
  if n == 0 {
    return none
  }
  let pairs = @path.dijkstra_all(graph, weight=w) catch { _ => return none }
  let totals : Array[Double] = Array::make(n, 0.0)
  for from in 0..<n {
    for to in 0..<n {
      if from == to {
        continue
      }
      match pairs.distance[from][to] {
        Some(cost) => totals[from] = totals[from] + cost
        None => return none
      }
    }
  }
  let mut best = totals[0]
  for node in 1..<n {
    if totals[node] < best {
      best = totals[node]
    }
  }
  let out : Array[Int32] = []
  for node in 0..<n {
    if totals[node] == best {
      out.push(node)
    }
  }
  out
}
