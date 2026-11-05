///|
/// A graph addressed by keys instead of numbers: keys go in, keys come out, and
/// the numbers stay inside.
///
/// The algorithms take dense node numbers because that is what makes them fast;
/// a caller whose data is keyed by names should not have to translate in both
/// directions around every call. The wrapper holds the translation and hands the
/// inner `Graph` to anything that needs it.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new()
///   let k = @moongraph.Keyed::new(graph=g)
///   let a = k.add_node("a", ())
///   let b = k.add_node("b", ())
///   k.add_edge("a", "b", 1.0) |> ignore
///   assert_eq(k.node("b"), Some(b))
///   assert_eq(k.key(a), Some("a"))
///   assert_eq(k.graph().edge_count(), 1)
/// }
/// ```
pub struct Keyed[K, N, E] {
  graph : Graph[N, E]
  index : Map[K, Int]
  back : Array[K?]
}

///|
/// Wraps a graph. The wrapper takes ownership of the numbering from here on: add
/// nodes and edges through it so the two views cannot drift.
pub fn[K : Hash + Eq, N, E] Keyed::new(graph~ : Graph[N, E]) -> Keyed[K, N, E] {
  let back : Array[K?] = []
  for _ in 0..<graph.node_count() {
    back.push(None)
  }
  Keyed::{ graph, index: Map([]), back }
}

///|
/// Adds a node under a key and returns its number. A key that is already present
/// is refused rather than silently overwriting the node.
pub fn[K : Hash + Eq, N, E] Keyed::add_node(
  self : Keyed[K, N, E],
  key : K,
  data : N,
) -> Int raise Refused {
  if self.index.contains(key) {
    raise Refused::NotA(kind="key", what="the key is already a node")
  }
  let node = self.graph.add_node(data)
  self.index[key] = node
  while self.back.length() <= node {
    self.back.push(None)
  }
  self.back[node] = Some(key)
  node
}

///|
/// Adds an edge between two keys and returns its number. Either key missing is
/// refused, because an edge to a node that is not there has no number to use.
pub fn[K : Hash + Eq, N, E] Keyed::add_edge(
  self : Keyed[K, N, E],
  from : K,
  to : K,
  data : E,
) -> Int raise Refused {
  let a = match self.index.get(from) {
    Some(node) => node
    None => raise Refused::NotA(kind="key", what="no node has the source key")
  }
  let b = match self.index.get(to) {
    Some(node) => node
    None => raise Refused::NotA(kind="key", what="no node has the target key")
  }
  self.graph.add_edge(a, b, data)
}

///|
/// The number behind a key.
pub fn[K : Hash + Eq, N, E] Keyed::node(
  self : Keyed[K, N, E],
  key : K,
) -> Int? {
  self.index.get(key)
}

///|
/// The key behind a number.
pub fn[K, N, E] Keyed::key(
  self : Keyed[K, N, E],
  node : Int,
) -> K? {
  if node < 0 || node >= self.back.length() {
    return None
  }
  self.back[node]
}

///|
/// The wrapped graph, for an algorithm that works in numbers.
pub fn[K, N, E] Keyed::graph(
  self : Keyed[K, N, E],
) -> Graph[N, E] {
  self.graph
}

///|
/// The route to a key, as keys. `None` when the node was not reached.
pub fn[K : Hash + Eq, N, E] Keyed::path(
  self : Keyed[K, N, E],
  paths : Paths,
  key : K,
) -> Array[K]? {
  let node = match self.index.get(key) {
    Some(node) => node
    None => return None
  }
  let route = match paths.path_to(node) {
    Some(route) => route
    None => return None
  }
  let out : Array[K] = []
  for step in route {
    if self.back[step] is Some(k) {
      out.push(k)
    }
  }
  Some(out)
}

///|
/// A score per key, for a caller that thinks in keys.
pub fn[K : Hash + Eq, N, E] Keyed::scores(
  self : Keyed[K, N, E],
  scores : Scores,
) -> Map[K, Double] {
  let out : Map[K, Double] = Map([])
  for node, score in scores.score {
    if self.back[node] is Some(key) {
      out[key] = score
    }
  }
  out
}
