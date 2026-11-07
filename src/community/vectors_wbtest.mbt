///|
test "the k-clique partition agrees with the reference" {
  for case in @internal.community_cases() {
    let graph = @internal.vector_graph(case.graph)
    let partition = k_clique_communities(graph, 2)
    if partition.count != case.blocks {
      fail(case.graph.name + ": community block count differs")
    }
    // The block sizes, smallest first, must match the reference's.
    let sizes : Array[Int32] = []
    for i in 0..<partition.count {
      let mut size = 0
      for node in 0..<partition.label.length() {
        if partition.label[node] == i {
          size = size + 1
        }
      }
      sizes.push(size)
    }
    sizes.sort()
    if sizes != case.sizes {
      fail(case.graph.name + ": community block sizes differ")
    }
  }
}
