// The differential test for accessibility: the count must be the count the all-pairs distances
// give, and the decayed sum must be the sum of the kernel over those same distances. The
// all-pairs answer comes from Floyd–Warshall, a different algorithm from the per-source search
// the metric itself runs, so agreement is not a tautology.

///|
fn almost(a : Double, b : Double) -> Bool {
  let diff = a - b
  (if diff < 0.0 { -diff } else { diff }) < 1.0e-9
}

///|
/// A random undirected graph with whole-number weights from one to five.
fn random_weighted(
  rng : &@contract.Rng,
  n : Int32,
  percent : Int32,
) -> @moongraph.Graph[Unit, Double] {
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new(directed=false)
  for _ in 0..<n {
    g.add_node(()) |> ignore
  }
  for a in 0..<n {
    for b in (a + 1)..<n {
      if @moonrand.randint(rng, 0, 99).to_int() < percent {
        g.add_edge(
          a,
          b,
          1.0 + @moonrand.randint(rng, 0, 4).to_int().to_double(),
        )
        |> ignore
      }
    }
  }
  g
}

///|
test "the reachable count is the count the all-pairs distances give" {
  let rng = @moonrand.seeded(b"access-diff")
  for round in 0..<40 {
    let n = 8
    let g = random_weighted(rng, n, 45)
    let w = g.weights(fn(cost) { cost })
    let pairs = @path.floyd_warshall(g, weight=w)
    let cutoff = 3.0 + @moonrand.randint(rng, 0, 4).to_int().to_double()
    let mine = accessibility(g, cutoff, weight=w)
    for from in 0..<n {
      let mut expected = 0
      for to in 0..<n {
        match pairs.distance[from][to] {
          Some(cost) => if cost <= cutoff { expected = expected + 1 }
          None => ()
        }
      }
      if mine[from] != expected {
        fail(
          "round " +
          round.to_string() +
          ": accessibility differs at node " +
          from.to_string(),
        )
      }
    }
  }
}

///|
test "the decayed sum is the kernel over the all-pairs distances" {
  let rng = @moonrand.seeded(b"decay-diff")
  for round in 0..<40 {
    let n = 8
    let g = random_weighted(rng, n, 45)
    let w = g.weights(fn(cost) { cost })
    let pairs = @path.floyd_warshall(g, weight=w)
    let cutoff = 6.0
    let decay = 0.4
    let mine = accessibility_decay(g, cutoff, decay, weight=w)
    for from in 0..<n {
      let mut expected = 0.0
      for to in 0..<n {
        match pairs.distance[from][to] {
          Some(cost) =>
            if cost <= cutoff {
              expected = expected + @math.exp(-decay * cost)
            }
          None => ()
        }
      }
      if !almost(mine[from], expected) {
        fail(
          "round " +
          round.to_string() +
          ": decayed accessibility differs at node " +
          from.to_string(),
        )
      }
    }
  }
}

///|
test "a node always reaches itself" {
  let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new(directed=false)
  for _ in 0..<4 {
    g.add_node(()) |> ignore
  }
  let mine = accessibility(g, 0.0)
  for node in 0..<4 {
    assert_eq(mine[node], 1)
  }
}
