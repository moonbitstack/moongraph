---
name: moongraph
description: Graphs and graph algorithms for MoonBit. Use it when a task needs a graph structure (adjacency list, stable numbering, compressed rows, dense matrix) or an algorithm on one — shortest paths, spanning trees, flow, matching, colouring, centrality, communities, topological order, cycles, isomorphism, or reading and writing graph files.
---

# moongraph

One graph interface, four storage types, and the algorithms written against it.

## Install and import

```sh
moon add moonbitstack/moongraph
```

```moonbit
import {
  "moonbitstack/moongraph",
  "moonbitstack/moongraph/path",
}
```

Every algorithm package imports the root, so you name only the family you use.

## Nodes are numbers

`add_node` and `add_edge` answer with the number they assigned. Those numbers are how a node is
identified; there is nothing else to keep.

```moonbit
let g : @moongraph.Graph[String, Double] = @moongraph.Graph::new(directed=false)
let a = g.add_node("a")
let b = g.add_node("b")
g.add_edge(a, b, 1.5) |> ignore
assert_eq(g.neighbors(a).length(), 1)
```

If the data is keyed by name, wrap the graph in `Keyed` and stay in keys at the edges of your
program — the numbers never have to leave the algorithm call.

## Weights are functions

An algorithm takes `weight? : (Int) -> Double` over edge numbers. `Graph::weights` adapts a
function over payloads. Leave it out and every edge costs one.

```moonbit
let paths = @path.dijkstra(g, a, weight=g.weights(fn(cost) { cost }))
assert_eq(paths.distance[b], Some(1.5))
assert_eq(paths.path_to(b), Some([a, b]))
```

## Refusals, not silence

Dijkstra on a negative edge, a topological order on a cyclic graph, a spanning tree on a graph in
pieces: each raises `Refused` naming the node, the edge, or a witness cycle. Catch the variants
you can act on; let the rest through.

```moonbit
let outcome = try {
  @dag.topological_order(g)
} catch {
  @moongraph.Refused::Cycle(nodes~) => nodes
  _ => []
}
```

## Cycles and Euler walks

`girth` answers the reading the graph has. In a directed graph that is the shortest closed walk
the arcs allow, which is not the shortest cycle of the graph with its directions dropped, and
`None` means the arcs never come back at all.

```moonbit
let ring : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
  [(0, 1), (1, 2), (2, 0)],
  node=(),
  edge=(),
  directed=true,
)
assert_eq(@cycle.girth(ring), Some(3))
assert_true(@cycle.is_eulerian(ring))
```

An Eulerian graph has every degree even if it is undirected, and as many arcs leaving each node
as entering it if it is directed — two arcs out of one node and none in are even by degree and
have no way back. `eulerian_circuit` walks the trail, and `eulerian_path` answers the open one.

## Questions the counts alone answer

`struct.is_graphical`, `struct.is_digraphical` and `struct.is_multigraphical` decide whether a
list of degrees (or in/out-degree pairs) can be realised, without a graph. The directed case is the
Gale-Ryser criterion; `struct.gale_ryser` runs it over two non-increasing sequences directly.

```moonbit
assert_eq(@struct.is_digraphical([(0, 1), (0, 1)]), false)
assert_eq(@struct.gale_ryser([2, 1, 1], [2, 1, 1]), true)
```

## Three things that trip people up

- `remove_node` renumbers the nodes above the hole. Use `StableGraph` if you hold numbers across
  deletions; it never moves a node and never reuses a vacant one for an existing edge.
- A result array is indexed by node number and holds `Double?`: `None` means "not reached", not
  infinity. Do not add to it without handling that.
- `Csr` and `Matrix` cannot be changed after construction. `Csr` also renumbers edges densely; if
  you need the original edge numbers, keep the `Graph`.
- `graph6` and `sparse6` write the format's own bytes, not a rendering of them: the node count
  widens to four bytes above 62 nodes and to eight above 258047, and the last byte is filled so
  that a reader stops at the end of the edges. A text another tool wrote reads back unchanged.
- `metric.wl_hash` is a fingerprint, not a measurement: two graphs that agree locally for the
  rounds it takes share it, and the digest is blake2b at sixteen bytes, so the string is the one
  another implementation of the same rounds prints.
