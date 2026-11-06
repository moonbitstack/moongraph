///|
test "betweenness agrees with the reference" {
  for case in @internal.centrality_cases() {
    let graph = @internal.vector_graph(case.graph)
    let scores = betweenness_centrality(graph)
    for node in 0..<case.graph.nodes {
      if !@internal.close(scores.score[node], case.betweenness[node]) {
        fail(case.graph.name + ": node " + node.to_string() + " differs")
      }
    }
  }
}
