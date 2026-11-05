// Breadth-first and depth-first walks over any graph that implements
// `@moongraph.Topology`.
//
// Two rules run through the whole package. A walk visits the edges of a node in
// ascending neighbour number, then ascending edge number, so two walks over the
// same edges agree. And a walk from a node that is not there is a no-op rather
// than an error: there is nothing contradictory about asking.

///|
/// The order a breadth-first walk discovers nodes, ordered by distance from the
/// source and then by node number.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (0, 2)],
///     node=(),
///     edge=(),
///   )
///   assert_eq(@traverse.bfs(g, 0), [0, 1, 2])
/// }
/// ```
pub fn[G : @moongraph.Topology] bfs(graph : G, source : Int) -> Array[Int] {
  let paths = bfs_tree(graph, source)
  let out : Array[Int] = []
  let n = graph.node_count()
  let mut deepest = 0
  let mut seen = false
  for node in 0..<n {
    match paths.distance[node] {
      Some(d) => {
        seen = true
        let step = d.to_int()
        if step > deepest {
          deepest = step
        }
      }
      None => ()
    }
  }
  if !seen {
    return out
  }
  let counts = Array::make(deepest + 1, 0)
  for node in 0..<n {
    if paths.distance[node] is Some(d) {
      let step = d.to_int()
      counts[step] = counts[step] + 1
    }
  }
  let offset = Array::make(deepest + 2, 0)
  for step in 0..<(deepest + 1) {
    offset[step + 1] = offset[step] + counts[step]
  }
  let placed : Array[Int] = Array::make(n, 0)
  for node in 0..<n {
    if paths.distance[node] is Some(d) {
      let step = d.to_int()
      placed[offset[step]] = node
      offset[step] = offset[step] + 1
    }
  }
  let total = counts.fold(init=0, fn(acc, c) { acc + c })
  for at in 0..<total {
    out.push(placed[at])
  }
  out
}

///|
/// Distances and parents from a breadth-first walk.
///
/// The parent of a node is the smallest-numbered node one step closer to the
/// source, not whichever edge happened to be scanned first, so two runs over the
/// same edges produce the same forest.
pub fn[G : @moongraph.Topology] bfs_tree(graph : G, source : Int) -> @moongraph.Paths {
  let n = graph.node_count()
  let distance : Array[Double?] = Array::make(n, (None : Double?))
  let previous : Array[Int?] = Array::make(n, (None : Int?))
  if source < 0 || source >= n {
    return @moongraph.Paths::{ distance, previous }
  }
  let depth : Array[Int] = Array::make(n, -1)
  let queue : Array[Int] = [source]
  depth[source] = 0
  distance[source] = Some(0.0)
  let mut head = 0
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    for nbr in graph.neighbors(node) {
      if depth[nbr] < 0 {
        depth[nbr] = depth[node] + 1
        distance[nbr] = Some(depth[nbr].to_double())
        previous[nbr] = Some(node)
        queue.push(nbr)
      }
    }
  }
  // The smallest parent, not the first one seen.
  for node in 0..<n {
    if depth[node] > 0 {
      for nbr in graph.neighbors(node) {
        if depth[nbr] == depth[node] - 1 {
          match previous[node] {
            Some(best) =>
              if nbr < best {
                previous[node] = Some(nbr)
              }
            None => previous[node] = Some(nbr)
          }
        }
      }
    }
  }
  @moongraph.Paths::{ distance, previous }
}

///|
/// The tree edges of a breadth-first walk, as `(parent, child)`, in discovery
/// order.
pub fn[G : @moongraph.Topology] bfs_edges(graph : G, source : Int) -> Iter[(Int, Int)] {
  let paths = bfs_tree(graph, source)
  let out : Array[(Int, Int)] = []
  for node in bfs(graph, source) {
    match paths.previous[node] {
      Some(parent) => out.push((parent, node))
      None => ()
    }
  }
  out.iter()
}

///|
/// The nodes at each distance from a set of sources, layer by layer, each layer
/// ascending.
pub fn[G : @moongraph.Topology] bfs_layers(graph : G, sources : Array[Int]) -> Array[Array[Int]] {
  let n = graph.node_count()
  let depth : Array[Int] = Array::make(n, -1)
  let mut layer : Array[Int] = []
  for source in sources {
    if source >= 0 && source < n && depth[source] < 0 {
      depth[source] = 0
      layer.push(source)
    }
  }
  layer.sort()
  let out : Array[Array[Int]] = []
  while layer.length() > 0 {
    out.push(layer.copy())
    let next : Array[Int] = []
    for node in layer {
      for nbr in graph.neighbors(node) {
        if depth[nbr] < 0 {
          depth[nbr] = depth[node] + 1
          next.push(nbr)
        }
      }
    }
    next.sort()
    layer = next
  }
  out
}

///
/// A beam walk: the same layer expansion as `bfs_layers`, but each layer keeps
/// only its `width` lowest-numbered nodes, which is how a search stays inside a
/// budget when the frontier explodes.
pub fn[G : @moongraph.Topology] bfs_beam(
  graph : G,
  source : Int,
  width~ : Int = 8,
) -> Array[Int] {
  let n = graph.node_count()
  let out : Array[Int] = []
  if source < 0 || source >= n {
    return out
  }
  let seen : Array[Bool] = Array::make(n, false)
  let limit = if width > 0 { width } else { 1 }
  let mut layer : Array[Int] = [source]
  seen[source] = true
  while layer.length() > 0 {
    layer.sort()
    let kept = if layer.length() > limit { layer.exact_view(start=0, end=limit) } else { layer[:] }
    for node in kept {
      out.push(node)
    }
    let next : Array[Int] = []
    for node in kept {
      for nbr in graph.neighbors(node) {
        if !seen[nbr] {
          seen[nbr] = true
          next.push(nbr)
        }
      }
    }
    layer = next
  }
  out
}

///|
/// The preorder of a depth-first walk: a node is listed when the walk reaches it,
/// and its edges are visited in ascending neighbour number.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (0, 2), (1, 3)],
///     node=(),
///     edge=(),
///   )
///   assert_eq(@traverse.dfs(g, 0), [0, 1, 3, 2])
/// }
/// ```
pub fn[G : @moongraph.Topology] dfs(graph : G, source : Int) -> Array[Int] {
  let out : Array[Int] = []
  let n = graph.node_count()
  if source < 0 || source >= n {
    return out
  }
  let seen : Array[Bool] = Array::make(n, false)
  let stack : Array[(Int, Int)] = [(source, 0)]
  seen[source] = true
  out.push(source)
  while stack.length() > 0 {
    let top = stack.length() - 1
    let (node, at) = stack[top]
    let edges = @internal.out_edges(graph, node)
    if at < edges.length() {
      stack[top] = (node, at + 1)
      let nbr = edges[at].0
      if !seen[nbr] {
        seen[nbr] = true
        out.push(nbr)
        stack.push((nbr, 0))
      }
    } else {
      stack.pop() |> ignore
    }
  }
  out
}

///|
/// The postorder of the same walk: a node is listed after all of its descendants.
pub fn[G : @moongraph.Topology] dfs_postorder(graph : G, source : Int) -> Array[Int] {
  let out : Array[Int] = []
  let n = graph.node_count()
  if source < 0 || source >= n {
    return out
  }
  let seen : Array[Bool] = Array::make(n, false)
  let stack : Array[(Int, Int)] = [(source, 0)]
  seen[source] = true
  while stack.length() > 0 {
    let top = stack.length() - 1
    let (node, at) = stack[top]
    let edges = @internal.out_edges(graph, node)
    if at < edges.length() {
      stack[top] = (node, at + 1)
      let nbr = edges[at].0
      if !seen[nbr] {
        seen[nbr] = true
        stack.push((nbr, 0))
      }
    } else {
      out.push(node)
      stack.pop() |> ignore
    }
  }
  out
}

///|
/// The depth-first forest from one source, as distances (how many edges deep) and
/// parents.
pub fn[G : @moongraph.Topology] dfs_tree(graph : G, source : Int) -> @moongraph.Paths {
  let n = graph.node_count()
  let distance : Array[Double?] = Array::make(n, (None : Double?))
  let previous : Array[Int?] = Array::make(n, (None : Int?))
  if source < 0 || source >= n {
    return @moongraph.Paths::{ distance, previous }
  }
  let depth : Array[Int] = Array::make(n, -1)
  let seen : Array[Bool] = Array::make(n, false)
  let stack : Array[(Int, Int)] = [(source, 0)]
  seen[source] = true
  depth[source] = 0
  distance[source] = Some(0.0)
  while stack.length() > 0 {
    let top = stack.length() - 1
    let (node, at) = stack[top]
    let edges = @internal.out_edges(graph, node)
    if at < edges.length() {
      stack[top] = (node, at + 1)
      let nbr = edges[at].0
      if !seen[nbr] {
        seen[nbr] = true
        depth[nbr] = depth[node] + 1
        distance[nbr] = Some(depth[nbr].to_double())
        previous[nbr] = Some(node)
        stack.push((nbr, 0))
      }
    } else {
      stack.pop() |> ignore
    }
  }
  @moongraph.Paths::{ distance, previous }
}

///|
/// Every edge a depth-first walk looks at, as `(from, to, kind)`.
///
/// `kind` is 0 for a tree edge (the one that discovered `to`), 1 for an edge to a
/// node that is already finished, and 2 for an edge back to a node still on the
/// walk's stack.
pub fn[G : @moongraph.Topology] dfs_labeled(graph : G, source : Int) -> Array[(Int, Int, Int)] {
  let out : Array[(Int, Int, Int)] = []
  let n = graph.node_count()
  if source < 0 || source >= n {
    return out
  }
  // 0 white, 1 on the stack, 2 finished
  let state : Array[Int] = Array::make(n, 0)
  let stack : Array[(Int, Int)] = [(source, 0)]
  state[source] = 1
  while stack.length() > 0 {
    let top = stack.length() - 1
    let (node, at) = stack[top]
    let edges = @internal.out_edges(graph, node)
    if at < edges.length() {
      stack[top] = (node, at + 1)
      let (nbr, _) = edges[at]
      if state[nbr] == 0 {
        state[nbr] = 1
        out.push((node, nbr, 0))
        stack.push((nbr, 0))
      } else if state[nbr] == 1 {
        out.push((node, nbr, 2))
      } else {
        out.push((node, nbr, 1))
      }
    } else {
      state[node] = 2
      stack.pop() |> ignore
    }
  }
  out
}

///|
/// The moments of a depth-first walk, in order.
///
/// A walk that wants to do something on the way in and on the way out reads
/// `Enter` and `Leave`; a walk that wants cycle detection reads `Back`. This is
/// the visitor pattern without the class hierarchy: a loop over the events, and
/// stopping is leaving the loop.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1)],
///     node=(),
///     edge=(),
///   )
///   let events = @traverse.dfs_events(g, 0).collect()
///   assert_eq(events.length(), 4)
/// }
/// ```
pub fn[G : @moongraph.Topology] dfs_events(graph : G, source : Int) -> Iter[Event] {
  let out : Array[Event] = []
  let n = graph.node_count()
  if source < 0 || source >= n {
    return out.iter()
  }
  let state : Array[Int] = Array::make(n, 0)
  let stack : Array[(Int, Int)] = [(source, 0)]
  state[source] = 1
  out.push(Enter(node=source))
  while stack.length() > 0 {
    let top = stack.length() - 1
    let (node, at) = stack[top]
    let edges = @internal.out_edges(graph, node)
    if at < edges.length() {
      stack[top] = (node, at + 1)
      let (nbr, eid) = edges[at]
      if state[nbr] == 0 {
        state[nbr] = 1
        out.push(Enter(node=nbr))
        stack.push((nbr, 0))
      } else if state[nbr] == 1 {
        out.push(Back(edge=eid, to=nbr))
      } else {
        out.push(Forward(edge=eid, to=nbr))
      }
    } else {
      state[node] = 2
      out.push(Leave(node=node))
      stack.pop() |> ignore
    }
  }
  out.iter()
}

///|
/// The tree edges of a breadth-first walk that covers every component, as
/// `(from, to)`. Each component is entered at its lowest-numbered node.
pub fn[G : @moongraph.Topology] edge_bfs(graph : G, source : Int) -> Iter[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  let n = graph.node_count()
  let seen : Array[Bool] = Array::make(n, false)
  let order : Array[Int] = []
  if source >= 0 && source < n {
    order.push(source)
  }
  for node in 0..<n {
    order.push(node)
  }
  for start in order {
    if !seen[start] {
      seen[start] = true
      let queue : Array[Int] = [start]
      let mut head = 0
      while head < queue.length() {
        let node = queue[head]
        head = head + 1
        for nbr in graph.neighbors(node) {
          if !seen[nbr] {
            seen[nbr] = true
            out.push((node, nbr))
            queue.push(nbr)
          }
        }
      }
    }
  }
  out.iter()
}

///|
/// The tree edges of a depth-first walk that covers every component.
pub fn[G : @moongraph.Topology] edge_dfs(graph : G, source : Int) -> Iter[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  let n = graph.node_count()
  let seen : Array[Bool] = Array::make(n, false)
  let order : Array[Int] = []
  if source >= 0 && source < n {
    order.push(source)
  }
  for node in 0..<n {
    order.push(node)
  }
  for start in order {
    if !seen[start] {
      seen[start] = true
      let stack : Array[(Int, Int)] = [(start, 0)]
      while stack.length() > 0 {
        let top = stack.length() - 1
        let (node, at) = stack[top]
        let edges = @internal.out_edges(graph, node)
        if at < edges.length() {
          stack[top] = (node, at + 1)
          let nbr = edges[at].0
          if !seen[nbr] {
            seen[nbr] = true
            out.push((node, nbr))
            stack.push((nbr, 0))
          }
        } else {
          stack.pop() |> ignore
        }
      }
    }
  }
  out.iter()
}

///|
/// The nodes exactly `distance` edges from `source`, ascending. A distance of 0
/// is the source itself, and a negative distance is nothing.
pub fn[G : @moongraph.Topology] descendants_at(
  graph : G,
  source : Int,
  distance : Int,
) -> Array[Int] {
  let out : Array[Int] = []
  if distance < 0 {
    return out
  }
  let paths = bfs_tree(graph, source)
  for node in 0..<graph.node_count() {
    if paths.distance[node] is Some(d) {
      if d.to_int() == distance {
        out.push(node)
      }
    }
  }
  out
}

///|
/// A moment in a depth-first walk.
#derive(Eq, @debug.Debug)
pub(all) enum Event {
  /// The walk reached the node for the first time.
  Enter(node~ : Int)
  /// The walk finished the node: every edge out of it has been looked at.
  Leave(node~ : Int)
  /// The walk looked at an edge to a node that is already finished.
  Forward(edge~ : Int, to~ : Int)
  /// The walk looked at an edge back to a node still on its stack, which is
  /// what a cycle in a directed graph looks like from inside.
  Back(edge~ : Int, to~ : Int)
}

///|
pub extend Event with Eq::{ equal, not_equal }

///|
pub extend Event with @debug.Debug::{ to_repr }
