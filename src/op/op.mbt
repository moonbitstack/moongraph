// Graphs combined, restricted and transformed.

///|
/// The graph that keeps every node and edge present in either input.
///
/// The node numbers are kept as they are, which is only meaningful for two graphs over the
/// same numbering; `disjoint_union` is the one to reach for otherwise.
///
/// ```mbt check
/// test {
///   let a : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1)],
///     node=0,
///     edge=(),
///     directed=false,
///   )
///   let b : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::from_edges(
///     [(1, 2)],
///     node=0,
///     edge=(),
///     directed=false,
///   )
///   let joined = @op.union(a, b)
///   assert_eq(joined.node_count(), 3)
///   assert_eq(joined.edge_count(), 2)
/// }
/// ```
pub fn union(
  a : @moongraph.Graph[Int32, Unit],
  b : @moongraph.Graph[Int32, Unit],
) -> @moongraph.Graph[Int32, Unit] {
  let out = copy_into(a, @moongraph.Graph::new(directed=a.directed()))
  for node in 0..<b.node_count() {
    if out.node_count() <= node {
      out.add_node(node) |> ignore
    }
  }
  add_edges_from(out, b)
  out
}

///|
/// The graph that keeps the edges both inputs have.
pub fn intersection(
  a : @moongraph.Graph[Int32, Unit],
  b : @moongraph.Graph[Int32, Unit],
) -> @moongraph.Graph[Int32, Unit] {
  let out : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=a.directed(),
  )
  let nodes = if a.node_count() < b.node_count() {
    a.node_count()
  } else {
    b.node_count()
  }
  for node in 0..<nodes {
    out.add_node(node) |> ignore
  }
  for edge in 0..<a.edge_count() {
    let (from, to) = a.endpoints(edge)
    if from < nodes &&
      to < nodes &&
      b.find_edge(from, to) is Some(_) &&
      out.find_edge(from, to) is None {
      out.add_edge(from, to, ()) |> ignore
    }
  }
  out
}

///|
/// The edges of the first graph that the second does not have.
pub fn difference(
  a : @moongraph.Graph[Int32, Unit],
  b : @moongraph.Graph[Int32, Unit],
) -> @moongraph.Graph[Int32, Unit] {
  let out : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=a.directed(),
  )
  for node in 0..<a.node_count() {
    out.add_node(node) |> ignore
  }
  for edge in 0..<a.edge_count() {
    let (from, to) = a.endpoints(edge)
    if b.find_edge(from, to) is None {
      out.add_edge(from, to, ()) |> ignore
    }
  }
  out
}

///|
/// The edges exactly one of the two graphs has.
pub fn symmetric_difference(
  a : @moongraph.Graph[Int32, Unit],
  b : @moongraph.Graph[Int32, Unit],
) -> @moongraph.Graph[Int32, Unit] {
  let out = difference(a, b)
  for node in 0..<b.node_count() {
    if out.node_count() <= node {
      out.add_node(node) |> ignore
    }
  }
  for edge in 0..<b.edge_count() {
    let (from, to) = b.endpoints(edge)
    if a.find_edge(from, to) is None && out.find_edge(from, to) is None {
      out.add_edge(from, to, ()) |> ignore
    }
  }
  out
}

///|
/// The two graphs side by side with the second one's numbers shifted up, so nothing
/// collides.
pub fn disjoint_union(
  a : @moongraph.Graph[Int32, Unit],
  b : @moongraph.Graph[Int32, Unit],
) -> @moongraph.Graph[Int32, Unit] {
  let out = copy_into(a, @moongraph.Graph::new(directed=a.directed()))
  let shift = a.node_count()
  for node in 0..<b.node_count() {
    out.add_node(node) |> ignore
  }
  for edge in 0..<b.edge_count() {
    let (from, to) = b.endpoints(edge)
    out.add_edge(from + shift, to + shift, ()) |> ignore
  }
  out
}

///|
/// The graph with the same nodes and the edges it does not have.
pub fn[G : @moongraph.Topology] complement(
  graph : G,
) -> @moongraph.Graph[Int32, Unit] {
  let n = @moongraph.Topology::node_count(graph)
  let out : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=@moongraph.Topology::directed(graph),
  )
  for node in 0..<n {
    out.add_node(node) |> ignore
  }
  for a in 0..<n {
    let start = if @moongraph.Topology::directed(graph) { 0 } else { a + 1 }
    for b in start..<n {
      if a != b && !@internal.adjacent(graph, a, b) {
        out.add_edge(a, b, ()) |> ignore
      }
    }
  }
  out
}

///|
/// The same edges with every direction turned around.
pub fn reverse(
  graph : @moongraph.Graph[Int32, Unit],
) -> @moongraph.Graph[Int32, Unit] {
  let out : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=graph.directed(),
  )
  for node in 0..<graph.node_count() {
    out.add_node(node) |> ignore
  }
  for edge in 0..<graph.edge_count() {
    let (from, to) = graph.endpoints(edge)
    out.add_edge(to, from, ()) |> ignore
  }
  out
}

///|
/// The part of the graph on the given nodes, with the numbers renumbered from 0 in the order
/// the nodes are listed.
pub fn subgraph(
  graph : @moongraph.Graph[Int32, Unit],
  nodes : Array[Int32],
) -> @moongraph.Graph[Int32, Unit] {
  let out : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=graph.directed(),
  )
  let location : Array[Int32] = Array::make(graph.node_count(), -1)
  for node in nodes {
    if node >= 0 && node < graph.node_count() && location[node] < 0 {
      location[node] = out.node_count()
      out.add_node(node) |> ignore
    }
  }
  for edge in 0..<graph.edge_count() {
    let (from, to) = graph.endpoints(edge)
    if from >= 0 &&
      to >= 0 &&
      from < graph.node_count() &&
      to < graph.node_count() &&
      location[from] >= 0 &&
      location[to] >= 0 {
      out.add_edge(location[from], location[to], ()) |> ignore
    }
  }
  out
}

///|
/// The part of the graph on the given edges, keeping the node numbers.
pub fn edge_subgraph(
  graph : @moongraph.Graph[Int32, Unit],
  edges : Array[Int32],
) -> @moongraph.Graph[Int32, Unit] {
  let out : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=graph.directed(),
  )
  for node in 0..<graph.node_count() {
    out.add_node(node) |> ignore
  }
  for edge in edges {
    if edge >= 0 && edge < graph.edge_count() {
      let (from, to) = graph.endpoints(edge)
      if out.find_edge(from, to) is None {
        out.add_edge(from, to, ()) |> ignore
      }
    }
  }
  out
}

///|
/// The pair graph: one node per pair of inputs, joined when both coordinates are joined.
pub fn cartesian_product(
  a : @moongraph.Graph[Int32, Unit],
  b : @moongraph.Graph[Int32, Unit],
) -> @moongraph.Graph[Int32, Unit] {
  let out : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=a.directed(),
  )
  let width = b.node_count()
  for node in 0..<(a.node_count() * width) {
    out.add_node(node) |> ignore
  }
  for i in 0..<a.node_count() {
    for j in 0..<width {
      let node = i * width + j
      if i + 1 < a.node_count() && a.find_edge(i, i + 1) is Some(_) {
        out.add_edge(node, (i + 1) * width + j, ()) |> ignore
      }
      if j + 1 < width && b.find_edge(j, j + 1) is Some(_) {
        out.add_edge(node, i * width + j + 1, ()) |> ignore
      }
      if a.directed() {
        for edge in 0..<a.edge_count() {
          let (from, to) = a.endpoints(edge)
          if from == i {
            out.add_edge(from * width + j, to * width + j, ()) |> ignore
          }
        }
        for edge in 0..<b.edge_count() {
          let (from, to) = b.endpoints(edge)
          if from == j {
            out.add_edge(i * width + from, i * width + to, ()) |> ignore
          }
        }
      }
    }
  }
  out
}

///|
/// The tensor product: an edge where both coordinates have one.
pub fn tensor_product(
  a : @moongraph.Graph[Int32, Unit],
  b : @moongraph.Graph[Int32, Unit],
) -> @moongraph.Graph[Int32, Unit] {
  let out : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=a.directed(),
  )
  let width = b.node_count()
  for node in 0..<(a.node_count() * width) {
    out.add_node(node) |> ignore
  }
  for edge_a in 0..<a.edge_count() {
    let (from_a, to_a) = a.endpoints(edge_a)
    for edge_b in 0..<b.edge_count() {
      let (from_b, to_b) = b.endpoints(edge_b)
      out.add_edge(from_a * width + from_b, to_a * width + to_b, ()) |> ignore
    }
  }
  out
}

///|
/// The strong product: an edge where either coordinate has one or both do.
pub fn strong_product(
  a : @moongraph.Graph[Int32, Unit],
  b : @moongraph.Graph[Int32, Unit],
) -> @moongraph.Graph[Int32, Unit] {
  let out = cartesian_product(a, b)
  let tensor = tensor_product(a, b)
  add_edges_from(out, tensor)
  out
}

///|
/// The line graph: one node per edge of the input, joined when the edges met.
pub fn line_graph(
  graph : @moongraph.Graph[Int32, Unit],
) -> @moongraph.Graph[Int32, Unit] {
  let out : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=false,
  )
  for edge in 0..<graph.edge_count() {
    out.add_node(edge) |> ignore
  }
  for first in 0..<graph.edge_count() {
    for second in (first + 1)..<graph.edge_count() {
      let (a1, b1) = graph.endpoints(first)
      let (a2, b2) = graph.endpoints(second)
      if a1 == a2 || a1 == b2 || b1 == a2 || b1 == b2 {
        out.add_edge(first, second, ()) |> ignore
      }
    }
  }
  out
}

///|
/// The graph with a set of nodes replaced by one: the contraction.
pub fn contraction(
  graph : @moongraph.Graph[Int32, Unit],
  nodes : Array[Int32],
) -> @moongraph.Graph[Int32, Unit] {
  let n = graph.node_count()
  let inside : Array[Bool] = Array::make(n, false)
  let mut first = -1
  for node in nodes {
    if node >= 0 && node < n {
      inside[node] = true
      if first < 0 {
        first = node
      }
    }
  }
  let out : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=graph.directed(),
  )
  for node in 0..<n {
    if !inside[node] || node == first {
      out.add_node(node) |> ignore
    }
  }
  for edge in 0..<graph.edge_count() {
    let (from, to) = graph.endpoints(edge)
    let a = if inside[from] { first } else { from }
    let b = if inside[to] { first } else { to }
    if a != b && out.find_edge(a, b) is None {
      out.add_edge(a, b, ()) |> ignore
    }
  }
  out
}

///|
/// The graph with `b` laid over `a` where their node numbers agree.
pub fn compose(
  a : @moongraph.Graph[Int32, Unit],
  b : @moongraph.Graph[Int32, Unit],
) -> @moongraph.Graph[Int32, Unit] {
  let out : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(directed=true)
  let size = if a.node_count() > b.node_count() {
    a.node_count()
  } else {
    b.node_count()
  }
  for node in 0..<size {
    out.add_node(node) |> ignore
  }
  for first in 0..<b.edge_count() {
    let (middle, to) = b.endpoints(first)
    for second in 0..<a.edge_count() {
      let (from, target) = a.endpoints(second)
      if target == middle && out.find_edge(from, to) is None {
        out.add_edge(from, to, ()) |> ignore
      }
    }
  }
  out
}

///|
/// The graph reached in at most `power` steps of the input.
pub fn graph_power(
  graph : @moongraph.Graph[Int32, Unit],
  power : Int32,
) -> @moongraph.Graph[Int32, Unit] {
  let n = graph.node_count()
  let out : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=graph.directed(),
  )
  for node in 0..<n {
    out.add_node(node) |> ignore
  }
  for start in 0..<n {
    let depth : Array[Int32] = Array::make(n, -1)
    depth[start] = 0
    let queue : Array[Int32] = [start]
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      if depth[node] >= power {
        continue
      }
      for nbr in graph.neighbors(node) {
        if depth[nbr] < 0 {
          depth[nbr] = depth[node] + 1
          queue.push(nbr)
        }
      }
    }
    for other in 0..<n {
      if other != start &&
        depth[other] > 0 &&
        out.find_edge(start, other) is None {
        out.add_edge(start, other, ()) |> ignore
      }
    }
  }
  out
}

///|
fn copy_into(
  source : @moongraph.Graph[Int32, Unit],
  target : @moongraph.Graph[Int32, Unit],
) -> @moongraph.Graph[Int32, Unit] {
  for node in 0..<source.node_count() {
    target.add_node(node) |> ignore
  }
  for edge in 0..<source.edge_count() {
    let (from, to) = source.endpoints(edge)
    target.add_edge(from, to, ()) |> ignore
  }
  target
}

///|
fn add_edges_from(
  target : @moongraph.Graph[Int32, Unit],
  source : @moongraph.Graph[Int32, Unit],
) -> Unit {
  for edge in 0..<source.edge_count() {
    let (from, to) = source.endpoints(edge)
    if target.find_edge(from, to) is None {
      target.add_edge(from, to, ()) |> ignore
    }
  }
}

///|
/// A copy of the graph: the same payloads, the same directions, the same edges.
fn[N, E] clone(graph : @moongraph.Graph[N, E]) -> @moongraph.Graph[N, E] {
  let out : @moongraph.Graph[N, E] = @moongraph.Graph::new(
    directed=graph.directed(),
  )
  for node in 0..<graph.node_count() {
    out.add_node(graph.node_data(node)) |> ignore
  }
  for edge in graph.edges() {
    let (from, to) = graph.endpoints(edge)
    out.add_edge(from, to, graph.edge_data(edge)) |> ignore
  }
  out
}

///|
/// The graph with every node payload put through `f`, and the edges kept as they are.
///
/// This is alga's `nmap`: a graph whose nodes carry different data over the same shape. Node
/// numbers are untouched, so an edge that ran from `u` to `v` still does.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(directed=false)
///   g.add_node(7) |> ignore
///   g.add_node(9) |> ignore
///   g.add_edge(0, 1, ()) |> ignore
///   let named = @op.nmap(g, fn(node) { "n" + node.to_string() })
///   assert_eq(named.node_data(1), "n9")
///   assert_eq(named.edge_count(), 1)
/// }
/// ```
pub fn[N, E, M] nmap(
  graph : @moongraph.Graph[N, E],
  f : (N) -> M,
) -> @moongraph.Graph[M, E] {
  let out : @moongraph.Graph[M, E] = @moongraph.Graph::new(
    directed=graph.directed(),
  )
  for node in 0..<graph.node_count() {
    out.add_node(f(graph.node_data(node))) |> ignore
  }
  for edge in graph.edges() {
    let (from, to) = graph.endpoints(edge)
    out.add_edge(from, to, graph.edge_data(edge)) |> ignore
  }
  out
}

///|
/// The graph with every edge payload put through `f`, and the nodes kept as they are.
///
/// This is alga's `emap`. It is how a weight becomes a cost, or a label becomes a length,
/// without rebuilding the shape.
pub fn[N, E, F] emap(
  graph : @moongraph.Graph[N, E],
  f : (E) -> F,
) -> @moongraph.Graph[N, F] {
  let out : @moongraph.Graph[N, F] = @moongraph.Graph::new(
    directed=graph.directed(),
  )
  for node in 0..<graph.node_count() {
    out.add_node(graph.node_data(node)) |> ignore
  }
  for edge in graph.edges() {
    let (from, to) = graph.endpoints(edge)
    out.add_edge(from, to, f(graph.edge_data(edge))) |> ignore
  }
  out
}

///|
/// Both at once: alga's `gmap`, the node payloads through `node_f` and the edge payloads
/// through `edge_f`.
pub fn[N, E, M, F] gmap(
  graph : @moongraph.Graph[N, E],
  node_f : (N) -> M,
  edge_f : (E) -> F,
) -> @moongraph.Graph[M, F] {
  let out : @moongraph.Graph[M, F] = @moongraph.Graph::new(
    directed=graph.directed(),
  )
  for node in 0..<graph.node_count() {
    out.add_node(node_f(graph.node_data(node))) |> ignore
  }
  for edge in graph.edges() {
    let (from, to) = graph.endpoints(edge)
    out.add_edge(from, to, edge_f(graph.edge_data(edge))) |> ignore
  }
  out
}

///|
/// A copy of the graph with one node and every edge touching it taken out.
///
/// The nodes above it move down by one, exactly as `Graph::remove_node` moves them, so a
/// caller holding old node numbers has to adjust the ones past `node`. Removing a number the
/// graph does not have changes nothing.
pub fn[N, E] remove_vertex(
  graph : @moongraph.Graph[N, E],
  node : Int32,
) -> @moongraph.Graph[N, E] {
  let out = clone(graph)
  out.remove_node(node)
  out
}

///|
/// A copy of the graph with one edge between two nodes taken out: the first one found, which
/// in a simple graph is the only one. Asking for an edge the graph does not have changes
/// nothing.
///
/// This is alga's `removeEdge` and NetworkX's `remove_edge(u, v)`, by endpoints rather than by
/// edge number; `Graph::remove_edge` is the one that takes a number.
pub fn[N, E] remove_edge(
  graph : @moongraph.Graph[N, E],
  from : Int32,
  to : Int32,
) -> @moongraph.Graph[N, E] {
  let out = clone(graph)
  let found = out.find_edges(from, to)
  if found.length() > 0 {
    out.remove_edge(found[0])
  }
  out
}

///|
/// The two graphs side by side, with every node of the first joined to every node of the
/// second: alga's `connect`.
///
/// The first graph keeps its numbers and the second moves up by the first one's node count, so
/// this is `disjoint_union` plus the complete join between the two halves. The result has
/// `na + nb` nodes and `ea + eb + na · nb` edges.
///
/// ```mbt check
/// test {
///   let a : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1)],
///     node=0,
///     edge=(),
///     directed=false,
///   )
///   let b : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1)],
///     node=0,
///     edge=(),
///     directed=false,
///   )
///   let joined = @op.connect(a, b)
///   // Two nodes in each half, so four joining edges on top of the two kept.
///   assert_eq(joined.edge_count(), 6)
///   assert_eq(joined.node_count(), 4)
/// }
/// ```
pub fn connect(
  a : @moongraph.Graph[Int32, Unit],
  b : @moongraph.Graph[Int32, Unit],
) -> @moongraph.Graph[Int32, Unit] {
  let out = disjoint_union(a, b)
  let half = a.node_count()
  for left in 0..<half {
    for right in 0..<b.node_count() {
      out.add_edge(left, half + right, ()) |> ignore
    }
  }
  out
}

///|
/// The graph with an edge from every node to every node it can reach, itself included: the
/// reflexive transitive closure, alga's `closure`.
///
/// One breadth-first walk per node settles it, so the cost is `O(n · (n + m))`. On an
/// undirected graph it turns each connected piece into a complete graph with a loop on every
/// node; on a directed one it is the reachability relation as edges.
pub fn closure(
  graph : @moongraph.Graph[Int32, Unit],
) -> @moongraph.Graph[Int32, Unit] {
  let out = clone(graph)
  let n = graph.node_count()
  for start in 0..<n {
    let seen : Array[Bool] = Array::make(n, false)
    let queue : Array[Int32] = [start]
    seen[start] = true
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      for next in graph.neighbors(node) {
        if !seen[next] {
          seen[next] = true
          queue.push(next)
        }
      }
    }
    for to in 0..<n {
      if seen[to] && out.find_edge(start, to) is None {
        out.add_edge(start, to, ()) |> ignore
      }
    }
  }
  out
}

///|
/// Whether one graph sits inside another: every node number it uses exists in the larger
/// graph, and every edge it has is an edge there too, in the same direction when the larger
/// graph is directed.
///
/// This is alga's `isSubgraphOf`. It compares numbers with numbers, so it answers for two
/// graphs over the same numbering; a pair of parallel edges counts as one, since the
/// question is about shape rather than about multiplicity.
///
/// ```mbt check
/// test {
///   let small : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   let big : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (2, 0)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   assert_eq(@op.is_subgraph_of(small, big), true)
///   assert_eq(@op.is_subgraph_of(big, small), false)
/// }
/// ```
pub fn[G : @moongraph.Topology, H : @moongraph.Topology] is_subgraph_of(
  small : G,
  big : H,
) -> Bool {
  let inside = @moongraph.Topology::node_count(big)
  for node in 0..<@moongraph.Topology::node_count(small) {
    if node >= inside {
      return false
    }
  }
  let directed = @moongraph.Topology::directed(big)
  for node in 0..<@moongraph.Topology::node_count(small) {
    for eid in @moongraph.Topology::incident(small, node) {
      let (from, to) = @moongraph.Topology::endpoints(small, eid)
      if from >= inside || to >= inside {
        return false
      }
      if !has_arc(big, from, to) && (directed || !has_arc(big, to, from)) {
        return false
      }
    }
  }
  true
}

///|
/// Whether an arc joins two nodes, read out of the adjacency list.
fn[G : @moongraph.Topology] has_arc(
  graph : G,
  from : Int32,
  to : Int32,
) -> Bool {
  for nbr in @moongraph.Topology::neighbors(graph, from) {
    if nbr == to {
      return true
    }
  }
  false
}

///|
/// Replaces every node of a shape with a graph: the answer holds each piece side by side,
/// and wherever the shape had an edge, the two pieces are joined completely — every node of
/// one to every node of the other.
///
/// This is alga's `bind`, the operation that makes a graph a monad: a node is a piece, an
/// edge is a way of wiring two pieces together. It is how a graph of machines becomes the
/// graph of their networks, and how a coarse map becomes a fine one without losing the
/// coarse structure.
///
/// A node with no piece — an index past the end of `pieces` — becomes a single node of its
/// own, so a partial binding still names every piece of the shape. A self-loop in the shape
/// adds nothing: the piece is already joined to itself.
///
/// ```mbt check
/// test {
///   let shape : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1)],
///     node=0,
///     edge=(),
///     directed=false,
///   )
///   let pair : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1)],
///     node=0,
///     edge=(),
///     directed=false,
///   )
///   let single : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
///     directed=false,
///   )
///   single.add_node(0) |> ignore
///   // Two nodes wired to one: three nodes and the pair's own edge plus two joins.
///   let wired = @op.bind(shape, [pair, single])
///   assert_eq(wired.node_count(), 3)
///   assert_eq(wired.edge_count(), 3)
/// }
/// ```
pub fn bind(
  shape : @moongraph.Graph[Int32, Unit],
  pieces : Array[@moongraph.Graph[Int32, Unit]],
) -> @moongraph.Graph[Int32, Unit] {
  let n = shape.node_count()
  let start : Array[Int32] = Array::make(n, 0)
  let size : Array[Int32] = Array::make(n, 1)
  let mut total = 0
  for node in 0..<n {
    if node < pieces.length() {
      size[node] = pieces[node].node_count()
    }
    start[node] = total
    total = total + size[node]
  }
  let out : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=shape.directed(),
  )
  for _ in 0..<total {
    out.add_node(0) |> ignore
  }
  // Each piece, moved to where its node landed.
  for node in 0..<n {
    if node >= pieces.length() {
      continue
    }
    let piece = pieces[node]
    for eid in piece.edges() {
      let (from, to) = piece.endpoints(eid)
      out.add_edge(start[node] + from, start[node] + to, ()) |> ignore
    }
  }
  // The shape's edges become complete joins between the pieces they touch.
  for eid in shape.edges() {
    let (from, to) = shape.endpoints(eid)
    if from == to {
      continue
    }
    for left in 0..<size[from] {
      for right in 0..<size[to] {
        out.add_edge(start[from] + left, start[to] + right, ()) |> ignore
      }
    }
  }
  out
}
