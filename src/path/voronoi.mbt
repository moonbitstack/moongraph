// Voronoi cells: hand every node to the centre it is closest to.

///|
/// Which centre each node belongs to: the one it is cheapest to reach. The answer is one
/// label per node, holding the centre's node number, or `-1` for a node no centre can reach.
///
/// Ties go to the smaller centre, so the answer does not depend on the order the centres
/// were given and two runs on the same graph agree. A centre is always in its own cell.
/// A negative weight has no cheapest route and is refused, as everywhere else in the
/// library that walks a graph by cost.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (2, 3), (3, 4)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   // Node 2 is two hops from either centre, and the tie goes to the smaller one.
///   assert_eq(@path.voronoi(g, [0, 4]), [0, 0, 0, 4, 4])
/// }
/// ```
pub fn[G : @moongraph.Topology] voronoi(
  graph : G,
  centers : Array[Int32],
  weight? : (Int32) -> Double,
) -> Array[Int32] raise @moongraph.Refused {
  let w = @internal.take_weight(weight)
  let n = @moongraph.Topology::node_count(graph)
  let label : Array[Int32] = Array::make(n, -1)
  let distance : Array[Double?] = Array::make(n, (None : Double?))
  let heap = @moonstl.PairingHeap::new_by(cmp=@internal.entry_cmp)
  for center in centers {
    if center < 0 || center >= n {
      continue
    }
    let already = match distance[center] {
      Some(_) => true
      None => false
    }
    if already {
      continue
    }
    distance[center] = Some(0.0)
    label[center] = center
    heap.insert((0.0, center)) |> ignore
  }
  while heap.pop() is Some((cost, node)) {
    match distance[node] {
      Some(best) => if cost > best { continue }
      None => continue
    }
    let nbrs = @moongraph.Topology::neighbors(graph, node)
    let eids = @moongraph.Topology::incident(graph, node)
    for at in 0..<eids.length() {
      let to = nbrs[at]
      let step = w(eids[at])
      if step < 0.0 {
        raise @moongraph.Refused::NegativeWeight(edge=eids[at])
      }
      let next = cost + step
      let mut better = false
      match distance[to] {
        Some(old) =>
          if next < old {
            better = true
          } else if next == old && label[node] < label[to] {
            // Two centres are equally far: the smaller number keeps the node, and its
            // answer has to be carried on to the nodes behind it.
            better = true
          }
        None => better = true
      }
      if better {
        distance[to] = Some(next)
        label[to] = label[node]
        heap.insert((next, to)) |> ignore
      }
    }
  }
  label
}

///|
/// The same answer, grouped the other way round: one array per centre, in the order the
/// centres were given, holding the nodes that look to it. A centre that reaches nothing is
/// an empty array rather than a missing one, and a node that no centre reaches appears in
/// no cell at all.
pub fn[G : @moongraph.Topology] voronoi_cells(
  graph : G,
  centers : Array[Int32],
  weight? : (Int32) -> Double,
) -> Array[Array[Int32]] raise @moongraph.Refused {
  let label = voronoi(graph, centers, weight?)
  let cells : Array[Array[Int32]] = Array::makei(centers.length(), fn(_) { [] })
  let slot : Array[Int32] = Array::make(graph.node_count(), -1)
  for i in 0..<centers.length() {
    if centers[i] >= 0 && centers[i] < slot.length() && slot[centers[i]] < 0 {
      slot[centers[i]] = i
    }
  }
  for node in 0..<label.length() {
    let center = label[node]
    if center >= 0 && slot[center] >= 0 {
      cells[slot[center]].push(node)
    }
  }
  cells
}
