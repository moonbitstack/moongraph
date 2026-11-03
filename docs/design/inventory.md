# API inventory

Every capability the nine reference libraries offer, merged into one row per capability, with
the licence the code would be transcribed under and the package that owns it.

The list is drawn from the sources and the reference pages, not from memory: the entries are the
`autosummary` blocks of `doc/reference/**` in NetworkX 3.7, the `pub fn` surface of
`petgraph@v0.8.3`, the algorithm classes under `org/jgrapht/alg` in `jgrapht-1.5.2`, the
algorithm pages of Boost.Graph `boost-1.92.0`, `interfaces/functions.yaml` in igraph 1.0.1,
and the `sknetwork`/`easygraph` packages of scikit-network 0.33.5 and Easy-Graph.

## How to read this

**Library / Name.** Names are given in the order of the libraries, so the third name belongs to
the third library. A capability that only one library has still gets its own row, because the
row is what carries the attribution.

**Coverage.** Five references are covered name by name: every entry of the NetworkX reference
pages (805 names), every `pub fn` of petgraph, every class under `org/jgrapht/alg`, every
algorithm page of Boost.Graph, and all 482 functions of igraph. scikit-network and EasyGraph are
covered capability by capability: their public surface is grouped under the capability it
implements, and the internal helpers (`safe_div`, `vlen`, `check_*` validators, `test_*`
fixtures) are not listed, because they are not interface.

**Licence.** `BSD-3`, `MIT`, `Apache-2.0`, `BSL-1.0` code may be transcribed. A star
(`GPL-2.0*`, `EPL-2.0*`, `PSF-2.0*`) means the library is read for the shape of the interface
only and no line of it is copied.

**Complexity.** `V` nodes, `E` edges, `d` average degree, `k` the parameter named in the purpose.
The bound is the one the reference documents for its own implementation; where it documents
none, the classical bound of the algorithm is given.

**Home.** One of:

| Home | Meaning |
|:--|:--|
| `root` | graph types, the two traits, shared result records |
| `traverse` `path` `flow` `matching` `tree` `component` `centrality` `community` `iso` `color` `clique` `cycle` `dag` `gen` `io` | the packages fixed in the task sheet |
| `io/graphml` | the one format that pulls in moonxml |
| `metric`† `struct`† `op`† `approx`† | packages this inventory asks for; the task sheet's list does not cover these capabilities. The reasons are in `interface.md`, first section |
| `moonstl` | binary heap, indexed heap, union-find, ordered map — the library already owns them |
| `moonmath` | vectors, matrices, linear solves, geometry |
| `not done` | outside this library; the reason follows in the last column |

A dagger `†` marks a package that is not in the task sheet.

---

# 1. Representations, construction and formats

## 1.1 Storage

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph, EasyGraph | `Graph`/`DiGraph`/`MultiGraph`/`MultiDiGraph`; `Graph<N, E, Directed>`/`Graph<N, E, Undirected>`; `DefaultDirectedGraph`/`SimpleGraph`/`WeightedMultigraph`; `adjacency_list`; `igraph_t`; `Graph` | Adjacency-list graph, directed flag fixed at construction, parallel edges optional, node and edge payloads | O(1) insert, O(V+E) space | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0*, BSD-3 | `root` |
| petgraph | `StableGraph<N, E, Ty>` | Adjacency list whose node and edge numbers survive deletion (holes stay) | O(1) insert, O(V+E) space | MIT | `root` |
| petgraph, Boost.Graph, igraph | `Csr`, `compressed_sparse_row_graph`, `igraph_get_adjacency(IGRAPH_GET_ADJACENCY_BOTH)` on a CSR | Immutable compressed adjacency, one array per direction | O(V+E) build, O(1) neighbour jump | MIT, BSL-1.0, GPL-2.0* | `root` |
| petgraph, Boost.Graph | `MatrixGraph`, `adjacency_matrix` | Dense V x V storage of one edge payload per cell | O(V^2) space, O(1) lookup | MIT, BSL-1.0 | `root` |
| petgraph | `GraphMap<N, E, Ty>` | Graph keyed by a hashable node value instead of a dense number | O(1) average per operation | MIT | `root` |
| NetworkX, igraph, scikit-network, EasyGraph | `Graph` node/edge dicts, `igraph_t` attributes, CSR matrices as graphs, `Graph` class | Payload lookup by node or edge | O(1) average | BSD-3, GPL-2.0*, BSD-3, BSD-3 | `root` |
| petgraph | `Frozen<'a, G>` | Structure frozen, payload still mutable | O(1) | MIT | `root` (`Csr` is the frozen form; a borrowing wrapper is not offered) |
| NetworkX, JGraphT, Boost.Graph, petgraph | `subgraph`, `AsSubgraph`, `MaskSubgraph`, `subgraph`, `NodeFiltered`, `EdgeFiltered`, `filter_map` | Lazy subgraph view, node and edge predicates | O(touched) per traversal | BSD-3, EPL-2.0*, BSL-1.0, MIT | `op` (materialised, not lazy — see the note in `interface.md`) |
| JGraphT | `GraphDelegator`, `ListenableGraph`, `UnmodifiableGraph` | Wrapper that adds behaviour to another graph | O(1) delegation | EPL-2.0* | `not done`: no wrapper layer, a caller that needs it implements `Topology` over its own type |
| igraph | `sparse_adjacency`, `sparse_weighted_adjacency`, `weighted_adjacency`, `get_adjacency_sparse`, `get_stochastic_sparse`, `get_laplacian_sparse`, `empty_attrs`, `has_attribute_table`, `is_same_graph`, `create_bipartite` | A graph built from a sparse matrix, and the attribute table that goes with it | O(V+E) | GPL-2.0* | `root` (the matrix forms are `Csr` and `Matrix`) |
| NetworkX | `restricted_view`, `freeze`, `is_frozen` | Read-only graph and hidden nodes/edges | O(1) | BSD-3 | `root` (`Graph` has no mutating alias to hide; `Csr` is read-only) |

## 1.2 Node and edge access

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `nodes`, `number_of_nodes`, `node_index`, `node_identifiers`/`vertices`, `num_vertices`, `vcount` | Enumerate nodes, count them, tell a node's number | O(1) count, O(V) enumerate | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `root` |
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `edges`, `number_of_edges`, `edge_references`, `edgeSet`, `num_edges`, `ecount` | Enumerate edges with endpoints, count them | O(1) count, O(E) enumerate | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `root` |
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `neighbors`, `all_neighbors`, `neighbors_directed`, `neighbors_undirected`, `neighbors`/`edgesOf`, `adjacent_vertices`, `neighbors` | Adjacent nodes, optionally split by direction, with the edge that reaches them | O(1+d) | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `root` |
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `in_edges`, `out_edges`, `edges_directed`, `incoming`/`outgoing`, `in_edges`/`out_edges`, `incident`/`in_edges`/`out_edges` | Edges on one side of a node | O(1+d) | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `root` |
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `has_node`, `__contains__`, `contains_vertex`, `find_edge`, `edge`, `get_eid`, `are_adjacent` | Membership and edge lookup, including parallel edges | O(1) average, O(min(d_out,d_in)) for a pair | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `root` |
| NetworkX, igraph | `common_neighbors`, `non_neighbors`, `non_edges`, `selfloop_edges`, `nodes_with_selfloops`, `number_of_selfloops`, `neighborhood`, `neighborhood_size` | Neighbourhood set operations and self-loop queries | O(d^2) worst | BSD-3, GPL-2.0* | `root` |
| igraph | `add_vertices`, `delete_vertices_map`, `get_eids`, `get_all_eids_between`, `maxdegree`, `is_loop` | Bulk vertex insertion, the old-to-new number map after a deletion, and edge lookup by endpoint pair | O(k), O(V+E) for the map | GPL-2.0* | `root` |
| NetworkX, Boost.Graph | `degree`, `degree_histogram`, `in_degree`, `out_degree`, `degree` property map | Degree per node and its histogram | O(V+E) | BSD-3, BSL-1.0 | `metric` |
| NetworkX, igraph | `is_directed`, `is_multigraph`, `is_weighted`, `is_negatively_weighted`, `is_simple`, `is_multiple`, `has_loop`, `has_multiple`, `count_loops`, `count_multiple` | Static properties of the stored graph | O(V+E) | BSD-3, GPL-2.0* | `root` |

## 1.3 Mutation

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `add_node`, `add_nodes_from`, `add_vertex`, `add_vertex`/`addVertex`, `add_edge`, `add_edges_from`, `add_edge`, `addEdge`, `add_edges` | Insert nodes and edges, singly or in bulk | O(1) each, O(k) for a bulk of k | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `root` |
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `remove_node`, `remove_nodes_from`, `remove_vertex`, `removeVertex`, `remove_edge`, `remove_edges_from`, `removeEdge`, `delete_vertices`, `delete_edges` | Remove nodes and edges | O(d) per node, O(1) per edge | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `root` |
| NetworkX, petgraph, JGraphT, Boost.Graph | `clear`, `clear_edges`, `update` | Empty the graph, or merge another into it | O(V+E) | BSD-3, MIT, EPL-2.0*, BSL-1.0 | `root` |
| NetworkX, petgraph, Boost.Graph | `add_star`, `add_path`, `add_cycle` | Insert a fixed shape in one call | O(k) | BSD-3, MIT, BSL-1.0 | `root` |
| NetworkX, petgraph, JGraphT | `add_weighted_edges_from`, `update_edge`, `setEdgeWeight` | Insert or replace an edge in place | O(1) average | BSD-3, MIT, EPL-2.0* | `root` |
| NetworkX | `set_node_attributes`, `get_node_attributes`, `set_edge_attributes`, `get_edge_attributes` | Bulk payload read and write by name | O(V+E) | BSD-3 | `root` (`Graph` addresses payloads by number; a name-keyed bag of attributes is not modelled) |
| NetworkX, igraph | `contract_nodes`, `identified_nodes`, `contract_vertices`, `equivalence_classes` | Merge nodes, keep the edge multiset | O(V+E) | BSD-3, GPL-2.0* | `op` |
| NetworkX | `contracted_edge` | Merge the two ends of one edge | O(V+E) | BSD-3 | `op` |
| NetworkX | `quotient_graph` | Collapse each block of a partition into one node | O(V+E) | BSD-3 | `op` |

## 1.4 Conversion

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, petgraph, Boost.Graph | `to_numpy_array`/`to_scipy_sparse_array`, `to_directed`/`to_undirected`, `Csr::from`, `MatrixGraph::from`, `copy_graph`, `transpose_graph`, `reverse_graph` | Between adjacency list, CSR, matrix and the opposite direction | O(V+E) or O(V^2) for the dense form | BSD-3, MIT, BSL-1.0 | `root` |
| NetworkX, Boost.Graph | `to_dict_of_dicts`, `to_dict_of_lists`, `from_dict_of_dicts`, `from_edgelist`, `edge_list` | Between foreign containers and the graph | O(V+E) | BSD-3, BSL-1.0 | `root` |
| NetworkX, igraph | `biadjacency_matrix`, `from_biadjacency_matrix`, `weighted_biadjacency`, `get_biadjacency`, `bipartite_projection` from a matrix | Bipartite adjacency as a matrix and back | O(V*E) | BSD-3, GPL-2.0* | `root` (the matrix type is `Matrix`) |
| NetworkX | `to_pandas_adjacency`, `to_pandas_edgelist`, `from_pandas_edgelist`, `to_scipy_sparse_array`, `to_numpy_matrix` | DataFrame and SciPy interop | O(V+E) | BSD-3 | `not done`: no DataFrame or SciPy type exists here; the arrays are reachable through `Matrix` and the edge iterator |
| scikit-network | `from_adjacency_list`, `from_edge_array`, `from_edge_list`, `from_csv`, `from_graphml`, `bipartite2directed`, `bipartite2undirected`, `directed2undirected`, `add_self_loops`, `make_weights`, `break_cycles`, `get_largest_connected_component`, `get_connected_components`, `reindex_labels`, `values2prob`, `stack_values`, `top_k`, `get_labels`, `get_index` | Loaders, orientation fixes, and the small transforms a pipeline runs before an algorithm | O(V+E) | BSD-3 | `root` (loading files: `io`) |
| NetworkX | `create_empty_copy` | Copy the structure without payloads | O(V+E) | BSD-3 | `root` |
| NetworkX, petgraph | `is_empty`, `is_path`, `path_weight` | Queries over an existing graph | O(V) | BSD-3, MIT | `root` (`is_path`) and `metric` (`path_weight`) |
| scikit-network | `get_adjacency`, `get_edgelist`, `get_laplacian`, `get_stochastic`, `get_probs`, `check_format`, `is_square`, `is_symmetric` | Between a sparse matrix and the graph view of it | O(V+E) | BSD-3 | `root` for the adjacency and edge list; `moonmath` for the Laplacian and the stochastic matrix |

## 1.5 Operators and derived graphs

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, igraph, Boost.Graph | `union`, `union_all`, `disjoint_union`, `disjoint_union_many`, `disjoint_union_all`, `intersection`, `intersection_many`, `intersection_all`, `difference`, `symmetric_difference`, `compose`, `compose_all`, `full_join`, `join`, `complement`, `complementer`, `reverse`, `reverse_edges`, `to_directed`, `to_undirected` | Set operations on node and edge sets, orientation changes | O(V+E) | BSD-3, GPL-2.0*, BSL-1.0 | `op` |
| NetworkX, igraph, JGraphT | `cartesian_product`, `lexicographic_product`, `strong_product`, `tensor_product`, `rooted_product`, `modular_product`, `corona_product`, `power`, `graph_power`, `LineGraphConverter`, `line_graph`, `inverse_line_graph`, `mycielskian` | Products, powers and line graphs | O(V1*V2 + E1*V2 + E2*V1) for products | BSD-3, GPL-2.0*, EPL-2.0* | `op` |
| NetworkX, igraph, JGraphT | `ego_graph`, `induced_subgraph`, `subgraph_from_edges`, `edge_subgraph`, `AsSubgraph`, `MaskSubgraph` | Subgraph by node set, edge set or radius | O(subgraph) | BSD-3, GPL-2.0*, EPL-2.0* | `op` |
| NetworkX, igraph | `relabel_nodes`, `permute_vertices`, `convert_node_labels_to_integers`, `reindex_membership` | Renumber nodes | O(V+E) | BSD-3, GPL-2.0* | `op` |
| NetworkX, igraph | `stochastic_graph`, `get_stochastic`, `simplify`, `weighted_projected_graph`, `projected_graph`, `overlap_weighted_projected_graph`, `collaboration_weighted_projected_graph`, `generic_weighted_projected_graph`, `bipartite_projection`, `bipartite_projection_size` | Normalise edge weights, drop parallel edges, project a bipartite graph onto one side | O(V+E) | BSD-3, GPL-2.0* | `op` |
| NetworkX, igraph | `unfold_tree`, `junction_tree`, `moral_graph`, `dedensify`, `snap_aggregation` | Structural rewrites used before an algorithm | O(V+E) | BSD-3, GPL-2.0* | `op` (`dedensify`, `snap_aggregation`: `approx`) |
| Boost.Graph, JGraphT | `copy_graph`, `transpose_graph`, `LineGraphConverter`, `AsGraphUnion` | Whole-graph copies and converters | O(V+E) | BSL-1.0, EPL-2.0* | `op` |
| petgraph | `map`, `filter_map`, `node_weights_mut`, `edge_weights_mut` | Project payloads without touching the structure | O(V+E) | MIT | `root` |

## 1.6 Node numbering facade

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX | arbitrary hashable nodes, `convert_node_labels_to_integers`, `relabel_nodes` | Address nodes by a key rather than by a number | O(1) average per lookup | BSD-3 | `root` (`Keyed[K, G]` wraps the number-keyed graph and maps keys both ways) |
| petgraph | `GraphMap<N, E, Ty>` | Keyed graph without a separate map | O(1) average | MIT | `root` (`Keyed` is the same idea over `Graph`; a second storage type is not worth its maintenance) |

## 1.7 Generators

`gen` builds the graph; the row's complexity is the construction cost.

### 1.7.1 Fixed shapes

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, petgraph, igraph, JGraphT, Boost.Graph | `empty_graph`, `null_graph`, `trivial_graph`, `prefix_tree`, `dorogovtsev_goltsev_mendes_graph`, `complete_graph`, `full`, `CompleteGraphGenerator`, `path_graph`, `cycle_graph`, `star_graph`, `wheel_graph`, `ladder_graph`, `circular_ladder_graph`, `barbell_graph`, `lollipop_graph`, `tadpole_graph`, `windmill_graph`, `bull_graph`, `diamond_graph`, `house_graph`, `house_x_graph`, `tetrahedral_graph`, `cubical_graph`, `octahedral_graph`, `icosahedral_graph`, `dodecahedral_graph` | Named small graphs and the standard families | O(V+E) | BSD-3, MIT, GPL-2.0*, EPL-2.0*, BSL-1.0 | `gen` |
| NetworkX, igraph | `complete_multipartite_graph`, `turan_graph`, `full_multipartite`, `full_bipartite`, `complete_bipartite_graph`, `kneser_graph` | Complete multipartite and bipartite families | O(V+E) | BSD-3, GPL-2.0* | `gen` |
| NetworkX, igraph | `balanced_tree`, `full_rary_tree`, `binomial_tree`, `kary_tree`, `symmetric_tree`, `regular_tree`, `random_labeled_tree`, `random_labeled_rooted_tree`, `random_labeled_rooted_forest`, `random_unlabeled_tree`, `random_unlabeled_rooted_tree`, `random_unlabeled_rooted_forest`, `nonisomorphic_trees`, `number_of_nonisomorphic_trees`, `random_powerlaw_tree`, `random_powerlaw_tree_sequence`, `degree_sequence_tree` | Trees of a given shape, arity or degree sequence | O(V) | BSD-3, GPL-2.0* | `gen` |
| NetworkX, igraph | `circulant_graph`, `generalized_petersen_graph`, `LCF_graph`, `hoffman_singleton_graph`, `heawood_graph`, `pappus_graph`, `desargues_graph`, `moebius_kantor_graph`, `frucht_graph`, `sedgewick_maze_graph`, `shrikhande_graph`, `tutte_graph`, `chvatal_graph`, `krackhardt_kite_graph`, `truncated_cube_graph`, `truncated_tetrahedron_graph` | Named cubic, circulant and small symmetric graphs | O(V+E) | BSD-3, GPL-2.0* | `gen` |
| NetworkX, igraph | `graph_atlas`, `graph_atlas_g`, `famous` | The small graph atlas and the named-graph registry | O(1) lookup | BSD-3, GPL-2.0* | `gen` (`atlas`: small, 1253 graphs, kept as data) |
| igraph | `full_citation`, `extended_chordal_ring`, `connect_neighborhood`, `linegraph`, `de_bruijn`, `kautz`, `lcf`, `tree_game` | Citation graphs, de Bruijn and Kautz digraphs, and neighbourhood wiring | O(V+E) | GPL-2.0* | `gen` (`linegraph`: `op`) |
| NetworkX | `chordal_cycle_graph`, `paley_graph`, `margulis_gabber_galil_graph`, `maybe_regular_expander`, `random_regular_expander_graph`, `is_regular_expander`, `mycielski_graph`, `mycielskian`, `hnm_harary_graph`, `hkn_harary_graph`, `random_cograph`, `interval_graph`, `sudoku_graph`, `visibility_graph`, `triad_graph` | Expanders, Mycielski, Harary, cographs, and graphs read off other structures | O(V+E) | BSD-3 | `gen` |
| NetworkX | `spectral_graph_forge` | Rewire an adjacency matrix while keeping its spectrum | O(V^2) | BSD-3 | `not done`: it needs a full eigensolver and exists to feed a demonstration; the linear algebra belongs to moonmath |

### 1.7.2 Lattices and grids

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, igraph, Boost.Graph | `grid_2d_graph`, `grid_graph`, `square_lattice`, `triangular_lattice`, `triangular_lattice_graph`, `hexagonal_lattice_graph`, `hypercube_graph`, `hypercube`, `ring`, `triangular_lattice`, `grid_graph`, `king_ordering`-style indexing | Regular lattices in 2 or n dimensions | O(V+E) | BSD-3, GPL-2.0*, BSL-1.0 | `gen` |
| Boost.Graph, igraph | `mesh_generator`, `grid_graph`, `square_lattice` | Mesh used as a test bed for orderings | O(V+E) | BSL-1.0, GPL-2.0* | `gen` |

### 1.7.3 Random models

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, igraph, JGraphT, Boost.Graph, EasyGraph | `gnp_random_graph`, `fast_gnp_random_graph`, `erdos_renyi_graph`, `binomial_graph`, `gnm_random_graph`, `dense_gnm_random_graph`, `erdos_renyi_game_gnp`, `erdos_renyi_game_gnm`, `GnmRandomGraphGenerator`, `GnpRandomGraphGenerator`, `erdos_renyi_graph` | Erdos-Renyi in the G(n,p) and G(n,m) forms | O(V+E) for the sparse form, O(V^2) for the dense | BSD-3, GPL-2.0*, EPL-2.0*, BSL-1.0, BSD-3 | `gen` |
| NetworkX, igraph | `barabasi_albert_graph`, `dual_barabasi_albert_graph`, `extended_barabasi_albert_graph`, `powerlaw_cluster_graph`, `barabasi_game`, `barabasi_aging_game`, `recent_degree_game`, `recent_degree_aging_game`, `growing_random_game` | Preferential attachment and its variants | O(V log V) expected with a heap | BSD-3, GPL-2.0* | `gen` |
| NetworkX, igraph, Boost.Graph | `watts_strogatz_graph`, `newman_watts_strogatz_graph`, `connected_watts_strogatz_graph`, `watts_strogatz_game`, `small_world_connector` | Small-world rewiring | O(V*d) | BSD-3, GPL-2.0*, BSL-1.0 | `gen` |
| NetworkX, igraph | `stochastic_block_model`, `gaussian_random_partition_graph`, `planted_partition_graph`, `random_partition_graph`, `relaxed_caveman_graph`, `ring_of_cliques`, `caveman_graph`, `connected_caveman_graph`, `sbm_game`, `hsbm_game`, `hsbm_list_game` | Block models and clustered graphs | O(V+E) | BSD-3, GPL-2.0* | `gen` |
| NetworkX, igraph | `configuration_model`, `directed_configuration_model`, `expected_degree_graph`, `havel_hakimi_graph`, `directed_havel_hakimi_graph`, `alternating_havel_hakimi_graph`, `reverse_havel_hakimi_graph`, `random_clustered_graph`, `random_degree_sequence_graph`, `degree_sequence_game`, `realize_degree_sequence`, `realize_bipartite_degree_sequence`, `chung_lu_game`, `static_fitness_game`, `static_power_law_game`, `k_regular_game`, `random_regular_graph`, `random_k_out_graph` | Draw a graph with a prescribed degree sequence | O(V+E) | BSD-3, GPL-2.0* | `gen` |
| NetworkX, igraph | `random_geometric_graph`, `soft_random_geometric_graph`, `thresholded_random_geometric_graph`, `geographical_threshold_graph`, `waxman_graph`, `geometric_soft_configuration_graph`, `geometric_edges`, `navigable_small_world_graph`, `random_internet_as_graph`, `grg_game`, `gnmk_random_graph`, `preferential_attachment_graph` | Geometric and spatial models | O(V log V) with a grid index | BSD-3, GPL-2.0* | `gen` |
| NetworkX, igraph | `gn_graph`, `gnr_graph`, `gnc_graph`, `scale_free_graph`, `duplication_divergence_graph`, `partial_duplication_graph`, `random_kernel_graph`, `random_k_lift`, `random_lobster_graph`, `random_shell_graph`, `random_k_out_graph` | Growing, duplicating and kernel-based models | O(V+E) | BSD-3, GPL-2.0* | `gen` |
| NetworkX | `uniform_random_intersection_graph`, `k_random_intersection_graph`, `general_random_intersection_graph`, `interval_graph`, `random_cograph` | Intersection and recursive families | O(V+E*`) | BSD-3 | `gen` |
| NetworkX, igraph | `LFR_benchmark_graph`, `correlated_game`, `correlated_pair_game`, `dot_product_game`, `iea_game`, `bipartite_iea_game`, `bipartite_game_gnp`, `bipartite_game_gnm`, `callaway_traits_game`, `establishment_game`, `preference_game`, `asymmetric_preference_game`, `forest_fire_game`, `simple_interconnected_islands_game`, `lastcit_game`, `cited_type_game`, `citing_cited_type_game`, `growing_random_game` | Benchmark and simulation models | O(V+E) to O(V^2) | BSD-3, GPL-2.0* | `gen` |
| NetworkX, igraph | `random_tournament`, `tournament_matrix`, `score_sequence` | Random tournament and its score sequence | O(V^2) | BSD-3, GPL-2.0* | `gen` |
| NetworkX | `is_valid_joint_degree`, `joint_degree_graph`, `is_valid_directed_joint_degree`, `directed_joint_degree_graph` | Joint degree matrix realisation | O(V+E) | BSD-3 | `gen` |

### 1.7.4 Data sets and fixtures

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, igraph | `karate_club_graph`, `davis_southern_women_graph`, `florentine_families_graph`, `les_miserables_graph`, `famous`, `atlas` | The classic small data sets | O(1) | BSD-3, GPL-2.0* | `gen` |
| scikit-network, EasyGraph | `Dataset`, `ToyGraphs`, `load`, `parse`, `models` | Loaders for the benchmark graphs | O(V+E) | BSD-3, BSD-3 | `not done`: a library ships shapes, not data sets; the four small ones above are the exception because every reference embeds them |

## 1.8 Read and write

`io` for the text formats, `io/graphml` for the one that needs moonxml.

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, igraph | `read_edgelist`, `write_edgelist`, `read_weighted_edgelist`, `write_weighted_edgelist`, `parse_edgelist`, `generate_edgelist`, `read_graph_edgelist`, `write_graph_edgelist` | One edge per line, optional weight | O(V+E) | BSD-3, GPL-2.0* | `io` |
| NetworkX, igraph | `read_adjlist`, `write_adjlist`, `parse_adjlist`, `generate_adjlist`, `read_multiline_adjlist`, `write_multiline_adjlist`, `parse_multiline_adjlist`, `generate_multiline_adjlist`, `read_graph_ncol`, `write_graph_ncol`, `read_graph_lgl`, `write_graph_lgl` | One node per line with its neighbours | O(V+E) | BSD-3, GPL-2.0* | `io` |
| NetworkX, igraph | `read_dot`, `write_dot`, `write_graph_dot`, `write_graph_leda` | Graphviz DOT, attributes included | O(V+E) | BSD-3, GPL-2.0* | `io` |
| NetworkX, igraph | `read_gml`, `write_gml`, `parse_gml`, `generate_gml`, `read_graph_gml`, `write_graph_gml`, `literal_destringizer`, `literal_stringizer` | GML, the other attributed text format | O(V+E) | BSD-3, GPL-2.0* | `io` |
| NetworkX, igraph | `read_graphml`, `write_graphml`, `generate_graphml`, `parse_graphml`, `read_graph_graphml`, `write_graph_graphml` | GraphML, keyed attributes, nested graphs | O(V+E) | BSD-3, GPL-2.0* | `io/graphml` |
| NetworkX, igraph | `read_pajek`, `write_pajek`, `parse_pajek`, `generate_pajek`, `read_graph_pajek`, `write_graph_pajek` | Pajek, the social-network exchange format | O(V+E) | BSD-3, GPL-2.0* | `io` |
| NetworkX, igraph | `read_leda`, `parse_leda`, `read_graph_dimacs_flow`, `write_graph_dimacs_flow` | LEDA and DIMACS max-flow instances | O(V+E) | BSD-3, GPL-2.0* | `io` |
| NetworkX, igraph | `from_graph6_bytes`, `to_graph6_bytes`, `read_graph6`, `write_graph6`, `from_sparse6_bytes`, `to_sparse6_bytes`, `read_sparse6`, `write_sparse6`, `get_graph6_representation`, `from_graph6_representation`, `read_graph_dl`, `read_graph_graphdb`, `write_graph_graphml` | The compact nauty formats and the remaining readers | O(V+E) | BSD-3, GPL-2.0*, MIT | `io` |
| NetworkX, igraph | `read_gexf`, `write_gexf`, `generate_gexf`, `relabel_gexf_graph`, `read_multiline_adjlist` | GEXF, the Gephi exchange format | O(V+E) | BSD-3, GPL-2.0* | `io` |
| NetworkX | `node_link_data`, `node_link_graph`, `adjacency_data`, `adjacency_graph`, `cytoscape_data`, `cytoscape_graph`, `tree_data`, `tree_graph` | JSON-shaped interchanges used by the web front ends | O(V+E) | BSD-3 | `io` (`tree_data`/`tree_graph` too: the same module) |
| NetworkX | `generate_network_text`, `write_network_text` | ASCII rendering of a graph | O(V+E) | BSD-3 | `not done`: rendering is not a graph algorithm, and the output is for humans reading a terminal |
| Boost.Graph | `graphml`, `graphviz` readers and writers, `dimacs` | The three Boost.Graph exchange modules | O(V+E) | BSL-1.0 | `io` (GraphML: `io/graphml`) |
| JGraphT | `jgrapht-io`: `DOTImporter`, `DOTExporter`, `CSVImporter`, `CSVExporter`, `GraphMLImporter`, `GraphMLExporter`, `GMLImporter`, `GmlExporter`, `SimpleGraphMLImporter`, `DIMACSImporter`, `LEMONGraphImporter` | Readers and writers with attribute mapping | O(V+E) | EPL-2.0* | `io` |
| petgraph | `Dot`, `Config`, `graph_fmt`, `with_attr_getters` | DOT output | O(V+E) | MIT | `io` |

# 2. Algorithms

## 2.1 Traversal

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `bfs_edges`, `bfs_tree`, `bfs_layers`, `bfs_predecessors`, `bfs_successors`, `bfs_labeled_edges`, `generic_bfs_edges`, `bfs_beam_edges`, `Bfs`, `breadth_first_search`, `breadth_first_visit`, `BreadthFirstIterator`, `ClosestFirstIterator`, `bfs`, `bfs_simple`, `neighbor_bfs` | Breadth-first sweep, as edges, as a tree, as layers, as labelled events | O(V+E) | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `traverse` |
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `dfs_edges`, `dfs_tree`, `dfs_predecessors`, `dfs_successors`, `dfs_preorder_nodes`, `dfs_postorder_nodes`, `dfs_labeled_edges`, `Dfs`, `DfsPostOrder`, `simple_fast`, `depth_first_search`, `depth_first_visit`, `undirected_dfs`, `DepthFirstIterator`, `dfs`, `dfs_simple`, `maximum_cardinality_search` | Depth-first sweep in preorder, postorder, or as labelled events | O(V+E) | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `traverse` |
| NetworkX, petgraph, Boost.Graph | `edge_bfs`, `edge_dfs` | Traversal that yields edges and keeps going across components | O(V+E) | BSD-3, MIT, BSL-1.0 | `traverse` |
| NetworkX, petgraph, JGraphT, igraph | `descendants_at_distance`, `bfs_layers`, `subcomponent`, `RandomWalkIterator`, `random_walk` | Everything within k hops, and a lazy walk | O(V+E) up to depth k | BSD-3, MIT, EPL-2.0*, GPL-2.0* | `traverse` |
| petgraph, Boost.Graph | `Topo` walker, `topological_sort`, `TopologicalSorter.static_order` | Traversal that yields nodes in dependency order | O(V+E) | MIT, BSL-1.0, PSF-2.0* | `dag` |
| Boost.Graph, JGraphT | `BFSVisitor`, `DFSVisitor`, `EventVisitor`, `EventVisitorList`, `depth_first_visit` with a visitor | Hook a callback into each traversal event instead of materialising a result | O(V+E) | BSL-1.0, EPL-2.0* | `traverse` (the callers here are closures; a visitor class hierarchy is not needed) |

## 2.2 Shortest paths

Distances are `Double` in every signature; an unweighted graph passes `unit` as the weight.

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph, scikit-network, EasyGraph | `single_source_dijkstra`, `dijkstra_path`, `dijkstra_path_length`, `dijkstra_predecessor_and_distance`, `dijkstra`, `DijkstraShortestPath`, `IntVertexDijkstraShortestPath`, `DeltaSteppingShortestPath`, `dijkstra_shortest_paths`, `dijkstra_shortest_paths_no_color_map`, `distances_dijkstra`, `distances_dijkstra_cutoff`, `get_shortest_path_dijkstra`, `get_shortest_paths_dijkstra`, `get_all_shortest_paths_dijkstra`, `single_source_dijkstra`, `get_shortest_path` | Single-source shortest paths on non-negative weights | O(E + V log V) | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0*, BSD-3, BSD-3 | `path` |
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `multi_source_dijkstra`, `multi_source_dijkstra_path`, `multi_source_dijkstra_path_length`, `multi_source_dijkstra`, `distances` with several sources, `voronoi`, `voronoi_cells` | Shortest paths from a set of sources, and the cell each node falls in | O(E + V log V) | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `path` |
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `bidirectional_dijkstra`, `bidirectional_shortest_path`, `BidirectionalDijkstraShortestPath`, `bidirectional_dijkstra`, `get_shortest_path` | Search from both ends, meeting in the middle | O(E + V log V) worst, about half in practice | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `path` |
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `bellman_ford_path`, `bellman_ford_path_length`, `single_source_bellman_ford`, `single_source_bellman_ford_path`, `single_source_bellman_ford_path_length`, `bellman_ford_predecessor_and_distance`, `bellman_ford`, `BellmanFordShortestPath`, `bellman_ford_shortest_paths`, `bellman_ford_shortest`, `distances_bellman_ford`, `get_shortest_path_bellman_ford` | Single-source shortest paths, negative weights allowed, negative cycles rejected | O(V*E) | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `path` |
| NetworkX, petgraph, igraph | `spfa`, `spfa`, `distances_bellman_ford` with a queue | Bellman-Ford with a work queue, quick on most inputs | O(V*E) worst, O(k*E) expected | BSD-3, MIT, GPL-2.0* | `path` |
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `johnson`, `johnson`, `JohnsonShortestPaths`, `johnson_all_pairs_shortest_paths`, `distances_johnson`, `all_pairs_all_shortest_paths`, `goldberg_radzik` | All pairs with a reweighting pass, sparse graphs | O(V*E + V*E log V) | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `path` |
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `floyd_warshall`, `floyd_warshall_predecessor_and_distance`, `floyd_warshall_numpy`, `floyd_warshall_tree`, `FloydWarshallShortestPaths`, `floyd_warshall_shortest_paths`, `distances_floyd_warshall`, `widest_path_widths_floyd_warshall` | All pairs by dynamic programming, dense graphs | O(V^3) | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `path` |
| NetworkX, petgraph, JGraphT, Boost.Graph | `all_pairs_shortest_path`, `all_pairs_shortest_path_length`, `all_pairs_dijkstra`, `all_pairs_dijkstra_path`, `all_pairs_dijkstra_path_length`, `all_pairs_bellman_ford_path`, `all_pairs_bellman_ford_path_length`, `DijkstraManyToManyShortestPaths`, `DefaultManyToManyShortestPaths`, `CHManyToManyShortestPaths`, `all_pairs_shortest_paths` | All pairs by running a single-source method from each node | O(V * single-source) | BSD-3, MIT, EPL-2.0*, BSL-1.0 | `path` |
| NetworkX, JGraphT | `shortest_path`, `shortest_path_length`, `has_path`, `single_source_shortest_path`, `single_source_all_shortest_paths`, `single_source_dijkstra_path`, `single_source_dijkstra_path_length`, `single_source_shortest_path_length`, `single_target_shortest_path`, `single_target_shortest_path_length`, `PathValidator`, `AllDirectedPaths` | The uniform entry point that picks a method, and the single-pair wrappers | O(chosen method) | BSD-3, EPL-2.0* | `path` |
| NetworkX, petgraph, JGraphT, Boost.Graph | `astar_path`, `astar_path_length`, `astar`, `AStarShortestPath`, `BidirectionalAStarShortestPath`, `astar_search`, `AStarAdmissibleHeuristic`, `ALTAdmissibleHeuristic`, `get_shortest_path_astar` | Shortest path guided by a heuristic | O(E log V) worst | BSD-3, MIT, EPL-2.0*, BSL-1.0 | `path` |
| NetworkX, petgraph, JGraphT, igraph | `shortest_simple_paths`, `k_shortest_path`, `YenKShortestPath`, `YenShortestPathIterator`, `EppsteinKShortestPath`, `EppsteinShortestPathIterator`, `get_k_shortest_paths` | The k cheapest loopless paths, in order | O(k*V*(E + V log V)) | BSD-3, MIT, EPL-2.0*, GPL-2.0* | `path` |
| NetworkX, petgraph | `all_simple_paths`, `all_simple_edge_paths`, `all_simple_paths`, `all_simple_paths_multi`, `get_all_simple_paths`, `is_simple_path` | Every loopless path between two nodes | O(V+E) per path, exponential in the count | BSD-3, MIT, GPL-2.0* | `path` |
| NetworkX, JGraphT | `shortest_path` with several objectives, `MultiObjectiveShortestPathAlgorithm`, `ListMultiObjectiveSingleSourcePathsImpl`, `MartinShortestPath` | Pareto-optimal paths under several weights | O(paths * E log V) | BSD-3, EPL-2.0* | `path` |
| petgraph, igraph | `find_negative_cycle`, `negative_edge_cycle`, `find_cycle`, `girth`, `is_cyclic_directed` | Detect and exhibit a negative cycle | O(V*E) | MIT, GPL-2.0* | `path` (`find_negative_cycle`), `cycle` (the rest) |
| NetworkX, JGraphT | `r_c_shortest_paths` | Resource-constrained shortest path, elementary or non-elementary | O(labels * E) | EPL-2.0* | `path` |
| JGraphT, NetworkX | `SuurballeKDisjointShortestPaths`, `BhandariKDisjointShortestPaths`, `edge_disjoint_paths`, `node_disjoint_paths` | k pairwise disjoint paths of least total cost | O(k * max-flow) | EPL-2.0*, BSD-3 | `flow` |
| NetworkX, igraph, Boost.Graph | `get_widest_path`, `get_widest_paths`, `widest_path_widths_dijkstra`, `widest_path_widths_floyd_warshall` | Maximise the minimum edge weight along the path | O(E + V log V) | BSD-3, GPL-2.0* | `path` |
| igraph | `distances_cutoff`, `get_shortest_paths_bellman_ford` | Distances truncated at a radius, and the Bellman-Ford variant of the path getter | O(E + V log V) up to the cutoff | GPL-2.0* | `path` |
| NetworkX, igraph, Boost.Graph, JGraphT | `dag_longest_path`, `dag_longest_path_length`, `dag_shortest_paths`, `get_shortest_paths` on a DAG, `r_c_shortest_paths` on a DAG | Shortest and longest paths when the graph is acyclic, in one linear sweep | O(V+E) | BSD-3, GPL-2.0*, BSL-1.0, EPL-2.0* | `dag` |
| igraph | `expand_path_to_pairs`, `vertex_path_from_edge_path` | Turn an edge path into node pairs, and back | O(path) | GPL-2.0* | `path` |
| NetworkX | `average_shortest_path_length`, `reconstruct_path` | Mean distance over reachable pairs; rebuild a path from a predecessor array | O(V*E) unweighted, O(V*E log V) weighted | BSD-3 | `metric` (`average_shortest_path_length`), `path` (`reconstruct_path`) |
| JGraphT, Boost.Graph | `GraphMeasurer`, `TreeMeasurer`, `eccentricity`, `geodesic_distance`, `distance_recorder` | Diameter and radius computed while the search runs | O(V*E) | EPL-2.0*, BSL-1.0 | `metric` |
| JGraphT | `TransitNodeRoutingPrecomputation`, `ContractionHierarchyPrecomputation`, `ContractionHierarchyBidirectionalDijkstra` | Preprocessing that answers repeated shortest-path queries on road networks | O(V log V) preprocessing, near O(1) queries | EPL-2.0* | `not done`: a specialised speed-up for continental road networks; the plain methods above cover the semantics, and this is a research-sized addition |

## 2.3 Components, connectivity and cuts

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph, EasyGraph | `connected_components`, `number_connected_components`, `is_connected`, `node_connected_component`, `connected_components`, `ConnectivityInspector`, `connected_components`, `incremental_components`, `decompose`, `connected_component_of_node`, `is_connected` | Weakly connected pieces of an undirected graph | O(V+E) | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0*, BSD-3 | `component` |
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph, EasyGraph | `strongly_connected_components`, `number_strongly_connected_components`, `is_strongly_connected`, `kosaraju_strongly_connected_components`, `tarjan_scc`, `kosaraju_scc`, `scc`, `condensation`, `KosarajuStrongConnectivityInspector`, `GabowStrongConnectivityInspector`, `strong_components`, `connected_components` on a directed graph | Strongly connected pieces | O(V+E) | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0*, BSD-3 | `component` |
| NetworkX, igraph, JGraphT, Boost.Graph | `weakly_connected_components`, `number_weakly_connected_components`, `is_weakly_connected`, `is_weakly_connected`, `is_connected`, `decompose` | Weakly connected pieces of a directed graph | O(V+E) | BSD-3, GPL-2.0*, EPL-2.0*, BSL-1.0 | `component` |
| NetworkX, igraph, JGraphT | `is_semiconnected`, `condensation`, `TransitiveClosure`, `attracting_components`, `number_attracting_components`, `is_attracting_component` | Reachability between components, and the sinks that attract | O(V+E) | BSD-3, GPL-2.0*, EPL-2.0* | `component` |
| NetworkX, igraph, JGraphT, Boost.Graph | `biconnected_components`, `biconnected_component_edges`, `is_biconnected`, `articulation_points`, `biconnected_components`, `BiconnectivityInspector`, `biconnected_components`, `articulation_points` | Blocks and cut vertices | O(V+E) | BSD-3, GPL-2.0*, EPL-2.0*, BSL-1.0 | `component` |
| NetworkX, petgraph, JGraphT, igraph, Boost.Graph | `bridges`, `has_bridges`, `local_bridges`, `bridges`, `LocalBridge`, `bridges`, `Bridge` edges | Edges whose removal disconnects | O(V+E) | BSD-3, MIT, EPL-2.0*, GPL-2.0*, BSL-1.0 | `component` |
| NetworkX, JGraphT, igraph | `chain_decomposition`, `chain_decomposition`, `TreeDynamicConnectivity`, `BlockCutpointGraph`, `adhesion`, `cohesion`, `is_separator`, `is_minimal_separator`, `all_minimal_st_separators`, `minimum_size_separators`, `cohesive_blocks` | Chains, block-cut trees, separators and the cohesive block hierarchy | O(V+E) to O(V^3) | BSD-3, EPL-2.0*, GPL-2.0* | `component` |
| NetworkX, igraph | `kl_connected_subgraph`, `is_kl_connected` | Subgraph in which every pair has k paths of bounded length | O(V*E) | BSD-3, GPL-2.0* | `component` |
| NetworkX, igraph, JGraphT, Boost.Graph | `k_edge_components`, `k_edge_subgraphs`, `is_k_edge_connected`, `is_locally_k_edge_connected`, `bridge_components`, `k_edge_augmentation`, `edge_connectivity`, `local_edge_connectivity`, `minimum_edge_cut`, `minimum_st_edge_cut`, `edge_disjoint_paths`, `GusfieldEquivalentFlowTree`, `edge_connectivity`, `make_connected` | Edge connectivity, the cuts that witness it, and the edges that would raise it | O(k * max-flow) | BSD-3, GPL-2.0*, EPL-2.0*, BSL-1.0 | `flow` |
| NetworkX, igraph, JGraphT | `node_connectivity`, `local_node_connectivity`, `all_pairs_node_connectivity`, `average_node_connectivity`, `minimum_node_cut`, `minimum_st_node_cut`, `node_disjoint_paths`, `k_components`, `vertex_connectivity`, `st_vertex_connectivity`, `vertex_disjoint_paths`, `vertex_connectivity`, `vertex_disjoint_paths` by max flow | Vertex connectivity and the k-components it induces | O(k * max-flow) | BSD-3, GPL-2.0*, EPL-2.0* | `flow` |
| NetworkX, igraph | `stoer_wagner`, `stoer_wagner_min_cut` | Global minimum cut without a source-sink pair | O(V^3) simple, O(V*E + V^2 log V) with a heap | BSD-3, GPL-2.0* | `flow` |
| NetworkX, igraph | `edge_boundary`, `node_boundary`, `volume`, `cut_size` | Boundary of a node set | O(V+E) | BSD-3, GPL-2.0* | `component` |
| NetworkX, igraph | `all_node_cuts`, `minimum_st_edge_cut`, `even_tarjan_reduction`, `all_st_cuts`, `all_st_mincuts`, `st_mincut`, `st_mincut_value`, `mincut`, `mincut_value` | Enumerating minimum cuts | O(2^k * max-flow) | BSD-3, GPL-2.0* | `flow` |
| NetworkX, JGraphT | `build_auxiliary_edge_connectivity`, `build_auxiliary_node_connectivity`, `EdgeComponentAuxGraph` | The auxiliary graphs that turn connectivity into max flow | O(V+E) | BSD-3, EPL-2.0* | `flow` |

## 2.4 Flow and minimum cost flow

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph, LEMON | `maximum_flow`, `maximum_flow_value`, `dinitz`, `dinics`, `DinicMFImpl`, `push_relabel_max_flow`, `preflow_push`, `PushRelabelMFImpl`, `edmonds_karp`, `EdmondsKarpMFImpl`, `edmonds_karp_max_flow`, `boykov_kolmogorov`, `BoykovKolmogorovMFImpl`, `boykov_kolmogorov_max_flow`, `shortest_augmenting_path`, `maxflow`, `maxflow_value`, `Preflow` | Maximum s-t flow, by whichever augmenting scheme suits the graph | Dinic O(V^2*E), push-relabel O(V^3), Edmonds-Karp O(V*E^2) | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0*, BSL-1.0 | `flow` |
| NetworkX, JGraphT, igraph | `minimum_cut`, `minimum_cut_value`, `mincut`, `mincut_value`, `PadbergRaoOddMinimumCutset`, `st_mincut`, `st_mincut_value` | The s-t cut of least capacity, and its two sides | O(max-flow) | BSD-3, EPL-2.0*, GPL-2.0* | `flow` |
| NetworkX, JGraphT, igraph, LEMON | `gomory_hu_tree`, `GusfieldGomoryHuCutTree`, `gomory_hu_tree` | All-pairs min cuts in V-1 max-flow runs | O(V * max-flow) | BSD-3, EPL-2.0*, GPL-2.0*, BSL-1.0 | `flow` |
| NetworkX, JGraphT, LEMON | `network_simplex`, `min_cost_flow`, `min_cost_flow_cost`, `cost_of_flow`, `max_flow_min_cost`, `MinimumCostFlowProblem`, `CapacityScalingMinimumCostFlow`, `NetworkSimplex`, `CostScaling`, `CapacityScaling` | Minimum cost flow with supplies and demands | Practical near O(V*E log V); capacity scaling O((E log V)(E + V log V)) | BSD-3, EPL-2.0*, BSL-1.0 | `flow` |
| NetworkX, Boost.Graph, LEMON | `capacity_scaling`, `successive_shortest_path_nonnegative_weights`, `cycle_canceling`, `find_flow_cost`, `CycleCanceling` | The other three minimum cost flow schemes | O((E log V)(E + V log V)), O(V*E log V), the cycle canceling bound | BSD-3, BSL-1.0, BSL-1.0 | `flow` |
| NetworkX, Boost.Graph | `build_residual_network`, `residual_graph`, `reverse_residual_graph` | The residual graph as a first-class object | O(V+E) | BSD-3, BSL-1.0 | `flow` |
| igraph, Boost.Graph | `st_edge_connectivity`, `edge_connectivity`, `vertex_connectivity`, `dominator_tree`, `st_connected`, `find_odd_cycle` | Connectivity queries that run through the flow machinery | O(max-flow) | GPL-2.0*, BSL-1.0 | `flow` |

## 2.5 Matching, covering and assignment

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph, LEMON | `maximal_matching`, `greedy_matching`, `GreedyMaximumCardinalityMatching`, `maximum_matching`, `maximum_cardinality_matching`, `MaxMatching` | A maximal matching, and a maximum cardinality one in a general graph | Maximal O(E), maximum O(V^3) | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0*, BSL-1.0 | `matching` |
| NetworkX, JGraphT, igraph, LEMON | `max_weight_matching`, `KolmogorovWeightedMatching`, `SparseEdmondsMaximumCardinalityMatching`, `DenseEdmondsMaximumCardinalityMatching`, `maximum_bipartite_matching`, `MaxWeightedMatching` | Maximum weight matching in a general graph, blossom algorithm | O(V^3) | BSD-3, EPL-2.0*, GPL-2.0*, BSL-1.0 | `matching` |
| NetworkX, JGraphT, igraph | `hopcroft_karp_matching`, `eppstein_matching`, `HopcroftKarpMaximumCardinalityBipartiteMatching`, `maximum_bipartite_matching`, `min_weight_matching`, `PathGrowingWeightedMatching`, `GreedyWeightedMatching` | Bipartite matching, cardinality and weight | O(E*sqrt(V)) cardinality, O(V^3) weighted | BSD-3, EPL-2.0*, GPL-2.0* | `matching` |
| NetworkX, JGraphT | `minimum_weight_full_matching`, `KuhnMunkresMinimalWeightBipartitePerfectMatching`, `MaximumWeightBipartiteMatching`, `solve_lsap` | Assignment problem on a bipartite graph, square or not | O(V^3) | BSD-3, EPL-2.0*, GPL-2.0* | `matching` |
| NetworkX, igraph, Boost.Graph | `is_matching`, `is_maximal_matching`, `is_perfect_matching`, `is_maximal_matching`, `is_matching`, `checked_matching` | Predicates over a proposed matching | O(V+E) | BSD-3, GPL-2.0*, BSL-1.0 | `matching` |
| NetworkX, igraph | `min_edge_cover`, `is_edge_cover`, `min_edge_cover`, `to_vertex_cover` | Edge cover from a matching, and the vertex cover a bipartite matching implies | O(V*E) | BSD-3, GPL-2.0* | `matching` |
| NetworkX, igraph, JGraphT | `maximal_extendability`, `DulmageMendelsohnDecomposition`, `is_matching` on a bipartite graph | Structure of a bipartite matching | O(V+E) | BSD-3, EPL-2.0*, GPL-2.0* | `matching` |

## 2.6 Spanning trees, arborescences and tree algorithms

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, JGraphT, Boost.Graph, igraph, EasyGraph, LEMON | `minimum_spanning_tree`, `minimum_spanning_edges`, `KruskalMinimumSpanningTree`, `kruskal_min_spanning_tree`, `minimum_spanning_tree`, `kruskal_mst_edges`, `Kruskal` | Minimum spanning tree, Kruskal form | O(E log V) | BSD-3, EPL-2.0*, BSL-1.0, GPL-2.0*, BSD-3, BSL-1.0 | `tree` |
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph, EasyGraph, LEMON | `minimum_spanning_tree` (Prim), `min_spanning_tree`, `min_spanning_tree_prim`, `PrimMinimumSpanningTree`, `prim_minimum_spanning_tree`, `minimum_spanning_tree`, `prim_mst_edges`, `Prim` | Minimum spanning tree, Prim form | O(E + V log V) | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0*, BSD-3, BSL-1.0 | `tree` |
| JGraphT, Boost.Graph | `BoruvkaMinimumSpanningTree`, `boruvka_mst_edges` | Minimum spanning tree, Boruvka form, parallel friendly | O(E log V) | EPL-2.0*, BSD-3 | `tree` |
| NetworkX, JGraphT | `maximum_spanning_tree`, `maximum_spanning_edges`, `SpanningTreeIterator`, `ArborescenceIterator` | Maximum spanning tree, and the trees in order of weight | O(E log V) per tree | BSD-3, EPL-2.0* | `tree` |
| NetworkX, Boost.Graph, igraph | `random_spanning_tree`, `random_spanning_tree`, `random_spanning_tree`, `loop_erased_random_walk` | A spanning tree drawn at random, the loop-erased walk of Wilson | O(V*E) | BSD-3, BSL-1.0, GPL-2.0* | `tree` |
| NetworkX, JGraphT | `greedy_branching`, `maximum_branching`, `minimum_branching`, `maximum_spanning_arborescence`, `minimum_spanning_arborescence`, `ArborescenceIterator`, `Edmonds` based branching | Optimum branching in a directed graph | O(V*E) | BSD-3, EPL-2.0* | `tree` |
| NetworkX | `branching_weight`, `number_of_spanning_trees` | Weight of a branching, and the count of spanning trees by the matrix-tree theorem | O(V+E) and O(V^3) | BSD-3 | `tree` (`number_of_spanning_trees` sits in `moonmath` for the determinant) |
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `steiner_tree`, `metric_closure`, `steiner_tree`, `GreedyMultiplicativeSpanner`, `spanner`, `spanner` | A small connecting subgraph for a terminal set | O(k*V^2) for the metric closure | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `approx` (`tree` holds the exact parts) |
| NetworkX, JGraphT, igraph, Boost.Graph | `is_tree`, `is_forest`, `is_arborescence`, `is_branching`, `is_tree`, `is_forest`, `is_tree` | Shape predicates for trees and forests | O(V+E) | BSD-3, EPL-2.0*, GPL-2.0*, BSL-1.0 | `struct` |
| NetworkX, igraph | `to_prufer_sequence`, `from_prufer_sequence`, `to_prufer`, `from_prufer`, `tree_from_parent_vector` | Bijection between trees and integer sequences | O(V) | BSD-3, GPL-2.0* | `gen` |
| NetworkX | `to_nested_tuple`, `from_nested_tuple`, `join_trees` | Canonical tree shapes as nested tuples; graft one tree onto another | O(V) | BSD-3 | `gen` |
| NetworkX, JGraphT, igraph | `center`, `centroid`, `tree_center`, `TreeMeasurer`, `graph_center`, `radius`, `tree_center`, `TreeMeasurer` | Centre and centroid of a tree | O(V) | BSD-3, EPL-2.0*, GPL-2.0* | `metric` |
| NetworkX | `tree_broadcast_center`, `tree_broadcast_time` | The node that minimises the worst broadcast delay | O(V) | BSD-3 | `tree` |
| NetworkX, JGraphT | `lowest_common_ancestor`, `all_pairs_lowest_common_ancestor`, `tree_all_pairs_lowest_common_ancestor`, `NaiveLCAFinder`, `BinaryLiftingLCAFinder`, `EulerTourRMQLCAFinder`, `HeavyPathLCAFinder`, `TarjanLCAFinder` | Lowest common ancestor, offline, online and in bulk | O(1) per query after O(V log V) preprocessing | BSD-3, EPL-2.0* | `tree` |
| JGraphT | `HeavyPathDecomposition`, `TreeToPathDecompositionAlgorithm` | Split a tree into heavy paths | O(V) | EPL-2.0* | `tree` |
| NetworkX, JGraphT | `minimum_spanning_tree` on a tree, `TreeSingleSourcePathsImpl`, `TreeMeasurer`, `is_tree` with a designated root | Rooted-tree utilities: depth, ancestors, subtree sizes | O(V) | BSD-3, EPL-2.0* | `tree` |
| JGraphT | `AbstractCapacitatedMinimumSpanningTree`, `AhujaOrlinSharmaCapacitatedMinimumSpanningTree`, `EsauWilliamsCapacitatedMinimumSpanningTree`, `KSpanningTreeClustering` | Spanning tree with a capacity per branch | O(V^2 log V) and worse | EPL-2.0* | `not done`: a vehicle-routing problem, not a graph primitive; the four heuristics would each need their own differential test against JGraphT |

## 2.7 Cycles and Eulerian tours

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `cycle_basis`, `minimum_cycle_basis`, `PatonCycleBase`, `AbstractFundamentalCycleBasis`, `QueueBFSFundamentalCycleBasis`, `StackBFSFundamentalCycleBasis`, `fundamental_cycles`, `minimum_cycle_basis` | A cycle basis of the graph, plain or of least total weight | O(V*E) | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `cycle` |
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `simple_cycles`, `recursive_simple_cycles`, `JohnsonSimpleCycles`, `HawickJamesSimpleCycles`, `SzwarcfiterLauerSimpleCycles`, `TarjanSimpleCycles`, `TiernanSimpleCycles`, `hawick_circuits`, `tiernan_all_cycles`, `simple_cycles`, `simple_cycles_callback`, `Cycles` | Every elementary cycle | O((V+E)(c+1)) for c cycles | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `cycle` |
| NetworkX, petgraph, JGraphT, igraph | `find_cycle`, `is_cyclic_directed`, `is_cyclic_undirected`, `CycleDetector`, `find_cycle`, `find_odd_cycle` | Whether a cycle exists, and one witness | O(V+E) | BSD-3, MIT, EPL-2.0*, GPL-2.0* | `cycle` |
| NetworkX, JGraphT, Boost.Graph, igraph | `chordless_cycles`, `ChordalityInspector`, `find_odd_cycle`, `girth` related | Cycles with no chord; odd cycles for bipartiteness | O(V*E) per cycle | BSD-3, EPL-2.0*, BSL-1.0, GPL-2.0* | `cycle` |
| NetworkX, JGraphT, igraph | `girth`, `girth` | Length of the shortest cycle | O(V*E) | BSD-3, EPL-2.0*, GPL-2.0* | `cycle` |
| NetworkX, igraph | `is_eulerian`, `has_eulerian_path`, `is_semieulerian`, `eulerian_circuit`, `eulerian_path`, `eulerize`, `is_eulerian`, `eulerian_path`, `eulerian_cycle` | Eulerian trail and circuit, and the edges that would complete one | O(V+E) | BSD-3, GPL-2.0* | `cycle` |
| JGraphT | `HierholzerEulerianCycle`, `ChinesePostman`, `EulerianCycleAlgorithm` | Hierholzer's construction and the Chinese postman tour | O(V+E) and O(V^3) | EPL-2.0* | `cycle` (`ChinesePostman` in `approx`) |
| JGraphT, NetworkX | `HowardMinimumMeanCycle`, `AhujaOrlinSharmaCyclicExchangeLocalAugmentation` | Minimum mean cycle ratio, and cycle-canceling augmentation | O(V*E) | EPL-2.0*, BSD-3 | `cycle` (`HowardMinimumMeanCycle`), `flow` (the augmentation) |
| NetworkX, JGraphT | `hammer`-free check, `BergeGraphInspector`, `WeakChordalityInspector` | Recognise perfect and weakly chordal graphs by looking for odd holes | O(V^5) | BSD-3, EPL-2.0* | `struct` |

## 2.8 DAG, topological order and reachability

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph, CPython | `topological_sort`, `toposort`, `TopologicalOrderIterator`, `topological_sort`, `topological_sorting`, `TopologicalSorter.static_order`, `TopologicalSorter.get_ready`, `TopologicalSorter.done`, `TopologicalSorter.prepare`, `TopologicalSorter.is_active`, `TopologicalSorter.add` | Linear order consistent with the edges; the incremental form reports batches as they unblock | O(V+E) | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0*, PSF-2.0* | `dag` |
| NetworkX, petgraph, JGraphT, igraph | `is_directed_acyclic_graph`, `is_cyclic_directed`, `CycleDetector`, `is_dag`, `is_acyclic` | Acyclicity test | O(V+E) | BSD-3, MIT, EPL-2.0*, GPL-2.0* | `dag` |
| NetworkX | `all_topological_sorts`, `lexicographical_topological_sort`, `topological_generations` | Every order, the smallest one, and the level structure | O(V+E) per order | BSD-3 | `dag` |
| NetworkX, JGraphT, Boost.Graph, igraph | `ancestors`, `descendants`, `TransitiveClosure`, `transitive_closure`, `transitive_closure`, `dfs` based closure | Reachability from or to a node, and the whole closure | O(V*E) for the closure | BSD-3, EPL-2.0*, BSL-1.0, GPL-2.0* | `dag` |
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `transitive_reduction`, `tred`, `TransitiveReduction`, `transitive_reduction`, `transitive_closure_dag` | The smallest graph with the same reachability | O(V*E) | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `dag` |
| NetworkX, petgraph | `dag_longest_path`, `dag_longest_path_length`, `dag_to_branching`, `feedback_arc_set`, `greedy_feedback_arc_set` | Longest path in a DAG; a minimum set of edges to remove to get one | O(V+E), feedback set O(V*E) | BSD-3, MIT | `dag` |
| NetworkX | `antichains`, `antichain_width`, `colliders`, `v_structures`, `is_aperiodic` | Order-theoretic width, and the v-structures a causal reading needs | O(V*E) | BSD-3 | `dag` |
| igraph | `feedback_arc_set`, `feedback_vertex_set` | Smallest set of edges or vertices that breaks all cycles | O(V*E) to O(V^3) | GPL-2.0* | `dag` |
| NetworkX, Boost.Graph, igraph | `immediate_dominators`, `dominance_frontiers`, `lengauer_tarjan_dominator`, `dominator_tree` | Dominators of a flow graph, and the frontier between them | O(E log V) | BSD-3, BSL-1.0, GPL-2.0* | `dag` |
| Boost.Graph, JGraphT | `two_graphs_common_spanning_trees` | Spanning trees present in two graphs at once | O(V*E) | BSL-1.0 | `tree` |

## 2.9 Coloring

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `greedy_color`, `dsatur_coloring`, `GreedyColoring`, `LargestDegreeFirstColoring`, `SmallestDegreeLastColoring`, `SaturationDegreeColoring`, `RandomGreedyColoring`, `sequential_vertex_coloring`, `vertex_coloring_greedy` | Vertex coloring by a greedy order | O(V+E) plus the order's sort | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `color` |
| NetworkX | `strategy_largest_first`, `strategy_smallest_last`, `strategy_independent_set`, `strategy_connected_sequential`, `strategy_connected_sequential_bfs`, `strategy_connected_sequential_dfs`, `strategy_saturation_largest_first`, `strategy_random_sequential` | The orderings a greedy coloring runs over | O(V+E) each | BSD-3 | `color` |
| NetworkX, JGraphT | `equitable_color`, `BrownBacktrackColoring` | Balanced coloring, and exact coloring by backtracking | O(V^2) greedy, exponential exact | BSD-3, EPL-2.0* | `color` |
| JGraphT, Boost.Graph, igraph | `ChordalGraphColoring`, `edge_coloring`, `is_vertex_coloring`, `is_edge_coloring`, `is_bipartite_coloring` | Coloring a chordal graph in linear time; edge coloring; validity checks | O(V+E) | EPL-2.0*, BSL-1.0, GPL-2.0* | `color` |
| NetworkX | `greedy_color` with a strategy, `chromatic_polynomial` | The chromatic number, and the polynomial that counts colorings | Exponential | BSD-3 | `color` |
| NetworkX, JGraphT | `ColorRefinementAlgorithm` | Refine a coloring until it is stable, the first step of isomorphism testing | O((V+E) log V) | BSD-3, EPL-2.0* | `iso` |

## 2.10 Cliques, independent sets and chordality

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph | `find_cliques`, `find_cliques_recursive`, `maximal_cliques`, `BronKerboschCliqueFinder`, `PivotBronKerboschCliqueFinder`, `DegeneracyBronKerboschCliqueFinder`, `BaseBronKerboschCliqueFinder`, `bron_kerbosch_all_cliques`, `maximal_cliques`, `maximal_cliques_subset`, `maximal_cliques_callback`, `maximal_cliques_count`, `largest_cliques` | Every maximal clique, with or without pivoting | O(3^(V/3)) worst | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0* | `clique` |
| NetworkX, igraph | `enumerate_all_cliques`, `cliques`, `cliques_callback`, `clique_size_hist`, `count_cliques`, `all_cliques` | Every clique, not only the maximal ones | O(#cliques * V) | BSD-3, GPL-2.0* | `clique` |
| NetworkX, JGraphT, igraph | `max_weight_clique`, `weighted_cliques`, `largest_weighted_cliques`, `weighted_clique_number` | The clique of greatest total weight | Exponential worst | BSD-3, EPL-2.0*, GPL-2.0* | `clique` |
| NetworkX, igraph | `node_clique_number`, `number_of_cliques`, `clique_number`, `max_clique` | Clique counts and the clique number per node | O(#cliques * V) | BSD-3, GPL-2.0* | `clique` |
| NetworkX, igraph, JGraphT | `make_max_clique_graph`, `make_clique_bipartite`, `is_clique` | Graph over the cliques, and the clique-bipartite form | O(V^2) | BSD-3, GPL-2.0*, EPL-2.0* | `clique` |
| NetworkX, JGraphT, igraph | `maximal_independent_set`, `ChordalGraphIndependentSetFinder`, `independent_vertex_sets`, `largest_independent_vertex_sets`, `maximal_independent_vertex_sets`, `independence_number`, `is_independent_vertex_set` | Independent sets, and the independence number | Exponential worst | BSD-3, EPL-2.0*, GPL-2.0* | `clique` |
| NetworkX, JGraphT, igraph | `is_chordal`, `is_perfect_graph`, `chordal_graph_cliques`, `chordal_graph_treewidth`, `complete_to_chordal_graph`, `find_induced_nodes`, `ChordalityInspector`, `ChordalGraphMaxCliqueFinder`, `CliqueMinimalSeparatorDecomposition`, `is_chordal`, `is_perfect` | Chordality by maximum cardinality search, and the treewidth it bounds | O(V+E) | BSD-3, EPL-2.0*, GPL-2.0* | `clique` |
| igraph | `maximal_cliques_file`, `maximal_cliques_hist` | Maximal cliques streamed to a file, and their size histogram | O(#cliques) plus I/O | GPL-2.0* | `clique` |
| NetworkX | `is_at_free`, `find_asteroidal_triple` | Asteroidal-triple-free graphs, the class in which the independent set problem is easy | O(V^3) | BSD-3 | `struct` |
| JGraphT | `ChordalGraphMinimalVertexSeparatorFinder` | Minimal vertex separators of a chordal graph | O(V+E) | EPL-2.0* | `clique` |

## 2.11 Isomorphism and canonical forms

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, petgraph, JGraphT, Boost.Graph, igraph, scikit-network | `is_isomorphic`, `is_isomorphic`, `VF2GraphIsomorphismInspector`, `isomorphism` (vf2_sub_graph_iso), `isomorphic`, `isomorphic_vf2`, `isomorphic_bliss`, `are_isomorphic` | Whether two graphs are the same up to relabelling | Exponential worst, near linear on most pairs after refinement | BSD-3, MIT, EPL-2.0*, BSL-1.0, GPL-2.0*, BSD-3 | `iso` |
| NetworkX | `could_be_isomorphic`, `fast_could_be_isomorphic`, `faster_could_be_isomorphic` | Cheap necessary conditions before the real test | O(V+E) | BSD-3 | `iso` |
| NetworkX | `GraphMatcher.__init__`, `GraphMatcher.initialize`, `GraphMatcher.is_isomorphic`, `GraphMatcher.isomorphisms_iter`, `GraphMatcher.match`, `GraphMatcher.candidate_pairs_iter`, `GraphMatcher.syntactic_feasibility`, `GraphMatcher.semantic_feasibility`, `DiGraphMatcher.__init__`, `DiGraphMatcher.initialize`, `DiGraphMatcher.is_isomorphic`, `DiGraphMatcher.isomorphisms_iter`, `DiGraphMatcher.match`, `DiGraphMatcher.candidate_pairs_iter`, `DiGraphMatcher.syntactic_feasibility`, `DiGraphMatcher.semantic_feasibility` | The VF2 state machine, exposed so callers can add their own pruning | Exponential worst | BSD-3 | `iso` |
| NetworkX, petgraph, JGraphT, igraph | `GraphMatcher.subgraph_is_isomorphic`, `GraphMatcher.subgraph_is_monomorphic`, `GraphMatcher.subgraph_isomorphisms_iter`, `GraphMatcher.subgraph_monomorphisms_iter`, `DiGraphMatcher.subgraph_is_isomorphic`, `DiGraphMatcher.subgraph_is_monomorphic`, `DiGraphMatcher.subgraph_isomorphisms_iter`, `DiGraphMatcher.subgraph_monomorphisms_iter`, `is_isomorphic_subgraph`, `is_isomorphic_subgraph_matching`, `subgraph_isomorphisms_iter`, `VF2SubgraphIsomorphismInspector`, `subisomorphic`, `subisomorphic_vf2`, `subisomorphic_lad`, `get_subisomorphisms_vf2`, `count_subisomorphisms_vf2` | Subgraph isomorphism and monomorphism | Exponential worst | BSD-3, MIT, EPL-2.0*, GPL-2.0* | `iso` |
| NetworkX | `categorical_node_match`, `categorical_edge_match`, `categorical_multiedge_match`, `numerical_node_match`, `numerical_edge_match`, `numerical_multiedge_match`, `generic_node_match`, `generic_edge_match`, `generic_multiedge_match` | Payload compatibility predicates handed to the matcher | O(1) per comparison | BSD-3 | `iso` |
| NetworkX, petgraph | `vf2pp_is_isomorphic`, `vf2pp_all_isomorphisms`, `vf2pp_isomorphism`, `is_isomorphic_matching` | VF2++ with a better node order | O(V+E) on most pairs | BSD-3, MIT | `iso` |
| NetworkX, igraph, JGraphT | `tree_isomorphism`, `rooted_tree_isomorphism`, `AHURootedTreeIsomorphismInspector`, `AHUUnrootedTreeIsomorphismInspector`, `AHUForestIsomorphismInspector`, `isomorphic` on trees | Tree isomorphism by AHU canonical strings, linear time | O(V) | BSD-3, GPL-2.0*, EPL-2.0* | `iso` |
| igraph | `induced_subgraph_map`, `get_isomorphisms_vf2_callback`, `count_isomorphisms_vf2`, `get_isomorphisms_vf2`, `get_subisomorphisms_vf2_callback` | The callback and count forms of the VF2 queries, and the node map an induced subgraph leaves behind | Exponential worst | GPL-2.0* | `iso`, `op` (`induced_subgraph_map`) |
| NetworkX | `ISMAGS`, `GraphMatcher` with symmetry breaking | Subgraph enumeration that skips symmetric duplicates | Depends on the pattern | BSD-3 | `iso` |
| igraph | `canonical_permutation`, `canonical_permutation_bliss`, `permute_vertices`, `count_automorphisms`, `automorphism_group`, `count_automorphisms_bliss`, `automorphism_group_bliss` | Canonical labelling and the automorphism group | Exponential worst | GPL-2.0* | `iso` |
| igraph | `isoclass`, `isoclass_subgraph`, `isoclass_create`, `graph_count` | The isomorphism class number of a small graph | O(1) after a table lookup | GPL-2.0* | `iso` |
| igraph | `simplify_and_colorize` | Preprocessing before a BLISS run | O(V+E) | GPL-2.0* | `iso` |
| JGraphT | `ColorRefinementIsomorphismInspector`, `IsomorphicGraphMapping`, `GraphOrdering` | Refinement-based isomorphism and the mapping object it returns | O((V+E) log V) | EPL-2.0* | `iso` |
| Boost.Graph | `mcgregor_common_subgraphs` | Largest common subgraph of two graphs | Exponential | BSL-1.0 | `iso` |

## 2.12 Centrality and ranking

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, JGraphT, Boost.Graph, igraph, EasyGraph | `degree_centrality`, `in_degree_centrality`, `out_degree_centrality`, `DegreeCentrality`, `degree_centrality`, `centralization_degree`, `degree_centrality` | Share of nodes each node touches | O(V+E) | BSD-3, EPL-2.0*, BSL-1.0, GPL-2.0*, BSD-3 | `centrality` |
| NetworkX, JGraphT, igraph, EasyGraph | `closeness_centrality`, `incremental_closeness_centrality`, `ClosenessCentrality`, `closeness`, `closeness_cutoff`, `centralization_closeness`, `closeness_centrality`, `closeness_centrality_parallel` | Reciprocal of the mean distance to everyone else | O(V*E) unweighted, O(V*E + V^2 log V) weighted | BSD-3, EPL-2.0*, GPL-2.0*, BSD-3 | `centrality` |
| NetworkX, JGraphT, Boost.Graph, igraph, scikit-network, EasyGraph | `betweenness_centrality`, `betweenness_centrality_subset`, `BetweennessCentrality`, `ApBetweennessCentrality`, `betweenness_centrality`, `betweenness`, `betweenness_cutoff`, `betweenness_subset`, `centralization_betweenness`, `Betweenness`, `betweenness_centrality`, `betweenness_centrality_parallel` | Share of shortest paths through each node | O(V*E) unweighted, O(V*E + V^2 log V) weighted | BSD-3, EPL-2.0*, BSL-1.0, GPL-2.0*, BSD-3, BSD-3 | `centrality` |
| NetworkX, JGraphT, igraph, EasyGraph | `edge_betweenness_centrality`, `edge_betweenness_centrality_subset`, `EdgeBetweennessCentrality`, `edge_betweenness`, `edge_betweenness_cutoff`, `edge_betweenness_subset`, `ego_betweenness` | Share of shortest paths through each edge | O(V*E) | BSD-3, EPL-2.0*, GPL-2.0*, BSD-3 | `centrality` |
| NetworkX, JGraphT | `current_flow_betweenness_centrality`, `edge_current_flow_betweenness_centrality`, `approximate_current_flow_betweenness_centrality`, `current_flow_betweenness_centrality_subset`, `edge_current_flow_betweenness_centrality_subset`, `current_flow_closeness_centrality` | Centrality that spreads current instead of counting paths | O(V^3) exact, O(V*E) approximate | BSD-3 | `centrality` (the Laplacian solve comes from `moonmath`) |
| NetworkX | `information_centrality`, `load_centrality`, `edge_load_centrality` | Centrality by information flow, and by traffic load | O(V*E) | BSD-3 | `centrality` |
| NetworkX, JGraphT, igraph, scikit-network, EasyGraph | `eigenvector_centrality`, `eigenvector_centrality_numpy`, `katz_centrality`, `katz_centrality_numpy`, `EigenvectorCentrality`, `KatzCentrality`, `eigenvector_centrality`, `centralization_eigenvector_centrality`, `Katz`, `eigenvector_centrality`, `katz_centrality` | Centrality from the dominant eigenvector, or from a damped walk | O(k*E) for k iterations | BSD-3, EPL-2.0*, GPL-2.0*, BSD-3, BSD-3 | `centrality` |
| NetworkX, JGraphT, Boost.Graph, igraph, scikit-network, EasyGraph | `pagerank`, `google_matrix`, `PageRank`, `page_rank`, `pagerank`, `personalized_pagerank`, `personalized_pagerank_vs`, `PageRank`, `get_pagerank`, `push_pagerank`, `pagerank` | PageRank, personalisable and with a push variant | O(k*E) | BSD-3, EPL-2.0*, BSL-1.0, GPL-2.0*, BSD-3, BSD-3 | `centrality` |
| NetworkX, igraph, scikit-network | `hits`, `hub_and_authority_scores`, `HITS` | Hub and authority scores | O(k*E) | BSD-3, GPL-2.0*, BSD-3 | `centrality` |
| NetworkX, JGraphT | `harmonic_centrality`, `HarmonicCentrality`, `harmonic_centrality`, `harmonic_centrality_cutoff` | Mean reciprocal distance, defined on disconnected graphs too | O(V*E) | BSD-3, EPL-2.0*, GPL-2.0* | `centrality` |
| NetworkX, igraph | `group_betweenness_centrality`, `group_closeness_centrality`, `group_degree_centrality`, `group_in_degree_centrality`, `group_out_degree_centrality`, `prominent_group` | Centrality of a set of nodes rather than one | O(V*E) | BSD-3, GPL-2.0* | `centrality` |
| NetworkX | `percolation_centrality`, `second_order_centrality`, `subgraph_centrality`, `subgraph_centrality_exp`, `estrada_index`, `communicability_betweenness_centrality`, `laplacian_centrality` | Centralities built from matrix functions | O(V^3) | BSD-3 | `centrality` (`moonmath` supplies the matrix exponential and the eigen decomposition) |
| igraph | `centralization_degree_tmax`, `centralization_betweenness_tmax`, `centralization_closeness_tmax`, `centralization_eigenvector_centrality_tmax` | The theoretical maximum a centralisation index divides by | O(1) or O(V) | GPL-2.0* | `centrality` |
| NetworkX | `dispersion`, `local_reaching_centrality`, `global_reaching_centrality`, `voterank`, `trophic_levels`, `trophic_differences`, `trophic_incoherence_parameter` | Spread around a node, and the trophic structure of a directed network | O(V*E) | BSD-3 | `centrality` (trophic measures: `metric`) |
| NetworkX, igraph, scikit-network | `birank` | Bipartite ranking with separate hub and authority scores | O(k*E) | BSD-3 | `centrality` |
| NetworkX, igraph | `structural_rank`-style measures, `constraint`, `effective_size`, `efficiency`, `hierarchy`, `inverse_closeness_centrality`, `bounded_inverse_closeness_centrality` | Structural-hole measures over a node's ego network | O(V*E) | BSD-3, GPL-2.0* | `metric` |

## 2.13 Community detection and partitioning

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, igraph, scikit-network, EasyGraph | `louvain_communities`, `louvain_partitions`, `community_multilevel`, `Louvain`, `LouvainIteration`, `louvain_communities`, `louvain_partitions` | Modularity by local moving and aggregation | O(E) per level | BSD-3, GPL-2.0*, BSD-3, BSD-3 | `community` |
| NetworkX, igraph, scikit-network | `leiden_communities`, `leiden_partitions`, `community_leiden`, `community_leiden_simple`, `Leiden` | Leiden, with the refinement step that guarantees well connected parts | O(E) per level | BSD-3, GPL-2.0*, BSD-3 | `community` |
| NetworkX, JGraphT, igraph | `label_propagation_communities`, `asyn_lpa_communities`, `fast_label_propagation_communities`, `LabelPropagationClustering`, `community_label_propagation` | Communities by letting labels spread | O(k*E) | BSD-3, EPL-2.0*, GPL-2.0* | `community` |
| NetworkX, JGraphT, igraph | `greedy_modularity_communities`, `naive_greedy_modularity_communities`, `community_fastgreedy`, `GirvanNewmanClustering`, `greedy_modularity_communities` | Merge the pair that gains the most modularity, and the Girvan-Newman split | O(E log^2 V) with a heap | BSD-3, EPL-2.0*, GPL-2.0*, BSD-3 | `community` |
| NetworkX, igraph | `girvan_newman`, `edge_betweenness_partition`, `edge_current_flow_betweenness_partition`, `community_edge_betweenness`, `community_eb_get_merges` | Split by repeatedly removing the edge with the highest betweenness | O(V*E^2) | BSD-3, GPL-2.0* | `community` |
| NetworkX, JGraphT, igraph | `kernighan_lin_bisection`, `spectral_modularity_bipartition`, `greedy_node_swap_bipartition`, `community_leading_eigenvector`, `community_spinglass`, `community_spinglass_single`, `community_infomap`, `community_optimal_modularity`, `community_walktrap` | Bisection by swapping, by spectrum, by spin glass, by information flow | O(V^2) to exponential | BSD-3, EPL-2.0*, GPL-2.0* | `community` (spin glass and infomap: `not done`, they need statistical-physics machinery and their own differential tests) |
| NetworkX, igraph, scikit-network | `asyn_fluidc`, `PropagationClustering`, `KCenters`, `Paris`, `community_fluid_communities`, `community_voronoi` | Fluid, propagation and hierarchical clustering | O(V*E) to O(V^2) | BSD-3, BSD-3, GPL-2.0* | `community` |
| EasyGraph | `SLPA`, `BMLPA`, `HANP`, `ICC`, `BICC`, `AP_BICC`, `AP_Greedy`, `Propagate_bbc`, `SelectLabels`, `SelectLabels_HANP`, `Id`, `Id1`, `LS_degree_communities`, `UpdateScore`, `UpdateScore_Hier`, `HopAttenuation_Hier`, `estimate_stop_cond`, `estimate_stop_cond_HANP`, `standard_data` | Overlapping communities by speaker-listener propagation and by hierarchical attention | O(k*E) | BSD-3 | `community` (speaker-listener and the label-selection family; the attention model: `not done`) |
| NetworkX | `k_clique_communities`, `greedy_source_expansion`, `overlapping_modularity`, `constant_potts_model` | Overlapping communities from k-cliques, and the Potts objective | Exponential in k | BSD-3 | `community` |
| NetworkX | `lukes_partitioning`, `is_partition`, `is_cover`, `partition_quality` | Partition of a tree with size and weight limits, and the validity and quality of a proposed partition | O(V^2) | BSD-3 | `community` |
| NetworkX, igraph | `modularity`, `modularity`, `modularity_matrix`, `UndirectedModularityMeasurer`, `compare_communities`, `split_join_distance`, `get_membership` | Score a partition, and compare two partitions | O(V+E) | BSD-3, GPL-2.0*, EPL-2.0* | `community` |
| JGraphT, NetworkX | `BipartitePartitioning`, `is_partition` on a bipartite graph | Two-way partition check | O(V+E) | EPL-2.0*, BSD-3 | `community` |
| igraph | `community_to_membership`, `le_community_to_membership`, `reindex_membership`, `hrg_fit`, `hrg_sample`, `hrg_consensus`, `hrg_predict`, `hrg_create`, `hrg_resize`, `hrg_size`, `from_hrg_dendrogram` | The membership array of a merge hierarchy, and hierarchical random graphs | O(V log V) to O(V^2) | GPL-2.0* | `community` (the hrg family: `not done`, a separate model with its own fitting procedure) |

## 2.14 Approximation and heuristics

`approx` holds the algorithms whose answer is not guaranteed optimal; the exact form stays in the
family package named in the row.

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, JGraphT | `christofides`, `ChristofidesThreeHalvesApproxMetricTSP` | Tour within 3/2 of optimal on a metric graph | O(V^3) | BSD-3, EPL-2.0* | `approx` |
| NetworkX, JGraphT | `traveling_salesman_problem`, `greedy_tsp`, `simulated_annealing_tsp`, `threshold_accepting_tsp`, `asadpour_atsp`, `GreedyHeuristicTSP`, `NearestNeighborHeuristicTSP`, `NearestInsertionHeuristicTSP`, `TwoOptHeuristicTSP`, `RandomTourTSP`, `TwoApproxMetricTSP`, `PalmerHamiltonianCycle`, `HeldKarpTSP`, `HamiltonianCycleAlgorithm` | Tour construction and local search, symmetric and asymmetric | O(V^2) per construction, O(V^2) per 2-opt pass, exponential for Held-Karp | BSD-3, EPL-2.0* | `approx` |
| NetworkX, JGraphT | `min_weighted_vertex_cover`, `min_weighted_dominating_set`, `min_edge_dominating_set`, `dominating_set`, `is_dominating_set`, `GreedyVCImpl`, `EdgeBasedTwoApproxVCImpl`, `BarYehudaEvenTwoApproxVCImpl`, `ClarksonTwoApproxVCImpl`, `RecursiveExactVCImpl` | Vertex cover and dominating set, greedy, 2-approximate or exact | O(V*E) greedy, exponential exact | BSD-3, EPL-2.0* | `approx` |
| NetworkX | `maximum_independent_set`, `max_clique`, `clique_removal`, `large_clique_size`, `min_maximal_matching`, `ramsey_R2`, `randomized_partitioning`, `one_exchange`, `hamiltonian_path` | Heuristics for the independent set, clique and partition problems | O(V+E) per pass | BSD-3 | `approx` |
| NetworkX, JGraphT | `densest_subgraph`, `GoldbergMaximumDensitySubgraphAlgorithm`, `GoldbergMaximumDensitySubgraphAlgorithmNodeWeights`, `GoldbergMaximumDensitySubgraphAlgorithmNodeWeightPerEdgeWeight` | Densest subgraph by parametric flow | O(log V * max-flow) | BSD-3, EPL-2.0* | `approx` |
| NetworkX | `treewidth_min_degree`, `treewidth_min_fill_in` | Upper bounds on treewidth by elimination order | O(V^2) | BSD-3 | `approx` |
| NetworkX, igraph | `steiner_tree`, `metric_closure`, `spanner` | A connecting tree or a sparse spanner for a terminal set | O(k*V^2) | BSD-3, GPL-2.0* | `approx` |
| NetworkX | `average_clustering`, `diameter` by double sweep | Sampling shortcuts for measures that are too slow exactly | O(V*E) | BSD-3 | `approx` |
| NetworkX, petgraph, Boost.Graph | `dedensify`, `snap_aggregation`, `double_edge_swap`, `directed_edge_swap`, `connected_double_edge_swap`, `rewire_edges`, `rewire_directed_edges` | Rewire a graph while keeping its degree sequence, and compress dense neighbourhoods | O(k) per swap | BSD-3, MIT, BSL-1.0, GPL-2.0* | `gen` |
| JGraphT | `AhujaOrlinSharmaCapacitatedMinimumSpanningTree`, `EsauWilliamsCapacitatedMinimumSpanningTree` | Capacitated spanning tree heuristics | O(V^2 log V) | EPL-2.0* | `not done`: a routing problem, see the note in 2.6 |
| JGraphT, igraph | `ChinesePostman` | Shortest closed walk that covers every edge | O(V^3) | EPL-2.0*, GPL-2.0* | `approx` |

## 2.15 Planarity, embedding and minors

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, Boost.Graph, JGraphT | `check_planarity`, `is_planar`, `PlanarEmbedding`, `boyer_myrvold_planarity_test`, `BoyerMyrvoldPlanar`, `BoyerMyrvoldPlanarityInspector`, `PlanarityTestingAlgorithm` | Planarity test and the rotation system if planar | O(V+E) | BSD-3, BSL-1.0, EPL-2.0* | `struct` |
| NetworkX, Boost.Graph | `combinatorial_embedding_to_pos`, `chrobak_payne_straight_line_drawing`, `planar_canonical_ordering`, `planar_face_traversal`, `is_straight_line_drawing`, `make_maximal_planar`, `make_biconnected_planar`, `make_connected` | Turn an embedding into coordinates, and the augmentation steps before it | O(V+E) to O(V^2) | BSD-3, BSL-1.0 | `struct` (the drawing itself is out of scope; see the last section) |
| Boost.Graph | `is_kuratowski_subgraph` | Whether a set of edges forms a forbidden subdivision | O(V+E) | BSL-1.0 | `struct` |
| NetworkX | `contracted_edge`, `contracted_nodes`, `identified_nodes`, `equivalence_classes`, `quotient_graph` | Minors: merge nodes, keep the edge multiset, collapse a partition | O(V+E) | BSD-3 | `op` |
| NetworkX, petgraph | `GraphMatcher` with the minor predicate, `subgraph_isomorphisms_iter` on a minor | Minor containment test | Exponential | BSD-3, MIT | `iso` |

## 2.16 Structural predicates and decompositions

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, igraph, JGraphT, Boost.Graph, scikit-network | `is_bipartite`, `bipartite.color`, `bipartite.sets`, `is_bipartite_node_set`, `is_bipartite`, `is_bipartite_coloring`, `BipartitePartitioning`, `is_bipartite`, `is_bipartite` | Two-coloring test and the two sides it yields | O(V+E) | BSD-3, GPL-2.0*, EPL-2.0*, BSL-1.0, BSD-3 | `struct` |
| NetworkX, igraph | `core_number`, `k_core`, `k_shell`, `k_crust`, `k_corona`, `k_truss`, `onion_layers`, `coreness`, `get_core_decomposition`, `Coreness`, `k_core` | Degeneracy, the k-core hierarchy and the onion layers | O(V+E) for cores, O(E^1.5) for k-truss | BSD-3, GPL-2.0*, EPL-2.0*, BSD-3 | `struct` |
| NetworkX | `is_graphical`, `is_digraphical`, `is_multigraphical`, `is_pseudographical`, `is_valid_degree_sequence_havel_hakimi`, `is_valid_degree_sequence_erdos_gallai`, `is_graphical`, `is_bigraphical` | Whether a degree sequence is realisable, with the class of graph it needs | O(V^2) Havel-Hakimi, O(V log V) Erdos-Gallai | BSD-3, GPL-2.0* | `struct` |
| NetworkX, igraph, Boost.Graph | `is_regular`, `is_k_regular`, `k_factor`, `k_regular_game`, `is_regular` | Regularity, and a k-factor of a regular graph | O(V+E), k-factor by matching | BSD-3, GPL-2.0* | `struct` |
| NetworkX | `is_threshold_graph`, `find_threshold_graph` | Threshold graphs, and the creation sequence that proves it | O(V+E) | BSD-3 | `struct` |
| NetworkX | `is_distance_regular`, `is_strongly_regular`, `intersection_array`, `global_parameters` | Distance-regular and strongly regular graphs | O(V^3) | BSD-3 | `struct` |
| NetworkX | `is_d_separator`, `is_minimal_d_separator`, `find_minimal_d_separator`, `moral_graph` | d-separation in a causal graph, and the moral graph it reduces to | O(V+E) to O(V^3) | BSD-3 | `struct` |
| igraph, NetworkX | `trussness`, `is_complete`, `count_reachable`, `neighborhood_graphs` | Per-edge truss number, completeness, reachable-set size, and the subgraph each neighbourhood induces | O(E^1.5), O(V+E) | GPL-2.0*, BSD-3 | `struct` |
| NetworkX, igraph | `is_isolate`, `isolates`, `number_of_isolates`, `is_simple`, `is_multiple`, `has_loop`, `has_multiple` | Trivial-shape predicates | O(V+E) | BSD-3, GPL-2.0* | `struct` |
| NetworkX, igraph | `is_tournament`, `score_sequence`, `tournament_matrix`, `is_reachable` on a tournament | Tournament recognition and its score sequence | O(V^2) | BSD-3, GPL-2.0* | `struct` |
| NetworkX, Boost.Graph, JGraphT | `is_arborescence`, `is_branching`, `is_forest`, `is_tree`, `NotATree` as the refusal, `topological_sort` as a check, `is_kuratowski_subgraph` | Tree, forest, branching and planarity-minor predicates | O(V+E) | BSD-3, BSL-1.0, EPL-2.0* | `struct` |
| NetworkX, JGraphT | `is_perfect_graph`, `is_at_free`, `find_asteroidal_triple`, `BergeGraphInspector`, `WeakChordalityInspector` | Recognition of the perfect and AT-free classes | O(V^5) | BSD-3, EPL-2.0* | `struct` |

## 2.17 Hashing and refinement

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX | `weisfeiler_lehman_graph_hash`, `weisfeiler_lehman_subgraph_hashes` | A hash that is invariant under relabelling, and the per-node hashes a subgraph kernel needs | O(k*(V+E)) for k rounds | BSD-3 | `iso` |
| scikit-network | `weisfeiler_lehman_coloring`, `weisfeiler_lehman_kernel`, `color_weisfeiler_lehman`, `WLColoring`, `WLKernel` | Colour refinement and the kernel built on it | O(k*(V+E)) | BSD-3 | `iso` |
| JGraphT, NetworkX | `ColorRefinementAlgorithm`, `ColorRefinementIsomorphismInspector` | Refinement as a standalone step | O((V+E) log V) | EPL-2.0*, BSD-3 | `iso` |
| NetworkX | `s_metric` | The sum of products of the degrees of the two ends of every edge | O(E) | BSD-3 | `metric` |

## 2.18 Algorithm interfaces and shared plumbing

Every reference exposes its algorithms twice: once as a concrete function and once behind an
interface, so a caller can hold one without naming the scheme. The rows here are that second
surface. They map onto one MoonBit trait per family, so a caller can swap a scheme without
touching the call site.

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| JGraphT | `FlowAlgorithm`, `MaximumFlowAlgorithm`, `MaximumFlowAlgorithmBase`, `MinimumSTCutAlgorithm`, `MinimumCostFlowAlgorithm`, `StoerWagnerMinimumCut` | The interface each flow family implements | O(1) dispatch | EPL-2.0* | `flow` |
| JGraphT | `ShortestPathAlgorithm` and its bases: `BaseShortestPathAlgorithm`, `BaseBidirectionalShortestPathAlgorithm`, `BaseManyToManyShortestPaths`, `BaseMultiObjectiveShortestPathAlgorithm`, `BaseKDisjointShortestPathsAlgorithm`, `ListSingleSourcePathsImpl`, `BFSShortestPath`, `DijkstraClosestFirstIterator`, `ManyToManyShortestPathsAlgorithm`, `KShortestPathAlgorithm` | The shortest-path interface, the path container it returns, and the BFS and closest-first schemes behind it | O(1) dispatch | EPL-2.0* | `path` |
| JGraphT | `MatchingAlgorithm`, `SpanningTreeAlgorithm`, `CapacitatedSpanningTreeAlgorithm`, `SpannerAlgorithm`, `PartitioningAlgorithm`, `ClusteringAlgorithm`, `CliqueAlgorithm`, `MaximalCliqueEnumerationAlgorithm`, `IndependentSetAlgorithm`, `VertexColoringAlgorithm`, `VertexCoverAlgorithm`, `VertexScoringAlgorithm`, `CycleBasisAlgorithm`, `LinkPredictionAlgorithm`, `EdgeScoringAlgorithm`, `MinimumCycleMeanAlgorithm`, `LowestCommonAncestorAlgorithm`, `StrongConnectivityAlgorithm`, `AbstractStrongConnectivityInspector`, `HamiltonianCycleAlgorithmBase`, `HamiltonianCycleImprovementAlgorithm`, `GoldbergMaximumDensitySubgraphAlgorithmBase`, `IsomorphismInspector` | One interface per family, so the caller asks for "a matching" rather than for Blossom V | O(1) dispatch | EPL-2.0* | `matching`, `tree`, `approx`, `community`, `clique`, `color`, `cycle`, `metric`, `dag`, `component`, `flow`, `iso` (one trait per package named) |
| JGraphT | `BlossomVState`, `BlossomVTree`, `BlossomVTreeEdge`, `BlossomVNode`, `BlossomVEdge`, `BlossomVOptions`, `BlossomVInitializer`, `BlossomVPrimalUpdater`, `BlossomVDualUpdater`, `KolmogorovWeightedPerfectMatching` | The Blossom V implementation of weighted perfect matching, and the object graph it builds | O(V^3) | EPL-2.0* | `matching` (the public entry is `max_weight_matching`; the state objects are private here) |
| JGraphT | `DirectedSimpleCycles` | The interface behind the six simple-cycle enumerators | O(1) dispatch | EPL-2.0* | `cycle` |
| JGraphT | `VF2State`, `VF2AbstractIsomorphismInspector`, `VF2GraphIsomorphismState`, `VF2SubgraphIsomorphismState`, `VF2MappingIterator`, `VF2GraphMappingIterator`, `VF2SubgraphMappingIterator`, `IsomorphismUndecidableException` | The VF2 state machine JGraphT exposes, and the refusal it raises when it cannot decide | Exponential worst | EPL-2.0* | `iso` |
| JGraphT | `LinkPredictionIndexNotWellDefinedException`, `NegativeCycleDetectedException`, `IsomorphismUndecidableException` | The three refusals JGraphT defines | O(1) | EPL-2.0* | `root` (each becomes a `RefusalKind`) |
| JGraphT | `ObjectiveSense`, `Extension`, `ExtensionFactory`, `ExtensionManager`, `Pair`, `Triple`, `UnorderedPair`, `UnionFind`, `NeighborCache`, `RatioVertex`, `VertexDegreeComparator`, `AliasMethodSampler`, `FixedSizeIntegerQueue`, `ToleranceDoubleComparator` | Minimise-maximise switch, the extension mechanism, and the small utility types the algorithms share | O(1) to O(V) | EPL-2.0* | `moonstl` (`UnionFind`, the queues), `root` (`Pair`, `Triple`, `ObjectiveSense`), `not done` (`Extension` and the sampler have no caller here) |
| JGraphT | `TransitNodeRoutingShortestPath` | The query side of the road-network preprocessing | Fast queries | EPL-2.0* | `not done`, with the preprocessing it needs |
| JGraphT | `ZhangShashaTreeEditDistance` | Edit distance between two ordered trees | O(V1*V2*min(d1,d2)^2) | EPL-2.0* | `metric` |
| JGraphT | `SørensenIndexLinkPrediction` | Sørensen index over the two neighbourhoods | O(V*d^2) | EPL-2.0* | `metric` |
| petgraph | `edge_index`, `node_index` | Number an endpoint of an edge | O(1) | MIT | `root` |
| petgraph | `has_path_connecting` | Reachability between two nodes in an undirected graph | O(V+E) | MIT | `component` |
| petgraph | `is_bipartite_undirected` | Two-colouring along a DFS | O(V+E) | MIT | `struct` |
| petgraph | `floyd_warshall_path` | Floyd-Warshall followed by one path reconstruction | O(V^3) | MIT | `path` |
| petgraph | `ford_fulkerson` | The textbook augmenting-path flow, kept for its short proof of correctness | O(E * max-flow) | MIT | `flow` |
| petgraph | `with_dynamic_goal` | An A* variant whose goal test is a closure rather than a node | O(E log V) | MIT | `path` |
| petgraph | `dag_to_toposorted_adjacency_list`, `dag_transitive_reduction_closure` | Topological numbering of a DAG, and the reduction it enables | O(V+E) | MIT | `dag` |
| Boost.Graph | `core_numbers`, `maximum_adjacency_search` | Degeneracy by repeatedly removing the smallest degree; the search that certifies chordality | O(V+E) | BSL-1.0 | `struct` (`core_numbers`), `clique` (`maximum_adjacency_search`) |
| Boost.Graph | `maximum_weighted_matching` | Weighted matching in a general graph | O(V^3) | BSL-1.0 | `matching` |
| Boost.Graph | `metric_tsp_approx`, `howard_cycle_ratio` | Tour on a metric closure; minimum cycle ratio | O(V^3) | BSL-1.0 | `approx` (`metric_tsp_approx`), `cycle` (`howard_cycle_ratio`) |
| Boost.Graph | `erdos_renyi_generator`, `plod_generator`, `rmat_generator`, `small_world_generator`, `ssca_generator` | The random generators Boost.Graph ships as header-only classes | O(V+E) | BSL-1.0 | `gen` |

# 3. Measures and statistics

| Library | Name | Purpose | Complexity | Licence | Home |
|:--|:--|:--|:--|:--|:--|
| NetworkX, igraph, scikit-network, EasyGraph | `density`, `mean_degree`, `average_degree`, `get_degrees`, `degree_histogram`, `strength` | Density, mean degree, degree histogram, weighted degree | O(V+E) | BSD-3, GPL-2.0*, BSD-3, BSD-3 | `metric` |
| NetworkX, igraph, JGraphT, Boost.Graph | `eccentricity`, `diameter`, `radius`, `center`, `periphery`, `centroid`, `eccentricity`, `graph_center`, `radius`, `pseudo_diameter`, `GraphMeasurer`, `eccentricity`, `graph_stats` | Eccentricity of every node and the four numbers derived from it | O(V*E) unweighted, O(V*E + V^2 log V) weighted | BSD-3, GPL-2.0*, EPL-2.0*, BSL-1.0 | `metric` |
| NetworkX | `resistance_distance`, `effective_graph_resistance`, `kemeny_constant` | Random-walk resistance between nodes, and the Kemeny constant of the chain | O(V^3) | BSD-3 | `metric` (`moonmath` supplies the pseudoinverse) |
| NetworkX, igraph | `average_shortest_path_length`, `harmonic_diameter`, `wiener_index`, `hyper_wiener_index`, `schultz_index`, `gutman_index`, `average_path_length`, `path_length_hist`, `spatial_edge_lengths` | Mean and total distance summaries | O(V*E) | BSD-3, GPL-2.0* | `metric` |
| NetworkX, igraph, JGraphT, Boost.Graph, scikit-network, EasyGraph | `clustering`, `average_clustering`, `transitivity`, `square_clustering`, `generalized_degree`, `triangles`, `all_triangles`, `transitivity_undirected`, `transitivity_local_undirected`, `transitivity_avglocal_undirected`, `transitivity_barrat`, `count_triangles`, `list_triangles`, `count_adjacent_triangles`, `ClusteringCoefficient`, `clustering_coefficient`, `get_clustering_coefficient`, `average_clustering`, `calculate` | Triangle counts, local and global clustering | O(V*d^2) to O(V*E^1.5) | BSD-3, GPL-2.0*, EPL-2.0*, BSL-1.0, BSD-3, BSD-3 | `metric` |
| NetworkX, igraph | `degree_assortativity_coefficient`, `degree_pearson_correlation_coefficient`, `attribute_assortativity_coefficient`, `numeric_assortativity_coefficient`, `degree_mixing_matrix`, `attribute_mixing_matrix`, `degree_mixing_dict`, `attribute_mixing_dict`, `mixing_dict`, `node_degree_xy`, `node_attribute_xy`, `average_neighbor_degree`, `average_degree_connectivity`, `assortativity`, `assortativity_nominal`, `assortativity_degree`, `joint_degree_matrix`, `joint_degree_distribution`, `joint_type_distribution`, `degree_correlation_vector`, `avg_nearest_neighbor_degree` | Degree and attribute correlation between the two ends of an edge | O(V+E) | BSD-3, GPL-2.0* | `metric` |
| NetworkX, JGraphT, igraph | `resource_allocation_index`, `jaccard_coefficient`, `adamic_adar_index`, `preferential_attachment`, `cn_soundarajan_hopcroft`, `ra_index_soundarajan_hopcroft`, `within_inter_cluster`, `common_neighbor_centrality`, `AdamicAdarIndexLinkPrediction`, `CommonNeighborsLinkPrediction`, `HubDepressedIndexLinkPrediction`, `HubPromotedIndexLinkPrediction`, `JaccardCoefficientLinkPrediction`, `LeichtHolmeNewmanIndexLinkPrediction`, `PreferentialAttachmentLinkPrediction`, `ResourceAllocationIndexLinkPrediction`, `SaltonIndexLinkPrediction`, `SorensenIndexLinkPrediction`, `similarity_jaccard`, `similarity_dice`, `similarity_inverse_log_weighted` | Score a missing or a present edge from the neighbourhoods of its ends | O(V*d^2) over all pairs | BSD-3, EPL-2.0*, GPL-2.0* | `metric` |
| NetworkX | `simrank_similarity`, `panther_similarity`, `panther_vector_similarity`, `generate_random_paths`, `graph_edit_distance`, `optimal_edit_paths`, `optimize_graph_edit_distance`, `optimize_edit_paths` | Node similarity by random walks, and edit distance between whole graphs | O(k*V^2) similarity, exponential edit distance | BSD-3 | `metric` |
| NetworkX, JGraphT | `efficiency`, `local_efficiency`, `global_efficiency`, `average_local_efficiency`, `global_efficiency`, `local_efficiency`, `diversity` | How well the graph moves information | O(V*E) | BSD-3, GPL-2.0* | `metric` |
| igraph | `bond_percolation`, `site_percolation`, `edgelist_percolation` | Component growth as edges, nodes or a list of edges are added | O(E*alpha(V)) | GPL-2.0* | `metric` |
| NetworkX, igraph | `rich_club_coefficient`, `rich_club_sequence`, `s_metric`, `non_randomness`, `sigma`, `omega`, `random_reference`, `lattice_reference`, `smallworld_sigma`, `smallworld_omega` | Rich club, small-world and randomness measures | O(V*E) per rewiring round | BSD-3, GPL-2.0* | `metric` |
| NetworkX | `triadic_census`, `triads_by_type`, `triad_type`, `is_triad`, `all_triads`, `dyad_census`, `triangles` per type | The 16 triad types and their census | O(V*d^2) | BSD-3, GPL-2.0* | `metric` |
| NetworkX, igraph | `reciprocity`, `overall_reciprocity`, `is_mutual`, `has_mutual`, `mutual_weight` | How many edges are answered in the other direction | O(V+E) | BSD-3, GPL-2.0* | `metric` |
| NetworkX, igraph | `constraint`, `effective_size`, `local_constraint`, `efficiency`, `hierarchy` | Structural holes in a node's ego network | O(V*E) | BSD-3, GPL-2.0* | `metric` |
| NetworkX | `flow_hierarchy`, `closeness_vitality`, `number_of_walks`, `random_walk`, `communicability`, `communicability_exp`, `bipartite.spectral_bipartivity`, `bipartite.butterflies`, `bipartite.latapy_clustering`, `bipartite.robins_alexander_clustering`, `bipartite.node_redundancy`, `bipartite.degrees`, `bipartite.density` | Assorted global measures: hierarchy, vitality, walk counts, communicability and the bipartite-specific ones | O(V^3) for the matrix forms, O(V*E) otherwise | BSD-3 | `metric` |
| NetworkX, igraph | `cut_size`, `volume`, `normalized_cut_size`, `conductance`, `edge_expansion`, `node_expansion`, `mixing_expansion`, `boundary_expansion` | Quality of a cut, as a number in [0,1] | O(V+E) | BSD-3, GPL-2.0* | `metric` |
| igraph | `cocitation`, `bibcoupling`, `similarity_dice_es`, `similarity_dice_pairs`, `similarity_jaccard_es`, `similarity_jaccard_pairs`, `graphlets`, `graphlets_candidate_basis`, `graphlets_project`, `motifs_randesu`, `motifs_randesu_estimate`, `motifs_randesu_no`, `triad_census`, `local_scan_0`, `local_scan_0_them`, `local_scan_1_ecount`, `local_scan_1_ecount_them`, `local_scan_k_ecount`, `local_scan_k_ecount_them`, `local_scan_neighborhood_ecount`, `local_scan_subset_ecount` | Co-citation and bibliographic coupling, the graphlet and motif counts, the triad census, and the local-scan neighbourhood statistics | O(V*d^2) for the triangle-based ones, exponential in the motif size | GPL-2.0* | `metric` (motifs and graphlets: `approx` for the sampled forms) |
| NetworkX | `tutte_polynomial`, `chromatic_polynomial` | Two graph polynomials | Exponential | BSD-3 | `metric` |
| NetworkX, igraph | `graph_edit_distance` with node and edge costs, `compare_communities`, `split_join_distance`, `convergence_degree` | Distance between two graphs or two partitions | Exponential | BSD-3, GPL-2.0* | `metric` |
| scikit-network | `get_distances`, `get_clustering_coefficient`, `get_cycles`, `is_acyclic`, `get_dag`, `eigenvector_err`, `svd_err`, `diffusion`, `get_tfidf`, `get_norms`, `get_probs`, `normalize`, `get_laplacian` | The measures the scikit-network API exposes over a sparse adjacency | O(V*E) | BSD-3 | `metric` (the Laplacian and the normalisation: `moonmath`) |
| EasyGraph, NetworkX | `hypergraph_density`, `hypergraph_clustering_coefficient`, `hypergraph_local_clustering_coefficient`, `hypergraph_two_node_clustering_coefficient`, `degree_assortativity` on a hypergraph, `dynamical_assortativity` | Measures that only a hypergraph has | O(V+E) | BSD-3, BSD-3 | `not done`: no hypergraph type; see the reason in the last section |

# 4. Not done, and why

These are the capabilities of the reference libraries that this library does not plan to carry.
Everything here is deliberate: each has a reason, and a caller who needs one can build it on the
public interface without changing this library.

| Capability | Where it appears | Reason |
|:--|:--|:--|
| Hypergraphs: `Hypergraph` and its algorithms | EasyGraph (`hypergraph`), NetworkX has none, igraph has none | The four graph types are pairwise: a hypergraph is not a graph with a flag, and its algorithms (hypergraph clustering, dynamical assortativity, incidence-matrix methods) are a different research surface. Listing it here keeps it out of the interface without closing the door: a `Hypergraph` type can be added beside the four without touching them, because no algorithm takes a concrete graph type. |
| Layout and drawing: `layout_random`, `layout_circle`, `layout_fruchterman_reingold`, `layout_kamada_kawai`, `layout_lgl`, `layout_reingold_tilford`, `layout_sugiyama`, `layout_mds`, `layout_umap`, `layout_drl`, `layout_graphopt`, `layout_gem`, `layout_davidson_harel`, `layout_sphere`, `layout_grid`, `layout_bipartite`, `FRLayoutAlgorithm2D`, `CircularLayoutAlgorithm2D`, `RandomLayoutAlgorithm2D`, `TwoLayeredBipartiteLayout2D`, `fruchterman_reingold`, `kamada_kawai_spring_layout`, `gursoy_atun_layout`, `random_layout`, `circle_layout`, `cuthill_mckee_ordering`, `king_ordering`, `minimum_degree_ordering`, `sloan_ordering`, `smallest_last_ordering`, `wavefront`, `RescaleLayoutAlgorithm2D`, `BaseLayoutAlgorithm2D`, `BarycenterGreedyTwoLayeredBipartiteLayout2D`, `MedianGreedyTwoLayeredBipartiteLayout2D`, `IndexedFRLayoutAlgorithm2D`, `FRQuadTree`, `LayoutModel2D`, `ListenableLayoutModel2D`, `MapLayoutModel2D`, `Point2D`, `Points`, `Box2D`, `Boxes`, `layout_star`, `layout_grid_3d`, `layout_reingold_tilford_circular`, `roots_for_tree_layout`, `layout_random_3d`, `layout_fruchterman_reingold_3d`, `layout_kamada_kawai_3d`, `layout_drl_3d`, `layout_merge_dla`, `layout_umap_3d`, `layout_umap_compute_weights`, `layout_align` | igraph, NetworkX (`drawing`), JGraphT (`drawing`), Boost.Graph (`layout_overview`) | A layout produces coordinates, not a graph: the output is a picture, and the consumer owns the canvas, the viewport and the pan and zoom. The bandwidth-reducing orderings (`cuthill_mckee_ordering` and the rest) are the exception that matters — they are useful without a picture — but they exist to make a sparse matrix banded, which belongs to the linear algebra side (moonmath) rather than here. |
| Graph embedding: `spectral`, `spring`, `force_atlas`, `svd`, `PCA`, `RandomProjection`, `GSVD`, `SparseLR`, `LouvainEmbedding`, `deepwalk`, `node2vec`, `graph_to_d_atleast2`, `Spectral`, `adjacency_spectral_embedding`, `laplacian_spectral_embedding`, `eigen_adjacency` | scikit-network (`embedding`), EasyGraph (`graph_embedding`) | An embedding is a machine-learning product with its own training loop, its own evaluation and its own hyperparameters. The graph part of it is one sparse multiplication, which `moonmath` can already do. |
| Graph neural networks: `gnn_classifier`, `layer`, `neighbor_sampler`, `optimizer`, `loss`, `activation` | scikit-network (`gnn`) | Same reason: a model zoo, not a graph algorithm. |
| Node classification and regression: `harmonic_function`, `local_and_global_consistency`, `Propagation`, `Diffusion`, `kNN`, `base_rank` | NetworkX (`node_classification`), scikit-network (`classification`, `regression`) | Semi-supervised learning over a graph; the graph is the input, the answer is a label. Out of a graph library's remit. |
| Visualisation: `draw_*`, `plot_*`, `DrawGraph`, colour maps for communities | NetworkX, EasyGraph, scikit-network (`visualization`) | Not a graph algorithm. |
| Data loaders and data-set registries: `Dataset`, `load`, `parse`, `models`, `timeout`, `TestGraphs` | scikit-network (`data`), EasyGraph (`datasets`, `datapipe`) | Ships data, not code. The four classic graphs in `gen` are embedded because every reference embeds them. |
| Parallel variants: `parallel_johnson`, `parallel_page_rank`, `betweenness_centrality_parallel`, `closeness_centrality_parallel`, `effective_size_parallel`, `initialize_parallel`, `laplacian_parallel`, `_local_directed_triangles_and_degree_iter_parallel` | petgraph, NetworkX (via joblib), EasyGraph, scikit-network | MoonBit has no shared-memory threads. The algorithms are written so a caller can split the source loop itself, and the async runtime in `moonbitlang/async` covers the I/O side. |
| External-memory and out-of-core graphs | Boost.Graph `external`, STXXL in the task sheet's references | Not in the task sheet's scope; a different storage layer, and nothing here needs it yet. |
| Time-dependent graphs: `cd_index` | NetworkX (`time_dependent`), scikit-network (`ppr_solver` with time) | A distinct model (edge availability as a function of time) rather than an algorithm on a static graph. The interface has no room for it, and no other reference puts it in the core. |
| Hierarchical random graphs: `hrg_fit`, `hrg_sample`, `hrg_sample_many`, `hrg_game`, `hrg_consensus`, `hrg_predict`, `hrg_create`, `hrg_resize`, `hrg_size`, `from_hrg_dendrogram` | igraph | A statistical model with a fitting procedure, not a graph algorithm. |
| Statistical-physics communities: `community_spinglass`, `community_spinglass_single`, `community_infomap` | igraph | Both need machinery (simulated annealing over a Potts model, a map equation) that would be a library of its own, and neither is in NetworkX or JGraphT, so there is no second implementation to test against. |
| Road-network preprocessing: `ContractionHierarchyPrecomputation`, `TransitNodeRoutingPrecomputation`, `CHManyToManyShortestPaths` | JGraphT | A specialised speed-up for continental road networks; the plain methods cover the semantics. |
| Routing with capacities: `AbstractCapacitatedMinimumSpanningTree`, `AhujaOrlinSharmaCapacitatedMinimumSpanningTree`, `EsauWilliamsCapacitatedMinimumSpanningTree` | JGraphT, NetworkX `lukes_partitioning` is the nearest relative | A vehicle-routing problem. |
| Geometry on graphs: `delaunay_graph`, `gabriel_graph`, `relative_neighborhood_graph`, `lune_beta_skeleton`, `circle_beta_skeleton`, `beta_weighted_gabriel_graph`, `nearest_neighbor_graph`, `convex_hull_2d`, `voronoi` as geometry | igraph | Geometry, not graph theory. Belongs to `moonmath`, which owns the points, the hulls and the triangulations; this library consumes the resulting graph. |
| Linear algebra: `get_laplacian`, `eigen_matrix`, `eigen_matrix_symmetric`, `solve_lsap` (matrix form), `svd_solver`, `eig_solver`, `polynome`, `ppr_solver`, `Laplacian`, `Normalizer`, `Regularizer`, `SVD`, `EigSolver`, `LanczosSVD`, `LanczosEig` | scikit-network (`linalg`), igraph (`eigen_matrix`) | `moonmath` owns matrices, decompositions and solves. The centrality functions that need one call into it; nothing here re-implements it. |
| Graph statistics as a report: `graph_stats`, `profile`, `bandwidth` | Boost.Graph | A command-line report over a graph file, not a library function. The measures it prints are in `metric`. |
| Named-graph registry beyond the atlas: `famous`, `graph_atlas_g` for the atlas of atlases | igraph, NetworkX | The 1253-graph atlas is small enough to embed; the named-graph registry is a data file that grows without bound, and `gen` covers the families a caller can name. |
| `spectral_graph_forge` | NetworkX | Exists to seed a demonstration with a graph of a chosen spectrum; needs a full eigensolver, and `moonmath` is the place for that. |

| Fitted distributions and epidemic models: `power_law_fit`, `sir`, `running_mean`, `random_sample`, `dim_select`, `almost_equals`, `cmp_epsilon` | igraph | A curve fit, a compartmental model and a few float comparisons. The comparisons belong to a test helper; the fit and the model are statistics, not graph structure. |
| C-level status plumbing: `progress`, `status`, `strerror`, `invalidate_cache` | igraph | A C runtime's progress handler, error strings and cache invalidation have no counterpart in MoonBit: errors are `Refused` values, and there is no cache to invalidate because `Csr` is immutable. |
| Classifier and regressor families: `BaseClassifier`, `BaseRegressor`, `RankClassifier`, `DiffusionClassifier`, `PageRankClassifier`, `NNClassifier`, `GNNClassifier`, `BaseRanking`, `BaseClustering`, `BaseHierarchy`, `BaseEmbedding`, `BaseLinker`, `BaseGNN`, `BaseLayer`, `BaseActivation`, `BaseLoss`, `BaseOptimizer`, `ADAM`, `GD`, `ReLu`, `Sigmoid`, `Softmax`, `CrossEntropy`, `BinaryCrossEntropy`, `Diffusion`, `Propagation`, `kNN`, `base_rank`, `Convolution`, `UniformNeighborSampler`, `get_activation`, `get_layer`, `get_layers`, `get_loss`, `get_optimizer` | scikit-network (`classification`, `regression`, `gnn`) | Training loops and model classes; see the embedding row above. The graph algorithms they call are in this library, the models are not. |
| Evaluation metrics: `get_accuracy_score`, `get_f1_score`, `get_f1_scores`, `get_average_f1_score`, `get_confusion_matrix`, `get_modularity`, `dasgupta_cost`, `dasgupta_score`, `tree_sampling_divergence`, `cut_balanced`, `cut_straight`, `aggregate_dendrogram`, `reorder_dendrogram`, `split_dendrogram`, `get_dendrogram` | scikit-network (`classification.metrics`, `hierarchy.metrics`, `clustering.metrics`) | Scores a label prediction or a hierarchy; the partition itself is in `community`, the score against a ground truth is an evaluation harness concern. |
| Visualisation helpers: `svg_graph`, `svg_node`, `svg_edge`, `svg_edge_directed`, `svg_text`, `svg_pie_chart_node`, `svg_bigraph`, `svg_dendrogram`, `svg_dendrogram_left`, `svg_dendrogram_top`, `visualize_graph`, `visualize_bigraph`, `visualize_dendrogram`, `get_node_colors`, `get_edge_colors`, `get_node_sizes`, `get_node_widths`, `get_edge_widths`, `get_label_colors`, `get_n_colors`, `painters`, `draw_*`, `plot_*`, `default_style`, `default_size`, `default_strength`, `default_bipartite_style`, `fill_color`, `fill_sizes`, `fill_strength`, `force_layout`, `hull_layout`, `circular_position`, `polar_position`, `shell_position`, `random_position`, `rescale_position`, `node_pos`, `init_pos`, `apply_alpha`, `kamada_kawai_layout`, `community_pos`, `common_tangent_radian`, `edge_list_to_incidence_matrix`, `edge_partition` | scikit-network (`visualization`), EasyGraph (`drawing`) | Rendering and layout, same reason as the layout row. |
| Structural-hole and hierarchy research code: `get_structural_holes_HAM`, `get_structural_holes_HIS`, `get_structural_holes_MaxD`, `structural_hole_influence_index`, `weakTie`, `weakTieLocal`, `inverse_closeness_centrality`, `bounded_inverse_closeness_centrality`, `approximate_inverse_closeness_centrality`, `compute_constraint_of_nodes`, `nodes_of_max_cc_without_shs`, `max_degree_hierarchy_dag`, `degree_hierarchy_random_tree`, `common_greedy`, `pick_candidates`, `majority_voting`, `label_by_neighbors`, `build_network`, `Simulator`, `RDS`, `NOBE`, `NOBE_GA`, `NOBE_GA_SH`, `NOBE_SH`, `UpdateScore`, `ShowRecord`, `MAXD` initialisation | EasyGraph (`structural_holes`) | A research pipeline (influence maximisation over structural holes) built on top of the measures. `metric` carries `constraint`, `effective_size` and `local_constraint`; the pipeline that consumes them is a application, not a primitive. |
| Graph embedding trainers: `LINE`, `SDNE`, `Node2vec`, `DeepWalk` style trainers (`learn_embeddings`, `simulate_walks`, `eigs_nodes`, `eigenvector_centrality` for the spectral seed) | EasyGraph (`graph_embedding`) | See the embedding row. |
| Random network writers and argument parsers: `writeRandomNetworkToFile`, `graph_Gnm`, `erdos_renyi_P`, `erdos_renyi_M`, `fast_erdos_renyi_P`, `WS_Random`, `parse_args` | EasyGraph (`graph_generator`) | Command-line entry points around the generators in `gen`. |

# Counts

- **1601 distinct reference names** across the five references that are covered name by name:
  NetworkX 805, igraph 482, JGraphT 258, Boost.Graph 86, petgraph 55. Three petgraph names are
  excluded on purpose: `invalid_node_err`, `invalid_hole_err` and `invalid_length_err` build panics
  and have no counterpart in an interface that refuses with values.
- **311 rows** after merging by capability, so about five reference names share each row.
- One row can name more than one home when a capability splits across two packages (a path
  reconstruction helper beside the measure that needs it, for instance). That is why the per-package
  column below adds up to more than 311.

Rows that name each library:

| Library | Rows | Library | Rows |
|:--|--:|:--|--:|
| NetworkX | 237 | petgraph | 69 |
| igraph | 165 | EasyGraph | 20 |
| JGraphT | 135 | scikit-network | 19 |
| Boost.Graph | 87 | LEMON | 8 |
| | | CPython (`graphlib`) | 1 |

Rows that name each package:

| Home | Rows | Home | Rows |
|:--|--:|:--|--:|
| `root` | 36 | `cycle` | 12 |
| `metric`† | 32 | `component` | 11 |
| `gen` | 25 | `clique` | 11 |
| `path` | 23 | `matching` | 10 |
| `iso` | 21 | `moonmath` | 7 |
| `struct`† | 20 | `color` | 6 |
| `flow` | 17 | `traverse` | 5 |
| `centrality` | 15 | `moonstl` | 1 |
| `tree` | 15 | `not done` | 14 |
| `approx`† | 15 | `op`† | 14 |
| `community` | 14 | `io` | 14 |
| `dag` | 13 | | |

† a package this inventory proposes; see the first section of `interface.md`.
