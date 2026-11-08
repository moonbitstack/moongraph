///|
test "a network answers again after a capacity changes" {
  let net = Flow::new(4)
  net.add_edge(0, 1, 2.0) |> ignore
  net.add_edge(1, 3, 2.0) |> ignore
  net.add_edge(0, 2, 1.0) |> ignore
  net.add_edge(2, 3, 1.0) |> ignore
  assert_eq(net.flow(0, 3), 3.0)
  // Nothing has changed, so nothing more can be pushed.
  assert_eq(net.flow(0, 3), 0.0)
  // The middle edge is the bottleneck; widening the first one alone does not help.
  net.change_edge(0, 5.0, 2.0)
  assert_eq(net.flow(0, 3), 0.0)
  net.change_edge(1, 5.0, 2.0)
  assert_eq(net.flow(0, 3), 3.0)
  // The cut is the two edges out of the source, and they are both full.
  assert_eq(net.min_cut(0), [true, false, false, false])
  assert_eq(net.edge_flow(0), Some((0, 1, 5.0, 5.0)))
  assert_eq(net.edge_flow(1), Some((1, 3, 5.0, 5.0)))
}

///|
test "a limit stops the search where it was told to" {
  let net = Flow::new(2)
  net.add_edge(0, 1, 10.0) |> ignore
  assert_eq(net.flow(0, 1, limit=4.0), 4.0)
  assert_eq(net.edge_flow(0), Some((0, 1, 10.0, 4.0)))
  assert_eq(net.flow(0, 1), 6.0)
  assert_eq(net.edge_flow(0), Some((0, 1, 10.0, 10.0)))
}

///|
test "a change that breaks the flow is refused" {
  let net = Flow::new(2)
  net.add_edge(0, 1, 2.0) |> ignore
  let mut refused = false
  net.change_edge(0, 1.0, 2.0) catch {
    @moongraph.Refused::NotA(..) => refused = true
    _ => fail("the wrong refusal")
  }
  assert_true(refused)
}

///|
test "the price curve bends where a route fills up" {
  let net = CostFlow::new(2)
  net.add_edge(0, 1, 2.0, 5.0) |> ignore
  net.add_edge(0, 1, 1.0, 9.0) |> ignore
  assert_eq(net.slope(0, 1), [(0.0, 0.0), (2.0, 10.0), (3.0, 19.0)])
  // Sending the flow is what the curve describes, so the network is now full: a second
  // question is answered from what is left, which is nothing.
  assert_eq(net.flow(0, 1), (0.0, 0.0))
}

///|
test "one call asks for the total, and the network is spent" {
  let net = CostFlow::new(2)
  net.add_edge(0, 1, 2.0, 5.0) |> ignore
  net.add_edge(0, 1, 1.0, 9.0) |> ignore
  assert_eq(net.flow(0, 1), (3.0, 19.0))
  assert_eq(net.flow(0, 1), (0.0, 0.0))
}

///|
test "two routes at different prices give one bend each" {
  let net = CostFlow::new(4)
  net.add_edge(0, 1, 1.0, 1.0) |> ignore
  net.add_edge(0, 2, 1.0, 2.0) |> ignore
  net.add_edge(1, 3, 1.0, 1.0) |> ignore
  net.add_edge(2, 3, 1.0, 1.0) |> ignore
  assert_eq(net.slope(0, 3), [(0.0, 0.0), (1.0, 2.0), (2.0, 5.0)])
}
