// The exact tour, for the sizes where exact is still affordable: Held and Karp's dynamic
// program, and the ruler the heuristic is measured against.

///|
/// The shortest tour that visits every node once and comes back, by Held and Karp's dynamic
/// program: for every subset of the stops and every stopping point, the cheapest way to
/// cover the subset and end there, built up one subset at a time.
///
/// The cost is `O(2ⁿ·n²)` time and `O(2ⁿ·n)` memory, so the answer is exact only while the
/// graph is small — sixteen nodes is the limit here, about a million table entries. Beyond
/// that the heuristic in `traveling_salesman` is the answer, and this function refuses
/// rather than pretending.
///
/// Distances are shortest-path distances, not edge weights: the tour may hop through nodes
/// it is not visiting, which is exactly what a travelling salesman on a road network does.
/// The answer repeats the start at the end, so its length is one more than the node count.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (2, 0)],
///     node=(),
///     edge=1.0,
///     directed=false,
///   )
///   let tour = @approx.traveling_salesman_exact(
///     g,
///     start=0,
///     weight=g.weights(fn(w) { w }),
///   )
///   assert_eq(tour.length(), 4)
///   assert_eq(tour[0], 0)
///   assert_eq(tour[3], 0)
/// }
/// ```
pub fn[G : @moongraph.Topology] traveling_salesman_exact(
  graph : G,
  start~ : Int32,
  weight? : (Int32) -> Double,
) -> Array[Int32] raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let n = @moongraph.Topology::node_count(graph)
  if n == 0 {
    return []
  }
  if start < 0 || start >= n {
    raise @moongraph.Refused::OutOfRange(node=start)
  }
  if n == 1 {
    return [start, start]
  }
  if n > 16 {
    raise @moongraph.Refused::NotA(
      kind="TSP",
      what="more than sixteen nodes, where the exact tour stops being affordable",
    )
  }
  let pairs = @path.dijkstra_all(graph, weight=w)
  let cost : Array[Array[Double]] = Array::makei(n, fn(from) {
    Array::makei(n, fn(to) {
      match pairs.distance[from][to] {
        Some(value) => value
        None => -1.0
      }
    })
  })
  for from in 0..<n {
    for to in 0..<n {
      if from != to && cost[from][to] < 0.0 {
        raise @moongraph.Refused::Disconnected(from~, to~)
      }
    }
  }
  // The start leads the line-up, so its index in the table is always zero.
  let lineup : Array[Int32] = [start]
  for node in 0..<n {
    if node != start {
      lineup.push(node)
    }
  }
  let stops = n - 1
  let span = 1 << stops
  let far = 1.0e18
  let best : Array[Double] = Array::make(span * stops, far)
  let came_from : Array[Int32] = Array::make(span * stops, -1)
  for stop in 0..<stops {
    best[(1 << stop) * stops + stop] = cost[start][lineup[stop + 1]]
  }
  for mask in 1..<span {
    for stop in 0..<stops {
      let stop_bit = 1 << stop
      let here = mask & stop_bit
      if here == 0 {
        continue
      }
      let reached = best[mask * stops + stop]
      if reached >= far {
        continue
      }
      for next in 0..<stops {
        let next_bit = 1 << next
        let there = mask & next_bit
        if there != 0 {
          continue
        }
        let longer = reached + cost[lineup[stop + 1]][lineup[next + 1]]
        let grown = mask + next_bit
        if longer < best[grown * stops + next] {
          best[grown * stops + next] = longer
          came_from[grown * stops + next] = stop
        }
      }
    }
  }
  let full = span - 1
  let mut shortest = far
  let mut last = -1
  for stop in 0..<stops {
    let round = best[full * stops + stop] + cost[lineup[stop + 1]][start]
    if round < shortest {
      shortest = round
      last = stop
    }
  }
  if last < 0 {
    raise @moongraph.Refused::NoSolution
  }
  // Walk the table backwards, then turn the walk around and close it.
  let backwards : Array[Int32] = []
  let mut mask = full
  let mut at = last
  while at >= 0 {
    backwards.push(lineup[at + 1])
    let previous = came_from[mask * stops + at]
    mask = mask ^ (1 << at)
    at = previous
  }
  let tour : Array[Int32] = [start]
  for step in 0..<backwards.length() {
    tour.push(backwards[backwards.length() - 1 - step])
  }
  tour.push(start)
  tour
}

///|
/// How long a tour is, counting every leg it lists. A tour that repeats its start at the end
/// is measured whole, so this is the number to compare against the exact answer; a tour that
/// stops after its last stop is measured as the open walk it is.
///
/// `None` when a leg has no route, which is what a tour through a graph in pieces is.
pub fn[G : @moongraph.Topology] tour_length(
  graph : G,
  tour : Array[Int32],
  weight? : (Int32) -> Double,
) -> Double? {
  let w = @internal.take_weight(weight)
  if tour.length() < 2 {
    return Some(0.0)
  }
  let pairs = @path.dijkstra_all(graph, weight=w) catch { _ => return None }
  let mut total = 0.0
  for at in 1..<tour.length() {
    let from = tour[at - 1]
    let to = tour[at]
    if from < 0 ||
      to < 0 ||
      from >= pairs.distance.length() ||
      to >= pairs.distance.length() {
      return None
    }
    match pairs.distance[from][to] {
      Some(value) => total = total + value
      None => return None
    }
  }
  Some(total)
}
