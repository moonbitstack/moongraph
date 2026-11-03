# moongraph

Graphs and graph algorithms for MoonBit: four storage types that share one interface, and the
algorithms families that run on all of them.

The library is at the interface stage. The types, the two traits and every signature are fixed in
[`docs/design/interface.md`](docs/design/interface.md); the packages are empty until the interface
is signed off, and then they fill in one at a time.

## What it gives a caller

A graph is a set of numbered nodes and a set of numbered edges, each carrying its own payload.
Numbers are dense, from 0, so an algorithm can index an array by node instead of hashing it.

| Type | Shape | Parallel edges | Numbers after a deletion | Use it when |
|:--|:--|:--:|:--|:--|
| `Graph[N, E]` | Adjacency list | Yes | Renumbered | The default: build it, mutate it, run algorithms on it |
| `StableGraph[N, E]` | Adjacency list with holes | Yes | Kept | You hold node numbers across deletions |
| `Csr[N, E]` | Compressed adjacency, both directions | Yes | — | Read-only, built once, traversed millions of times |
| `Matrix[E]` | V x V cells | No | Renumbered | Dense graphs and the dynamic-programming passes |

Every one of them implements the same trait, so an algorithm is written once:

<!-- nocheck -->

```moonbit
pub(open) trait Topology[E] {
  node_count(Self) -> Int
  edge_count(Self) -> Int
  directed(Self) -> Bool
  neighbors(Self, Int) -> Iter[(Int, Int)]     // (edge, neighbour)
  edge_data(Self, Int) -> E
  endpoints(Self, Int) -> (Int, Int)
}
```

`Inbound[E]` adds `in_neighbors` for the algorithms that walk edges backwards. A graph type defined
outside this library implements the two traits and gets every algorithm without a conversion.

## Weights are a function, not a field

Nothing here looks for an attribute called `weight`. An algorithm asks for `(E) -> Double`, and
leaving it out means every edge weighs 1:

<!-- nocheck -->

```moonbit
import "moonbitstack/moongraph" as mg

let graph : @mg.Graph[Unit, Double] = @mg.Graph::new(directed=false)
let a = graph.add_node(())
let b = graph.add_node(())
let c = graph.add_node(())
graph.add_edge(a, b, 2.5) |> ignore
graph.add_edge(b, c, 1.0) |> ignore

// Weighted: the payload is the weight.
let paths = @path.dijkstra(graph, a, weight=fn(w) { w })
paths.distance[c]   // Some(3.5)
paths.path_to(c)    // Some([0, 1, 2])

// Unweighted: leave the weight out, every edge counts 1.
let hops = @path.dijkstra(graph, a)
hops.distance[c]    // Some(2.0)
```

Results are arrays indexed by node number, so nothing has to be unwrapped per lookup: `distance`
holds `Double?`, and `None` means "no path" rather than infinity.

## Refusals carry the evidence

A graph-level mistake is a value, not a panic. A negative weight reaching Dijkstra, a cycle reaching
a topological sort, a graph that is not the shape the function needs: each one comes back as
`Refused` naming the node, the edge, or a witness cycle.

<!-- nocheck -->

```moonbit
match @dag.topological_order(graph) {
  order => println(order.length().to_string())
  raise @mg.Refused(@mg.Cycle(nodes=[2, 5, 2])) => println("cycle through 2 and 5")
}
```

## Packages

| Package | What lives there |
|:--|:--|
| root | The four types, `Topology`, `Inbound`, `Keyed`, the result records, `Refused` |
| `traverse` | Breadth-first and depth-first sweeps, as orders, trees, layers or events |
| `path` | Dijkstra, Bellman-Ford, Johnson, Floyd-Warshall, A*, k shortest, simple paths |
| `component` | Connected, strongly connected, biconnected, articulation points, bridges |
| `flow` | Max flow, min cut, min cost flow, connectivity, disjoint paths |
| `matching` | Maximal, maximum, weighted, bipartite, assignment, edge and vertex cover |
| `tree` | Minimum and maximum spanning trees, branchings, Steiner, LCA, tree centres |
| `cycle` | Cycle basis, simple cycles, girth, Eulerian tours |
| `dag` | Topological order, reachability, longest path, dominators |
| `color` | Greedy, DSatur, equitable, edge colouring |
| `clique` | Maximal cliques, independent sets, chordality |
| `iso` | Isomorphism, subgraph isomorphism, canonical form, refinement hashes |
| `centrality` | Degree, closeness, betweenness, PageRank, eigenvector, Katz, HITS |
| `community` | Louvain, Leiden, label propagation, modularity, partitions |
| `metric` | Diameter, clustering, assortativity, similarity, cut quality |
| `struct` | Tree and planarity predicates, degree sequences, core and truss decomposition |
| `op` | Union, intersection, products, complement, subgraph, contraction, line graph |
| `approx` | Tours, vertex cover, dominating set, densest subgraph, spanner |
| `gen` | Named graphs, lattices, random models, degree-sequence graphs |
| `io` | Edge list, adjacency list, DOT, GML, Pajek, DIMACS; GraphML in `io/graphml` |

## Where the design lives

- [`docs/design/inventory.md`](docs/design/inventory.md): every capability the design survey
  turned up, one row each, with the property it computes, its complexity, its licence, and where in
  this library it belongs.
- [`docs/design/interface.md`](docs/design/interface.md): the signature of every package, the shapes
  results take, and the fifteen places where the references disagree and this library picks one.

## Licence

Apache-2.0.
