// The triadic census: every triple of nodes, classified into one of the sixteen shapes a
// directed triangle can take.

///|
/// The sixteen triad types, in the order the census counts them. The name is the shape's
/// canonical label: how many arcs it has, then a letter for the direction they take.
pub let triad_names : Array[String] = [
  "003", "012", "102", "021D", "021U", "021C", "111D", "111U", "030T", "030C", "201",
  "120D", "120U", "120C", "210", "300",
]

///|
/// Which of the sixteen shapes a triple falls into, indexed by the six-bit code the arcs
/// make: bit 0 is `v→u`, bit 1 `u→v`, bit 2 `v→w`, bit 3 `w→v`, bit 4 `u→w`, bit 5 `w→u`.
/// The table holds the position in `triad_names` for all sixty-four codes, so the census
/// never has to reason about a shape, only to look one up.
let tricode_index : Array[Int32] = [
  0, 1, 1, 2, 1, 3, 5, 7, 1, 5, 4, 6, 2, 7, 6, 10, 1, 5, 3, 7, 4, 8, 8, 12, 5, 9,
  8, 13, 6, 13, 11, 14, 1, 4, 5, 6, 5, 8, 9, 13, 3, 8, 8, 11, 7, 12, 13, 14, 2, 6,
  7, 10, 6, 11, 13, 14, 7, 13, 12, 14, 10, 14, 14, 15,
]

///|
/// How many triples of each of the sixteen shapes a graph has. `count` follows the order of
/// `triad_names`, and the sixteen counts always add up to the number of triples the graph
/// has room for.
pub(all) struct TriadCensus {
  count : Array[Int32]
}

///|
/// The census of one shape, looked up by its name.
pub fn TriadCensus::of(self : TriadCensus, name : String) -> Int32? {
  for i in 0..<triad_names.length() {
    if triad_names[i] == name {
      return Some(self.count[i])
    }
  }
  None
}

///|
/// Whether a sorted array holds a value, by halving it.
fn holds(sorted : Array[Int32], value : Int32) -> Bool {
  let mut low = 0
  let mut high = sorted.length() - 1
  while low <= high {
    let middle = (low + high) / 2
    if sorted[middle] == value {
      return true
    } else if sorted[middle] < value {
      low = middle + 1
    } else {
      high = middle - 1
    }
  }
  false
}

///|
/// The out-neighbours of a node, ascending and once each.
fn[G : @moongraph.Topology] out_set(g : G, node : Int32) -> Array[Int32] {
  @internal.distinct_neighbors(g, node)
}

///|
/// Every node joined to this one in either direction: the neighbourhood a triple can be
/// built from, which for an undirected graph is the ordinary one and for a directed graph
/// is the union of the two sides.
fn[G : @moongraph.Topology + @moongraph.Inbound] both_set(
  g : G,
  node : Int32,
) -> Array[Int32] {
  let merged : Array[Int32] = []
  for nbr in out_set(g, node) {
    merged.push(nbr)
  }
  for nbr in @moongraph.Inbound::in_neighbors(g, node) {
    merged.push(nbr)
  }
  merged.sort()
  let unique : Array[Int32] = []
  for nbr in merged {
    if unique.length() == 0 || unique[unique.length() - 1] != nbr {
      unique.push(nbr)
    }
  }
  unique
}

///|
/// The six-bit code of a triple: which of the six possible arcs is present.
fn tricode(
  outs : Array[Array[Int32]],
  v : Int32,
  u : Int32,
  w : Int32,
) -> Int32 {
  let mut code = 0
  if holds(outs[v], u) {
    code = code + 1
  }
  if holds(outs[u], v) {
    code = code + 2
  }
  if holds(outs[v], w) {
    code = code + 4
  }
  if holds(outs[w], v) {
    code = code + 8
  }
  if holds(outs[u], w) {
    code = code + 16
  }
  if holds(outs[w], u) {
    code = code + 32
  }
  code
}

///|
/// The census of the sixteen triad types: how many triples of nodes carry no arc, one, two
/// or three, and in which directions. An undirected graph is read as the directed graph
/// that has both arcs for every edge, so its triples are the four symmetric shapes.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (2, 0)],
///     node=(),
///     edge=(),
///     directed=true,
///   )
///   let census = @metric.triadic_census(g)
///   // Three arcs that run round rather than through: the cyclic triangle.
///   assert_eq(census.of("030C"), Some(1))
/// }
/// ```
pub fn[G : @moongraph.Topology + @moongraph.Inbound] triadic_census(
  graph : G,
) -> TriadCensus {
  let n = @moongraph.Topology::node_count(graph)
  let count : Array[Int32] = Array::make(16, 0)
  if n < 3 {
    return { count, }
  }
  let outs : Array[Array[Int32]] = Array::makei(n, fn(node) {
    out_set(graph, node)
  })
  let boths : Array[Array[Int32]] = Array::makei(n, fn(node) {
    both_set(graph, node)
  })
  for v in 0..<n {
    let vn = boths[v]
    for u in vn {
      if u <= v {
        continue
      }
      let un = boths[u]
      // The nodes that could close a triple with this pair: everything either of them
      // touches, the pair itself aside.
      let around : Array[Int32] = []
      for w in vn {
        if w != v && w != u {
          around.push(w)
        }
      }
      for w in un {
        if w != v && w != u && !holds(vn, w) {
          around.push(w)
        }
      }
      for w in around {
        // Each triple is reached once: from its first two nodes, or from the two that are
        // joined when the first is not joined to the second.
        if u < w || (v < w && w < u && !holds(boths[w], v)) {
          let code = tricode(outs, v, u, w)
          count[tricode_index[code]] = count[tricode_index[code]] + 1
        }
      }
      // The triples with only this arc: every other node that neither end touches.
      let lonely = n - around.length() - 2
      let mutual = holds(outs[v], u) && holds(outs[u], v)
      if mutual {
        count[2] = count[2] + lonely
      } else {
        count[1] = count[1] + lonely
      }
    }
  }
  // Whatever is left over is the triples with no arc at all.
  let mut total = n * (n - 1) * (n - 2) / 6
  for i in 1..<16 {
    total = total - count[i]
  }
  count[0] = total
  { count, }
}
