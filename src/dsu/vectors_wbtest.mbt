// The reference partition, replayed: the merges run in the order the generator wrote them, and
// every answer is compared at the step it is due — not only at the end, where a forest that
// merged the wrong pair early and the right one late would still look correct.

///|
test "the forest agrees with the reference at every merge" {
  for case in @internal.dsu_cases() {
    let forest = Dsu::new(case.nodes)
    if forest.length() != case.nodes || forest.count() != case.nodes {
      fail(case.name + ": a fresh forest is not one piece per number")
    }
    for at in 0..<case.merges.length() {
      let (a, b) = case.merges[at]
      if forest.union(a, b) != case.joined[at] {
        let step = at.to_string()
        fail(case.name + ": merge " + step + " joined the wrong way")
      }
      if forest.count() != case.pieces[at] {
        let want = case.pieces[at].to_string()
        let got = forest.count().to_string()
        fail(
          case.name +
          ": " +
          got +
          " pieces after merge " +
          at.to_string() +
          ", not " +
          want,
        )
      }
    }
    assert_eq(forest.groups(), case.groups)
    for node in 0..<case.nodes {
      if forest.size(node) != case.sizes[node] {
        let got = forest.size(node).to_string()
        fail(case.name + ": the piece of " + node.to_string() + " holds " + got)
      }
    }
  }
}

///|
/// Whether `a` and `b` sit in the same piece of the reference's partition.
fn together(groups : Array[Array[Int32]], a : Int32, b : Int32) -> Bool {
  for group in groups {
    if group.contains(a) && group.contains(b) {
      return true
    }
  }
  false
}

///|
test "the same question is answered from the reference's partition" {
  for case in @internal.dsu_cases() {
    let forest = Dsu::new(case.nodes)
    for (a, b) in case.merges {
      forest.union(a, b) |> ignore
    }
    for a in 0..<case.nodes {
      for b in 0..<case.nodes {
        if forest.same(a, b) != together(case.groups, a, b) {
          let pair = "(" + a.to_string() + ", " + b.to_string() + ")"
          fail(case.name + ": same" + pair + " differs")
        }
      }
    }
  }
}

///|
test "the representatives are a reading of the same partition" {
  for case in @internal.dsu_cases() {
    let forest = Dsu::new(case.nodes)
    for (a, b) in case.merges {
      forest.union(a, b) |> ignore
    }
    for group in case.groups {
      let root = forest.find(group[0])
      for node in group {
        if forest.find(node) != root {
          fail(
            case.name +
            ": " +
            node.to_string() +
            " is not under its piece's root",
          )
        }
      }
    }
  }
}
