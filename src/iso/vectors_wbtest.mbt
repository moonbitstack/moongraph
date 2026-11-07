///|
test "whether two graphs match agrees with the reference" {
  for case in @internal.iso_cases() {
    let a : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::from_edges(
      case.a,
      node=0,
      edge=(),
      directed=false,
    )
    let b : @moongraph.Graph[Int32, Unit] = @moongraph.Graph::from_edges(
      case.b,
      node=0,
      edge=(),
      directed=false,
    )
    if is_isomorphic(a, b) != case.isomorphic {
      fail(case.name + ": isomorphism reading differs")
    }
  }
}
