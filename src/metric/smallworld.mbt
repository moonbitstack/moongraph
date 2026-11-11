// Small worlds: is a graph closer to a lattice or to a random rewiring of one?

///|
/// The average number of hops between a pair of nodes, over the pairs that can reach each
/// other. The reference graphs a small-world question needs are built by the caller —
/// `random_rewire` in the approximation package makes one — so this stays a measurement.
pub fn[G : @moongraph.Topology] average_path_length(graph : G) -> Double {
  let n = @moongraph.Topology::node_count(graph)
  if n < 2 {
    return 0.0
  }
  let pairs = @path.dijkstra_all(graph) catch { _ => return 0.0 }
  let mut total = 0.0
  let mut seen = 0.0
  for from in 0..<n {
    for to in 0..<n {
      if from == to {
        continue
      }
      match pairs.distance[from][to] {
        Some(value) => {
          total = total + value
          seen = seen + 1.0
        }
        None => ()
      }
    }
  }
  if seen == 0.0 {
    0.0
  } else {
    total / seen
  }
}

///|
/// The small-world coefficient: how much more clustered a graph is than a random graph with
/// the same size and average degree, divided by how much longer its routes are. A value well
/// above one is the signature of a small world — clustered like a lattice, short like a
/// random graph — and a value near one means the graph is indistinguishable from random on
/// these two measures.
///
/// Both reference graphs are supplied by the caller: `lattice` for the clustering it should
/// be compared against, `random` for the route length. That keeps the measure a measurement;
/// how a reference is generated — and how much of the randomness the answer should carry —
/// stays the caller's decision.
pub fn[
  G : @moongraph.Topology + @moongraph.Inbound,
  H : @moongraph.Topology + @moongraph.Inbound,
  K : @moongraph.Topology,
] smallworld_sigma(
  graph : G,
  lattice~ : H,
  random~ : K,
) -> Double {
  let clustered = average_clustering(graph)
  let lattice_clustered = average_clustering(lattice)
  let hops = average_path_length(graph)
  let random_hops = average_path_length(random)
  if lattice_clustered <= 0.0 || hops <= 0.0 || random_hops <= 0.0 {
    return 0.0
  }
  clustered / lattice_clustered / (hops / random_hops)
}

///|
/// The small-world coefficient of Watts and Strogatz rewritten as a difference rather than a
/// ratio, which behaves near the ends: `L_lattice/L − C/C_lattice`. A graph that is as
/// clustered as the lattice and as short as random scores near zero; a lattice scores
/// positive, and a graph that has lost the lattice's clustering scores negative.
pub fn[
  G : @moongraph.Topology + @moongraph.Inbound,
  H : @moongraph.Topology + @moongraph.Inbound,
] smallworld_omega(
  graph : G,
  lattice~ : H,
) -> Double {
  let clustered = average_clustering(graph)
  let lattice_clustered = average_clustering(lattice)
  let hops = average_path_length(graph)
  let lattice_hops = average_path_length(lattice)
  if hops <= 0.0 || lattice_clustered <= 0.0 {
    return 0.0
  }
  lattice_hops / hops - clustered / lattice_clustered
}
