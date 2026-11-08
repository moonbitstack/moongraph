// Size, distance, clustering and similarity.

///|
/// How many of the possible edges are present: 0 for an empty graph, 1 for a complete
/// one.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (2, 0)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   assert_eq(@metric.density(g), 1.0)
/// }
/// ```
pub fn[G : @moongraph.Topology] density(graph : G) -> Double {
  let n = @moongraph.Topology::node_count(graph)
  if n < 2 {
    return 0.0
  }
  let m = distinct_edge_count(graph)
  let possible = if @moongraph.Topology::directed(graph) {
    n * (n - 1)
  } else {
    n * (n - 1) / 2
  }
  m.to_double() / possible.to_double()
}

///|
/// How many edges there are, counting a pair once however many parallel edges join it.
pub fn[G : @moongraph.Topology] distinct_edge_count(graph : G) -> Int32 {
  let n = @moongraph.Topology::node_count(graph)
  let mut total = 0
  for node in 0..<n {
    for nbr in @internal.distinct_neighbors(graph, node) {
      if @moongraph.Topology::directed(graph) || node < nbr {
        total = total + 1
      }
      if @moongraph.Topology::directed(graph) && node == nbr {
        // A self-loop is one edge, not two.
        ()
      }
    }
  }
  total
}

///|
/// The number of edges out of each node.
pub fn[G : @moongraph.Topology] degree(graph : G) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Int32] = []
  for node in 0..<n {
    out.push(@moongraph.Topology::incident(graph, node).length())
  }
  out
}

///|
/// The number of edges into each node.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] in_degree(
  graph : G,
) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Int32] = []
  for node in 0..<n {
    out.push(@moongraph.Inbound::in_incident(graph, node).length())
  }
  out
}

///|
/// The number of edges on each node, both directions together.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] total_degree(
  graph : G,
) -> Array[Int32] {
  let outs = degree(graph)
  let ins = in_degree(graph)
  for node in 0..<outs.length() {
    outs[node] = outs[node] + ins[node]
  }
  outs
}

///|
/// How many nodes have each degree, from 0 up to the largest.
pub fn[G : @moongraph.Topology] degree_histogram(graph : G) -> Array[Int32] {
  let degrees = degree(graph)
  let mut highest = 0
  for value in degrees {
    if value > highest {
      highest = value
    }
  }
  let out : Array[Int32] = Array::make(highest + 1, 0)
  for value in degrees {
    out[value] = out[value] + 1
  }
  out
}

///|
/// The number of hops from `node` to its furthest node.
pub fn[G : @moongraph.Topology] eccentricity(graph : G, node : Int32) -> Int32 {
  let n = @moongraph.Topology::node_count(graph)
  if node < 0 || node >= n {
    return 0
  }
  let depth : Array[Int32] = Array::make(n, -1)
  depth[node] = 0
  let queue : Array[Int32] = [node]
  let mut head = 0
  while head < queue.length() {
    let at = queue[head]
    head = head + 1
    for nbr in @moongraph.Topology::neighbors(graph, at) {
      if depth[nbr] < 0 {
        depth[nbr] = depth[at] + 1
        queue.push(nbr)
      }
    }
  }
  let mut worst = 0
  for at in 0..<n {
    if depth[at] > worst {
      worst = depth[at]
    }
  }
  worst
}

///|
/// The largest eccentricity: the longest shortest route.
pub fn[G : @moongraph.Topology] diameter(graph : G) -> Int32 {
  if !connected_ignoring_direction(graph) {
    return 0
  }
  let mut best = 0
  for node in 0..<@moongraph.Topology::node_count(graph) {
    let reach = eccentricity(graph, node)
    if reach > best {
      best = reach
    }
  }
  best
}

///|
/// The smallest eccentricity: the best node to stand at.
pub fn[G : @moongraph.Topology] radius(graph : G) -> Int32 {
  if !connected_ignoring_direction(graph) {
    return 0
  }
  let n = @moongraph.Topology::node_count(graph)
  if n == 0 {
    return 0
  }
  let mut best = eccentricity(graph, 0)
  for node in 1..<n {
    let reach = eccentricity(graph, node)
    if reach < best {
      best = reach
    }
  }
  best
}

///|
/// Whether every node can be reached from every other when direction is ignored.
fn[G : @moongraph.Topology] connected_ignoring_direction(graph : G) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  if n <= 1 {
    return true
  }
  let seen : Array[Bool] = Array::make(n, false)
  let queue : Array[Int32] = [0]
  seen[0] = true
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    for nbr in @moongraph.Topology::neighbors(graph, node) {
      if !seen[nbr] {
        seen[nbr] = true
        queue.push(nbr)
      }
    }
  }
  queue.length() == n
}

///|
/// The nodes at the diameter: the ends of the longest shortest route.
pub fn[G : @moongraph.Topology] periphery(graph : G) -> Array[Int32] {
  let far = diameter(graph)
  let out : Array[Int32] = []
  for node in 0..<@moongraph.Topology::node_count(graph) {
    if eccentricity(graph, node) == far {
      out.push(node)
    }
  }
  out
}

///|
/// The nodes at the radius: the middle of the graph.
pub fn[G : @moongraph.Topology] center(graph : G) -> Array[Int32] {
  let near = radius(graph)
  let out : Array[Int32] = []
  for node in 0..<@moongraph.Topology::node_count(graph) {
    if eccentricity(graph, node) == near {
      out.push(node)
    }
  }
  out
}

///|
/// How many of a node's neighbours are themselves neighbours, as a fraction of the pairs
/// that could be.
pub fn[G : @moongraph.Topology] clustering(graph : G, node : Int32) -> Double {
  let nbrs = @internal.distinct_neighbors(graph, node)
  let count = nbrs.length()
  if count < 2 {
    return 0.0
  }
  let mut joined = 0
  for i in 0..<count {
    for j in (i + 1)..<count {
      if @internal.adjacent(graph, nbrs[i], nbrs[j]) ||
        @internal.adjacent(graph, nbrs[j], nbrs[i]) {
        joined = joined + 1
      }
    }
  }
  joined.to_double() / (count * (count - 1) / 2).to_double()
}

///|
/// The mean of the local clustering over every node.
pub fn[G : @moongraph.Topology] average_clustering(graph : G) -> Double {
  let n = @moongraph.Topology::node_count(graph)
  if n == 0 {
    return 0.0
  }
  let mut total = 0.0
  for node in 0..<n {
    total = total + clustering(graph, node)
  }
  total / n.to_double()
}

///|
/// Three times the number of triangles over the number of open triples: the chance that
/// two neighbours of a node are neighbours of each other, weighted by node.
pub fn[G : @moongraph.Topology] transitivity(graph : G) -> Double {
  let n = @moongraph.Topology::node_count(graph)
  let mut triangles = 0
  let mut triples = 0
  for node in 0..<n {
    let nbrs = @internal.distinct_neighbors(graph, node)
    let count = nbrs.length()
    triples = triples + count * (count - 1) / 2
    for i in 0..<count {
      for j in (i + 1)..<count {
        if @internal.adjacent(graph, nbrs[i], nbrs[j]) ||
          @internal.adjacent(graph, nbrs[j], nbrs[i]) {
          triangles = triangles + 1
        }
      }
    }
  }
  if triples == 0 {
    return 0.0
  }
  triangles.to_double() / triples.to_double()
}

///|
/// The triangles each node takes part in, and the number of them.
pub fn[G : @moongraph.Topology] triangles(graph : G) -> (Array[Int32], Int32) {
  let n = @moongraph.Topology::node_count(graph)
  let per_node : Array[Int32] = Array::make(n, 0)
  let mut total = 0
  for node in 0..<n {
    let nbrs = @internal.distinct_neighbors(graph, node)
    let count = nbrs.length()
    for i in 0..<count {
      for j in (i + 1)..<count {
        if @internal.adjacent(graph, nbrs[i], nbrs[j]) ||
          @internal.adjacent(graph, nbrs[j], nbrs[i]) {
          per_node[node] = per_node[node] + 1
          if nbrs[i] < node {
            total = total + 1
          }
        }
      }
    }
  }
  (per_node, total)
}

///|
/// The square clustering of a node: how many of the pairs of its neighbours that share a
/// non-neighbour are joined by a four-node square.
pub fn[G : @moongraph.Topology] square_clustering(
  graph : G,
  node : Int32,
) -> Double {
  let nbrs = @internal.distinct_neighbors(graph, node)
  let count = nbrs.length()
  if count < 2 {
    return 0.0
  }
  let n = @moongraph.Topology::node_count(graph)
  let mut squares = 0
  let mut possible = 0
  for i in 0..<count {
    for j in (i + 1)..<count {
      if @internal.adjacent(graph, nbrs[i], nbrs[j]) {
        continue
      }
      possible = possible + 1
      for other in 0..<n {
        if other == node || other == nbrs[i] || other == nbrs[j] {
          continue
        }
        let left = @internal.adjacent(graph, nbrs[i], other)
        let right = @internal.adjacent(graph, nbrs[j], other)
        if left && right {
          squares = squares + 1
          break
        }
      }
    }
  }
  if possible == 0 {
    return 0.0
  }
  squares.to_double() / possible.to_double()
}

///|
/// The two neighbourhoods a pair of nodes brings to a score: how many neighbours each
/// has, how many they share counting the pair itself, and how many they share beside the
/// pair. Keeping the pair in the first two counts is what makes the union of the two
/// neighbourhoods their sum minus the overlap.
fn[G : @moongraph.Topology] neighbourhood_split(
  graph : G,
  a : Int32,
  b : Int32,
) -> (Int32, Int32, Int32, Int32) {
  let left = @internal.distinct_neighbors(graph, a)
  let right = @internal.distinct_neighbors(graph, b)
  let mut both = 0
  let mut shared = 0
  for node in left {
    if right.contains(node) {
      both = both + 1
      if node != a && node != b {
        shared = shared + 1
      }
    }
  }
  (left.length(), right.length(), both, shared)
}

///|
/// One count over another, with an empty denominator answering zero rather than a
/// division by nothing.
fn ratio(part : Int32, whole : Int32) -> Double {
  if whole == 0 {
    0.0
  } else {
    part.to_double() / whole.to_double()
  }
}

///|
/// How alike two nodes are: how much their neighbourhoods overlap. The seven measures
/// differ only in what they divide by, or in how much they trust a hub, and all of them
/// read the neighbourhoods out of the graph rather than out of a stored embedding.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 2), (1, 2), (0, 3), (1, 3)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   assert_eq(@metric.similarity(g, 0, 1), 1.0)
/// }
/// ```
pub fn[G : @moongraph.Topology] similarity(
  graph : G,
  a : Int32,
  b : Int32,
  kind~ : SimilarityKind = Jaccard,
) -> Double {
  let (left, right, both, shared) = neighbourhood_split(graph, a, b)
  match kind {
    Jaccard => ratio(shared, left + right - both)
    Dice => ratio(2 * shared, left + right)
    Cosine =>
      if left == 0 || right == 0 {
        0.0
      } else {
        shared.to_double() / (left.to_double() * right.to_double()).sqrt()
      }
    Overlap => ratio(shared, if left < right { left } else { right })
    PreferentialAttachment => left.to_double() * right.to_double()
    AdamicAdar => adamic_adar(graph, a, b)
    ResourceAllocation => resource_allocation(graph, a, b)
  }
}

///|
/// Which similarity measure to use. The first four divide a shared-neighbour count by a
/// size; the last three weigh the shared neighbours by how rare they are, or ignore them
/// and read only the two degrees.
pub(all) enum SimilarityKind {
  /// Shared neighbours over the union of the two neighbourhoods.
  Jaccard
  /// Twice the shared neighbours over the sum of the two sizes.
  Dice
  /// Shared neighbours over the square root of the product of the two sizes.
  Cosine
  /// Shared neighbours over the smaller neighbourhood, the Szymkiewicz-Simpson index.
  Overlap
  /// The product of the two degrees: a hub seeks a hub.
  PreferentialAttachment
  /// Each shared neighbour counted by one over the log of its degree.
  AdamicAdar
  /// Each shared neighbour counted by one over its degree.
  ResourceAllocation
}

///|
/// How many neighbours two nodes share. The pair itself does not count, which is what a
/// link prediction asks: who else knows both of them.
pub fn[G : @moongraph.Topology] common_neighbors(
  graph : G,
  a : Int32,
  b : Int32,
) -> Int32 {
  let (_, _, _, shared) = neighbourhood_split(graph, a, b)
  shared
}

///|
/// Every pair of nodes with no edge between them, scored as a candidate link. The pairs
/// come in ascending order, so two runs on the same graph answer the same array.
pub fn[G : @moongraph.Topology] link_prediction(
  graph : G,
  kind~ : SimilarityKind = Jaccard,
) -> Array[(Int32, Int32, Double)] {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[(Int32, Int32, Double)] = []
  for a in 0..<n {
    for b in (a + 1)..<n {
      if @internal.adjacent(graph, a, b) {
        continue
      }
      out.push((a, b, similarity(graph, a, b, kind~)))
    }
  }
  out
}

///|
/// How much traffic a route could carry between two nodes under the similarity measures
/// above: the resources a node and its neighbours allocate to it.
pub fn[G : @moongraph.Topology] resource_allocation(
  graph : G,
  a : Int32,
  b : Int32,
) -> Double {
  let left = @internal.distinct_neighbors(graph, a)
  let right = @internal.distinct_neighbors(graph, b)
  let mut total = 0.0
  for node in left {
    if right.contains(node) && node != a && node != b {
      let size = @internal.distinct_neighbors(graph, node).length()
      if size > 0 {
        total = total + 1.0 / size.to_double()
      }
    }
  }
  total
}

///|
/// The same idea with the neighbourhood size taken as just over one, which fades faster
/// as a hub grows.
pub fn[G : @moongraph.Topology] adamic_adar(
  graph : G,
  a : Int32,
  b : Int32,
) -> Double {
  let left = @internal.distinct_neighbors(graph, a)
  let right = @internal.distinct_neighbors(graph, b)
  let mut total = 0.0
  for node in left {
    if right.contains(node) && node != a && node != b {
      let size = @internal.distinct_neighbors(graph, node).length()
      if size > 1 {
        total = total + 1.0 / natural_log(size.to_double())
      }
    }
  }
  total
}

///|
/// The natural logarithm, by reducing the argument to the unit interval and summing the
/// series there. Degrees are small integers, so a few dozen terms reach the precision a
/// similarity score needs.
fn natural_log(value : Double) -> Double {
  if value <= 0.0 {
    return 0.0
  }
  let mut scaled = value
  let mut shift = 0.0
  while scaled >= 2.0 {
    scaled = scaled / 2.0
    shift = shift + 1.0
  }
  while scaled < 1.0 {
    scaled = scaled * 2.0
    shift = shift - 1.0
  }
  // ln(z) = 2 * (t + t^3/3 + t^5/5 + ...) with t = (z - 1) / (z + 1).
  let t = (scaled - 1.0) / (scaled + 1.0)
  let squared = t * t
  let mut term = t
  let mut total = term
  for n in 1..<40 {
    term = term * squared
    total = total + term / (2.0 * n.to_double() + 1.0)
  }
  2.0 * total + shift * 0.6931471805599453
}

///|
/// The fraction of edges that point both ways, over the edges a directed graph has.
pub fn[G : @moongraph.Topology] reciprocity(graph : G) -> Double {
  let n = @moongraph.Topology::node_count(graph)
  let mut forward = 0
  let mut mutual = 0
  for node in 0..<n {
    for nbr in @internal.distinct_neighbors(graph, node) {
      if node < nbr || node == nbr {
        forward = forward + 1
        if @internal.adjacent(graph, nbr, node) {
          mutual = mutual + 1
        }
      }
    }
  }
  if forward == 0 {
    return 0.0
  }
  mutual.to_double() / forward.to_double()
}

///|
/// How well the edges between two groups explain themselves: the edge weight inside each
/// group compared with what a random rewiring would give.
pub fn[G : @moongraph.Topology] modularity(
  graph : G,
  partition : @moongraph.Partition,
) -> Double {
  let n = @moongraph.Topology::node_count(graph)
  let m = @moongraph.Topology::edge_count(graph)
  if m == 0 {
    return 0.0
  }
  let degrees = total_degree_undirected(graph)
  let inside : Array[Double] = Array::make(partition.count, 0.0)
  let totals : Array[Double] = Array::make(partition.count, 0.0)
  for node in 0..<n {
    let group = partition.label[node]
    if group < 0 || group >= partition.count {
      continue
    }
    totals[group] = totals[group] + degrees[node].to_double()
  }
  for edge in 0..<@moongraph.Topology::edge_count(graph) {
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    if a >= 0 &&
      b >= 0 &&
      a < n &&
      b < n &&
      partition.label[a] == partition.label[b] {
      inside[partition.label[a]] = inside[partition.label[a]] + 1.0
    }
  }
  let scale = 2.0 * m.to_double()
  let mut total = 0.0
  for group in 0..<partition.count {
    total = total +
      inside[group] / m.to_double() -
      totals[group] / scale * (totals[group] / scale)
  }
  total
}

///|
/// The degree of each node when every edge is read as undirected, a self-loop counting
/// twice.
fn[G : @moongraph.Topology] total_degree_undirected(graph : G) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Int32] = Array::make(n, 0)
  for edge in 0..<@moongraph.Topology::edge_count(graph) {
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    if a >= 0 && a < n {
      out[a] = out[a] + 1
    }
    if b >= 0 && b < n {
      out[b] = out[b] + 1
    }
  }
  out
}

///|
/// How well the graph moves information: the mean of one over the shortest route between
/// every pair.
pub fn[G : @moongraph.Topology] efficiency(graph : G) -> Double {
  let n = @moongraph.Topology::node_count(graph)
  if n < 2 {
    return 0.0
  }
  let mut total = 0.0
  for start in 0..<n {
    let depth : Array[Int32] = Array::make(n, -1)
    depth[start] = 0
    let queue : Array[Int32] = [start]
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      for nbr in @moongraph.Topology::neighbors(graph, node) {
        if depth[nbr] < 0 {
          depth[nbr] = depth[node] + 1
          queue.push(nbr)
        }
      }
    }
    for other in 0..<n {
      if other != start && depth[other] > 0 {
        total = total + 1.0 / depth[other].to_double()
      }
    }
  }
  total / (n * (n - 1)).to_double()
}

///|
/// The degree correlation: whether nodes of like degree prefer each other.
///
/// 1 means high-degree nodes join high-degree ones, -1 the opposite, 0 no preference.
pub fn[G : @moongraph.Topology] assortativity(graph : G) -> Double {
  let n = @moongraph.Topology::node_count(graph)
  let degrees = total_degree_undirected(graph)
  let left : Array[Double] = []
  let right : Array[Double] = []
  for edge in 0..<@moongraph.Topology::edge_count(graph) {
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    if a >= 0 && b >= 0 && a < n && b < n && a != b {
      left.push(degrees[a].to_double())
      right.push(degrees[b].to_double())
    }
  }
  if left.length() == 0 {
    return 0.0
  }
  let mean_left = mean(left)
  let mean_right = mean(right)
  let mut covariance = 0.0
  let mut variance_left = 0.0
  let mut variance_right = 0.0
  for i in 0..<left.length() {
    covariance = covariance + (left[i] - mean_left) * (right[i] - mean_right)
    variance_left = variance_left +
      (left[i] - mean_left) * (left[i] - mean_left)
    variance_right = variance_right +
      (right[i] - mean_right) * (right[i] - mean_right)
  }
  let denominator = square_root(variance_left * variance_right)
  if denominator == 0.0 {
    0.0
  } else {
    covariance / denominator
  }
}

///|
fn mean(values : Array[Double]) -> Double {
  if values.length() == 0 {
    return 0.0
  }
  let mut total = 0.0
  for value in values {
    total = total + value
  }
  total / values.length().to_double()
}

///|
fn square_root(value : Double) -> Double {
  if value <= 0.0 {
    return 0.0
  }
  // Newton's step repeated until the square matches to the last bit the caller needs.
  let mut guess = if value > 1.0 { value } else { 1.0 }
  for _ in 0..<60 {
    guess = 0.5 * (guess + value / guess)
  }
  guess
}

///|
/// How many nodes each node can reach within `cutoff`, itself included: the count of nodes
/// whose cheapest route from it costs at most `cutoff`.
///
/// This is the question an accessibility study asks of a street network — how many jobs,
/// shops, or people lie within a ten-minute walk — with the opportunities counted as nodes;
/// sum a per-node weight over the answer to count opportunities instead. The cost is one
/// all-pairs search, `O(n · m log n)` on a sparse graph.
pub fn[G : @moongraph.Topology] accessibility(
  graph : G,
  cutoff : Double,
  weight? : (Int32) -> Double,
) -> Array[Int32] {
  let w = @internal.take_weight(weight)
  let n = graph.node_count()
  let out : Array[Int32] = Array::make(n, 0)
  let pairs = @path.dijkstra_all(graph, weight=w) catch { _ => return out }
  for from in 0..<n {
    for to in 0..<n {
      match pairs.distance[from][to] {
        Some(cost) => if cost <= cutoff { out[from] = out[from] + 1 }
        None => ()
      }
    }
  }
  out
}

///|
/// How much each node can reach within `cutoff`, with the near neighbourhood weighted more than
/// the far one: a node at cost `d` contributes `exp(-decay · d)`, so `decay` of zero counts
/// everything at one and a larger `decay` narrows the view to what is close.
///
/// This is Pandana's decayed accessibility, the exponential kernel an urban study uses when a
/// shop across the street is worth more than the same shop a mile away. `decay` is the
/// reciprocal of the distance at which a node's weight falls to `1/e`.
pub fn[G : @moongraph.Topology] accessibility_decay(
  graph : G,
  cutoff : Double,
  decay : Double,
  weight? : (Int32) -> Double,
) -> Array[Double] {
  let w = @internal.take_weight(weight)
  let n = graph.node_count()
  let out : Array[Double] = Array::make(n, 0.0)
  let pairs = @path.dijkstra_all(graph, weight=w) catch { _ => return out }
  for from in 0..<n {
    for to in 0..<n {
      match pairs.distance[from][to] {
        Some(cost) =>
          if cost <= cutoff {
            out[from] = out[from] + @math.exp(-decay * cost)
          }
        None => ()
      }
    }
  }
  out
}

///|
/// The distances from every node to its nearest points of interest, one entry per rank. This
/// is Pandana's `nearest_pois`: not "how many shops are within a mile" but "how far is the
/// nearest, the second nearest, the third", which is the question a site-selection study
/// actually asks.
///
/// The answer holds `count` slots per node in ascending order, with `None` where fewer than
/// that many points are within `cutoff`. A point is only counted once, so a node sitting on
/// a point of interest sees it at distance zero in the first slot and not again in the
/// second.
///
/// Points are searched one at a time and each node keeps only its best `count` distances, so
/// the memory is proportional to the nodes rather than to the nodes times the points.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (2, 3), (3, 4)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   let near = @metric.nearest_pois(g, [1, 3], count=2, cutoff=10.0)
///   assert_eq(near[0], [Some(1.0), Some(3.0)])
///   assert_eq(near[2], [Some(1.0), Some(1.0)])
/// }
/// ```
pub fn[G : @moongraph.Topology] nearest_pois(
  graph : G,
  pois : Array[Int32],
  count~ : Int32 = 1,
  cutoff~ : Double,
  weight? : (Int32) -> Double,
) -> Array[Array[Double?]] {
  let w = @internal.take_weight(weight)
  let n = @moongraph.Topology::node_count(graph)
  let keep = if count < 0 { 0 } else { count }
  let best : Array[Array[Double?]] = Array::makei(n, fn(_) { [] })
  if keep == 0 {
    return best
  }
  let mut seen : Array[Bool] = []
  for poi in pois {
    if poi < 0 || poi >= n {
      continue
    }
    // A point listed twice is still one point.
    if seen.length() == 0 {
      seen = Array::make(n, false)
    }
    if seen[poi] {
      continue
    }
    seen[poi] = true
    let paths = @path.dijkstra(graph, poi, weight=w) catch { _ => continue }
    for node in 0..<n {
      let distance = match paths.distance[node] {
        Some(value) => value
        None => continue
      }
      if distance > cutoff {
        continue
      }
      let slots = best[node]
      let mut at = slots.length()
      for i in 0..<slots.length() {
        match slots[i] {
          Some(value) =>
            if distance < value {
              at = i
              break
            }
          None => ()
        }
      }
      if at >= keep {
        continue
      }
      slots.insert(at, Some(distance))
      if slots.length() > keep {
        slots.pop() |> ignore
      }
    }
  }
  for node in 0..<n {
    while best[node].length() < keep {
      best[node].push((None : Double?))
    }
  }
  best
}

///|
/// The nodes that sit in a piece of the network too small to count: cut the graph down to the
/// edges a trip of `impedance` can use, and a node belongs to a piece of that graph. A piece
/// with fewer than `count` nodes is a pocket — a suburb with one road in, a station whose
/// platforms are joined to nothing else — and the nodes in it are the ones a
/// low-connectivity study is looking for.
///
/// This is Pandana's `low_connectivity_nodes`. The answer is ascending, and a node with no
/// usable edge at all is a piece of one and is included whenever `count` is above one.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (2, 0), (3, 4)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   // The pair 3-4 is a pocket of two; the triangle is a piece of three.
///   assert_eq(@metric.low_connectivity_nodes(g, impedance=1.0, count=3), [3, 4])
/// }
/// ```
pub fn[G : @moongraph.Topology] low_connectivity_nodes(
  graph : G,
  impedance~ : Double,
  count~ : Int32,
  weight? : (Int32) -> Double,
) -> Array[Int32] {
  let w = @internal.take_weight(weight)
  let n = @moongraph.Topology::node_count(graph)
  let piece : Array[Int32] = Array::make(n, -1)
  let pieces : Array[Array[Int32]] = []
  for start in 0..<n {
    if piece[start] >= 0 {
      continue
    }
    let label = pieces.length()
    let group : Array[Int32] = [start]
    piece[start] = label
    let mut head = 0
    while head < group.length() {
      let at = group[head]
      head = head + 1
      let nbrs = @moongraph.Topology::neighbors(graph, at)
      let eids = @moongraph.Topology::incident(graph, at)
      for i in 0..<eids.length() {
        if w(eids[i]) > impedance {
          continue
        }
        let other = nbrs[i]
        if piece[other] < 0 {
          piece[other] = label
          group.push(other)
        }
      }
    }
    pieces.push(group)
  }
  let out : Array[Int32] = []
  for group in pieces {
    if group.length() < count {
      for node in group {
        out.push(node)
      }
    }
  }
  out.sort()
  out
}
