---
name: moongraph
description: Graphs and graph algorithms for MoonBit. Use it when a task needs a graph structure (adjacency list, stable numbering, compressed rows, dense matrix) or an algorithm on one — shortest paths, spanning trees, flow, matching, colouring, centrality, communities, topological order, cycles, isomorphism, board pathfinding, disjoint sets, two-variable clauses, or reading and writing graph files.
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

## Boards, sets and clauses

Not every graph is built edge by edge. `grid` walks a board of cells — numbered `y * width + x`,
eight-connected, a diagonal step costing the diagonal of a unit square — and `jps` is the
jump-point search for a board large and open enough that expanding every cell is wasteful. It
answers the route cell by cell, and blocks are set with `block`.

```moonbit
let board = @grid.Grid::new(8, 8)
let route = board.jps(0, 63).unwrap()
assert_eq(route[0], 0)
assert_eq(route[route.length() - 1], 63)
board.block(1, 1)
let around = board.jps(0, 63).unwrap()
assert_true(board.path_cost(around) > board.path_cost(route))
```

`dsu` is a disjoint-set forest over the numbers `0 .. n - 1`, exposed for callers whose merging
problem has no graph in it; `sat` decides clauses over two variables and hands back an
assignment. A clause naming one variable twice is a unit clause, not a special case.

```moonbit
let forest = @dsu.Dsu::new(6)
forest.union(0, 1) |> ignore
forest.union(1, 2) |> ignore
assert_eq(forest.groups(), [[0, 1, 2], [3], [4], [5]])

let clauses = @sat.TwoSat::new(2)
clauses.add_clause(0, true, 1, false)
assert_true(clauses.satisfiable())
```

`incremental` holds a flow network you keep. `add_edge` returns the edge number, `change_edge`
replaces one edge's capacity and flow, and `flow` answers how much more it could push — the total
is the sum of the calls, and the network stays at a maximum flow in between.

```moonbit
let net = @incremental.Flow::new(3)
net.add_edge(0, 1, 2.0) |> ignore
net.add_edge(1, 2, 1.0) |> ignore
assert_eq(net.flow(0, 2), 1.0)
net.change_edge(1, 3.0, 1.0)
assert_eq(net.flow(0, 2), 1.0)
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
