// Connected components, strong components, and the structure that survives a
// single cut: biconnected pieces, articulation points, bridges.

///|
/// The components of a graph, as a label per node.
///
/// A directed graph is read as its underlying undirected one, because reachability
/// alone does not partition a directed graph: use `strong_components` for the
/// partition that follows the edge direction.
///
/// Labels are numbered from 0 in the order the components are found, and the
/// search starts at the lowest-numbered node of each, so the labelling is the same
/// on every run.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] components(
  graph : G,
) -> @moongraph.Components {
  let n = @moongraph.Topology::node_count(graph)
  let label : Array[Int32] = Array::make(n, -1)
  let mut count = 0
  for start in 0..<n {
    if label[start] < 0 {
      flood(graph, start, label, count)
      count = count + 1
    }
  }
  { label, count, }
}

///|
/// Labels everything reachable from `start`, reading edges in both directions, and
/// returns how many nodes it touched.
fn[G : @moongraph.Topology + @moongraph.Inbound] flood(
  graph : G,
  start : Int32,
  label : Array[Int32],
  tag : Int32,
) -> Unit {
  let queue : Array[Int32] = [start]
  label[start] = tag
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    for nbr in @internal.distinct_neighbors(graph, node) {
      if label[nbr] < 0 {
        label[nbr] = tag
        queue.push(nbr)
      }
    }
    if @moongraph.Topology::directed(graph) {
      for nbr in @internal.in_edges(graph, node) {
        if label[nbr.0] < 0 {
          label[nbr.0] = tag
          queue.push(nbr.0)
        }
      }
    }
  }
}

///|
/// How many components there are.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] component_count(
  graph : G,
) -> Int32 {
  components(graph).count
}

///|
/// Whether the graph is one piece.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] is_connected(
  graph : G,
) -> Bool {
  components(graph).count <= 1
}

///|
/// The nodes in the same component as `node`, ascending.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] component_of(
  graph : G,
  node : Int32,
) -> Array[Int32] {
  let out : Array[Int32] = []
  let n = @moongraph.Topology::node_count(graph)
  if node < 0 || node >= n {
    return out
  }
  let parts = components(graph)
  for other in 0..<n {
    if parts.label[other] == parts.label[node] {
      out.push(other)
    }
  }
  out
}

///|
/// The same components under the name that says the edges were read both ways.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] weak_components(
  graph : G,
) -> @moongraph.Components {
  components(graph)
}

///|
/// Whether the graph is one piece when direction is ignored.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] is_weakly_connected(
  graph : G,
) -> Bool {
  is_connected(graph)
}

///|
/// Strongly connected components by Tarjan's method: one depth-first pass, one
/// stack.
///
/// Components are numbered in reverse topological order of the condensation —
/// sinks first — so `condensation` can lay them out without a second sort. That
/// order is part of the answer, not an accident: a caller that wants a
/// topological order of the components already has one.
pub fn[G : @moongraph.Topology] strong_components(
  graph : G,
) -> @moongraph.Components {
  let n = @moongraph.Topology::node_count(graph)
  let label : Array[Int32] = Array::make(n, -1)
  let index : Array[Int32] = Array::make(n, -1)
  let low : Array[Int32] = Array::make(n, 0)
  let on_stack : Array[Bool] = Array::make(n, false)
  let stack : Array[Int32] = []
  let counter = [0]
  let mut count = 0
  // An explicit stack keeps a deep graph from exhausting the native stack: the
  // frames are (node, edge position).
  for start in 0..<n {
    if index[start] >= 0 {
      continue
    }
    let frames : Array[(Int32, Int32)] = [(start, 0)]
    index[start] = counter[0]
    low[start] = counter[0]
    counter[0] = counter[0] + 1
    stack.push(start)
    on_stack[start] = true
    while frames.length() > 0 {
      let top = frames.length() - 1
      let (node, at) = frames[top]
      let edges = @internal.out_edges(graph, node)
      if at < edges.length() {
        frames[top] = (node, at + 1)
        let nbr = edges[at].0
        if index[nbr] < 0 {
          index[nbr] = counter[0]
          low[nbr] = counter[0]
          counter[0] = counter[0] + 1
          stack.push(nbr)
          on_stack[nbr] = true
          frames.push((nbr, 0))
        } else if on_stack[nbr] && index[nbr] < low[node] {
          low[node] = index[nbr]
        }
      } else {
        frames.pop() |> ignore
        if low[node] == index[node] {
          let mut picked = -1
          while picked != node {
            picked = stack[stack.length() - 1]
            stack.pop() |> ignore
            on_stack[picked] = false
            label[picked] = count
          }
          count = count + 1
        }
        if frames.length() > 0 {
          let parent = frames[frames.length() - 1].0
          if low[node] < low[parent] {
            low[parent] = low[node]
          }
        }
      }
    }
  }
  { label, count, }
}

///|
/// Strong components by two passes: one forward, one over the reversed edges.
///
/// The same answer as `strong_components`, by a method that is easier to check by
/// hand and needs the graph to report incoming edges.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] strong_components_kosaraju(
  graph : G,
) -> @moongraph.Components {
  let n = @moongraph.Topology::node_count(graph)
  let order : Array[Int32] = []
  let seen : Array[Bool] = Array::make(n, false)
  for start in 0..<n {
    if seen[start] {
      continue
    }
    let frames : Array[(Int32, Int32)] = [(start, 0)]
    seen[start] = true
    while frames.length() > 0 {
      let top = frames.length() - 1
      let (node, at) = frames[top]
      let edges = @internal.out_edges(graph, node)
      if at < edges.length() {
        frames[top] = (node, at + 1)
        let nbr = edges[at].0
        if !seen[nbr] {
          seen[nbr] = true
          frames.push((nbr, 0))
        }
      } else {
        order.push(node)
        frames.pop() |> ignore
      }
    }
  }
  // Second pass over the reversed graph in reverse finishing order. Labels come
  // out in topological order of the condensation, matching Tarjan's numbering.
  let label : Array[Int32] = Array::make(n, -1)
  let mut count = 0
  for i in 0..<order.length() {
    let start = order[order.length() - 1 - i]
    if label[start] < 0 {
      let queue : Array[Int32] = [start]
      label[start] = count
      let mut head = 0
      while head < queue.length() {
        let node = queue[head]
        head = head + 1
        for (nbr, _) in @internal.in_edges(graph, node) {
          if label[nbr] < 0 {
            label[nbr] = count
            queue.push(nbr)
          }
        }
      }
      count = count + 1
    }
  }
  { label, count, }
}

///|
/// Whether every node reaches every other.
pub fn[G : @moongraph.Topology] is_strongly_connected(graph : G) -> Bool {
  strong_components(graph).count <= 1
}

///|
/// Whether the nodes can be laid on a line so that every pair has an edge in at
/// least one direction: the condensation has to be a single chain.
pub fn[G : @moongraph.Topology] is_semiconnected(graph : G) -> Bool {
  let parts = strong_components(graph)
  if parts.count <= 1 {
    return true
  }
  let cond = condensation(graph)
  let mut sources = 0
  let mut sinks = 0
  for comp in 0..<parts.count {
    let out_degree = cond.graph.neighbors(comp).length()
    let in_degree = cond.graph.in_neighbors(comp).length()
    if out_degree == 0 {
      sinks = sinks + 1
    }
    if in_degree == 0 {
      sources = sources + 1
    }
  }
  if sources != 1 || sinks != 1 {
    return false
  }
  // A unique source and a unique sink are not enough: an edge between two
  // middling components can still leave a gap, so the chain is walked.
  let mut node = 0
  for comp in 0..<parts.count {
    if cond.graph.in_neighbors(comp).length() == 0 {
      node = comp
    }
  }
  let mut visited = 1
  while cond.graph.neighbors(node).length() == 1 {
    node = cond.graph.neighbors(node)[0]
    visited = visited + 1
  }
  visited == parts.count
}

///|
/// The condensation: one node per strong component, one edge per component pair
/// that has an edge between them.
///
/// Components are numbered as `strong_components` numbers them, which is reverse
/// topological order, so every edge here goes from a higher number to a lower one.
pub fn[G : @moongraph.Topology] condensation(
  graph : G,
) -> @moongraph.Condensation {
  let parts = strong_components(graph)
  let n = @moongraph.Topology::node_count(graph)
  let members : Array[Array[Int32]] = Array::makei(parts.count, fn(_) {
    ([] : Array[Int32])
  })
  for node in 0..<n {
    members[parts.label[node]].push(node)
  }
  let out : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new()
  for comp in 0..<parts.count {
    out.add_node(comp) |> ignore
  }
  let joined : Array[Bool] = Array::make(parts.count * parts.count, false)
  for node in 0..<n {
    let from = parts.label[node]
    for nbr in graph.neighbors(node) {
      let to = parts.label[nbr]
      if from != to && !joined[from * parts.count + to] {
        joined[from * parts.count + to] = true
        out.add_edge(from, to, ()) |> ignore
      }
    }
  }
  { graph: out, of_node: parts.label, members, }
}

///|
/// The nodes from which a random walk never leaves its component: those with no
/// edge to another strong component.
pub fn[G : @moongraph.Topology] attracting_components(
  graph : G,
) -> Array[Array[Int32]] {
  let parts = strong_components(graph)
  let cond = condensation(graph)
  let out : Array[Array[Int32]] = []
  for comp in 0..<parts.count {
    if cond.graph.neighbors(comp).length() == 0 {
      out.push(cond.members[comp].copy())
    }
  }
  out
}

///|
/// Every edge that lies on a cycle, grouped by biconnected piece, with an isolated
/// edge forming a piece of its own.
///
/// The result is edge numbers, one array per piece, pieces ordered by their
/// lowest edge number. A bridge therefore appears as a single-edge piece.
pub fn[G : @moongraph.Topology] biconnected_components(
  graph : G,
) -> Array[Array[Int32]] {
  let n = @moongraph.Topology::node_count(graph)
  let disc : Array[Int32] = Array::make(n, -1)
  let low : Array[Int32] = Array::make(n, 0)
  let counter = [0]
  let edge_stack : Array[Int32] = []
  let out : Array[Array[Int32]] = []
  for start in 0..<n {
    if disc[start] >= 0 {
      continue
    }
    disc[start] = counter[0]
    low[start] = counter[0]
    counter[0] = counter[0] + 1
    let frames : Array[(Int32, Int32, Int32)] = [(start, 0, -1)]
    while frames.length() > 0 {
      let top = frames.length() - 1
      let (node, at, parent) = frames[top]
      let nbrs = graph.neighbors(node)
      let eids = graph.incident(node)
      if at < eids.length() {
        frames[top] = (node, at + 1, parent)
        let edge = eids[at]
        let nbr = nbrs[at]
        if edge == parent {
          continue
        }
        if disc[nbr] < 0 {
          edge_stack.push(edge)
          disc[nbr] = counter[0]
          low[nbr] = counter[0]
          counter[0] = counter[0] + 1
          frames.push((nbr, 0, edge))
        } else if disc[nbr] < disc[node] {
          // A back edge to an ancestor: the piece closes here or above.
          edge_stack.push(edge)
          if disc[nbr] < low[node] {
            low[node] = disc[nbr]
          }
        }
      } else {
        frames.pop() |> ignore
        if frames.length() > 0 {
          let above = frames[frames.length() - 1].0
          if low[node] < low[above] {
            low[above] = low[node]
          }
          if low[node] >= disc[above] {
            // `above` is an articulation point: pop one piece.
            let piece : Array[Int32] = []
            while edge_stack.length() > 0 {
              let edge = edge_stack[edge_stack.length() - 1]
              edge_stack.pop() |> ignore
              piece.push(edge)
              if edge == parent {
                break
              }
            }
            if piece.length() > 0 {
              out.push(piece)
            }
          }
        } else {
          // The root of a search tree closes whatever is left.
          while edge_stack.length() > 0 {
            let edge = edge_stack[edge_stack.length() - 1]
            edge_stack.pop() |> ignore
            out.push([edge])
          }
        }
      }
    }
  }
  out
}

///|
/// The nodes of each biconnected piece, ascending inside each piece, pieces in the
/// order `biconnected_components` returns them.
pub fn[G : @moongraph.Topology] biconnected_component_nodes(
  graph : G,
) -> Array[Array[Int32]] {
  let out : Array[Array[Int32]] = []
  for piece in biconnected_components(graph) {
    let nodes : Array[Int32] = []
    for edge in piece {
      let (a, b) = graph.endpoints(edge)
      if !nodes.contains(a) {
        nodes.push(a)
      }
      if !nodes.contains(b) {
        nodes.push(b)
      }
    }
    nodes.sort()
    out.push(nodes)
  }
  out
}

///|
/// Whether removing any single node leaves the graph connected.
pub fn[G : @moongraph.Topology] is_biconnected(graph : G) -> Bool {
  if articulation_points(graph).length() > 0 {
    return false
  }
  // A graph with fewer than three nodes is connected but not biconnected in the
  // usual sense: a piece needs at least a cycle.
  @moongraph.Topology::node_count(graph) >= 3
}

///|
/// The nodes whose removal disconnects the graph, ascending.
pub fn[G : @moongraph.Topology] articulation_points(graph : G) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let disc : Array[Int32] = Array::make(n, -1)
  let low : Array[Int32] = Array::make(n, 0)
  let counter = [0]
  let found : Array[Bool] = Array::make(n, false)
  for start in 0..<n {
    if disc[start] >= 0 {
      continue
    }
    disc[start] = counter[0]
    low[start] = counter[0]
    counter[0] = counter[0] + 1
    let frames : Array[(Int32, Int32, Int32)] = [(start, 0, -1)]
    let mut root_children = 0
    while frames.length() > 0 {
      let top = frames.length() - 1
      let (node, at, parent) = frames[top]
      let nbrs = graph.neighbors(node)
      let eids = graph.incident(node)
      if at < eids.length() {
        frames[top] = (node, at + 1, parent)
        let edge = eids[at]
        let nbr = nbrs[at]
        if nbr == parent && !is_self_loop(graph, edge, node, nbr) {
          continue
        }
        if disc[nbr] < 0 {
          disc[nbr] = counter[0]
          low[nbr] = counter[0]
          counter[0] = counter[0] + 1
          if parent < 0 {
            root_children = root_children + 1
          }
          frames.push((nbr, 0, node))
        } else if disc[nbr] < low[node] {
          low[node] = disc[nbr]
        }
      } else {
        frames.pop() |> ignore
        if frames.length() > 0 {
          let above = frames[frames.length() - 1].0
          if low[node] < low[above] {
            low[above] = low[node]
          }
          if low[node] >= disc[above] && frames[frames.length() - 1].2 >= 0 {
            found[above] = true
          }
        }
      }
    }
    if root_children > 1 {
      found[start] = true
    }
  }
  let out : Array[Int32] = []
  for node in 0..<n {
    if found[node] {
      out.push(node)
    }
  }
  out
}

///|
/// Whether an edge joins a node to itself, which a parallel edge makes possible
/// even when the two endpoints also have a second edge between them.
fn[G : @moongraph.Topology] is_self_loop(
  graph : G,
  edge : Int32,
  a : Int32,
  b : Int32,
) -> Bool {
  let (from, to) = graph.endpoints(edge)
  a == b || from == to
}

///|
/// The edges whose removal disconnects the graph, in number order.
pub fn[G : @moongraph.Topology] bridges(graph : G) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let disc : Array[Int32] = Array::make(n, -1)
  let low : Array[Int32] = Array::make(n, 0)
  let counter = [0]
  let found : Array[Int32] = []
  for start in 0..<n {
    if disc[start] >= 0 {
      continue
    }
    disc[start] = counter[0]
    low[start] = counter[0]
    counter[0] = counter[0] + 1
    let frames : Array[(Int32, Int32, Int32)] = [(start, 0, -1)]
    while frames.length() > 0 {
      let top = frames.length() - 1
      let (node, at, parent) = frames[top]
      let nbrs = graph.neighbors(node)
      let eids = graph.incident(node)
      if at < eids.length() {
        frames[top] = (node, at + 1, parent)
        let edge = eids[at]
        let nbr = nbrs[at]
        if edge == parent {
          continue
        }
        if disc[nbr] < 0 {
          disc[nbr] = counter[0]
          low[nbr] = counter[0]
          counter[0] = counter[0] + 1
          frames.push((nbr, 0, edge))
        } else if disc[nbr] < low[node] {
          low[node] = disc[nbr]
        }
      } else {
        frames.pop() |> ignore
        if frames.length() > 0 {
          let above = frames[frames.length() - 1].0
          if low[node] < low[above] {
            low[above] = low[node]
          }
          if low[node] > disc[above] && parent >= 0 {
            found.push(parent)
          }
        }
      }
    }
  }
  found.sort()
  found
}

///|
/// Whether any edge is a bridge.
pub fn[G : @moongraph.Topology] has_bridges(graph : G) -> Bool {
  bridges(graph).length() > 0
}

///|
/// The edges whose endpoints have no route between them short enough to make the
/// edge part of a small cycle.
///
/// `span` is how many edges either side of the edge count as short: with the
/// default of 1 an edge is local when its endpoints share no neighbour, which is
/// the usual definition.
pub fn[G : @moongraph.Topology] local_bridges(
  graph : G,
  span~ : Int32 = 1,
) -> Array[Int32] {
  let out : Array[Int32] = []
  let limit = 2 * span + 1
  let n = @moongraph.Topology::node_count(graph)
  for node in 0..<n {
    let nbrs = graph.neighbors(node)
    let eids = graph.incident(node)
    for at in 0..<eids.length() {
      let edge = eids[at]
      let other = nbrs[at]
      if node > other {
        continue
      }
      if node == other {
        continue
      }
      if !has_short_alternative(graph, node, other, edge, limit) {
        out.push(edge)
      }
    }
  }
  out.sort()
  out
}

///|
/// Whether a route of at most `limit` edges joins the pair without using `edge`.
fn[G : @moongraph.Topology] has_short_alternative(
  graph : G,
  from : Int32,
  to : Int32,
  edge : Int32,
  limit : Int32,
) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  let depth : Array[Int32] = Array::make(n, -1)
  depth[from] = 0
  let queue : Array[Int32] = [from]
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    if depth[node] >= limit {
      continue
    }
    let nbrs = graph.neighbors(node)
    let eids = graph.incident(node)
    for at in 0..<eids.length() {
      if eids[at] == edge {
        continue
      }
      let nbr = nbrs[at]
      if nbr == to {
        return true
      }
      if depth[nbr] < 0 {
        depth[nbr] = depth[node] + 1
        queue.push(nbr)
      }
    }
  }
  false
}

///|
/// Splits the graph into chains around a depth-first tree: every back edge with the
/// tree path under it, and every bridge on its own.
///
/// Each chain is a node sequence; the pieces are disjoint in their edges, which is
/// what makes them useful for path decomposition. Chains come in the order their
/// first node is finished.
pub fn[G : @moongraph.Topology] chain_decomposition(
  graph : G,
) -> Array[Array[Int32]] {
  let n = @moongraph.Topology::node_count(graph)
  let disc : Array[Int32] = Array::make(n, -1)
  let parent : Array[Int32] = Array::make(n, -1)
  let parent_edge : Array[Int32] = Array::make(n, -1)
  let counter = [0]
  let chains : Array[Array[Int32]] = []
  for start in 0..<n {
    if disc[start] >= 0 {
      continue
    }
    disc[start] = counter[0]
    counter[0] = counter[0] + 1
    let frames : Array[(Int32, Int32)] = [(start, 0)]
    while frames.length() > 0 {
      let top = frames.length() - 1
      let (node, at) = frames[top]
      let nbrs = graph.neighbors(node)
      let eids = graph.incident(node)
      if at < eids.length() {
        frames[top] = (node, at + 1)
        let edge = eids[at]
        let nbr = nbrs[at]
        if edge == parent_edge[node] || nbr == parent[node] {
          continue
        }
        if disc[nbr] < 0 {
          parent[nbr] = node
          parent_edge[nbr] = edge
          disc[nbr] = counter[0]
          counter[0] = counter[0] + 1
          frames.push((nbr, 0))
        } else if disc[nbr] < disc[node] {
          // A back edge closes a chain from the ancestor down to here.
          let chain : Array[Int32] = [node]
          let mut step = node
          while step != nbr {
            step = parent[step]
            chain.push(step)
          }
          chains.push(chain)
        }
      } else {
        frames.pop() |> ignore
      }
    }
  }
  // Whatever tree edge no chain used is a bridge, and a bridge is a chain of two.
  let used : Array[Bool] = Array::make(graph.edge_count(), false)
  for chain in chains {
    for i in 1..<chain.length() {
      match first_edge_between(graph, chain[i - 1], chain[i]) {
        Some(edge) => used[edge] = true
        None => ()
      }
    }
  }
  for edge in bridges(graph) {
    if !used[edge] {
      let (a, b) = graph.endpoints(edge)
      chains.push([a, b])
    }
  }
  chains
}

///|
/// One edge between two adjacent nodes, the lowest-numbered one.
fn[G : @moongraph.Topology] first_edge_between(
  graph : G,
  from : Int32,
  to : Int32,
) -> Int32? {
  let nbrs = graph.neighbors(from)
  let eids = graph.incident(from)
  for at in 0..<eids.length() {
    if nbrs[at] == to {
      return Some(eids[at])
    }
  }
  None
}

///|
/// The edges with one endpoint in `set` and one outside it, in number order.
pub fn[G : @moongraph.Topology] edge_boundary(
  graph : G,
  set : Array[Int32],
) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let inside : Array[Bool] = Array::make(n, false)
  for node in set {
    if node >= 0 && node < n {
      inside[node] = true
    }
  }
  let out : Array[Int32] = []
  for node in 0..<n {
    if !inside[node] {
      continue
    }
    let nbrs = graph.neighbors(node)
    let eids = graph.incident(node)
    for at in 0..<eids.length() {
      if !inside[nbrs[at]] && !out.contains(eids[at]) {
        out.push(eids[at])
      }
    }
  }
  out.sort()
  out
}

///|
/// The nodes outside `set` with an edge to it, ascending.
pub fn[G : @moongraph.Topology + @moongraph.Inbound] node_boundary(
  graph : G,
  set : Array[Int32],
) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let inside : Array[Bool] = Array::make(n, false)
  for node in set {
    if node >= 0 && node < n {
      inside[node] = true
    }
  }
  let seen : Array[Bool] = Array::make(n, false)
  let out : Array[Int32] = []
  for node in set {
    if node < 0 || node >= n {
      continue
    }
    for nbr in @moongraph.Topology::neighbors(graph, node) {
      if !inside[nbr] && !seen[nbr] {
        seen[nbr] = true
        out.push(nbr)
      }
    }
    if @moongraph.Topology::directed(graph) {
      for (nbr, _) in @internal.in_edges(graph, node) {
        if !inside[nbr] && !seen[nbr] {
          seen[nbr] = true
          out.push(nbr)
        }
      }
    }
  }
  out.sort()
  out
}

///|
/// How many nodes `node` reaches, itself included.
pub fn[G : @moongraph.Topology] reachable_count(
  graph : G,
  node : Int32,
) -> Int32 {
  let n = @moongraph.Topology::node_count(graph)
  if node < 0 || node >= n {
    return 0
  }
  let seen : Array[Bool] = Array::make(n, false)
  let queue : Array[Int32] = [node]
  seen[node] = true
  let mut head = 0
  while head < queue.length() {
    let at = queue[head]
    head = head + 1
    for nbr in graph.neighbors(at) {
      if !seen[nbr] {
        seen[nbr] = true
        queue.push(nbr)
      }
    }
  }
  queue.length()
}

///|
/// The strongly connected pieces in topological order: every edge runs from a piece at a
/// lower index to one at a higher index, or stays inside a single piece. Each piece lists its
/// node numbers in ascending order.
///
/// This is the shape AtCoder's `SccGraph::scc` returns, and the order is what a caller
/// reading a condensation forward wants; `strong_components` answers the other question, the
/// piece of each node.
pub fn[G : @moongraph.Topology] scc(graph : G) -> Array[Array[Int32]] {
  let pieces = strong_components(graph)
  let groups : Array[Array[Int32]] = []
  for _ in 0..<pieces.count {
    groups.push([])
  }
  for node in 0..<pieces.label.length() {
    groups[pieces.label[node]].push(node)
  }
  // The search closes sinks first, so a piece's label counts down from the sources; read the
  // labels backwards for a source-first order.
  let out : Array[Array[Int32]] = []
  for step in 0..<pieces.count {
    out.push(groups[pieces.count - 1 - step])
  }
  out
}
