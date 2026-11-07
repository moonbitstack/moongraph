// The differential test for the algebraic operators: each one is answered twice, once by the
// operator and once by a direct reading of what it is supposed to mean — a rebuilt edge list, a
// transitive-closure matrix, or a count — and the two must agree on random graphs.
//
// The second reading is deliberately the obvious one: a matrix closed by Floyd-Warshall's shape,
// a list rebuilt edge by edge. If both were written the same clever way, agreement would prove
// nothing.

///|
/// A random graph over `count` nodes with about `count * 2` edges, without self loops. Parallel
/// edges are allowed, because the storage allows them and the operators must keep them.
fn random_graph(
  count : Int32,
  rng : &@contract.Rng,
  directed : Bool,
) -> @moongraph.Graph[Int32, Unit] {
  let graph : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::new(directed~)
  for node in 0..<count {
    graph.add_node(node) |> ignore
  }
  if count < 2 {
    return graph
  }
  for _ in 0..<(count * 2) {
    let a = @moonrand.randint(rng, 0, (count - 1).to_int64()).to_int()
    let b = @moonrand.randint(rng, 0, (count - 1).to_int64()).to_int()
    if a != b {
      graph.add_edge(a, b, ()) |> ignore
    }
  }
  graph
}

///|
/// The edges as sorted "from-to" text, so two graphs over the same numbering can be compared
/// without depending on the order the storage keeps them in.
fn[N, E] edge_keys(graph : @moongraph.Graph[N, E]) -> Array[String] {
  let out : Array[String] = []
  for edge in graph.edges() {
    let (from, to) = graph.endpoints(edge)
    out.push(from.to_string() + "-" + to.to_string())
  }
  out.sort()
  out
}

///|
/// Reachability read as a matrix closed the Floyd-Warshall way: an edge marks its own cell, and
/// a node sitting between two others joins them. This is the second opinion on `closure`.
fn reach_matrix(graph : @moongraph.Graph[Int32, Unit]) -> Array[Array[Bool]] {
  let n = graph.node_count()
  let reach : Array[Array[Bool]] = []
  for _ in 0..<n {
    reach.push(Array::make(n, false))
  }
  for edge in graph.edges() {
    let (from, to) = graph.endpoints(edge)
    reach[from][to] = true
    if !graph.directed() {
      reach[to][from] = true
    }
  }
  for through in 0..<n {
    for from in 0..<n {
      if reach[from][through] {
        for to in 0..<n {
          if reach[through][to] {
            reach[from][to] = true
          }
        }
      }
    }
  }
  reach
}

///|
test "mapping the payloads keeps the shape" {
  let rng = @moonrand.seeded(b"op-map")
  for round in 0..<25 {
    let count = @moonrand.randint(rng, 2, 7).to_int()
    let directed = round % 2 == 0
    let graph = random_graph(count, rng, directed)
    // nmap: same shape, new node payloads.
    let named = nmap(graph, fn(node) { "n" + node.to_string() })
    assert_eq(named.node_count(), graph.node_count())
    assert_eq(named.edge_count(), graph.edge_count())
    assert_eq(named.directed(), graph.directed())
    for node in 0..<count {
      assert_eq(named.node_data(node), "n" + node.to_string())
    }
    // emap: same shape, new edge payloads.
    let counted = emap(graph, fn(_) { 1.0 })
    assert_eq(counted.node_count(), graph.node_count())
    assert_eq(counted.edge_count(), graph.edge_count())
    // gmap: both, and the edges still join the same pairs.
    let both = gmap(graph, fn(node) { node * 10 }, fn(_) { "e" })
    assert_eq(both.node_data(0), 0)
    assert_eq(edge_keys(both), edge_keys(graph))
  }
}

///|
test "removing a node leaves what a rebuild would" {
  let rng = @moonrand.seeded(b"op-remove-vertex")
  for round in 0..<25 {
    let count = @moonrand.randint(rng, 2, 7).to_int()
    let directed = round % 2 == 0
    let graph = random_graph(count, rng, directed)
    let victim = @moonrand.randint(rng, 0, (count - 1).to_int64()).to_int()
    let cut = remove_vertex(graph, victim)
    // The reference reading: walk the edges, drop the ones that touched the victim, and pull
    // every number above it down by one.
    let expected : Array[String] = []
    for edge in graph.edges() {
      let (from, to) = graph.endpoints(edge)
      if from != victim && to != victim {
        let shift = fn(node) { if node > victim { node - 1 } else { node } }
        expected.push(shift(from).to_string() + "-" + shift(to).to_string())
      }
    }
    expected.sort()
    assert_eq(cut.node_count(), count - 1)
    assert_eq(edge_keys(cut), expected)
    // A number the graph does not have changes nothing.
    assert_eq(edge_keys(remove_vertex(graph, count + 3)), edge_keys(graph))
  }
}

///|
test "removing an edge leaves the rest" {
  let rng = @moonrand.seeded(b"op-remove-edge")
  for _ in 0..<25 {
    let count = @moonrand.randint(rng, 2, 7).to_int()
    let graph = random_graph(count, rng, false)
    if graph.edge_count() == 0 {
      continue
    }
    // Take one edge away, then ask for the same pair again: one fewer copy, and the other
    // edges untouched.
    let first = graph.edges().collect()[0]
    let (from, to) = graph.endpoints(first)
    let before = edge_keys(graph)
    let after = edge_keys(remove_edge(graph, from, to))
    assert_eq(after.length(), before.length() - 1)
    assert_eq(remove_edge(graph, from, to).node_count(), graph.node_count())
    // Asking again for a pair that is not there changes nothing.
    let gone = remove_edge(graph, from, to)
    if gone.find_edges(from, to).length() == 0 {
      assert_eq(edge_keys(remove_edge(gone, from, to)), edge_keys(gone))
    }
  }
}

///|
test "connect joins every node of one half to every node of the other" {
  let rng = @moonrand.seeded(b"op-connect")
  for _ in 0..<20 {
    let left_count = @moonrand.randint(rng, 1, 5).to_int()
    let right_count = @moonrand.randint(rng, 1, 5).to_int()
    let left = random_graph(left_count, rng, false)
    let right = random_graph(right_count, rng, false)
    let joined = connect(left, right)
    assert_eq(joined.node_count(), left_count + right_count)
    assert_eq(
      joined.edge_count(),
      left.edge_count() + right.edge_count() + left_count * right_count,
    )
    // Every cross pair is an edge, and the halves keep their own.
    for a in 0..<left_count {
      for b in 0..<right_count {
        assert_true(joined.find_edge(a, left_count + b) is Some(_))
      }
    }
  }
}

///|
test "closure is reachability, and closing it again changes nothing" {
  let rng = @moonrand.seeded(b"op-closure")
  for round in 0..<20 {
    let count = @moonrand.randint(rng, 2, 6).to_int()
    let directed = round % 2 == 0
    let graph = random_graph(count, rng, directed)
    let closed = closure(graph)
    let reach = reach_matrix(graph)
    for from in 0..<count {
      for to in 0..<count {
        // The closure is reflexive, so a node always reaches itself.
        let expected = reach[from][to] || from == to
        let actual = closed.find_edge(from, to) is Some(_)
        if expected != actual {
          let pair = from.to_string() + " to " + to.to_string()
          fail(
            "closure misses " +
            pair +
            " (directed: " +
            directed.to_string() +
            ")",
          )
        }
      }
    }
    // Closing a closed graph adds nothing.
    assert_eq(edge_keys(closure(closed)), edge_keys(closed))
  }
}
