// Which neighbours a measurement reads when the graph has directions.
//
// An undirected graph has one neighbourhood per node, so every reading below agrees on it. A
// directed graph has three, and the implementations this library is checked against do not
// agree on which one a triangle coefficient is about: one reads the arcs as edges, another
// counts only the triangles that follow them. Rather than pick one for the reader, the reading
// is a parameter, and the cheapest one is the default.

///|
/// Which neighbours a triangle or a clustering coefficient reads when the graph has directions.
///
/// The default is `Outward`: the nodes the arcs leave, with a corner closed when either
/// direction joins the two. `Undirected` drops the directions, so the neighbours are the nodes
/// at either end of an arc; `Transitive` keeps them, closing a corner only when an arc runs from
/// the first successor to the second. All three agree on an undirected graph, and `Outward` is
/// the only one that needs nothing but the successor list — which is why it is the default.
pub(all) enum Neighborhood {
  /// The nodes the arcs leave. A corner is closed when either direction joins the two, over the
  /// pairs of successors the node has.
  Outward
  /// The nodes at either end of an arc: the graph with its directions dropped.
  Undirected
  /// The nodes the arcs leave, with a corner closed only by an arc from the first successor to
  /// the second, over the ordered pairs of successors.
  Transitive
}

///|
/// Two ascending lists without repeats, merged into one.
fn merge_sorted(a : Array[Int32], b : Array[Int32]) -> Array[Int32] {
  let out : Array[Int32] = []
  let mut i = 0
  let mut j = 0
  while i < a.length() || j < b.length() {
    if j >= b.length() {
      out.push(a[i])
      i = i + 1
    } else if i >= a.length() {
      out.push(b[j])
      j = j + 1
    } else if a[i] < b[j] {
      out.push(a[i])
      i = i + 1
    } else if b[j] < a[i] {
      out.push(b[j])
      j = j + 1
    } else {
      out.push(a[i])
      i = i + 1
      j = j + 1
    }
  }
  out
}

///|
/// The neighbours one reading collects at a node, ascending and without repeats.
fn[G : @moongraph.Topology + @moongraph.Inbound] read_neighbors(
  graph : G,
  node : Int32,
  reading : Neighborhood,
) -> Array[Int32] {
  let outside = @internal.distinct_neighbors(graph, node)
  match reading {
    Undirected => {
      let inside = @internal.distinct_in_neighbors(graph, node)
      merge_sorted(outside, inside)
    }
    _ => outside
  }
}

///|
/// How many corners a node closes under one reading, and how many corners it could close: the
/// numerator and the denominator of a clustering coefficient, both counted as the reading counts
/// them.
fn[G : @moongraph.Topology + @moongraph.Inbound] corners(
  graph : G,
  node : Int32,
  reading : Neighborhood,
) -> (Int32, Int32) {
  let nbrs = read_neighbors(graph, node, reading)
  let count = nbrs.length()
  // The ordered reading exists only where an arc has a direction to run in: on an undirected
  // graph every pair is joined both ways, and counting it twice would be an accident of the
  // test rather than a property of the graph.
  if reading is Transitive && @moongraph.Topology::directed(graph) {
    // Ordered pairs, and only an arc from the first to the second closes the corner.
    let mut joined = 0
    for i in 0..<count {
      for j in 0..<count {
        if i != j && @internal.adjacent(graph, nbrs[i], nbrs[j]) {
          joined = joined + 1
        }
      }
    }
    return (joined, count * (count - 1))
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
  (joined, count * (count - 1) / 2)
}

///|
/// Whether a reading drops the directions: on an undirected graph, or under `Undirected`, a
/// triangle is the same object seen from its three corners.
fn reads_without_direction(directed : Bool, reading : Neighborhood) -> Bool {
  !directed || reading is Undirected
}
