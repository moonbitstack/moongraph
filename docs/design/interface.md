# Interface

The signatures every package exposes: dense node numbers, four graph types, the `Topology` and
`Inbound` traits, weights as functions of the edge number, the shapes results take, and the
package split. The implementation is written against this table. A signature found not to compile
is changed here in the same commit, so the table never drifts from the code.

## Packages

Twenty packages: the root, the algorithm families (`traverse`, `path`, `flow`, `matching`, `tree`,
`component`, `centrality`, `community`, `iso`, `color`, `clique`, `cycle`, `dag`, `gen`), `io`, and
four more because the inventory found capabilities too large for any of those:

| Package | Holds | Rows |
|:--|:--|:--:|
| `metric` | density, diameter, radius, clustering, assortativity, similarity, link prediction, efficiency | see inventory |
| `struct` | `is_tree`, `is_bipartite`, `is_chordal`, `is_planar`, degree-sequence tests, regularity, decompositions | see inventory |
| `op` | union, intersection, difference, products, complement, reverse, subgraph, contraction, line graph, projection | see inventory |
| `approx` | TSP, vertex cover, dominating set, densest subgraph, spanner, treewidth bounds, rewiring | 15 |

GraphML needs moonxml, so it stays behind its own package, `io/graphml`, and nothing else in `io`
carries that dependency.

## What the four types are, and what they are not

| Type | Shape | Parallel edges | Deletion | Mutation |
|:--|:--|:--|:--|:--|
| `Graph[N, E]` | Adjacency list, one array per node | Yes, each with its own edge number | Renumbers the remaining nodes | Full |
| `StableGraph[N, E]` | Adjacency list with holes | Yes | Leaves a hole; numbers never move | Full |
| `Csr[N, E]` | Compressed adjacency, forward and reverse | Yes, sorted by target | None | None |
| `Matrix[E]` | V x V cells, one payload per cell | No | Renumbers | Full, O(1) access |

Undirected graphs store each edge once and report it from both endpoints; a self-loop is one edge
reported once. `Graph` and `StableGraph` numbering is dense and stable within a direction: adding a
node never renumbers an existing one, and only `remove_node` on `Graph` does.

## Conventions every signature follows

- **Graph first, then the nodes it is about, then the knobs.** `dijkstra(graph, source)`, not
  `dijkstra(source, graph)`.
- **Weights are a function of the edge number.** `weight? : (Int) -> Double`, and leaving it out
  means every edge weighs 1. A MoonBit trait takes no type parameter, so an algorithm generic over
  the graph cannot name `E`; `g.weights(e => e.cost)` turns a function of the payload into this
  shape, and a weight kept in an array beside the graph needs no adapter at all.
- **`Double` everywhere a number comes out.** Unreachable is `None` in a `Double?` array, never
  `infinity` or `NaN`, so arithmetic mistakes show up as option mismatches instead of silently
  poisoning a sum.
- **Refusals are values.** A function that can reject its input says `raise Refused` and carries
  the offending node or edge. Nothing aborts on a graph-level mistake.
- **Reproducibility is part of the contract.** Where an algorithm has a choice between equal
  answers, it breaks the tie by node number, then by edge number. Tests compare arrays, so a
  second implementation that breaks ties differently is a bug, not a variation.
- **Knobs are records with presets.** Anything with more than two knobs takes a record with a
  `pub let` preset (`community_settings` is the first one); one or two knobs stay flat and use
  `x~ : T = v`.
- **Randomness is a parameter, `rng~ : &@contract.Rng`.** The contract is moonrand's, so any
  generator that implements it works. `@moonrand.seeded(bytes)` makes a reproducible one. No
  global state, no hidden seed.

## root

The four types, the two traits, and every record a result takes.

<!-- nocheck -->

```moonbit
/// What every algorithm needs from a graph. `neighbors` and `incident` are parallel: position `i`
/// of each describes one edge leaving `node`, so a walk that only wants nodes allocates nothing and
/// a walk that wants weights reads both. In an undirected graph an edge appears at both of its
/// endpoints, and a self-loop appears once.
pub(open) trait Topology {
  node_count(Self) -> Int
  edge_count(Self) -> Int
  directed(Self) -> Bool
  neighbors(Self, Int) -> ArrayView[Int]
  incident(Self, Int) -> ArrayView[Int]
  endpoints(Self, Int) -> (Int, Int)
}

/// Graphs that can also walk their edges backwards. `Graph`, `StableGraph` and `Csr` keep both
/// directions, so this is O(1) to start and allocates nothing.
pub(open) trait Inbound {
  in_neighbors(Self, Int) -> ArrayView[Int]
  in_incident(Self, Int) -> ArrayView[Int]
}
```

A third party's graph joins by implementing `Topology`: nothing in the algorithm packages names a
concrete graph type, and an implementation that keeps its adjacency in another shape returns a
view of a copy.

### Graph

<!-- nocheck -->

```moonbit
pub struct Graph[N, E]

pub fn[N, E] Graph::new(directed~ : Bool = true) -> Graph[N, E]          // O(1)
pub fn[N, E] Graph::with_capacity(nodes? : Int, edges? : Int, directed~ : Bool = true) -> Graph[N, E]
pub fn[N, E] Graph::from_edges(edges : Array[(Int, Int)], node~ : N, edge~ : E, directed~ : Bool = true) -> Graph[N, E]   // O(V+E)

pub fn[N, E] Graph::add_node(self : Graph[N, E], data : N) -> Int         // O(1) amortised
pub fn[N, E] Graph::add_edge(self : Graph[N, E], from : Int, to : Int, data : E) -> Int   // O(1) amortised
pub fn[N, E] Graph::remove_node(self : Graph[N, E], node : Int) -> Unit   // O(V+E): renumbers
pub fn[N, E] Graph::remove_edge(self : Graph[N, E], edge : Int) -> Unit   // O(d)
pub fn[N, E] Graph::clear(self : Graph[N, E]) -> Unit                     // O(V+E)
pub fn[N, E] Graph::clear_edges(self : Graph[N, E]) -> Unit               // O(V+E)
pub fn[N, E] Graph::copy(self : Graph[N, E]) -> Graph[N, E]               // O(V+E)

pub fn[N, E] Graph::node_count(self : Graph[N, E]) -> Int                 // O(1)
pub fn[N, E] Graph::edge_count(self : Graph[N, E]) -> Int                 // O(1)
pub fn[N, E] Graph::directed(self : Graph[N, E]) -> Bool                  // O(1)
pub fn[N, E] Graph::contains_node(self : Graph[N, E], node : Int) -> Bool // O(1)
pub fn[N, E] Graph::contains_edge(self : Graph[N, E], edge : Int) -> Bool // O(1)
pub fn[N, E] Graph::find_edge(self : Graph[N, E], from : Int, to : Int) -> Int?      // O(min(d_out, d_in))
pub fn[N, E] Graph::find_edges(self : Graph[N, E], from : Int, to : Int) -> Array[Int]  // O(d_out)

pub fn[N, E] Graph::nodes(self : Graph[N, E]) -> Iter[Int]                // O(V)
pub fn[N, E] Graph::edges(self : Graph[N, E]) -> Iter[Int]                // O(E)
pub fn[N, E] Graph::neighbors(self : Graph[N, E], node : Int) -> ArrayView[Int]         // O(1)
pub fn[N, E] Graph::incident(self : Graph[N, E], node : Int) -> ArrayView[Int]          // O(1)
pub fn[N, E] Graph::in_neighbors(self : Graph[N, E], node : Int) -> ArrayView[Int]      // O(1)
pub fn[N, E] Graph::in_incident(self : Graph[N, E], node : Int) -> ArrayView[Int]       // O(1)
pub fn[N, E] Graph::endpoints(self : Graph[N, E], edge : Int) -> (Int, Int)             // O(1)

pub fn[N, E] Graph::node_data(self : Graph[N, E], node : Int) -> N        // O(1)
pub fn[N, E] Graph::edge_data(self : Graph[N, E], edge : Int) -> E        // O(1)
pub fn[N, E] Graph::set_node_data(self : Graph[N, E], node : Int, data : N) -> Unit     // O(1)
pub fn[N, E] Graph::set_edge_data(self : Graph[N, E], edge : Int, data : E) -> Unit     // O(1)
pub fn[N, E] Graph::weights(self : Graph[N, E], of : (E) -> Double) -> (Int) -> Double  // O(1)
```

`find_edge` returns the lowest-numbered edge between the pair; `find_edges` returns all of them in
number order. `neighbors` on a graph with parallel edges lists the same neighbour once per edge,
and `incident` gives each its own number; the caller deduplicates when it cares. A view is valid
until the next change to the graph.

### StableGraph

Same surface as `Graph`, except that `remove_node` leaves the number vacant and nothing is
renumbered. Two extra predicates make the holes visible.

<!-- nocheck -->

```moonbit
pub struct StableGraph[N, E]

pub fn[N, E] StableGraph::new(directed~ : Bool = true) -> StableGraph[N, E]
pub fn[N, E] StableGraph::add_node(self : StableGraph[N, E], data : N) -> Int
pub fn[N, E] StableGraph::add_edge(self : StableGraph[N, E], from : Int, to : Int, data : E) -> Int
pub fn[N, E] StableGraph::remove_node(self : StableGraph[N, E], node : Int) -> Unit   // O(d): keeps the hole
pub fn[N, E] StableGraph::remove_edge(self : StableGraph[N, E], edge : Int) -> Unit
pub fn[N, E] StableGraph::is_vacant(self : StableGraph[N, E], node : Int) -> Bool     // O(1)
pub fn[N, E] StableGraph::vacant_count(self : StableGraph[N, E]) -> Int               // O(1)
```

`node_count` counts occupied nodes; the highest number is a separate query, because the two differ
after a deletion.

### Csr

<!-- nocheck -->

```moonbit
pub struct Csr[N, E]

pub fn[N, E] Csr::from(graph : Graph[N, E]) -> Csr[N, E]                 // O(V+E) plus a sort
pub fn[N, E] Csr::from_stable(graph : StableGraph[N, E]) -> Csr[N, E]    // O(V+E) plus a sort
pub fn[N, E] Csr::node_count(self : Csr[N, E]) -> Int
pub fn[N, E] Csr::edge_count(self : Csr[N, E]) -> Int
pub fn[N, E] Csr::neighbors(self : Csr[N, E], node : Int) -> ArrayView[Int]         // O(1)
pub fn[N, E] Csr::incident(self : Csr[N, E], node : Int) -> ArrayView[Int]          // O(1)
pub fn[N, E] Csr::in_neighbors(self : Csr[N, E], node : Int) -> ArrayView[Int]      // O(1)
pub fn[N, E] Csr::in_incident(self : Csr[N, E], node : Int) -> ArrayView[Int]       // O(1)
pub fn[N, E] Csr::node_data(self : Csr[N, E], node : Int) -> N
pub fn[N, E] Csr::edge_data(self : Csr[N, E], edge : Int) -> E
pub fn[N, E] Csr::directed(self : Csr[N, E]) -> Bool                     // O(1)
pub fn[N, E] Csr::to_graph(self : Csr[N, E]) -> Graph[N, E]              // O(V+E)
```

`Csr` keeps both directions even for a directed graph, which is what makes `in_neighbors` O(d_in);
the cost is one extra array of edge numbers. It remembers whether the graph it was built from was
directed, so `to_graph` needs no flag.

### Matrix

<!-- nocheck -->

```moonbit
pub struct Matrix[E]

pub fn[E] Matrix::new(nodes : Int) -> Matrix[E]                          // O(V^2): every cell empty
pub fn[E] Matrix::get(self : Matrix[E], from : Int, to : Int) -> E?      // O(1)
pub fn[E] Matrix::set(self : Matrix[E], from : Int, to : Int, data : E) -> Unit       // O(1)
pub fn[E] Matrix::remove(self : Matrix[E], from : Int, to : Int) -> Unit              // O(1)
pub fn[E] Matrix::node_count(self : Matrix[E]) -> Int
pub fn[E] Matrix::edge_count(self : Matrix[E]) -> Int                    // O(1) kept as a counter
pub fn[E] Matrix::neighbors(self : Matrix[E], node : Int) -> ArrayView[Int]           // O(V): a new array
pub fn[E] Matrix::incident(self : Matrix[E], node : Int) -> ArrayView[Int]            // O(V): a new array
```

A cell holds at most one edge and starts empty, so `Matrix` cannot represent parallel edges; its
edge numbers are the cell index `from * V + to`, which is what makes it the right type for the
dense dynamic-programming passes (Floyd-Warshall weights, transitive closure).

### Keyed

The NetworkX hand feel over a number-keyed graph: keys in, keys out, numbers inside.

<!-- nocheck -->

```moonbit
pub struct Keyed[K, N, E]

pub fn[K : Hash + Eq, N, E] Keyed::new(graph~ : Graph[N, E]) -> Keyed[K, N, E]          // O(1)
pub fn[K : Hash + Eq, N, E] Keyed::add_node(self : Keyed[K, N, E], key : K, data : N) -> Int raise Refused   // O(1)
pub fn[K : Hash + Eq, N, E] Keyed::add_edge(self : Keyed[K, N, E], from : K, to : K, data : E) -> Int raise Refused  // O(1)
pub fn[K : Hash + Eq, N, E] Keyed::node(self : Keyed[K, N, E], key : K) -> Int?         // O(1)
pub fn[K : Hash + Eq, N, E] Keyed::key(self : Keyed[K, N, E], node : Int) -> K?         // O(1)
pub fn[K : Hash + Eq, N, E] Keyed::graph(self : Keyed[K, N, E]) -> Graph[N, E]          // O(1)
pub fn[K : Hash + Eq, N, E] Keyed::path(self : Keyed[K, N, E], paths : Paths, key : K) -> Array[K]?   // O(path)
pub fn[K : Hash + Eq, N, E] Keyed::scores(self : Keyed[K, N, E], scores : Scores) -> Map[K, Double]     // O(V log V)
```

Inserting through the wrapper needs the payload types, so they are its parameters. The wrapped graph
is always a `Graph`: a keyed view of a `Csr` would have nothing to insert into.

### Results

<!-- nocheck -->

```moonbit
pub(all) struct Paths {
  distance : Array[Double?]     // None: unreachable
  previous : Array[Int?]        // None at the source and at unreachable nodes
}

pub fn Paths::path_to(self : Paths, node : Int) -> Array[Int]?   // O(path)
pub fn Paths::reached(self : Paths, node : Int) -> Bool          // O(1)

pub(all) struct AllPairs {
  distance : Array[Array[Double?]]
  next : Array[Array[Int?]]
}

pub fn AllPairs::path(self : AllPairs, from : Int, to : Int) -> Array[Int]?   // O(path)
pub fn AllPairs::reached(self : AllPairs, from : Int, to : Int) -> Bool       // O(1)

pub(all) struct Flow {
  value : Double
  flow : Array[Double]          // by edge number
}

pub(all) struct Cut {
  value : Double
  source_side : Array[Bool]
}

pub(all) struct Matching {
  pairs : Array[(Int, Int)]     // each pair once, smaller number first
  weight : Double
}

pub(all) struct Cover {
  edges : Array[Int]            // by edge number
}

pub(all) struct Spanning {
  edges : Array[Int]            // V - 1 edge numbers, in the order they were chosen
  weight : Double
}

pub(all) struct Components {
  label : Array[Int]            // label[n]: the component of n
  count : Int
}

pub(all) struct Scores {
  score : Array[Double]
}

pub(all) struct Coloring {
  color : Array[Int]
  count : Int
}

pub(all) struct Partition {
  label : Array[Int]
  count : Int
}

pub(all) struct Cliques {
  members : Array[Array[Int]]   // each clique sorted, cliques ordered by first member
}

pub(all) struct Mapping {
  to : Array[Int]               // to[i]: the node of the second graph matching i
}
```

Every field is `pub(all)` and every array is indexed by node number (or edge number, for the ones
that say so). A caller that needs a record keyed by something else wraps it: `Keyed` maps numbers
back to keys, and `Partition` plus a `Array[K]` is a map from label to key set.

### Refusals

<!-- nocheck -->

```moonbit
pub(all) suberror Refused {
  NegativeWeight(edge~ : Int)
  Cycle(nodes~ : Array[Int])
  Disconnected(from~ : Int, to~ : Int)
  NoSolution
  NotA(kind~ : String, what~ : String)   // the graph is not a tree, not bipartite, not planar
  OutOfRange(node~ : Int)
}
```

`Cycle` carries a witness: the node sequence of one cycle, starting and ending at the same node.
`NotA` covers the predicates that take a graph and refuse to answer: `kind` is the property asked
for and `what` is the reason, so a caller can print one line without matching every case.

## traverse

<!-- nocheck -->

```moonbit
pub fn[G : Topology] bfs(graph : G, source : Int) -> Array[Int]              // O(V+E): order visited
pub fn[G : Topology] bfs_tree(graph : G, source : Int) -> Paths             // O(V+E): parent per node
pub fn[G : Topology] bfs_edges(graph : G, source : Int) -> Iter[(Int, Int)]  // O(V+E)
pub fn[G : Topology] bfs_layers(graph : G, sources : Array[Int]) -> Array[Array[Int]]  // O(V+E)
pub fn[G : Topology] bfs_beam(graph : G, source : Int, width~ : Int = 8) -> Array[Int] // O(V+E log width)

pub fn[G : Topology] dfs(graph : G, source : Int) -> Array[Int]             // O(V+E): preorder
pub fn[G : Topology] dfs_postorder(graph : G, source : Int) -> Array[Int]   // O(V+E)
pub fn[G : Topology] dfs_tree(graph : G, source : Int) -> Paths             // O(V+E)
pub fn[G : Topology] dfs_labeled(graph : G, source : Int) -> Array[(Int, Int, Int)]  // O(V+E): (from, to, kind)
pub fn[G : Topology] dfs_events(graph : G, source : Int) -> Iter[Event]  // O(V+E)

pub fn[G : Topology] edge_bfs(graph : G, source : Int) -> Iter[(Int, Int)]  // O(V+E): across components
pub fn[G : Topology] edge_dfs(graph : G, source : Int) -> Iter[(Int, Int)]  // O(V+E): across components
pub fn[G : Topology] descendants_at(graph : G, source : Int, distance : Int) -> Array[Int]  // O(V+E)
```

<!-- nocheck -->

```moonbit
pub(all) enum Event {
  Enter(node~ : Int)
  Leave(node~ : Int)
  Forward(edge~ : Int, to~ : Int)
  Back(edge~ : Int, to~ : Int)
}
```

`Event` is the four moments a depth-first walk can report: `Enter(node)`, `Leave(node)`,
`Forward(edge)`, `Back(edge)`. It replaces the visitor class hierarchy of Boost.Graph and the
callback objects of JGraphT; a caller reads them in a loop and stops the walk by leaving it.

Traversal never refuses: an out-of-range source yields an empty result rather than an error,
because a walk from a node that is not there is a no-op, not a contradiction.

## path

<!-- nocheck -->

```moonbit
pub fn[G : Topology] dijkstra(graph : G, source : Int, weight? : (Int) -> Double) -> Paths raise Refused   // O(E + V log V)
pub fn[G : Topology] dijkstra_multi(graph : G, sources : Array[Int], weight? : (Int) -> Double) -> Paths raise Refused  // O(E + V log V)
pub fn[G : Topology] dijkstra_bidirectional(graph : G, from : Int, to : Int, weight? : (Int) -> Double) -> Paths raise Refused  // O(E + V log V), about half the work
pub fn[G : Topology] bellman_ford(graph : G, source : Int, weight? : (Int) -> Double) -> Paths raise Refused   // O(V*E)
pub fn[G : Topology] spfa(graph : G, source : Int, weight? : (Int) -> Double) -> Paths raise Refused           // O(V*E) worst, O(k*E) expected
pub fn[G : Topology] johnson(graph : G, weight? : (Int) -> Double) -> AllPairs raise Refused                   // O(V*E log V)
pub fn[G : Topology] floyd_warshall(graph : G, weight? : (Int) -> Double) -> AllPairs raise Refused            // O(V^3)
pub fn[G : Topology] dijkstra_all(graph : G, weight? : (Int) -> Double) -> AllPairs raise Refused             // O(V*E log V)
pub fn[G : Topology] bfs_all(graph : G) -> AllPairs                                                                   // O(V*E), unweighted
pub fn[G : Topology] astar(graph : G, from : Int, to : Int, weight? : (Int) -> Double, estimate~ : (Int) -> Double) -> Paths raise Refused  // O(E log V)
pub fn[G : Topology] k_shortest(graph : G, from : Int, to : Int, k : Int, weight? : (Int) -> Double) -> Array[Array[Int]] raise Refused  // O(k*V*(E + V log V))
pub fn[G : Topology] widest(graph : G, source : Int, weight? : (Int) -> Double) -> Paths raise Refused         // O(E + V log V)
pub fn[G : Topology] shortest(graph : G, from : Int, to : Int, weight? : (Int) -> Double) -> Array[Int]? raise Refused  // O(chosen method)
pub fn[G : Topology] has_path(graph : G, from : Int, to : Int) -> Bool                                                // O(V+E)
pub fn[G : Topology] path_weight(graph : G, path : Array[Int], weight? : (Int) -> Double) -> Double raise Refused  // O(path * d)
```

Simple paths, which are exponential and so live in their own group:

<!-- nocheck -->

```moonbit
pub fn[G : Topology] all_simple(graph : G, from : Int, to : Int) -> Iter[Array[Int]]     // O(V+E) per path
pub fn[G : Topology] all_simple_edges(graph : G, from : Int, to : Int) -> Iter[Array[Int]]  // O(V+E) per path
pub fn[G : Topology] is_simple_path(graph : G, path : Array[Int]) -> Bool                 // O(path * d)
```

`dijkstra` refuses `NegativeWeight` and names the edge; a graph with negative edges is
`bellman_ford`'s job. `astar` additionally requires the estimate to be admissible and refuses
`NoSolution` when the walk closes without reaching the target. `johnson` refuses `NegativeWeight`
only for a *cycle*: negative edges are what its reweighting pass is for.

`bfs_all` exists because on an unweighted graph the plain sweep is the fastest all-pairs method,
and NetworkX users reach for it by reflex; naming it keeps them from calling `dijkstra` on a graph
where every weight is 1.

## component

<!-- nocheck -->

```moonbit
pub fn[G : Topology] components(graph : G) -> Components               // O(V+E)
pub fn[G : Topology] component_count(graph : G) -> Int                 // O(V+E)
pub fn[G : Topology] is_connected(graph : G) -> Bool                   // O(V+E)
pub fn[G : Topology] component_of(graph : G, node : Int) -> Array[Int] // O(V+E)

pub fn[G : Topology] strong_components(graph : G) -> Components        // O(V+E), Tarjan
pub fn[G : Topology] strong_components_kosaraju(graph : G) -> Components  // O(V+E), two passes
pub fn[G : Topology] is_strongly_connected(graph : G) -> Bool          // O(V+E)
pub fn[G : Topology] weak_components(graph : G) -> Components          // O(V+E)
pub fn[G : Topology] is_weakly_connected(graph : G) -> Bool            // O(V+E)
pub fn[G : Topology] is_semiconnected(graph : G) -> Bool               // O(V+E)
pub fn[G : Topology] condensation(graph : G) -> Condensation           // O(V+E)

pub fn[G : Topology] attracting_components(graph : G) -> Array[Array[Int]]  // O(V+E)

pub fn[G : Topology] biconnected_components(graph : G) -> Array[Array[Int]]  // O(V+E), edge sets
pub fn[G : Topology] biconnected_component_nodes(graph : G) -> Array[Array[Int]]  // O(V+E)
pub fn[G : Topology] is_biconnected(graph : G) -> Bool                  // O(V+E)
pub fn[G : Topology] articulation_points(graph : G) -> Array[Int]       // O(V+E)
pub fn[G : Topology] bridges(graph : G) -> Array[Int]                   // O(V+E), edge numbers
pub fn[G : Topology] has_bridges(graph : G) -> Bool                     // O(V+E)
pub fn[G : Topology] local_bridges(graph : G, span~ : Int = 1) -> Array[Int]  // O(V*E)
pub fn[G : Topology] chain_decomposition(graph : G) -> Array[Array[Int]]  // O(V+E)

pub fn[G : Topology] edge_boundary(graph : G, set : Array[Int]) -> Array[Int]  // O(V+E)
pub fn[G : Topology] node_boundary(graph : G, set : Array[Int]) -> Array[Int]  // O(V+E)
pub fn[G : Topology] reachable_count(graph : G, node : Int) -> Int      // O(V+E)
```

<!-- nocheck -->

```moonbit
pub(all) struct Condensation {
  graph : Graph[Int, Unit]      // one node per component, numbered by label
  of_node : Array[Int]          // of_node[n]: the component node of n
  members : Array[Array[Int]]   // members[c]: the nodes of component c
}
```

`strong_components` numbers components in reverse topological order of the condensation (the
order Tarjan produces them), and `condensation` relies on that: the component graph needs no
sorting pass. Both facts are part of the contract, because a caller that wants a topological
order of the components should not have to recompute it.

## flow

Capacity and cost are functions of the edge payload, exactly like weight. Flow values come back
indexed by edge number, and a solver refuses a graph that cannot carry an integer-valued answer
only if the caller asked for one.

<!-- nocheck -->

```moonbit
pub(all) enum FlowMethod {
  Dinitz
  PushRelabel
  EdmondsKarp
  BoykovKolmogorov
  ShortestAugmenting
}

pub fn[G : Topology] max_flow(graph : G, source : Int, sink : Int, capacity? : (Int) -> Double, method~ : FlowMethod = Dinitz) -> Flow raise Refused   // O(V^2*E) Dinitz, O(V^3) push-relabel
pub fn[G : Topology] max_flow_value(graph : G, source : Int, sink : Int, capacity? : (Int) -> Double) -> Double raise Refused   // O(max-flow)
pub fn[G : Topology] min_cut(graph : G, source : Int, sink : Int, capacity? : (Int) -> Double) -> Cut raise Refused              // O(max-flow)
pub fn[G : Topology] min_cut_global(graph : G, capacity? : (Int) -> Double) -> Cut                                              // O(V^3)
pub fn[G : Topology] all_min_cuts(graph : G, source : Int, sink : Int, capacity? : (Int) -> Double) -> Iter[Cut]                 // O(2^k * max-flow)
pub fn[G : Topology] gomory_hu(graph : G, capacity? : (Int) -> Double) -> Array[(Int, Int, Double)]                              // O(V * max-flow)

pub fn[G : Topology] min_cost_flow(graph : G, supply : Array[Double], cost? : (Int) -> Double, capacity? : (Int) -> Double) -> Flow raise Refused   // practical near O(V*E log V)
pub fn[G : Topology] max_flow_min_cost(graph : G, source : Int, sink : Int, cost? : (Int) -> Double, capacity? : (Int) -> Double) -> Flow raise Refused  // O(V*E log V * flow)
pub fn[G : Topology] flow_cost(graph : G, flow : Flow, cost? : (Int) -> Double) -> Double                                        // O(E)

pub fn[G : Topology] edge_connectivity(graph : G, capacity? : (Int) -> Double) -> Int                                            // O(V * max-flow)
pub fn[G : Topology] edge_connectivity_pair(graph : G, from : Int, to : Int) -> Int                                                      // O(max-flow)
pub fn[G : Topology] node_connectivity(graph : G) -> Int                                                                                 // O(V * max-flow)
pub fn[G : Topology] node_connectivity_pair(graph : G, from : Int, to : Int) -> Int                                                      // O(max-flow)
pub fn[G : Topology] min_edge_cut(graph : G) -> Array[Int]                                                                               // O(V * max-flow)
pub fn[G : Topology] min_node_cut(graph : G) -> Array[Int]                                                                               // O(V * max-flow)
pub fn[G : Topology] edge_disjoint_paths(graph : G, from : Int, to : Int) -> Array[Array[Int]]                                           // O(k * max-flow)
pub fn[G : Topology] node_disjoint_paths(graph : G, from : Int, to : Int) -> Array[Array[Int]]                                           // O(k * max-flow)
pub fn[G : Topology] k_edge_components(graph : G, k : Int) -> Array[Array[Int]]                                                          // O(k * V * max-flow)
pub fn[G : Topology] k_components(graph : G) -> Array[Array[Int]]                                                                         // O(V * max-flow)
```

`min_cost_flow` takes the excess per node directly (`supply[n] > 0` means n produces) and refuses
`Disconnected` when the supplies cannot be routed, with the two sides of the failed cut. `Flow`
always reports a feasible circulation, so a caller that only wants the cost calls `flow_cost`.

The connectivity family is in this package and not in `component` on purpose: every one of these
functions is a max-flow run in disguise, and keeping them here means the auxiliary-graph builders
(edge split for node connectivity, super-source for global edge connectivity) live next to the
solver that consumes them.

## matching

<!-- nocheck -->

```moonbit
pub fn[G : Topology] matching_maximal(graph : G) -> Matching                          // O(E)
pub fn[G : Topology] matching_maximum(graph : G, weight? : (Int) -> Double) -> Matching   // O(V^3) weighted, O(V*E) unweighted
pub fn[G : Topology] matching_bipartite(graph : G, weight? : (Int) -> Double) -> Matching // O(E*sqrt(V)) cardinality, O(V^3) weighted
pub fn[G : Topology] assignment(graph : G, weight~ : (Int) -> Double) -> Matching      // O(V^3)
pub fn[G : Topology] matching_min_weight(graph : G, weight~ : (Int) -> Double) -> Matching  // O(V^3)

pub fn[G : Topology] is_matching(graph : G, pairs : Array[(Int, Int)]) -> Bool        // O(V+E)
pub fn[G : Topology] is_maximal_matching(graph : G, pairs : Array[(Int, Int)]) -> Bool  // O(V+E)
pub fn[G : Topology] is_perfect_matching(graph : G, pairs : Array[(Int, Int)]) -> Bool  // O(V)

pub fn[G : Topology] edge_cover(graph : G) -> Cover                                   // O(V*E)
pub fn[G : Topology] is_edge_cover(graph : G, cover : Cover) -> Bool                  // O(V+E)
pub fn[G : Topology] vertex_cover_bipartite(graph : G) -> Array[Int]                  // O(E*sqrt(V))
```

`Matching.weight` is filled in every function that was given a weight, and is the number of pairs
when no weight was given. `matching_maximum` on a bipartite graph is not an error — it returns the
same answer by the general algorithm — but `matching_bipartite` is the one that is allowed to
assume the graph is bipartite and refuses `NotA("bipartite", ...)` when it is not.

## tree

<!-- nocheck -->

```moonbit
pub(all) enum SpanningMethod {
  Kruskal
  Prim
  Boruvka
}

pub fn[G : Topology] minimum_spanning(graph : G, weight? : (Int) -> Double, method~ : SpanningMethod = Kruskal) -> Spanning raise Refused  // O(E log V)
pub fn[G : Topology] maximum_spanning(graph : G, weight? : (Int) -> Double) -> Spanning raise Refused                                     // O(E log V)
pub fn[G : Topology] spanning_trees(graph : G, weight? : (Int) -> Double) -> Iter[Spanning]                                              // O(E log V) per tree
pub fn[G : Topology] random_spanning(graph : G, rng~ : &@contract.Rng) -> Spanning                                                        // O(V*E)
pub fn[G : Topology] spanning_count(graph : G) -> Double                                                                                        // O(V^3), a determinant
pub fn[G : Topology] minimum_branching(graph : G, weight? : (Int) -> Double, root? : Int = None) -> Spanning raise Refused               // O(V*E)
pub fn[G : Topology] maximum_branching(graph : G, weight? : (Int) -> Double, root? : Int = None) -> Spanning raise Refused               // O(V*E)
pub fn[G : Topology] branching_weight(graph : G, spanning : Spanning, weight? : (Int) -> Double) -> Double                               // O(E)

pub fn[G : Topology] steiner_tree(graph : G, terminals : Array[Int], weight? : (Int) -> Double) -> Spanning raise Refused               // O(2^k * V^2 + V*E log V)

pub fn[G : Topology] tree_center(graph : G) -> Array[Int] raise Refused       // O(V)
pub fn[G : Topology] tree_centroid(graph : G) -> Array[Int] raise Refused     // O(V)
pub fn[G : Topology] broadcast_center(graph : G) -> (Int, Int) raise Refused  // O(V): (node, worst delay)
pub fn[G : Topology] tree_depth(graph : G, root : Int) -> Array[Int] raise Refused  // O(V)
pub fn[G : Topology] subtree_sizes(graph : G, root : Int) -> Array[Int] raise Refused  // O(V)
pub fn[G : Topology] prufer_sequence(graph : G) -> Array[Int] raise Refused   // O(V)
pub fn from_prufer(sequence : Array[Int]) -> Graph[Int, Unit]                       // O(V)
pub fn to_nested(graph : Graph[Int, Unit], root : Int) -> Nested raise Refused      // O(V log V)
pub fn from_nested(nested : Nested) -> (Graph[Int, Unit], Int)                      // O(V)
```

A nested tuple is how a caller names the shape of a rooted tree without carrying node numbers.

<!-- nocheck -->

```moonbit
pub(all) enum Nested {
  Leaf(node~ : Int)
  Branch(children~ : Array[Nested])
}
```

Lowest common ancestor is a preprocessed object rather than a function, because the whole point is
to pay the preprocessing once.

<!-- nocheck -->

```moonbit
pub struct Lca

pub fn[G : Topology] Lca::new(graph : G, root : Int) -> Lca raise Refused   // O(V log V), binary lifting
pub fn Lca::of(self : Lca, a : Int, b : Int) -> Int?                              // O(log V)
pub fn Lca::depth(self : Lca, node : Int) -> Int                                  // O(1)
pub fn Lca::ancestor_at(self : Lca, node : Int, up : Int) -> Int?                 // O(log V)
```

`minimum_spanning` refuses `Disconnected`: a forest is not a spanning tree, and the caller who
wants the forest asks for `minimum_spanning` per component after `components`. `root? : Int = None`
on the branching functions means "find the best root"; giving one fixes it, which is the difference
between a branching and an arborescence.

## cycle

<!-- nocheck -->

```moonbit
pub fn[G : Topology] is_cyclic(graph : G) -> Bool                                    // O(V+E)
pub fn[G : Topology] find_cycle(graph : G) -> Array[Int]?                            // O(V+E), a witness
pub fn[G : Topology] cycle_basis(graph : G) -> Array[Array[Int]]                     // O(V*E)
pub fn[G : Topology] minimum_cycle_basis(graph : G, weight? : (Int) -> Double) -> Array[Array[Int]]  // O(V*E^2)
pub fn[G : Topology] simple_cycles(graph : G) -> Iter[Array[Int]]                    // O((V+E)(c+1))
pub fn[G : Topology] chordless_cycles(graph : G, length_bound? : Int) -> Iter[Array[Int]]  // O(V*E) per cycle
pub fn[G : Topology] girth(graph : G) -> Int?                                        // O(V*E)

pub fn[G : Topology] is_eulerian(graph : G) -> Bool                                  // O(V+E)
pub fn[G : Topology] has_eulerian_path(graph : G) -> Bool                            // O(V+E)
pub fn[G : Topology] eulerian_circuit(graph : G) -> Array[Int] raise Refused         // O(V+E), edge numbers
pub fn[G : Topology] eulerian_path(graph : G) -> Array[Int]?                         // O(V+E)
pub fn[G : Topology] eulerize(graph : G) -> Array[(Int, Int)]                        // O(V^3): edges to duplicate

pub fn[G : Topology] feedback_arc_set(graph : G) -> Array[Int] raise Refused         // O(V*E) greedy
pub fn[G : Topology] chinese_postman(graph : G, weight? : (Int) -> Double) -> Array[Int] raise Refused  // O(V^3)
pub fn[G : Topology] min_cycle_ratio(graph : G, cost~ : (Int) -> Double, weight? : (Int) -> Double) -> Double raise Refused  // O(V*E)
```

## dag

<!-- nocheck -->

```moonbit
pub fn[G : Topology] topological_order(graph : G) -> Array[Int] raise Refused         // O(V+E)
pub fn[G : Topology] is_dag(graph : G) -> Bool                                        // O(V+E)
pub fn[G : Topology] all_topological_orders(graph : G) -> Iter[Array[Int]]            // O(V+E) per order
pub fn[G : Topology] topological_generations(graph : G) -> Array[Array[Int]] raise Refused  // O(V+E)
pub fn[G : Topology] topological_smallest(graph : G) -> Array[Int] raise Refused      // O((V+E) log V)

pub fn[G : Topology] ancestors(graph : G, node : Int) -> Array[Int]                   // O(V+E)
pub fn[G : Topology] descendants(graph : G, node : Int) -> Array[Int]                 // O(V+E)
pub fn[G : Topology] transitive_closure(graph : G) -> Array[Array[Bool]]              // O(V*E)
pub fn[G : Topology] transitive_reduction(graph : G) -> Array[(Int, Int)]             // O(V*E), edges to keep
pub fn[G : Topology] longest_path(graph : G, weight? : (Int) -> Double) -> Array[Int] raise Refused  // O(V+E)
pub fn[G : Topology] longest_path_length(graph : G, weight? : (Int) -> Double) -> Double raise Refused  // O(V+E)

pub fn[G : Topology] antichains(graph : G) -> Array[Array[Int]]                       // O(V*E)
pub fn[G : Topology] is_aperiodic(graph : G) -> Bool                                  // O(V*E)
pub fn[G : Topology] colliders(graph : G) -> Array[Int]                               // O(V*d^2)
pub fn[G : Topology] dominators(graph : G, entry : Int) -> Array[Int?]                // O(E log V), Lengauer-Tarjan
pub fn[G : Topology] dominance_frontiers(graph : G, entry : Int) -> Array[Array[Int]] // O(E log V)
```

The incremental sorter is the one piece of stateful API in this package: a build system feeds it
nodes as they become known and asks which are ready, without restarting the walk.

<!-- nocheck -->

```moonbit
pub struct Sorter

pub fn[G : Topology] Sorter::new(graph : G) -> Sorter                    // O(V+E)
pub fn[G : Topology] Sorter::add(self : Sorter, node : Int, after : Array[Int]) -> Unit raise Refused  // O(d)
pub fn Sorter::ready(self : Sorter) -> Array[Int] raise Refused                // O(d) amortised
pub fn Sorter::finish(self : Sorter, nodes : Array[Int]) -> Unit raise Refused // O(d)
pub fn Sorter::is_active(self : Sorter) -> Bool                                // O(1)
pub fn Sorter::order(self : Sorter) -> Array[Int] raise Refused                // O(V+E)
```

`topological_order` refuses `Cycle` with the cycle as witness, which is what every reference does
(NetworkX raises, JGraphT throws, `graphlib` raises `CycleError`) and what a caller needs in order
to point at the offending edge. There is no "best effort partial order" mode: a partial order that
silently drops edges is how build systems ship broken release orders.

## color

<!-- nocheck -->

```moonbit
pub(all) enum ColoringOrder {
  LargestFirst
  SmallestLast
  SaturationLargest
  ConnectedSequential
  RandomSequential
}

pub fn[G : Topology] greedy_coloring(graph : G, order~ : ColoringOrder = LargestFirst, rng? : &@contract.Rng) -> Coloring   // O(V+E) plus the sort
pub fn[G : Topology] dsatur(graph : G) -> Coloring                                    // O(V^2)
pub fn[G : Topology] equitable_coloring(graph : G, colors : Int) -> Coloring raise Refused  // O(V^2)
pub fn[G : Topology] edge_coloring(graph : G) -> Coloring                            // O(V*E)
pub fn[G : Topology] is_coloring(graph : G, coloring : Coloring) -> Bool              // O(V+E)
pub fn[G : Topology] is_edge_coloring(graph : G, coloring : Coloring) -> Bool         // O(V+E)
pub fn[G : Topology] chromatic_number(graph : G, limit~ : Int = 32) -> Int raise Refused  // exponential
```

`chromatic_number` refuses `NoSolution` when `limit` colors are not enough, rather than returning a
number that would quietly mean "at least this many". The `limit` has a default because a caller
that does not care wants an answer, not a configuration parameter.

## clique

<!-- nocheck -->

```moonbit
pub fn[G : Topology] maximal_cliques(graph : G) -> Cliques                            // O(3^(V/3)) worst
pub fn[G : Topology] all_cliques(graph : G, at_least~ : Int = 1) -> Iter[Array[Int]]   // O(#cliques * V)
pub fn[G : Topology] max_weight_clique(graph : G, weight? : (Int) -> Double) -> Cliques   // exponential
pub fn[G : Topology] clique_number(graph : G) -> Int                                  // O(3^(V/3))
pub fn[G : Topology] clique_numbers(graph : G) -> Array[Int]                          // O(#cliques * V)
pub fn[G : Topology] is_clique(graph : G, nodes : Array[Int]) -> Bool                 // O(k^2)
pub fn[G : Topology] independent_set(graph : G) -> Array[Int]                         // exponential
pub fn[G : Topology] independence_number(graph : G) -> Int                             // exponential
pub fn[G : Topology] clique_graph(graph : G) -> Graph[Int, Unit]                      // O(V^2)

pub fn[G : Topology] is_chordal(graph : G) -> Bool                                     // O(V+E)
pub fn[G : Topology] chordal_cliques(graph : G) -> Cliques raise Refused               // O(V+E)
pub fn[G : Topology] chordal_treewidth(graph : G) -> Int raise Refused                 // O(V+E)
pub fn[G : Topology] chordal_fill_in(graph : G) -> Array[(Int, Int)] raise Refused      // O(V+E)
pub fn[G : Topology] is_perfect(graph : G) -> Bool                                     // O(V^5)
```

## iso

Two graphs of different payload types can be compared, so the trait parameters are separate.

<!-- nocheck -->

```moonbit
pub fn[GA : Topology, GB : Topology] is_isomorphic(a : GA, b : GB) -> Bool   // exponential worst, near linear after refinement
pub fn[GA : Topology, GB : Topology] isomorphism(a : GA, b : GB) -> Mapping?  // exponential worst
pub fn[GA : Topology, GB : Topology] all_isomorphisms(a : GA, b : GB) -> Iter[Mapping]  // exponential in the count
pub fn[GA : Topology, GB : Topology] is_subgraph_isomorphic(pattern : GA, host : GB) -> Bool  // exponential worst
pub fn[GA : Topology, GB : Topology] subgraph_isomorphisms(pattern : GA, host : GB) -> Iter[Mapping]  // exponential in the count
pub fn[G : Topology] tree_isomorphism(a : G, b : G) -> Mapping?                        // O(V) via AHU strings
pub fn[G : Topology] weisfeiler_lehman(graph : G, rounds~ : Int = 3) -> Array[Int]      // O(rounds*(V+E))
pub fn[G : Topology] graph_hash(graph : G, rounds~ : Int = 3) -> UInt64                 // O(rounds*(V+E))
pub fn[G : Topology] canonical_form(graph : G) -> Array[Int]                            // exponential worst
```

Payload compatibility is a parameter of the matcher, not nine separate `*_match` functions:

<!-- nocheck -->

```moonbit
pub struct Matcher

pub fn[GA : Topology, GB : Topology] Matcher::new(
  pattern~ : GA,
  host~ : GB,
  node_match? : (Int, Int) -> Bool,
  edge_match? : (Int, Int) -> Bool,
) -> Matcher

pub fn Matcher::is_isomorphic(self : Matcher) -> Bool
pub fn Matcher::is_subgraph_isomorphic(self : Matcher, induced~ : Bool = true) -> Bool
pub fn Matcher::mappings(self : Matcher) -> Iter[Mapping]
pub fn Matcher::count(self : Matcher) -> Int
```

`canonical_form` returns a permutation, not a graph: the caller permutes its own payloads, which is
what makes the result useful for hashing without copying.

## centrality

Every function returns a `Scores` indexed by node number, so a caller can compare two centralities
element by element without translating a map into an array.

<!-- nocheck -->

```moonbit
pub fn[G : Topology] degree_centrality(graph : G) -> Scores                            // O(V+E)
pub fn[G : Topology] closeness(graph : G, weight? : (Int) -> Double, normalized~ : Bool = false) -> Scores   // O(V*E + V^2 log V) weighted
pub fn[G : Topology] betweenness(graph : G, weight? : (Int) -> Double, normalized~ : Bool = false, endpoints~ : Bool = false) -> Scores  // O(V*E) unweighted, O(V*E + V^2 log V) weighted
pub fn[G : Topology] edge_betweenness(graph : G, weight? : (Int) -> Double, normalized~ : Bool = false) -> Scores  // O(V*E)
pub fn[G : Topology] harmonic(graph : G, weight? : (Int) -> Double, cutoff? : Int) -> Scores   // O(V*E)
pub fn[G : Topology] eigenvector(graph : G, weight? : (Int) -> Double, limit~ : Int = 100, tolerance~ : Double = 1e-8) -> Scores raise Refused  // O(limit*E)
pub fn[G : Topology] katz(graph : G, alpha~ : Double = 0.1, beta~ : Double = 1.0, limit~ : Int = 100, tolerance~ : Double = 1e-8, weight? : (Int) -> Double) -> Scores raise Refused  // O(limit*E)
pub fn[G : Topology] pagerank(graph : G, damping~ : Double = 0.85, tolerance~ : Double = 1e-8, limit~ : Int = 100, weight? : (Int) -> Double, personal? : Array[Double] = None) -> Scores raise Refused  // O(limit*E)
pub fn[G : Topology] hits(graph : G, limit~ : Int = 100, tolerance~ : Double = 1e-8, weight? : (Int) -> Double) -> (Scores, Scores) raise Refused  // O(limit*E)
pub fn[G : Topology] load(graph : G, weight? : (Int) -> Double) -> Scores        // O(V*E)
pub fn[G : Topology] percolation(graph : G) -> Scores                                  // O(V*E)
pub fn[G : Topology] voterank(graph : G, number~ : Int = 5) -> Array[Int]              // O(number*V*E)
pub fn[G : Topology] birank(graph : G, limit~ : Int = 100, tolerance~ : Double = 1e-8) -> (Scores, Scores) raise Refused  // O(limit*E)

pub fn[G : Topology] closeness_group(graph : G, group : Array[Int], weight? : (Int) -> Double) -> Double       // O(V*E)
pub fn[G : Topology] betweenness_group(graph : G, group : Array[Int], weight? : (Int) -> Double) -> Double      // O(V*E)
pub fn[G : Topology] degree_group(graph : G, group : Array[Int]) -> Double                                         // O(V+E)

pub fn[G : Topology] current_flow_betweenness(graph : G, capacity? : (Int) -> Double) -> Scores                 // O(V^3)
pub fn[G : Topology] subgraph_centrality(graph : G, approximate~ : Bool = false) -> Scores                             // O(V^3)
pub fn[G : Topology] laplacian_centrality(graph : G, weight? : (Int) -> Double) -> Scores                      // O(V^3)
pub fn[G : Topology] trophic_levels(graph : G) -> Scores raise Refused                                                // O(V*E)
pub fn[G : Topology] dispersion(graph : G, node : Int) -> Double                                                      // O(V*E)
```

`normalized~ : Bool = false` everywhere. NetworkX normalises by default and igraph does not, and the
two conventions are the main reason two libraries disagree about the *same* graph; a raw value is
the one that composes (a caller can normalise when it knows the size it wants), and the doc comment
of each function states the normalising constant so a caller can reproduce NetworkX's number in one
line.

`pagerank` refuses `Disconnected` only when `personal` is given and the personalisation vector puts
all its mass on nodes that cannot reach the dangling ones; otherwise it redistributes the dangling
mass uniformly, which is what every reference does and what keeps the sum at 1.

## community

<!-- nocheck -->

```moonbit
pub(all) struct CommunitySettings {
  resolution : Double         // 1.0
  limit : Int                 // 100 rounds per level
  tolerance : Double          // 1e-7 change in modularity
}

pub let community_settings : CommunitySettings

pub fn[G : Topology] louvain(graph : G, weight? : (Int) -> Double, community_settings~ : CommunitySettings = community_settings, rng~ : &@contract.Rng) -> Partition   // O(E) per level
pub fn[G : Topology] louvain_levels(graph : G, weight? : (Int) -> Double, community_settings~ : CommunitySettings = community_settings, rng~ : &@contract.Rng) -> Array[Partition]  // O(E log V)
pub fn[G : Topology] leiden(graph : G, weight? : (Int) -> Double, community_settings~ : CommunitySettings = community_settings, rng~ : &@contract.Rng) -> Partition   // O(E) per level
pub fn[G : Topology] label_propagation(graph : G, limit~ : Int = 100, rng~ : &@contract.Rng) -> Partition        // O(limit*E)
pub fn[G : Topology] greedy_modularity(graph : G, weight? : (Int) -> Double, resolution~ : Double = 1.0) -> Partition   // O(E log^2 V)
pub fn[G : Topology] girvan_newman(graph : G, weight? : (Int) -> Double) -> Iter[Partition]                     // O(V*E^2)
pub fn[G : Topology] kernighan_lin(graph : G, weight? : (Int) -> Double, rng~ : &@contract.Rng) -> Partition  // O(V^2 log V)
pub fn[G : Topology] fluid(graph : G, communities : Int, limit~ : Int = 100, rng~ : &@contract.Rng) -> Partition  // O(limit*E)
pub fn[G : Topology] source_expansion(graph : G, seeds : Array[Int]) -> Partition                                      // O(V*E)
pub fn[G : Topology] k_clique_communities(graph : G, k : Int) -> Array[Array[Int]]                                     // exponential in k

pub fn[G : Topology] modularity(graph : G, partition : Partition, weight? : (Int) -> Double, resolution~ : Double = 1.0) -> Double  // O(V+E)
pub fn[G : Topology] is_partition(graph : G, partition : Partition) -> Bool                                            // O(V)
pub fn compare_partitions(a : Partition, b : Partition) -> Double                                                             // O(V)
```

Every randomised community function takes the generator explicitly (no default seed), because a
default seed is how a test starts passing on one platform and failing on another. The settings
record carries the three numbers that every reference exposes and that nobody agrees on; the preset
takes NetworkX's values, documented in the record's doc comment.

## metric

<!-- nocheck -->

```moonbit
pub fn[G : Topology] density(graph : G) -> Double                                      // O(1)
pub fn[G : Topology] degree_histogram(graph : G) -> Array[Int]                          // O(V+E)
pub fn[G : Topology] eccentricity(graph : G, weight? : (Int) -> Double) -> Array[Double?]  // O(V*E)
pub fn[G : Topology] diameter(graph : G, weight? : (Int) -> Double) -> Double?  // O(V*E)
pub fn[G : Topology] radius(graph : G, weight? : (Int) -> Double) -> Double?     // O(V*E)
pub fn[G : Topology] center(graph : G, weight? : (Int) -> Double) -> Array[Int]  // O(V*E)
pub fn[G : Topology] periphery(graph : G, weight? : (Int) -> Double) -> Array[Int]  // O(V*E)
pub fn[G : Topology] centroid(graph : G) -> Array[Int] raise Refused                     // O(V)
pub fn[G : Topology] average_path_length(graph : G, weight? : (Int) -> Double) -> Double raise Refused  // O(V*E)
pub fn[G : Topology] wiener_index(graph : G, weight? : (Int) -> Double) -> Double  // O(V*E)

pub fn[G : Topology] triangles(graph : G) -> Array[Int]                                  // O(V*d^2)
pub fn[G : Topology] triangle_count(graph : G) -> Int                                    // O(V*d^2)
pub fn[G : Topology] clustering(graph : G) -> Array[Double]                              // O(V*d^2)
pub fn[G : Topology] average_clustering(graph : G, samples? : Int) -> Double              // O(V*d^2) exact
pub fn[G : Topology] transitivity(graph : G) -> Double                                   // O(V*d^2)
pub fn[G : Topology] square_clustering(graph : G) -> Array[Double]                        // O(V*d^2)

pub fn[G : Topology] assortativity_degree(graph : G, weight? : (Int) -> Double) -> Double?  // O(V+E)
pub fn[G : Topology] assortativity_attribute(graph : G, values : Array[Double]) -> Double?           // O(V+E)
pub fn[G : Topology] average_neighbor_degree(graph : G) -> Array[Double]                  // O(V+E)

pub fn[G : Topology] link_prediction(graph : G, pairs : Array[(Int, Int)], weight? : (Int) -> Double, kind~ : LinkKind = Jaccard) -> Array[Double]  // O(pairs*d^2)
pub fn[G : Topology] jaccard(graph : G, a : Int, b : Int) -> Double                       // O(d)
pub fn[G : Topology] adamic_adar(graph : G, a : Int, b : Int) -> Double                   // O(d log d)
pub fn[G : Topology] resource_allocation(graph : G, a : Int, b : Int) -> Double            // O(d)
pub fn[G : Topology] preferential_attachment(graph : G, a : Int, b : Int) -> Double        // O(1)

pub fn[G : Topology] global_efficiency(graph : G, weight? : (Int) -> Double) -> Double   // O(V*E)
pub fn[G : Topology] local_efficiency(graph : G, weight? : (Int) -> Double) -> Array[Double]  // O(V*E)
pub fn[G : Topology] s_metric(graph : G) -> Double                                        // O(E)
pub fn[G : Topology] rich_club(graph : G, weight? : (Int) -> Double) -> Array[Double]  // O(V*E)
pub fn[G : Topology] triads(graph : G) -> Array[Int]                                      // O(V*d^2)
pub fn[G : Topology] reciprocity(graph : G) -> Double                                     // O(V+E)
pub fn[G : Topology] non_randomness(graph : G, weight? : (Int) -> Double) -> (Double, Double)  // O(V^3)

pub fn[G : Topology] cut_size(graph : G, set : Array[Int], weight? : (Int) -> Double) -> Double   // O(V+E)
pub fn[G : Topology] volume(graph : G, set : Array[Int], weight? : (Int) -> Double) -> Double     // O(V+E)
pub fn[G : Topology] conductance(graph : G, set : Array[Int], weight? : (Int) -> Double) -> Double  // O(V+E)
pub fn[G : Topology] normalized_cut(graph : G, set : Array[Int], weight? : (Int) -> Double) -> Double  // O(V+E)

pub fn[G : Topology] resistance_distance(graph : G, from : Int, to : Int) -> Double raise Refused   // O(V^3)
pub fn[G : Topology] kemeny_constant(graph : G) -> Double raise Refused                             // O(V^3)
pub fn[G : Topology] chromatic_polynomial(graph : G) -> Array[Int]                                  // exponential
pub fn[G : Topology] tutte_polynomial(graph : G) -> Array[Array[Int]]                               // exponential
```

<!-- nocheck -->

```moonbit
pub(all) enum LinkKind {
  Jaccard
  AdamicAdar
  ResourceAllocation
  PreferentialAttachment
  CommonNeighbors
}
```

The two polynomials come back as coefficient arrays (`chromatic_polynomial[k]` is the coefficient of
`x^k`, highest degree first) rather than as a symbolic object: there is no polynomial type in this
library, and inventing one for two functions would be a second algebra to maintain.

## struct

<!-- nocheck -->

```moonbit
pub fn[G : Topology] is_tree(graph : G) -> Bool                                       // O(V+E)
pub fn[G : Topology] is_forest(graph : G) -> Bool                                     // O(V+E)
pub fn[G : Topology] is_arborescence(graph : G) -> Bool                               // O(V+E)
pub fn[G : Topology] is_branching(graph : G) -> Bool                                  // O(V+E)
pub fn[G : Topology] is_bipartite(graph : G) -> Bool                                  // O(V+E)
pub fn[G : Topology] bipartition(graph : G) -> (Array[Int], Array[Int]) raise Refused  // O(V+E)
pub fn[G : Topology] is_planar(graph : G) -> Bool                                     // O(V+E)
pub fn[G : Topology] is_isolate(graph : G, node : Int) -> Bool                        // O(1)
pub fn[G : Topology] isolates(graph : G) -> Array[Int]                                // O(V)
pub fn[G : Topology] is_regular(graph : G) -> Bool                                    // O(V+E)
pub fn[G : Topology] is_tournament(graph : G) -> Bool                                 // O(V^2)
pub fn[G : Topology] score_sequence(graph : G) -> Array[Int]                          // O(V*d)
pub fn[G : Topology] is_threshold(graph : G) -> Bool                                  // O(V+E)
pub fn[G : Topology] is_distance_regular(graph : G) -> Bool                            // O(V^3)
pub fn[G : Topology] is_at_free(graph : G) -> Bool                                    // O(V^3)

pub fn is_graphical(degrees : Array[Int]) -> Bool                                           // O(V log V)
pub fn is_digraphical(degrees : Array[(Int, Int)]) -> Bool                                   // O(V log V)
pub fn is_multigraphical(degrees : Array[Int]) -> Bool                                       // O(V log V)

pub fn[G : Topology] core_numbers(graph : G) -> Array[Int]                             // O(V+E)
pub fn[G : Topology] k_core(graph : G, k : Int) -> Array[Int]                          // O(V+E)
pub fn[G : Topology] k_shell(graph : G, k : Int) -> Array[Int]                         // O(V+E)
pub fn[G : Topology] k_truss(graph : G, k : Int) -> Array[Int]                         // O(E^1.5)
pub fn[G : Topology] onion_layers(graph : G) -> Array[Int]                             // O(V+E)

pub fn[G : Topology] d_separator(graph : G, x : Array[Int], y : Array[Int], z : Array[Int]) -> Bool  // O(V+E)
pub fn[G : Topology] minimal_d_separator(graph : G, x : Array[Int], y : Array[Int]) -> Array[Int]?   // O(V*E)
pub fn[G : Topology] moral_graph(graph : G) -> Graph[Int, Unit]                        // O(V*d^2)

pub fn[G : Topology] planarity_embedding(graph : G) -> Array[Array[Int]]?              // O(V+E)
```

## op

<!-- nocheck -->

```moonbit
pub fn[GA : Topology, GB : Topology] union(a : GA, b : GB) -> Graph[Unit, Unit]     // O(V+E)
pub fn[GA : Topology, GB : Topology] intersection(a : GA, b : GB) -> Graph[Unit, Unit]  // O(V+E)
pub fn[GA : Topology, GB : Topology] difference(a : GA, b : GB) -> Graph[Unit, Unit]    // O(V+E)
pub fn[GA : Topology, GB : Topology] symmetric_difference(a : GA, b : GB) -> Graph[Unit, Unit]  // O(V+E)
pub fn[GA : Topology, GB : Topology] compose(a : GA, b : GB) -> Graph[Unit, Unit]   // O(V+E)
pub fn[G : Topology] complement(graph : G) -> Graph[Unit, Unit]                                  // O(V^2)
pub fn[G : Topology] reverse(graph : G) -> Graph[Unit, Unit]                                    // O(V+E)
pub fn[G : Topology] to_undirected(graph : G, merge~ : Bool = true) -> Graph[Unit, Unit]        // O(V+E)
pub fn[G : Topology] to_directed(graph : G) -> Graph[Unit, Unit]                                // O(V+E)

pub(all) enum Product {
  Cartesian
  Lexicographic
  Strong
  Tensor
  Rooted
  Corona
  Modular
}

pub fn[GA : Topology, GB : Topology] product(a : GA, b : GB, kind~ : Product) -> Graph[Unit, Unit]  // O(V1*V2 + E1*V2 + E2*V1)
pub fn[G : Topology] power(graph : G, k : Int) -> Graph[Unit, Unit]                              // O(k*V*E)

pub fn[G : Topology] subgraph(graph : G, nodes : Array[Int]) -> Graph[Unit, Unit]                // O(subgraph)
pub fn[G : Topology] edge_subgraph(graph : G, edges : Array[Int]) -> Graph[Unit, Unit]           // O(subgraph)
pub fn[G : Topology] ego_graph(graph : G, node : Int, radius : Int) -> Graph[Unit, Unit]         // O(V+E)
pub fn[G : Topology] contract(graph : G, a : Int, b : Int) -> Graph[Unit, Unit]                  // O(V+E)
pub fn[G : Topology] quotient(graph : G, partition : Partition) -> Graph[Unit, Unit]             // O(V+E)
pub fn[G : Topology] line_graph(graph : G) -> Graph[Unit, Unit]                                  // O(V+E)
pub fn[G : Topology] simplify(graph : G, merge~ : Bool = true, self_loops~ : Bool = false) -> Graph[Unit, Unit]  // O(V+E)
pub fn[G : Topology] relabel(graph : G, mapping : Array[Int]) -> Graph[Unit, Unit]               // O(V+E)
pub fn[G : Topology] project_bipartite(graph : G, side : Array[Bool], weight? : (Int) -> Double) -> Graph[Unit, Unit]  // O(V*E)
```

Every operator returns `Graph[Unit, Unit]`: two graphs with different payload types have no payload
type in common, and inventing one (a tuple, a sum) means the caller unpacks every element anyway.
A caller that wants to keep payloads applies the operator and then `set_node_data` /
`set_edge_data` on the result, which is one pass and explicit.

`subgraph` copies. There is no lazy view type: MoonBit has no lifetimes to tie a view to the graph
it borrows, and a view that owns a copy is a copy with extra steps. The cost is documented on the
function; the benefit is that a result can outlive the graph it came from.

## approx

Every function here documents its guarantee. A caller that needs optimality calls the exact
function in the package named in the row, and pays for it.

<!-- nocheck -->

```moonbit
pub(all) enum TourMethod {
  NearestNeighbor
  NearestInsertion
  TwoOpt
  Christofides
  Palmer
}

pub fn[G : Topology] tour(graph : G, weight? : (Int) -> Double, method~ : TourMethod = NearestNeighbor, rng? : &@contract.Rng) -> Array[Int]  // O(V^2) construction, O(V^2) per 2-opt pass
pub fn[G : Topology] tour_length(graph : G, tour : Array[Int], weight? : (Int) -> Double) -> Double   // O(V)
pub fn[G : Topology] vertex_cover(graph : G, weight? : (Int) -> Double) -> Array[Int]                 // O(V*E): 2-approximate
pub fn[G : Topology] dominating_set(graph : G) -> Array[Int]                                                  // O(V*E)
pub fn[G : Topology] densest_subgraph(graph : G, weight? : (Int) -> Double) -> Array[Int]              // O(log V * max-flow)
pub fn[G : Topology] spanner(graph : G, stretch~ : Int = 2, weight? : (Int) -> Double) -> Array[Int]    // O(V*E): edge numbers kept
pub fn[G : Topology] max_cut(graph : G, weight? : (Int) -> Double, rng? : &@contract.Rng) -> (Array[Bool], Double)  // O(V*E) per pass
pub fn[G : Topology] treewidth_upper(graph : G, fill~ : Bool = false) -> Int                                  // O(V^2)
```

## gen

<!-- nocheck -->

```moonbit
pub fn empty(nodes : Int) -> Graph[Unit, Unit]                                          // O(V)
pub fn path(nodes : Int) -> Graph[Unit, Unit]                                            // O(V)
pub fn cycle(nodes : Int) -> Graph[Unit, Unit]                                           // O(V)
pub fn complete(nodes : Int) -> Graph[Unit, Unit]                                        // O(V^2)
pub fn complete_bipartite(left : Int, right : Int) -> Graph[Unit, Unit]                  // O(V^2)
pub fn complete_multipartite(sizes : Array[Int]) -> Graph[Unit, Unit]                    // O(V^2)
pub fn star(leaves : Int) -> Graph[Unit, Unit]                                           // O(V)
pub fn wheel(spokes : Int) -> Graph[Unit, Unit]                                          // O(V)
pub fn ladder(rungs : Int) -> Graph[Unit, Unit]                                          // O(V)
pub fn barbell(m : Int, n : Int) -> Graph[Unit, Unit]                                    // O(V)
pub fn lollipop(m : Int, n : Int) -> Graph[Unit, Unit]                                   // O(V)
pub fn turan(n : Int, parts : Int) -> Graph[Unit, Unit]                                   // O(V^2)
pub fn circulant(n : Int, offsets : Array[Int]) -> Graph[Unit, Unit]                      // O(V*offsets)
pub fn petersen() -> Graph[Unit, Unit]                                                   // O(1)
pub fn generalized_petersen(n : Int, k : Int) -> Graph[Unit, Unit]                        // O(V)
pub fn grid(width : Int, height : Int) -> Graph[Unit, Unit]                               // O(V)
pub fn hypercube(dimension : Int) -> Graph[Unit, Unit]                                    // O(V*d)
pub fn triangular_lattice(width : Int, height : Int) -> Graph[Unit, Unit]                 // O(V)
pub fn hexagonal_lattice(width : Int, height : Int) -> Graph[Unit, Unit]                  // O(V)
pub fn balanced_tree(branching : Int, height : Int) -> Graph[Unit, Unit]                  // O(V)
pub fn full_rary_tree(branching : Int, nodes : Int) -> Graph[Unit, Unit]                  // O(V)
pub fn tree_from_prufer(sequence : Array[Int]) -> Graph[Unit, Unit]                        // O(V)

pub fn erdos_renyi(nodes : Int, probability~ : Double, rng~ : &@contract.Rng) -> Graph[Unit, Unit]     // O(V+E) expected
pub fn erdos_renyi_edges(nodes : Int, edges : Int, rng~ : &@contract.Rng) -> Graph[Unit, Unit]          // O(V+E)
pub fn barabasi_albert(nodes : Int, attach : Int, rng~ : &@contract.Rng) -> Graph[Unit, Unit]           // O(V log V)
pub fn watts_strogatz(nodes : Int, neighbours : Int, probability~ : Double, rng~ : &@contract.Rng) -> Graph[Unit, Unit]  // O(V*k)
pub fn random_regular(nodes : Int, degree : Int, rng~ : &@contract.Rng) -> Graph[Unit, Unit] raise Refused  // O(V*d)
pub fn configuration(degrees : Array[Int], rng~ : &@contract.Rng) -> Graph[Unit, Unit]                 // O(V+E)
pub fn stochastic_block(sizes : Array[Int], probability~ : (Int, Int) -> Double, rng~ : &@contract.Rng) -> Graph[Unit, Unit]  // O(V^2)
pub fn random_tree(nodes : Int, rng~ : &@contract.Rng) -> Graph[Unit, Unit]                              // O(V)
pub fn random_tournament(nodes : Int, rng~ : &@contract.Rng) -> Graph[Unit, Unit]                        // O(V^2)
pub fn atlas() -> Array[Graph[Unit, Unit]]                                                                   // O(1): 1253 graphs
pub fn karate_club() -> Graph[Unit, Unit]                                                                     // O(1)
pub fn davis_southern_women() -> Graph[Unit, Unit]                                                            // O(1)
pub fn florentine_families() -> Graph[Unit, Unit]                                                             // O(1)
pub fn les_miserables() -> Graph[Unit, Unit]                                                                  // O(1)
```

Generators take a node count and a generator, never a global seed, and return `Graph[Unit, Unit]`
so a caller can decorate it: `set_node_data` in one pass is clearer than a generator that takes a
payload function it cannot call with anything meaningful.

## io

<!-- nocheck -->

```moonbit
pub(all) struct Dataset {
  node_count : Int
  edges : Array[(Int, Int, Double?)]     // weight when the format carries one
  labels : Array[String?]                // node label from the file, if any
}

pub fn parse_edge_list(text : StringView, strict~ : Bool = false) -> Dataset raise Refused      // O(V+E)
pub fn encode_edge_list(graph : G, weight? : (Int) -> Double) -> String                  // O(V+E)
pub fn parse_adjacency_list(text : StringView, strict~ : Bool = false) -> Dataset raise Refused  // O(V+E)
pub fn encode_adjacency_list(graph : G) -> String                                               // O(V+E)
pub fn parse_dot(text : StringView, strict~ : Bool = false) -> Dataset raise Refused             // O(V+E)
pub fn encode_dot(graph : G, labels? : Array[String]) -> String                                   // O(V+E)
pub fn parse_gml(text : StringView, strict~ : Bool = false) -> Dataset raise Refused             // O(V+E)
pub fn encode_gml(graph : G) -> String                                                          // O(V+E)
pub fn parse_pajek(text : StringView, strict~ : Bool = false) -> Dataset raise Refused           // O(V+E)
pub fn encode_pajek(graph : G) -> String                                                        // O(V+E)
pub fn parse_dimacs(text : StringView, strict~ : Bool = false) -> Dataset raise Refused          // O(V+E)
pub fn encode_dimacs(graph : G, capacity~ : (Int) -> Double) -> String                             // O(V+E)
```

`strict~ : Bool = false` is the organisation's switch: by default a parser accepts what every other
implementation accepts (a blank line, a trailing comment, an edge number beyond the current
maximum), and with `strict` it refuses instead of repairing, carrying `at`, `got` and `want` in the
refusal. Every refusal names a line and a column, both starting at 1.

GraphML lives in its own package because it is the one format that needs moonxml:

<!-- nocheck -->

```moonbit
pub fn parse_graphml(text : StringView, strict~ : Bool = false) -> Dataset raise Refused   // O(V+E)
pub fn encode_graphml(graph : G, keys~ : Array[(String, String)]) -> String                // O(V+E)
```

File input and output is native-only and lives in `.native.mbt`, so the JavaScript and WebAssembly
builds carry the parsers but no filesystem:

<!-- nocheck -->

```moonbit
pub fn load(path : String) -> Dataset raise Refused     // native only, O(file)
pub fn save(path : String, text : String) -> Unit raise Refused   // native only, O(file)
```

# Where the references disagree, and what this library takes

Fifteen decisions. Each one is a place where at least two of the nine references do the same thing
differently, so "follow the references" is not an answer; the reason column is the part that matters
when someone later wants to change it.

| # | Divergence | Taken | Why |
|:--:|:--|:--|:--|
| 1 | Node identity: arbitrary hashable keys (NetworkX) vs dense integers (petgraph, igraph, JGraphT, Boost) | Dense `Int`, with `Keyed[K, G]` as a wrapper | An algorithm that indexes an array by node number is the only kind that stays fast on a million nodes. NetworkX's convenience is a map lookup, and a wrapper gives it back without charging every algorithm for it. The wrapper is the only place that knows about keys. |
| 2 | Weight: an edge attribute with a reserved name (NetworkX `weight="weight"`) vs a function (petgraph `weight : (E) -> Double`) | A function of the edge number, `weight? : ((E) -> Double)?` | A reserved attribute name means every algorithm has to know the payload's shape. A function means the payload can be anything, including `Unit`. The cost is one closure call per edge, which is what NetworkX pays per attribute lookup anyway. |
| 3 | Graph polymorphism: a class hierarchy (NetworkX, JGraphT) vs traits (petgraph) vs templates (Boost) | Traits, `Topology` and `Inbound` | Traits are the only one of the three that MoonBit has, and they also let a third party implement them over its own type. A caller's own storage becomes usable by every algorithm without a conversion. |
| 4 | Parallel edges: a separate type (NetworkX `MultiGraph`, JGraphT `Multigraph`) vs one type with a flag (petgraph) | One type, parallel edges always allowed | A second type doubles every algorithm's surface for no asymptotic gain. `Graph` keeps an edge number per edge, so the algorithms that need simple graphs call `simplify` first. `Matrix` is the exception: one payload per cell, so it cannot hold two. |
| 5 | Deletion: renumber everything (NetworkX) vs leave a hole (petgraph `StableGraph`) | Both types, chosen by the caller | Renumbering invalidates every stored node number; a caller that holds numbers across a deletion cannot use `Graph`. A caller that never deletes should not pay a hole check. Two types, one behaviour each. |
| 6 | Subgraphs: lazy views (NetworkX `subgraph`, Boost `filtered_graph`, petgraph `NodeFiltered`) vs copies | Copies | A lazy view needs a lifetime to prove the graph outlives it; MoonBit has no lifetimes. A view that owns its copy is a copy. Saying so in the signature ("returns a new graph") is better than a view type that silently disconnects from later mutations. |
| 7 | Several schemes for one problem: a `method=` string (NetworkX) vs one class per scheme (JGraphT) vs one function per scheme (petgraph, Boost) | An enum parameter with a default, plus the scheme as a named function when callers reach for it directly | A string is a typo away from silently running the wrong algorithm. An enum is checked at compile time. A class per scheme is a lot of types for a choice that is usually "the default is fine". Both faces exist: `max_flow(..., method=PushRelabel)` and `dijkstra`, `bellman_ford` (which cannot be swapped for each other because their preconditions differ). |
| 8 | Result shape: a dict keyed by node (NetworkX) vs arrays indexed by number (petgraph) | Arrays, one entry per node, plus a path accessor | A dict is three allocations per query and forces every caller to handle missing keys. An array with `None` for unreachable says exactly the same thing. `Paths.path_to` rebuilds a path without the caller juggling predecessors. |
| 9 | Unreachable distance: `math.inf` (NetworkX) vs `None` (petgraph) | `None` in `Double?` | `inf` propagates through arithmetic and turns a wrong answer into a subtle one; `inf - inf` is `NaN`, which then compares false against everything. An option forces the caller to say what happens when there is no path. |
| 10 | Failure: exceptions (NetworkX, `graphlib`) vs `panic` (petgraph on a bad index) vs sentinel values | `raise Refused` carrying the offending node or edge | A graph-level mistake (negative weight into Dijkstra, a cycle into a topological sort) is a caller error that a caller can handle; a panic takes the process down. The payload names the node or edge, which is what a caller needs to point at its input. |
| 11 | Tie-breaking when several answers are equally good | Lowest node number, then lowest edge number | Every reference leaves this to its container's iteration order: NetworkX to insertion order, petgraph to node number, JGraphT to the graph's implementation. Two of our storage types must give the same answer for the same edges, and a differential test compares arrays, so the order has to be part of the contract rather than an accident of the container. |
| 12 | Centrality normalisation: on by default (NetworkX `normalized=True`) vs off (igraph) | Off, `normalized~ : Bool = false` | Normalised values hide which constant was divided out, and the constants differ (component size in NetworkX, graph size in igraph). A raw value is the number the algorithm computes; the doc comment names the constant so a caller can normalise the way its other tool does. |
| 13 | Iterative solvers: fixed iteration count (petgraph) vs tolerance (NetworkX) | Both: `limit~ : Int = 100` and `tolerance~ : Double = 1e-8` | A fixed count does not converge on a slow graph, and a tolerance alone can loop forever on a graph whose spectrum is close to 1. Whichever is reached first stops the loop, and the result is the same on every run, which a differential test needs. |
| 14 | Bipartite: a whole namespace with its own measures and generators (NetworkX `bipartite`) vs one partitioning check (JGraphT) vs an attribute (igraph) | No bipartite namespace: the partition is `struct.bipartition`, the matching is `matching.matching_bipartite`, the projections are `op.project_bipartite`, the measures are in `metric` | A bipartite graph is not a different graph; it is a graph with a two-colouring. A namespace duplicates thirteen functions that already exist, and the duplication is where the two copies drift. The one thing that is genuinely different — `matching_bipartite` being allowed to assume the colouring — is marked by the `NotA` refusal. |
| 15 | Randomised algorithms: hidden global seed (NetworkX `seed=None` means global) vs a seeded generator | An `rng~ : &@contract.Rng` parameter, no default | A hidden default seed makes a test pass on one platform and fail on another, and makes two runs of the same program disagree. Passing the generator makes the dependency visible in the signature, which is where a caller looks. |

Three smaller ones, for completeness:

- **Self-loops in an undirected graph.** NetworkX counts a self-loop twice in `degree`, petgraph's
  neighbour iterator yields it once. This library yields it once from `neighbors` and counts it
  twice in a degree, which is what the handshake lemma needs; the doc comment on `neighbors` says so.
- **Directed to undirected.** NetworkX keeps one direction unless `reciprocal=True`; igraph has
  `to_undirected(mode="collapse")` and three other modes. This library takes `merge~ : Bool = true`:
  a reciprocal pair collapses to one edge, and the two parallel edges survive when `merge` is false.
  The other three igraph modes (each, mutual, collapse-and-sum) are one call to `simplify` away.
- **graph-tool contributes no rows of its own.** Everything it offers in this inventory is the same
  capability under a different name than the igraph row that already covers it, and the one thing
  the other references lack — stochastic block model inference — is in the `not done` list with the
  other statistical models. It is worth naming here because it is the reference that puts the
  boundary between graph structure and inference in the sharpest place, and this inventory follows
  that boundary.

# Decisions

- **`io/graphml` lands once moonxml is pinned.** Every other format lands first.
- **`Scores` stays in `centrality`.** `metric` returns numbers and arrays of numbers: wrapping a
  single number in a record buys nothing, and a caller that wants the record builds it in one line.
- **The inventory is the checklist.** 310 rows over 1601 reference names, and each row has a package
  or a reason in the `not done` list.
