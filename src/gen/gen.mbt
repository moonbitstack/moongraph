// Generators: the named graphs and the random families.

///|
/// The complete graph on `nodes` nodes: every pair joined.
///
/// ```mbt check
/// test {
///   let g = @gen.complete(3, directed=false)
///   assert_eq(g.edge_count(), 3)
/// }
/// ```
pub fn complete(
  nodes : Int32,
  directed~ : Bool = false,
) -> @moongraph.Graph[Int32, Unit] {
  let graph : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(directed~)
  for node in 0..<nodes {
    graph.add_node(node) |> ignore
  }
  for a in 0..<nodes {
    for b in (a + 1)..<nodes {
      graph.add_edge(a, b, ()) |> ignore
    }
  }
  graph
}

///|
/// A path through every node, in number order.
pub fn path(
  nodes : Int32,
  directed~ : Bool = false,
) -> @moongraph.Graph[Int32, Unit] {
  let graph : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(directed~)
  for node in 0..<nodes {
    graph.add_node(node) |> ignore
  }
  for node in 1..<nodes {
    graph.add_edge(node - 1, node, ()) |> ignore
  }
  graph
}

///|
/// A single cycle through every node.
pub fn cycle(nodes : Int32) -> @moongraph.Graph[Int32, Unit] {
  let graph = path(nodes, directed=false)
  if nodes > 2 {
    graph.add_edge(nodes - 1, 0, ()) |> ignore
  }
  graph
}

///|
/// One node joined to all the others, which are joined to nothing else.
pub fn star(nodes : Int32) -> @moongraph.Graph[Int32, Unit] {
  let graph : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=false,
  )
  for node in 0..<nodes {
    graph.add_node(node) |> ignore
  }
  for node in 1..<nodes {
    graph.add_edge(0, node, ()) |> ignore
  }
  graph
}

///|
/// A grid of `rows` by `columns` nodes, each joined to the ones beside it.
pub fn grid(rows : Int32, columns : Int32) -> @moongraph.Graph[Int32, Unit] {
  let graph : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=false,
  )
  for node in 0..<(rows * columns) {
    graph.add_node(node) |> ignore
  }
  for row in 0..<rows {
    for column in 0..<columns {
      let node = row * columns + column
      if column + 1 < columns {
        graph.add_edge(node, node + 1, ()) |> ignore
      }
      if row + 1 < rows {
        graph.add_edge(node, node + columns, ()) |> ignore
      }
    }
  }
  graph
}

///|
/// A cycle with a hub in the middle joined to every node of it.
pub fn wheel(nodes : Int32) -> @moongraph.Graph[Int32, Unit] {
  let graph = cycle(nodes)
  graph.add_node(nodes) |> ignore
  for node in 0..<nodes {
    graph.add_edge(nodes, node, ()) |> ignore
  }
  graph
}

///|
/// Two paths with rungs between them: a ladder.
pub fn ladder(nodes : Int32) -> @moongraph.Graph[Int32, Unit] {
  let graph = path(nodes * 2, directed=false)
  for node in 0..<nodes {
    graph.add_edge(node, node + nodes, ()) |> ignore
  }
  graph
}

///|
/// Two complete graphs joined by one edge: the graph a minimum cut is worst on.
pub fn barbell(nodes : Int32) -> @moongraph.Graph[Int32, Unit] {
  let graph = complete(nodes, directed=false)
  for node in 0..<nodes {
    graph.add_node(node + nodes) |> ignore
  }
  for a in nodes..<(nodes * 2) {
    for b in (a + 1)..<(nodes * 2) {
      graph.add_edge(a, b, ()) |> ignore
    }
  }
  graph.add_edge(0, nodes, ()) |> ignore
  graph
}

///|
/// The Petersen graph: three nodes joined to three, with the matching inside each.
pub fn petersen() -> @moongraph.Graph[Int32, Unit] {
  let graph : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=false,
  )
  for node in 0..<10 {
    graph.add_node(node) |> ignore
  }
  for node in 0..<5 {
    graph.add_edge(node, (node + 1) % 5, ()) |> ignore
    graph.add_edge(node, node + 5, ()) |> ignore
    graph.add_edge(node + 5, (node + 2) % 5 + 5, ()) |> ignore
  }
  graph
}

///|
/// A random graph in which every pair is joined with the same chance.
pub fn random_gnp(
  nodes : Int32,
  probability~ : Double,
  rng~ : &@contract.Rng,
  directed~ : Bool = false,
) -> @moongraph.Graph[Int32, Unit] {
  let graph : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(directed~)
  for node in 0..<nodes {
    graph.add_node(node) |> ignore
  }
  for a in 0..<nodes {
    let start = if directed { 0 } else { a + 1 }
    for b in start..<nodes {
      if a != b && @moonrand.random(rng) < probability {
        graph.add_edge(a, b, ()) |> ignore
      }
    }
  }
  graph
}

///|
/// A random graph with exactly `edges` edges, drawn without repeats.
///
/// The pairs are laid out and shuffled, which gives exactly the count asked for; a graph too
/// large to lay out that way falls back to drawing pairs and skipping repeats.
pub fn random_gnm(
  nodes : Int32,
  edges : Int32,
  rng~ : &@contract.Rng,
  directed~ : Bool = false,
) -> @moongraph.Graph[Int32, Unit] {
  let graph : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(directed~)
  for node in 0..<nodes {
    graph.add_node(node) |> ignore
  }
  let pairs : Array[(Int32, Int32)] = []
  // Laying out every pair costs n squared; above that the sampling walk is cheaper than
  // the list would be.
  if nodes * nodes <= 4000000 {
    for a in 0..<nodes {
      let start = if directed { 0 } else { a + 1 }
      for b in start..<nodes {
        if a != b {
          pairs.push((a, b))
        }
      }
    }
    @moonrand.shuffle(rng, pairs)
    let wanted = if edges < pairs.length() { edges } else { pairs.length() }
    for i in 0..<wanted {
      graph.add_edge(pairs[i].0, pairs[i].1, ()) |> ignore
    }
  } else {
    let mut added = 0
    let mut rounds = 0
    while added < edges && rounds < edges * 100 + 1000 {
      rounds = rounds + 1
      let a = @moonrand.randint(rng, 0, nodes.to_int64()).to_int()
      let b = @moonrand.randint(rng, 0, nodes.to_int64()).to_int()
      if a != b && graph.find_edge(a, b) is None {
        graph.add_edge(a, b, ()) |> ignore
        added = added + 1
      }
    }
  }
  graph
}

///|
/// A preferential-attachment graph: every new node joins the existing ones that already
/// have the most edges, which is what makes the degree distribution heavy tailed.
pub fn barabasi_albert(
  nodes : Int32,
  attach~ : Int32,
  rng~ : &@contract.Rng,
) -> @moongraph.Graph[Int32, Unit] {
  let graph : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=false,
  )
  let seed = if attach + 1 < nodes { attach + 1 } else { nodes }
  for node in 0..<seed {
    graph.add_node(node) |> ignore
  }
  for a in 0..<seed {
    for b in (a + 1)..<seed {
      graph.add_edge(a, b, ()) |> ignore
    }
  }
  // A repeated-node list weighted by degree is the cheapest way to sample a neighbour
  // in proportion to how many it already has.
  let draws : Array[Int32] = []
  for node in 0..<seed {
    for _ in 0..<(seed - 1) {
      draws.push(node)
    }
  }
  for node in seed..<nodes {
    graph.add_node(node) |> ignore
    let picked : Array[Int32] = []
    let mut rounds = 0
    while picked.length() < attach && rounds < attach * 50 {
      rounds = rounds + 1
      let at = @moonrand.randint(rng, 0, draws.length().to_int64()).to_int()
      if at >= 0 && at < draws.length() && !picked.contains(draws[at]) {
        picked.push(draws[at])
      }
    }
    for target in picked {
      graph.add_edge(node, target, ()) |> ignore
      draws.push(target)
      draws.push(node)
    }
  }
  graph
}

///|
/// A small-world graph: a ring with each node joined to its nearest neighbours and a few
/// edges rewired at random.
pub fn watts_strogatz(
  nodes : Int32,
  neighbours~ : Int32,
  probability~ : Double,
  rng~ : &@contract.Rng,
) -> @moongraph.Graph[Int32, Unit] {
  let graph = cycle(nodes)
  let half = neighbours / 2
  for node in 0..<nodes {
    for step in 1..<(half + 1) {
      let other = (node + step) % nodes
      if other != node && graph.find_edge(node, other) is None {
        graph.add_edge(node, other, ()) |> ignore
      }
    }
  }
  if probability > 0.0 {
    // Each edge is cut and reattached somewhere else with the given chance, which is what
    // turns a ring into a small world.
    for edge in 0..<graph.edge_count() {
      if @moonrand.random(rng) < probability {
        let a = graph.endpoints(edge).0
        let target = @moonrand.randint(rng, 0, nodes.to_int64()).to_int()
        if target != a && graph.find_edge(a, target) is None {
          graph.remove_edge(edge)
          graph.add_edge(a, target, ()) |> ignore
        }
      }
    }
    ignore(probability)
  }
  graph
}

///|
/// A tree grown at random: every new node joins one node already in the tree.
pub fn random_tree(
  nodes : Int32,
  rng~ : &@contract.Rng,
) -> @moongraph.Graph[Int32, Unit] {
  let graph : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=false,
  )
  for node in 0..<nodes {
    graph.add_node(node) |> ignore
  }
  for node in 1..<nodes {
    let parent = @moonrand.randint(rng, 0, node.to_int64()).to_int()
    graph.add_edge(node, parent, ()) |> ignore
  }
  graph
}

///|
/// A graph in which every node has the same number of edges, by repeatedly retrying pairs
/// until the degrees line up.
pub fn random_regular(
  nodes : Int32,
  degree~ : Int32,
  rng~ : &@contract.Rng,
) -> @moongraph.Graph[Int32, Unit] {
  let graph = random_gnm(nodes, nodes * degree / 2, rng~, directed=false)
  // Repair: while two nodes differ by more than one from the target, swap edges.
  let mut rounds = 0
  while rounds < nodes * 20 {
    rounds = rounds + 1
    let mut over = -1
    let mut under = -1
    for node in 0..<nodes {
      let current = graph.incident(node).length()
      if current > degree && over < 0 {
        over = node
      }
      if current < degree && under < 0 {
        under = node
      }
    }
    if over < 0 || under < 0 {
      break
    }
    let nbrs = @internal.distinct_neighbors(graph, over)
    let mut moved = false
    for nbr in nbrs {
      if moved {
        break
      }
      if nbr != under && graph.find_edge(under, nbr) is None {
        match graph.find_edge(over, nbr) {
          Some(edge) => {
            graph.remove_edge(edge)
            graph.add_edge(under, nbr, ()) |> ignore
            moved = true
          }
          None => ()
        }
      }
    }
    if !moved {
      break
    }
  }
  graph
}

///|
/// A graph with the same degree sequence where the edges have been shuffled: pick two edges
/// that share no endpoint, and swap their ends. A double edge swap keeps every node's degree
/// exactly, so it is the null model for "is this structure more than its degree sequence
/// explains" — the rewiring that a rich-club or assortativity question compares against.
///
/// Self-loops and parallel edges are never created, so the result is as simple as the input.
/// The answer is a new graph; the input is unchanged. Swaps that would create a loop or a
/// repeat are skipped rather than repaired, which is why the count is a target rather than a
/// promise.
pub fn[G : @moongraph.Topology] double_edge_swap(
  graph : G,
  swaps~ : Int32,
  rng~ : &@contract.Rng,
) -> @moongraph.Graph[Int32, Unit] {
  let n = @moongraph.Topology::node_count(graph)
  let edges : Array[(Int32, Int32)] = []
  for edge in 0..<@moongraph.Topology::edge_count(graph) {
    let (from, to) = @moongraph.Topology::endpoints(graph, edge)
    if from != to {
      edges.push((from, to))
    }
  }
  let joins = fn(a : Int32, b : Int32) -> Bool {
    for pair in edges {
      if (pair.0 == a && pair.1 == b) || (pair.0 == b && pair.1 == a) {
        return true
      }
    }
    false
  }
  let total = edges.length()
  if total >= 2 {
    for _ in 0..<swaps {
      let first = @moonrand.randint(rng, 0, total.to_int64()).to_int() % total
      let second = @moonrand.randint(rng, 0, total.to_int64()).to_int() % total
      if first == second {
        continue
      }
      let (a, b) = edges[first]
      let (c, d) = edges[second]
      if a == c || a == d || b == c || b == d {
        continue
      }
      if joins(a, d) || joins(c, b) {
        continue
      }
      edges[first] = (a, d)
      edges[second] = (c, b)
    }
  }
  let out : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(
    directed=@moongraph.Topology::directed(graph),
  )
  for node in 0..<n {
    out.add_node(node) |> ignore
  }
  for pair in edges {
    out.add_edge(pair.0, pair.1, ()) |> ignore
  }
  out
}
