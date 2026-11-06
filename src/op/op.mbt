// Graphs combined, restricted and transformed.

///|
/// The graph that keeps every node and edge present in either input.
///
/// The node numbers are kept as they are, which is only meaningful for two graphs over the
/// same numbering; `disjoint_union` is the one to reach for otherwise.
///
/// ```mbt check
/// test {
///   let a : @moongraph.Graph[Int, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1)],
///     node=0,
///     edge=(),
///     directed=false,
///   )
///   let b : @moongraph.Graph[Int, Unit] = @moongraph.Graph::from_edges(
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
  a : @moongraph.Graph[Int, Unit],
  b : @moongraph.Graph[Int, Unit],
) -> @moongraph.Graph[Int, Unit] {
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
  a : @moongraph.Graph[Int, Unit],
  b : @moongraph.Graph[Int, Unit],
) -> @moongraph.Graph[Int, Unit] {
  let out : @moongraph.Graph[Int, Unit] = @moongraph.Graph::new(directed=a.directed())
  let nodes = if a.node_count() < b.node_count() { a.node_count() } else { b.node_count() }
  for node in 0..<nodes {
    out.add_node(node) |> ignore
  }
  for edge in 0..<a.edge_count() {
    let (from, to) = a.endpoints(edge)
    if from < nodes && to < nodes && b.find_edge(from, to) is Some(_) &&
      out.find_edge(from, to) is None {
      out.add_edge(from, to, ()) |> ignore
    }
  }
  out
}

///|
/// The edges of the first graph that the second does not have.
pub fn difference(
  a : @moongraph.Graph[Int, Unit],
  b : @moongraph.Graph[Int, Unit],
) -> @moongraph.Graph[Int, Unit] {
  let out : @moongraph.Graph[Int, Unit] = @moongraph.Graph::new(directed=a.directed())
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
  a : @moongraph.Graph[Int, Unit],
  b : @moongraph.Graph[Int, Unit],
) -> @moongraph.Graph[Int, Unit] {
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
  a : @moongraph.Graph[Int, Unit],
  b : @moongraph.Graph[Int, Unit],
) -> @moongraph.Graph[Int, Unit] {
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
pub fn[G : @moongraph.Topology] complement(graph : G) -> @moongraph.Graph[Int, Unit] {
  let n = @moongraph.Topology::node_count(graph)
  let out : @moongraph.Graph[Int, Unit] = @moongraph.Graph::new(
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
pub fn reverse(graph : @moongraph.Graph[Int, Unit]) -> @moongraph.Graph[Int, Unit] {
  let out : @moongraph.Graph[Int, Unit] = @moongraph.Graph::new(directed=graph.directed())
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
  graph : @moongraph.Graph[Int, Unit],
  nodes : Array[Int],
) -> @moongraph.Graph[Int, Unit] {
  let out : @moongraph.Graph[Int, Unit] = @moongraph.Graph::new(directed=graph.directed())
  let location : Array[Int] = Array::make(graph.node_count(), -1)
  for node in nodes {
    if node >= 0 && node < graph.node_count() && location[node] < 0 {
      location[node] = out.node_count()
      out.add_node(node) |> ignore
    }
  }
  for edge in 0..<graph.edge_count() {
    let (from, to) = graph.endpoints(edge)
    if from >= 0 && to >= 0 && from < graph.node_count() && to < graph.node_count() &&
      location[from] >= 0 && location[to] >= 0 {
      out.add_edge(location[from], location[to], ()) |> ignore
    }
  }
  out
}

///|
/// The part of the graph on the given edges, keeping the node numbers.
pub fn edge_subgraph(
  graph : @moongraph.Graph[Int, Unit],
  edges : Array[Int],
) -> @moongraph.Graph[Int, Unit] {
  let out : @moongraph.Graph[Int, Unit] = @moongraph.Graph::new(directed=graph.directed())
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
  a : @moongraph.Graph[Int, Unit],
  b : @moongraph.Graph[Int, Unit],
) -> @moongraph.Graph[Int, Unit] {
  let out : @moongraph.Graph[Int, Unit] = @moongraph.Graph::new(directed=a.directed())
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
  a : @moongraph.Graph[Int, Unit],
  b : @moongraph.Graph[Int, Unit],
) -> @moongraph.Graph[Int, Unit] {
  let out : @moongraph.Graph[Int, Unit] = @moongraph.Graph::new(directed=a.directed())
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
  a : @moongraph.Graph[Int, Unit],
  b : @moongraph.Graph[Int, Unit],
) -> @moongraph.Graph[Int, Unit] {
  let out = cartesian_product(a, b)
  let tensor = tensor_product(a, b)
  add_edges_from(out, tensor)
  out
}

///|
/// The line graph: one node per edge of the input, joined when the edges met.
pub fn line_graph(
  graph : @moongraph.Graph[Int, Unit],
) -> @moongraph.Graph[Int, Unit] {
  let out : @moongraph.Graph[Int, Unit] = @moongraph.Graph::new(directed=false)
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
  graph : @moongraph.Graph[Int, Unit],
  nodes : Array[Int],
) -> @moongraph.Graph[Int, Unit] {
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
  let out : @moongraph.Graph[Int, Unit] = @moongraph.Graph::new(directed=graph.directed())
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
  a : @moongraph.Graph[Int, Unit],
  b : @moongraph.Graph[Int, Unit],
) -> @moongraph.Graph[Int, Unit] {
  let out : @moongraph.Graph[Int, Unit] = @moongraph.Graph::new(directed=true)
  let size = if a.node_count() > b.node_count() { a.node_count() } else { b.node_count() }
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
  graph : @moongraph.Graph[Int, Unit],
  power : Int,
) -> @moongraph.Graph[Int, Unit] {
  let n = graph.node_count()
  let out : @moongraph.Graph[Int, Unit] = @moongraph.Graph::new(directed=graph.directed())
  for node in 0..<n {
    out.add_node(node) |> ignore
  }
  for start in 0..<n {
    let depth : Array[Int] = Array::make(n, -1)
    depth[start] = 0
    let queue : Array[Int] = [start]
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
      if other != start && depth[other] > 0 && out.find_edge(start, other) is None {
        out.add_edge(start, other, ()) |> ignore
      }
    }
  }
  out
}

///|
fn copy_into(
  source : @moongraph.Graph[Int, Unit],
  target : @moongraph.Graph[Int, Unit],
) -> @moongraph.Graph[Int, Unit] {
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
  target : @moongraph.Graph[Int, Unit],
  source : @moongraph.Graph[Int, Unit],
) -> Unit {
  for edge in 0..<source.edge_count() {
    let (from, to) = source.endpoints(edge)
    if target.find_edge(from, to) is None {
      target.add_edge(from, to, ()) |> ignore
    }
  }
}
