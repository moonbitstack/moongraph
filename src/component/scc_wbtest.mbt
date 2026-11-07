// The differential test for `scc`: the pieces it names must be the pieces "reachable both
// ways" names, and the order it gives them must be a topological one — every edge runs from a
// piece to the same piece or a later one. The reference is a naive search in both directions.

///|
/// Whether `to` is reachable from `from` by following the out-edges.
fn[G : @moongraph.Topology] reaches(
  graph : G,
  from : Int32,
  to : Int32,
) -> Bool {
  let n = graph.node_count()
  let seen : Array[Bool] = Array::make(n, false)
  let queue : Array[Int32] = [from]
  seen[from] = true
  let mut head = 0
  while head < queue.length() {
    let at = queue[head]
    head = head + 1
    if at == to {
      return true
    }
    for nbr in graph.neighbors(at) {
      if !seen[nbr] {
        seen[nbr] = true
        queue.push(nbr)
      }
    }
  }
  false
}

///|
/// The index of the piece holding `node`, or -1.
fn piece_of(groups : Array[Array[Int32]], node : Int32) -> Int32 {
  for at in 0..<groups.length() {
    if groups[at].contains(node) {
      return at
    }
  }
  -1
}

///|
/// A random directed graph over `n` nodes: one edge per pair with probability `p`.
fn random_directed(
  rng : &@contract.Rng,
  n : Int32,
  percent : Int32,
) -> @moongraph.Graph[Unit, Unit] {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new(directed=true)
  for _ in 0..<n {
    g.add_node(()) |> ignore
  }
  for a in 0..<n {
    for b in 0..<n {
      if a != b && @moonrand.randint(rng, 0, 99).to_int() < percent {
        g.add_edge(a, b, ()) |> ignore
      }
    }
  }
  g
}

///|
test "scc names the pieces mutual reachability names" {
  let rng = @moonrand.seeded(b"scc-diff")
  for round in 0..<60 {
    let n = 7
    let g = random_directed(rng, n, 22)
    let groups = scc(g)
    // Every pair is together exactly when each reaches the other.
    for a in 0..<n {
      for b in 0..<n {
        let together = piece_of(groups, a) == piece_of(groups, b)
        let mutual = reaches(g, a, b) && reaches(g, b, a)
        if together != mutual {
          fail(
            "round " +
            round.to_string() +
            ": piece membership differs at " +
            a.to_string() +
            "/" +
            b.to_string(),
          )
        }
      }
    }
    // The order is topological: an edge never runs backwards.
    for e in 0..<g.edge_count() {
      let (a, b) = g.endpoints(e)
      if piece_of(groups, a) > piece_of(groups, b) {
        fail("round " + round.to_string() + ": an edge runs backwards")
      }
    }
  }
}

///|
test "a chain's pieces come out in chain order" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new(directed=true)
  for _ in 0..<3 {
    g.add_node(()) |> ignore
  }
  g.add_edge(0, 1, ()) |> ignore
  g.add_edge(1, 2, ()) |> ignore
  assert_eq(scc(g), [[0], [1], [2]])
}

///|
test "a cycle is one piece, and its tail follows" {
  let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new(directed=true)
  for _ in 0..<4 {
    g.add_node(()) |> ignore
  }
  g.add_edge(0, 1, ()) |> ignore
  g.add_edge(1, 2, ()) |> ignore
  g.add_edge(2, 0, ()) |> ignore
  g.add_edge(2, 3, ()) |> ignore
  let groups = scc(g)
  assert_eq(groups.length(), 2)
  assert_eq(piece_of(groups, 0), piece_of(groups, 1))
  assert_eq(piece_of(groups, 1), piece_of(groups, 2))
  assert_true(piece_of(groups, 2) < piece_of(groups, 3))
}
