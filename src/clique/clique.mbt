// Cliques, independent sets, and the orderings that make them tractable.

///|
/// Every maximal clique, each one sorted and reported once.
///
/// Bron-Kerbosch with a pivot: the walk only branches where it must, which is what
/// keeps it usable on graphs that are dense but not complete.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1), (1, 2), (2, 0), (2, 3)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   let cliques = @clique.maximal_cliques(g)
///   assert_eq(cliques.members, [[0, 1, 2], [2, 3]])
/// }
/// ```
pub fn[G : @moongraph.Topology] maximal_cliques(graph : G) -> @moongraph.Cliques {
  let n = @moongraph.Topology::node_count(graph)
  let adjacency : Array[Array[Int]] = Array::makei(n, fn(i) {
    let row = @internal.distinct_neighbors(graph, i)
    let out : Array[Int] = []
    for node in row {
      if node != i {
        out.push(node)
      }
    }
    out
  })
  let members : Array[Array[Int]] = []
  let current : Array[Int] = []
  let candidates : Array[Int] = Array::makei(n, fn(i) { i })
  bron_kerbosch(adjacency, current, candidates, [], members)
  members.sort_by(fn(a, b) {
    if a.length() != b.length() {
      b.length() - a.length()
    } else if a.length() == 0 || b.length() == 0 {
      0
    } else {
      a[0] - b[0]
    }
  })
  { members, }
}

///|
/// The recursive walk with a pivot: every clique grown from the current one, skipping
/// the branches that a pivot already covers.
fn bron_kerbosch(
  adjacency : Array[Array[Int]],
  current : Array[Int],
  candidates : Array[Int],
  excluded : Array[Int],
  out : Array[Array[Int]],
) -> Unit {
  if candidates.length() == 0 && excluded.length() == 0 {
    let clique = current.copy()
    clique.sort()
    if !out.contains(clique) {
      out.push(clique)
    }
    return
  }
  // The pivot is the candidate with the most neighbours among the candidates.
  let mut pivot = -1
  let mut pivot_reach = -1
  for node in candidates {
    let mut reach = 0
    for other in candidates {
      if adjacency[node].contains(other) {
        reach = reach + 1
      }
    }
    if reach > pivot_reach {
      pivot = node
      pivot_reach = reach
    }
  }
  let branch : Array[Int] = []
  for node in candidates {
    if pivot >= 0 && node != pivot && adjacency[pivot].contains(node) {
      continue
    }
    branch.push(node)
  }
  for node in branch {
    let next_candidates : Array[Int] = []
    for other in candidates {
      if other != node && adjacency[node].contains(other) {
        next_candidates.push(other)
      }
    }
    let next_excluded : Array[Int] = []
    for other in excluded {
      if adjacency[node].contains(other) {
        next_excluded.push(other)
      }
    }
    current.push(node)
    bron_kerbosch(adjacency, current, next_candidates, next_excluded, out)
    current.pop() |> ignore
  }
}

///|
/// Every clique of at least `at_least` nodes.
///
/// The count grows exponentially, so the whole list is built before the first clique is
/// handed out; `at_least` is what keeps the list short.
pub fn[G : @moongraph.Topology] all_cliques(
  graph : G,
  at_least~ : Int = 3,
) -> @moongraph.Cliques {
  let floor = if at_least < 1 { 1 } else { at_least }
  let members : Array[Array[Int]] = []
  for clique in maximal_cliques(graph).members {
    if clique.length() >= floor {
      members.push(clique)
      // Every subset of a maximal clique is a clique too.
      if clique.length() > floor {
        for size in floor..<clique.length() {
          for subset in subsets_of(clique, size) {
            if !members.contains(subset) {
              members.push(subset)
            }
          }
        }
      }
    }
  }
  members.sort_by(fn(a, b) {
    if a.length() != b.length() {
      b.length() - a.length()
    } else if a.length() == 0 || b.length() == 0 {
      0
    } else {
      a[0] - b[0]
    }
  })
  { members, }
}

///|
/// The subsets of the given size, in lexicographic order.
fn subsets_of(nodes : Array[Int], size : Int) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = []
  if size <= 0 || size > nodes.length() {
    return out
  }
  let index : Array[Int] = Array::makei(size, fn(i) { i })
  while true {
    let pick : Array[Int] = []
    for i in index {
      pick.push(nodes[i])
    }
    out.push(pick)
    let mut at = size - 1
    while at >= 0 && index[at] == nodes.length() - size + at {
      at = at - 1
    }
    if at < 0 {
      break
    }
    index[at] = index[at] + 1
    for i in (at + 1)..<size {
      index[i] = index[i - 1] + 1
    }
  }
  out
}

///|
/// The clique with the largest total weight, where a node's weight is its payload.
pub fn[G : @moongraph.Topology] max_weight_clique(
  graph : G,
  weight~ : (Int) -> Double,
) -> @moongraph.Cliques {
  let mut best : Array[Int] = []
  let mut best_weight = 0.0
  for clique in maximal_cliques(graph).members {
    let mut total = 0.0
    for node in clique {
      total = total + weight(node)
    }
    if best.length() == 0 || total > best_weight {
      best = clique
      best_weight = total
    }
  }
  { members: if best.length() == 0 { [] } else { [best] } }
}

///|
/// The size of the largest clique.
pub fn[G : @moongraph.Topology] clique_number(graph : G) -> Int {
  let cliques = maximal_cliques(graph)
  let mut best = 0
  for clique in cliques.members {
    if clique.length() > best {
      best = clique.length()
    }
  }
  best
}

///|
/// The size of the largest clique each node belongs to.
pub fn[G : @moongraph.Topology] clique_numbers(graph : G) -> Array[Int] {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Int] = Array::make(n, 1)
  for clique in maximal_cliques(graph).members {
    for node in clique {
      if clique.length() > out[node] {
        out[node] = clique.length()
      }
    }
  }
  out
}

///|
/// Whether every pair of the given nodes is joined, so that they form a clique.
pub fn[G : @moongraph.Topology] is_clique(graph : G, nodes : Array[Int]) -> Bool {
  for i in 0..<nodes.length() {
    for j in (i + 1)..<nodes.length() {
      if !@internal.adjacent(graph, nodes[i], nodes[j]) &&
        !@internal.adjacent(graph, nodes[j], nodes[i]) {
        return false
      }
    }
  }
  true
}

///|
/// A largest set of nodes no two of which are joined.
///
/// Found as a largest clique of the complement, which is the same problem turned
/// around; the complement is built once, so a caller with many queries pays for it once.
pub fn[G : @moongraph.Topology] maximum_independent_set(graph : G) -> Array[Int] {
  let n = @moongraph.Topology::node_count(graph)
  let complement : @moongraph.Graph[Int, Unit] = @moongraph.Graph::new(directed=false)
  for node in 0..<n {
    complement.add_node(node) |> ignore
  }
  for a in 0..<n {
    for b in (a + 1)..<n {
      if !@internal.adjacent(graph, a, b) && !@internal.adjacent(graph, b, a) {
        complement.add_edge(a, b, ()) |> ignore
      }
    }
  }
  let cliques = maximal_cliques(complement)
  let mut best : Array[Int] = []
  for clique in cliques.members {
    if clique.length() > best.length() {
      best = clique
    }
  }
  best
}

///|
/// The size of the largest independent set.
pub fn[G : @moongraph.Topology] independence_number(graph : G) -> Int {
  maximum_independent_set(graph).length()
}

///|
/// The graph whose nodes are the maximal cliques, joined when those cliques share a node.
pub fn[G : @moongraph.Topology] clique_graph(graph : G) -> @moongraph.Graph[Int, Unit] {
  ignore(graph)
  let cliques = maximal_cliques(graph)
  let out : @moongraph.Graph[Int, Unit] = @moongraph.Graph::new(directed=false)
  for i in 0..<cliques.members.length() {
    out.add_node(i) |> ignore
  }
  for i in 0..<cliques.members.length() {
    for j in (i + 1)..<cliques.members.length() {
      let mut share = false
      for node in cliques.members[i] {
        if cliques.members[j].contains(node) {
          share = true
          break
        }
      }
      if share {
        out.add_edge(i, j, ()) |> ignore
      }
    }
  }
  out
}

///|
/// A perfect elimination order: a node order in which the later neighbours of each node
/// are all joined to each other. `None` when the graph is not chordal.
pub fn[G : @moongraph.Topology] perfect_elimination_order(
  graph : G,
) -> Array[Int]? {
  let n = @moongraph.Topology::node_count(graph)
  // Maximum cardinality search: always take the node with the most already-chosen
  // neighbours, which produces a perfect elimination order exactly when one exists.
  let weight : Array[Int] = Array::make(n, 0)
  let chosen : Array[Bool] = Array::make(n, false)
  let order : Array[Int] = []
  for _ in 0..<n {
    let mut pick = -1
    for node in 0..<n {
      if !chosen[node] && (pick < 0 || weight[node] > weight[pick]) {
        pick = node
      }
    }
    if pick < 0 {
      break
    }
    chosen[pick] = true
    order.push(pick)
    for nbr in @moongraph.Topology::neighbors(graph, pick) {
      if !chosen[nbr] {
        weight[nbr] = weight[nbr] + 1
      }
    }
  }
  // The search produces the reverse of an elimination order; the check wants the order
  // itself, so it is turned around first.
  let peo = order.copy()
  peo.rev_in_place()
  let position : Array[Int] = Array::make(n, 0)
  for i in 0..<peo.length() {
    position[peo[i]] = i
  }
  let mut chordal = true
  for node in 0..<n {
    let later : Array[Int] = []
    for nbr in @internal.distinct_neighbors(graph, node) {
      if position[nbr] > position[node] {
        later.push(nbr)
      }
    }
    for i in 0..<later.length() {
      for j in (i + 1)..<later.length() {
        if !@internal.adjacent(graph, later[i], later[j]) {
          chordal = false
        }
      }
    }
  }
  if chordal {
    Some(peo)
  } else {
    None
  }
}

///|
/// Whether every cycle of four or more nodes has a chord.
pub fn[G : @moongraph.Topology] is_chordal(graph : G) -> Bool {
  perfect_elimination_order(graph) is Some(_)
}

///|
/// The maximal cliques of a chordal graph, read off its elimination order: the node and
/// its later neighbours form one, and the ones that another contains are dropped.
pub fn[G : @moongraph.Topology] chordal_cliques(graph : G) -> @moongraph.Cliques {
  let n = @moongraph.Topology::node_count(graph)
  let members : Array[Array[Int]] = []
  match perfect_elimination_order(graph) {
    None => ()
    Some(order) => {
      let position : Array[Int] = Array::make(n, 0)
      for i in 0..<order.length() {
        position[order[i]] = i
      }
      for node in 0..<n {
        let clique : Array[Int] = [node]
        for nbr in @internal.distinct_neighbors(graph, node) {
          if position[nbr] > position[node] {
            clique.push(nbr)
          }
        }
        clique.sort()
        let mut contained = false
        for other in members {
          if contains_all(other, clique) {
            contained = true
            break
          }
        }
        if !contained {
          members.push(clique)
        }
      }
    }
  }
  { members, }
}

///|
/// Whether the second set is part of the first.
fn contains_all(outer : Array[Int], inner : Array[Int]) -> Bool {
  for node in inner {
    if !outer.contains(node) {
      return false
    }
  }
  true
}

///|
/// The width of the tree decomposition the elimination order gives: one less than the
/// largest clique in it.
pub fn[G : @moongraph.Topology] chordal_treewidth(graph : G) -> Int {
  let mut best = 0
  for clique in chordal_cliques(graph).members {
    if clique.length() - 1 > best {
      best = clique.length() - 1
    }
  }
  best
}

///|
/// The edges that have to be added to make the graph chordal, keeping the elimination
/// order the search found. A graph that is already chordal gets none.
pub fn[G : @moongraph.Topology] chordal_fill_in(graph : G) -> Array[(Int, Int)] {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[(Int, Int)] = []
  let order = match perfect_elimination_order(graph) {
    None => return out
    Some(order) => order
  }
  let position : Array[Int] = Array::make(n, 0)
  for i in 0..<order.length() {
    position[order[i]] = i
  }
  for node in 0..<n {
    let later : Array[Int] = []
    for nbr in @internal.distinct_neighbors(graph, node) {
      if position[nbr] > position[node] {
        later.push(nbr)
      }
    }
    for i in 0..<later.length() {
      for j in (i + 1)..<later.length() {
        if !@internal.adjacent(graph, later[i], later[j]) {
          out.push((later[i], later[j]))
        }
      }
    }
  }
  out
}

///|
/// Whether every induced subgraph has a clique and an independent set of the same size,
/// which chordal graphs and bipartite graphs both satisfy.
pub fn[G : @moongraph.Topology] is_perfect(graph : G) -> Bool {
  is_chordal(graph) || @internal.is_bipartite(graph)
}
