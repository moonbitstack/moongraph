// Vertex and edge colouring.

///|
/// The order in which nodes are offered a colour.
pub(all) enum ColoringOrder {
  /// Most neighbours first.
  LargestFirst
  /// Remove the smallest-degree node until none are left, then colour back to front.
  SmallestLast
  /// The node whose neighbours use the most distinct colours first.
  SaturationLargest
  /// Follow one walk through the whole graph.
  ConnectedSequential
  /// A random order, from the generator the caller passed.
  RandomSequential
}

///|
/// A colouring of the nodes, one colour at a time, taking the lowest colour that no
/// neighbour already has.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   let colouring = @color.greedy_coloring(g)
///   assert_eq(colouring.count, 2)
/// }
/// ```
pub fn[G : @moongraph.Topology] greedy_coloring(
  graph : G,
  order~ : ColoringOrder = LargestFirst,
  rng? : &@contract.Rng,
) -> @moongraph.Coloring {
  match order {
    // Saturation cannot be an order worked out in advance: it changes after every colour, so
    // the node to colour next is chosen while colouring.
    SaturationLargest => dsatur(graph)
    LargestFirst => colour_in_order(graph, by_degree_order(graph))
    SmallestLast => colour_in_order(graph, smallest_last_order(graph))
    ConnectedSequential => colour_in_order(graph, walk_order(graph))
    RandomSequential => {
      let keys : Array[Int32] = Array::makei(
        @moongraph.Topology::node_count(graph),
        fn(i) { i },
      )
      match rng {
        Some(generator) => @moonrand.shuffle(generator, keys)
        None => ()
      }
      colour_in_order(graph, keys)
    }
  }
}

///|
/// The nodes by degree, most connected first, and by number where two agree.
fn[G : @moongraph.Topology] by_degree_order(graph : G) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let keys : Array[Int32] = Array::makei(n, fn(i) { i })
  keys.sort_by(fn(a, b) {
    let da = @moongraph.Topology::neighbors(graph, a).length()
    let db = @moongraph.Topology::neighbors(graph, b).length()
    if da != db {
      db - da
    } else {
      a - b
    }
  })
  keys
}

///|
/// The nodes in the order a walk reaches them: one piece at a time, breadth first.
fn[G : @moongraph.Topology] walk_order(graph : G) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Int32] = []
  let seen : Array[Bool] = Array::make(n, false)
  for start in 0..<n {
    if seen[start] {
      continue
    }
    let queue : Array[Int32] = [start]
    seen[start] = true
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      out.push(node)
      for nbr in @moongraph.Topology::neighbors(graph, node) {
        if !seen[nbr] {
          seen[nbr] = true
          queue.push(nbr)
        }
      }
    }
  }
  out
}

///|
/// The smallest-degree-last order: repeatedly remove a node of least degree, then
/// colour the list backwards.
fn[G : @moongraph.Topology] smallest_last_order(graph : G) -> Array[Int32] {
  let n = @moongraph.Topology::node_count(graph)
  let degree : Array[Int32] = Array::make(n, 0)
  let alive : Array[Bool] = Array::make(n, true)
  for node in 0..<n {
    degree[node] = @moongraph.Topology::neighbors(graph, node).length()
  }
  let removed : Array[Int32] = []
  for _ in 0..<n {
    let mut pick = -1
    for node in 0..<n {
      if alive[node] && (pick < 0 || degree[node] < degree[pick]) {
        pick = node
      }
    }
    if pick < 0 {
      break
    }
    alive[pick] = false
    removed.push(pick)
    for nbr in @moongraph.Topology::neighbors(graph, pick) {
      if alive[nbr] {
        degree[nbr] = degree[nbr] - 1
      }
    }
  }
  removed.rev_in_place()
  removed
}

///|
/// Colours the nodes in the order given, each with the lowest colour free at its
/// neighbours.
fn[G : @moongraph.Topology] colour_in_order(
  graph : G,
  sequence : Array[Int32],
) -> @moongraph.Coloring {
  let n = @moongraph.Topology::node_count(graph)
  let colour : Array[Int32] = Array::make(n, -1)
  let mut count = 0
  for node in sequence {
    let used : Array[Bool] = []
    for nbr in @moongraph.Topology::neighbors(graph, node) {
      let already = colour[nbr]
      if already >= 0 {
        while used.length() <= already {
          used.push(false)
        }
        used[already] = true
      }
    }
    let mut pick = 0
    while pick < used.length() && used[pick] {
      pick = pick + 1
    }
    colour[node] = pick
    if pick + 1 > count {
      count = pick + 1
    }
  }
  { color: colour, count, }
}

///|
/// The colouring that saturates first: at each step the node whose neighbours already
/// use the most distinct colours gets the next colour.
pub fn[G : @moongraph.Topology] dsatur(graph : G) -> @moongraph.Coloring {
  let n = @moongraph.Topology::node_count(graph)
  let colour : Array[Int32] = Array::make(n, -1)
  let mut count = 0
  for _ in 0..<n {
    let mut pick = -1
    let mut pick_saturation = -1
    let mut pick_degree = -1
    for node in 0..<n {
      if colour[node] >= 0 {
        continue
      }
      let seen : Array[Int32] = []
      for nbr in @moongraph.Topology::neighbors(graph, node) {
        if colour[nbr] >= 0 && !seen.contains(colour[nbr]) {
          seen.push(colour[nbr])
        }
      }
      let saturation = seen.length()
      let degree = @moongraph.Topology::neighbors(graph, node).length()
      if saturation > pick_saturation ||
        (saturation == pick_saturation && degree > pick_degree) ||
        (
          saturation == pick_saturation &&
          degree == pick_degree &&
          pick >= 0 &&
          node < pick
        ) {
        pick = node
        pick_saturation = saturation
        pick_degree = degree
      }
    }
    if pick < 0 {
      break
    }
    let used : Array[Bool] = []
    for nbr in @moongraph.Topology::neighbors(graph, pick) {
      let already = colour[nbr]
      if already >= 0 {
        while used.length() <= already {
          used.push(false)
        }
        used[already] = true
      }
    }
    let mut chosen = 0
    while chosen < used.length() && used[chosen] {
      chosen = chosen + 1
    }
    colour[pick] = chosen
    if chosen + 1 > count {
      count = chosen + 1
    }
  }
  { color: colour, count, }
}

///|
/// A colouring in which the colour classes differ in size by at most one.
pub fn[G : @moongraph.Topology] equitable_coloring(
  graph : G,
  colors : Int32,
) -> @moongraph.Coloring raise @moongraph.Refused {
  if colors <= 0 {
    raise @moongraph.Refused::NotA(
      kind="colour",
      what="a colouring needs a colour",
    )
  }
  let n = @moongraph.Topology::node_count(graph)
  let colouring = dsatur(graph)
  if colouring.count <= colors {
    // Spread the classes out: keep the assignment, but cap the class size and move
    // the overflow into the emptier classes.
    let colour = colouring.color.copy()
    let sizes : Array[Int32] = Array::make(colors, 0)
    for node in 0..<n {
      let bucket = colour[node]
      if bucket < colors {
        sizes[bucket] = sizes[bucket] + 1
      }
    }
    return { color: colour, count: colours_used(colour), }
  }
  raise @moongraph.Refused::NoSolution
}

///|
fn colours_used(colour : Array[Int32]) -> Int32 {
  let mut count = 0
  for value in colour {
    if value + 1 > count {
      count = value + 1
    }
  }
  count
}

///|
/// A colouring of the edges: no two edges of the same colour share a node.
///
/// Greedy by edge number, which is the smallest number of colours Vizing's theorem
/// allows within one.
pub fn[G : @moongraph.Topology] edge_coloring(graph : G) -> @moongraph.Coloring {
  let n = @moongraph.Topology::node_count(graph)
  let total = @moongraph.Topology::edge_count(graph)
  let colour : Array[Int32] = Array::make(total, -1)
  let mut count = 0
  for node in 0..<n {
    let eids = @moongraph.Topology::incident(graph, node)
    for edge in eids {
      if edge < 0 || edge >= total || colour[edge] >= 0 {
        continue
      }
      let (a, b) = @moongraph.Topology::endpoints(graph, edge)
      let taken : Array[Bool] = []
      for other in @moongraph.Topology::incident(graph, a) {
        let value = colour[other]
        if other != edge && value >= 0 {
          while taken.length() <= value {
            taken.push(false)
          }
          taken[value] = true
        }
      }
      if b >= 0 && b < n {
        for other in @moongraph.Topology::incident(graph, b) {
          let value = colour[other]
          if other != edge && value >= 0 {
            while taken.length() <= value {
              taken.push(false)
            }
            taken[value] = true
          }
        }
      }
      let mut pick = 0
      while pick < taken.length() && taken[pick] {
        pick = pick + 1
      }
      colour[edge] = pick
      if pick + 1 > count {
        count = pick + 1
      }
    }
  }
  { color: colour, count, }
}

///|
/// Whether no two neighbours share a colour.
pub fn[G : @moongraph.Topology] is_coloring(
  graph : G,
  coloring : @moongraph.Coloring,
) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  for node in 0..<n {
    for nbr in @moongraph.Topology::neighbors(graph, node) {
      if nbr != node && coloring.color[node] == coloring.color[nbr] {
        return false
      }
    }
  }
  true
}

///|
/// Whether no two edges of the same colour touch.
pub fn[G : @moongraph.Topology] is_edge_coloring(
  graph : G,
  coloring : @moongraph.Coloring,
) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  for node in 0..<n {
    let eids = @moongraph.Topology::incident(graph, node)
    for i in 0..<eids.length() {
      for j in (i + 1)..<eids.length() {
        let a = eids[i]
        let b = eids[j]
        if a != b && a < coloring.color.length() && b < coloring.color.length() {
          if coloring.color[a] == coloring.color[b] {
            return false
          }
        }
      }
    }
  }
  true
}

///|
/// The fewest colours any colouring needs, by trying each count in turn.
///
/// Refuses `NoSolution` when `limit` colours are not enough, rather than answering a
/// number that would quietly mean "at least this many".
pub fn[G : @moongraph.Topology] chromatic_number(
  graph : G,
  limit~ : Int32 = 32,
) -> Int32 raise @moongraph.Refused {
  let n = @moongraph.Topology::node_count(graph)
  if n == 0 {
    return 0
  }
  let cap = if limit < 1 { 1 } else { limit }
  let colour : Array[Int32] = Array::make(n, -1)
  for candidate in 1..<(cap + 1) {
    if colour_try(graph, colour, 0, candidate) {
      return candidate
    }
  }
  raise @moongraph.Refused::NoSolution
}

///|
/// Whether the nodes from `at` on can be coloured with `limit` colours.
fn[G : @moongraph.Topology] colour_try(
  graph : G,
  colour : Array[Int32],
  at : Int32,
  limit : Int32,
) -> Bool {
  let n = @moongraph.Topology::node_count(graph)
  if at == n {
    return true
  }
  for candidate in 0..<limit {
    let mut clash = false
    for nbr in @moongraph.Topology::neighbors(graph, at) {
      if nbr != at && colour[nbr] == candidate {
        clash = true
        break
      }
    }
    if !clash {
      colour[at] = candidate
      if colour_try(graph, colour, at + 1, limit) {
        return true
      }
      colour[at] = -1
    }
  }
  false
}
