# moongraph

Graphs and graph algorithms for MoonBit: four storage types behind one interface, and twenty-one
packages of algorithms that run on all of them.

<p>
  <a href="https://moonbitstack.github.io/moongraph/">Home</a> ·
  <a href="https://moonbitstack.github.io/moongraph/guide.html">Guide</a> ·
  <a href="https://moonbitstack.github.io/moongraph/api.html">API</a> ·
  <a href="https://mooncakes.io/docs/moonbitstack/moongraph">mooncakes</a>
</p>

```moonbit
import {
  "moonbitstack/moongraph",
  "moonbitstack/moongraph/path",
}

fn route() -> Array[Int]? raise {
  let g : @moongraph.Graph[String, Double] = @moongraph.Graph::new()
  let a = g.add_node("a")
  let b = g.add_node("b")
  let c = g.add_node("c")
  g.add_edge(a, b, 1.0) |> ignore
  g.add_edge(b, c, 2.0) |> ignore
  g.add_edge(a, c, 5.0) |> ignore
  let paths = @path.dijkstra(g, a, weight=g.weights(fn(cost) { cost }))
  paths.path_to(c)
}
```

## A graph is numbers

A graph is a set of numbered nodes and a set of numbered edges, each carrying a payload of its
own. The numbers are dense and start at zero, so an algorithm can index an array by node instead
of hashing it. Everything else — names, records, keys of any kind — goes in the payload, or
through `Keyed`, which holds the translation and hands the numbers to the algorithms.

| Type | Shape | Parallel edges | Numbers after a deletion | Use it when |
|:--|:--|:--:|:--|:--|
| `Graph[N, E]` | Adjacency list | Yes | Renumbered | The default: build it, change it, run algorithms on it |
| `StableGraph[N, E]` | Adjacency list with holes | Yes | Kept | You hold node numbers across deletions |
| `Csr[N, E]` | Compressed adjacency, both directions | Yes | — | Read-only, built once, walked many times |
| `Matrix[E]` | V x V cells | No | Renumbered | Dense graphs and the passes that look at every pair |

All four implement the same trait, so an algorithm is written once and takes any of them — or a
graph type of your own:

<!-- nocheck -->

```moonbit
pub(open) trait Topology {
  node_count(Self) -> Int
  edge_count(Self) -> Int
  directed(Self) -> Bool
  neighbors(Self, Int) -> ArrayView[Int]   // one entry per edge
  incident(Self, Int) -> ArrayView[Int]    // the edge numbers, in the same order
  endpoints(Self, Int) -> (Int, Int)
}

pub(open) trait Inbound {
  in_neighbors(Self, Int) -> ArrayView[Int]
  in_incident(Self, Int) -> ArrayView[Int]
}
```

`neighbors` and `incident` are parallel views, so a walk that only needs nodes allocates nothing
and a walk that needs weights reads both without a lookup. `Inbound` is the extra ability a handful
of algorithms need — the ones that walk edges backwards, like strong components or the second half
of a bidirectional search.

## Weights are a function

An edge payload can be anything, so a weight is a function from edge number to cost rather than a
field the library reserves. `Graph::weights` turns a function over payloads into one over numbers.
An algorithm that is given no weight treats every edge as costing one.

```moonbit
let w = g.weights(fn(cost) { cost })   // the payload is the cost
let by_cost = @path.dijkstra(g, 0, weight=w)
let by_hop = @path.dijkstra(g, 0)      // every edge costs one
```

Results are arrays indexed by node number, so no lookup can fail: `distance` holds `Double?`, and
`None` means the node was not reached — not infinity, not a large number, so a forgotten case is a
type error rather than a poisoned sum.

## Refusals carry the reason

A graph-level mistake is a value, not an abort. A negative weight reaching Dijkstra, a cycle
reaching a topological order, a graph that is not the shape the function needs: each comes back as
`Refused`, naming the node, the edge, or a witness cycle.

```moonbit
let outcome = try {
  @path.dijkstra(g, 0, weight=w)
} catch {
  @moongraph.Refused::NegativeWeight(edge~) => "edge " + edge.to_string() + " is negative"
  _ => "answered"
}
```

## Packages

The root package holds the types, the two traits and the records results take. Every algorithm
lives in the package for its family, so a program that imports one pays for one.

| Package | What it answers |
|:--|:--|
| `moongraph` | `Graph`, `StableGraph`, `Csr`, `Matrix`, `Keyed`, the traits, the result records |
| `moongraph/traverse` | breadth-first and depth-first walks, their trees, layers and events |
| `moongraph/path` | Dijkstra, Bellman-Ford, Johnson, Floyd-Warshall, A\*, k shortest, widest, simple routes |
| `moongraph/component` | components, strong components, condensation, biconnected pieces, bridges, cuts |
| `moongraph/dag` | topological orders, generations, closures, longest path, dominance |
| `moongraph/cycle` | cycles and cycle bases, girth, Euler walks, the postman's route |
| `moongraph/tree` | spanning trees, branchings, Steiner tree, centres, Prüfer codes, common ancestors |
| `moongraph/flow` | maximum flow, minimum cut, cost flow, connectivity, disjoint routes |
| `moongraph/matching` | matchings, assignments, covers, the blossom walk |
| `moongraph/color` | greedy and saturation colourings, edge colouring, chromatic number |
| `moongraph/clique` | maximal cliques, independent sets, chordality |
| `moongraph/centrality` | degree, closeness, betweenness, eigenvector, PageRank, hubs and authorities |
| `moongraph/community` | modularity groups, label propagation, edge-betweenness splitting |
| `moongraph/metric` | density, distance, clustering, similarity, assortativity |
| `moongraph/struct` | what kind of graph this is, and the peelings that say how tightly it is knit |
| `moongraph/iso` | isomorphism, and the mapping when there is one |
| `moongraph/op` | unions, products, complements, subgraphs, line graphs, contraction |
| `moongraph/approx` | tours, covers, dominating sets, spanners, treewidth bounds |
| `moongraph/gen` | the named graphs, and the random families worth having by seed |
| `moongraph/io` | edge lists, adjacency lists, GML, graph6, sparse6, Pajek |
| `moongraph/io/graphml` | GraphML, on top of an XML parser |

## Reading and writing

Six text formats in `io`, and GraphML in `io/graphml` so the XML dependency stays behind one
package. Every reader refuses a broken document with the byte offset, the line and the column.

```moonbit
let text = @io.edge_list(g)
let back = @io.parse_edges(text)   // Graph[Unit, Double]; the third column is the weight
```

| Format | Writes | Reads | Notes |
|:--|:--:|:--:|:--|
| Edge list | yes | yes | two or three columns, `#` for comments |
| Adjacency list | yes | yes | one line per node |
| GML | yes | yes | nested `key value` lists |
| graph6 | yes | yes | one bit per possible edge |
| sparse6 | yes | yes | only the edges that are there, with a repeat flag |
| Pajek | yes | yes | counts nodes from one |
| GraphML | yes | yes | node labels and edge weights as data |

## Installing

```sh
moon add moonbitstack/moongraph
```

All four backends — `wasm`, `wasm-gc`, `js` and `native` — with no native code of its own, so
nothing about the library is platform-specific.

## Licence

Apache-2.0.
