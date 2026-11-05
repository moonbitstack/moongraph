///|
/// The result of a single-source search: one distance and one predecessor per
/// node.
///
/// Both arrays are indexed by node number, so no lookup happens and no entry
/// can be missing. `None` in `distance` means the node cannot be reached from
/// the sources — not infinity, not a large number — so a caller that forgets to
/// handle it gets a type error rather than a poisoned sum.
pub(all) struct Paths {
  /// The cost of the cheapest route from a source to each node.
  distance : Array[Double?]
  /// The node this one was reached from. `None` at a source and at every node
  /// that was not reached.
  previous : Array[Int?]
}

///|
/// The node numbers from a source to `node`, source first, or `None` when the
/// node was not reached.
pub fn Paths::path_to(self : Paths, node : Int) -> Array[Int]? {
  if node < 0 || node >= self.distance.length() {
    return None
  }
  if self.distance[node] is None {
    return None
  }
  let path : Array[Int] = []
  let mut at = node
  while true {
    path.push(at)
    match self.previous[at] {
      Some(back) => at = back
      None => break
    }
  }
  path.rev_in_place()
  Some(path)
}

///|
/// Whether the node was reached at all.
pub fn Paths::reached(self : Paths, node : Int) -> Bool {
  node >= 0 && node < self.distance.length() && self.distance[node] is Some(_)
}

///|
/// The result of an all-pairs search: a matrix of costs and a matrix of
/// successors.
///
/// `next[from][to]` is the node after `from` on a cheapest route, which is what
/// keeps path reconstruction to one lookup per step. Everything is indexed by
/// node number.
pub(all) struct AllPairs {
  /// The cost between every ordered pair.
  distance : Array[Array[Double?]]
  /// The successor of each node on the cheapest route to each other node.
  next : Array[Array[Int?]]
}

///|
/// The cheapest route from `from` to `to`, both included, or `None` when there
/// is none.
pub fn AllPairs::path(self : AllPairs, from : Int, to : Int) -> Array[Int]? {
  let n = self.distance.length()
  if from < 0 || from >= n || to < 0 || to >= n {
    return None
  }
  if self.distance[from][to] is None {
    return None
  }
  let path : Array[Int] = [from]
  let mut at = from
  while at != to {
    match self.next[at][to] {
      Some(step) => {
        path.push(step)
        at = step
      }
      None => return None
    }
  }
  Some(path)
}

///|
/// Whether `to` is reachable from `from`.
pub fn AllPairs::reached(self : AllPairs, from : Int, to : Int) -> Bool {
  let n = self.distance.length()
  from >= 0 && from < n && to >= 0 && to < n && self.distance[from][to] is Some(_)
}

///|
/// A feasible flow: its value and the flow on every edge.
pub(all) struct Flow {
  /// The net flow leaving the source, which is what a maximum-flow search
  /// maximises and a feasible circulation reports as zero.
  value : Double
  /// Flow on each edge, indexed by edge number. An edge that exists but carries
  /// nothing holds 0.
  flow : Array[Double]
}

///|
/// A cut: the value it separates, and which side each node falls on.
pub(all) struct Cut {
  /// The capacity crossing the cut.
  value : Double
  /// For each node, whether it is on the source side.
  source_side : Array[Bool]
}

///|
/// A matching: pairs of nodes and the weight those pairs add up to.
pub(all) struct Matching {
  /// Each pair once, with the smaller node number first, in increasing order of
  /// their first member.
  pairs : Array[(Int, Int)]
  /// The number of pairs when no weight was given, the sum of the weights
  /// otherwise.
  weight : Double
}

///|
/// An edge cover: the edges that touch every node.
pub(all) struct Cover {
  /// Edge numbers, ascending.
  edges : Array[Int]
}

///|
/// A spanning tree: its edges and its weight.
pub(all) struct Spanning {
  /// `V - 1` edge numbers, in the order the algorithm chose them.
  edges : Array[Int]
  /// The sum of the weights of those edges.
  weight : Double
}

///|
/// A labelling of nodes by component.
pub(all) struct Components {
  /// The component of each node.
  label : Array[Int]
  /// How many components there are.
  count : Int
}

///|
/// A score per node.
pub(all) struct Scores {
  /// The score of each node, indexed by node number.
  score : Array[Double]
}

///|
/// A colouring: a colour per node and how many colours were used.
pub(all) struct Coloring {
  /// The colour of each node, numbered from 0.
  color : Array[Int]
  /// The number of distinct colours, which is `max(color) + 1` for a graph with
  /// at least one node.
  count : Int
}

///|
/// A partition of the nodes into groups.
pub(all) struct Partition {
  /// The group of each node, numbered from 0.
  label : Array[Int]
  /// How many groups there are.
  count : Int
}

///|
/// A set of cliques.
pub(all) struct Cliques {
  /// Each clique sorted ascending, and the cliques ordered by their first
  /// member.
  members : Array[Array[Int]]
}

///|
/// A node-to-node map between two graphs.
pub(all) struct Mapping {
  /// `to[i]` is the node of the second graph that node `i` of the first one maps
  /// to.
  to : Array[Int]
}

///|
/// The condensation of a directed graph: one node per strong component.
pub(all) struct Condensation {
  /// One node per component, carrying the component's label.
  graph : Graph[Int, Unit]
  /// The component of each node of the original graph.
  of_node : Array[Int]
  /// The nodes of each component, ascending.
  members : Array[Array[Int]]
}
