// The demo page's engine.
//
// Everything the page draws comes from here: the graph, its layout, and the numbers the chosen
// algorithm produced. The page itself only places what this returns, so a mistake in the demo is
// a mistake in the library and shows up as one.

///|
/// One graph the page offers, with its layout already worked out.
///
/// The layout is part of the answer rather than the page's business: a ring graph is drawn as a
/// ring because a ring is what it is, and a grid keeps its rows.
fn build(
  name : String,
) -> (@moongraph.Graph[Int32, Double], Array[(Double, Double)]) {
  let rng = @moonrand.seeded(b"moongraph-demo")
  match name {
    "grid" => {
      let graph = @gen.grid(4, 5)
      let positions : Array[(Double, Double)] = []
      for row in 0..<4 {
        for column in 0..<5 {
          positions.push(
            (column.to_double() * 90.0 + 120.0, row.to_double() * 90.0 + 90.0),
          )
        }
      }
      (weighted(graph, rng), positions)
    }
    "tree" => {
      let graph = @gen.random_tree(13, rng~)
      (weighted(graph, rng), circle(13, 300.0, 300.0, 210.0))
    }
    "petersen" => {
      let graph = @gen.petersen()
      (weighted(graph, rng), petersen_positions())
    }
    "circles" => {
      let graph : @moongraph.Graph[Int32, Double] = @moongraph.Graph::new(
        directed=false,
      )
      for node in 0..<14 {
        graph.add_node(node) |> ignore
      }
      // Two rings joined by a single bridge, which is the shape that shows what a component
      // walk and a betweenness score are for.
      for node in 0..<6 {
        graph.add_edge(node, (node + 1) % 6, 1.0) |> ignore
      }
      for node in 7..<13 {
        graph.add_edge(node, 7 + (node - 6) % 6, 1.0) |> ignore
      }
      graph.add_edge(0, 7, 1.0) |> ignore
      (graph, circle(14, 300.0, 300.0, 210.0))
    }
    _ => {
      let graph = @gen.cycle(10)
      (weighted(graph, rng), circle(10, 300.0, 300.0, 210.0))
    }
  }
}

///|
/// Gives every edge a small whole-number weight, so the page can show a cost without printing a
/// long fraction.
fn weighted(
  graph : @moongraph.Graph[Int32, Unit],
  rng : &@contract.Rng,
) -> @moongraph.Graph[Int32, Double] {
  let out : @moongraph.Graph[Int32, Double] = @moongraph.Graph::new(
    directed=false,
  )
  for node in 0..<graph.node_count() {
    out.add_node(node) |> ignore
  }
  for edge in 0..<graph.edge_count() {
    let (a, b) = graph.endpoints(edge)
    let cost = 1.0 + @moonrand.randint(rng, 0, 5).to_double()
    out.add_edge(a, b, cost) |> ignore
  }
  out
}

///|
fn circle(
  count : Int32,
  cx : Double,
  cy : Double,
  radius : Double,
) -> Array[(Double, Double)] {
  let out : Array[(Double, Double)] = []
  for node in 0..<count {
    let angle = 6.283185307179586 * node.to_double() / count.to_double()
    out.push((cx + radius * cosine(angle), cy + radius * sine(angle)))
  }
  out
}

///|
fn petersen_positions() -> Array[(Double, Double)] {
  let outer = circle(5, 300.0, 300.0, 210.0)
  let inner = circle(5, 300.0, 300.0, 100.0)
  let out : Array[(Double, Double)] = []
  for i in 0..<5 {
    out.push(outer[i])
  }
  for i in 0..<5 {
    out.push(inner[i])
  }
  out
}

///|
/// Sine, by the series around zero after the argument is folded into a quarter turn.
fn sine(x : Double) -> Double {
  let mut angle = x
  while angle > 3.141592653589793 {
    angle = angle - 6.283185307179586
  }
  while angle < -3.141592653589793 {
    angle = angle + 6.283185307179586
  }
  let squared = angle * angle
  let mut term = angle
  let mut total = angle
  for n in 1..<12 {
    term = term * -squared / ((2 * n).to_double() * (2 * n + 1).to_double())
    total = total + term
  }
  total
}

///|
fn cosine(x : Double) -> Double {
  sine(x + 1.5707963267948966)
}

///|
/// The engine is loaded for its exported functions; it has nothing to run on its own.
fn main {

}

///|
/// The names the page offers, as a JSON array.
pub fn graphs() -> String {
  "[\"grid\",\"tree\",\"petersen\",\"circles\"]"
}

///|
/// Runs one algorithm on one graph and answers everything the page needs to draw it: the nodes
/// with their place and their number, the edges with the ones the algorithm chose, and a line of
/// text that says what was computed.
pub fn run(graph_name : String, algorithm : String, source : Int32) -> String {
  let (graph, positions) = build(graph_name)
  let n = graph.node_count()
  let values : Array[String] = Array::make(n, "\"\"")
  let chosen : Array[Bool] = Array::make(graph.edge_count(), false)
  let mut note = ""
  match algorithm {
    "bfs" => {
      let start = clamp(source, n)
      let paths = @traverse.bfs_tree(graph, start)
      for node in 0..<n {
        values[node] = match paths.distance[node] {
          Some(d) => "\"" + d.to_int().to_string() + "\""
          None => "\"—\""
        }
      }
      note = "Hops from node " + start.to_string() + ", breadth first."
    }
    "dijkstra" => {
      let start = clamp(source, n)
      let paths = @path.dijkstra(
        graph,
        start,
        weight=graph.weights(fn(cost) { cost }),
      ) catch {
        _ =>
          @moongraph.Paths::{
            distance: Array::make(n, (None : Double?)),
            previous: Array::make(n, (None : Int32?)),
          }
      }
      for node in 0..<n {
        values[node] = match paths.distance[node] {
          Some(d) => "\"" + d.to_string() + "\""
          None => "\"—\""
        }
      }
      // The tree of cheapest routes: an edge is drawn when it is the parent edge of a node.
      for node in 0..<n {
        match paths.previous[node] {
          Some(parent) =>
            match graph.find_edge(parent, node) {
              Some(edge) => chosen[edge] = true
              None => ()
            }
          None => ()
        }
      }
      note = "Cost of the cheapest route from node " + start.to_string() + "."
    }
    "mst" => {
      let tree = @tree.minimum_spanning(
        graph,
        weight=graph.weights(fn(cost) { cost }),
      ) catch {
        _ => @moongraph.Spanning::{ edges: [], weight: 0.0, }
      }
      for edge in tree.edges {
        if edge >= 0 && edge < chosen.length() {
          chosen[edge] = true
        }
      }
      for node in 0..<n {
        values[node] = "\"\""
      }
      note = "The cheapest set of edges that joins every node: " +
        tree.weight.to_string() +
        " in total."
    }
    "coloring" => {
      let colouring = @color.greedy_coloring(graph, order=SmallestLast)
      for node in 0..<n {
        values[node] = "\"" + colouring.color[node].to_string() + "\""
      }
      note = "Colors used: " +
        colouring.count.to_string() +
        ". Neighbours never share one."
    }
    "components" => {
      let parts = @component.components(graph)
      for node in 0..<n {
        values[node] = "\"c" + parts.label[node].to_string() + "\""
      }
      note = "Pieces: " + parts.count.to_string() + "."
    }
    "pagerank" => {
      let scores = @centrality.pagerank(graph)
      for node in 0..<n {
        values[node] = "\"" +
          (scores.score[node] * 1000.0).to_int().to_string() +
          "\""
      }
      note = "Share of a walk's time, in parts per thousand."
    }
    _ => {
      for node in 0..<n {
        values[node] = "\"\""
      }
      note = "Nothing chosen."
    }
  }
  let mut out = "{\"nodes\":["
  for node in 0..<n {
    if node > 0 {
      out = out + ","
    }
    let (x, y) = positions[node]
    out = out +
      "{\"i\":" +
      node.to_string() +
      ",\"x\":" +
      x.to_string() +
      ",\"y\":" +
      y.to_string() +
      ",\"v\":" +
      values[node] +
      "}"
  }
  out = out + "],\"edges\":["
  for edge in 0..<graph.edge_count() {
    if edge > 0 {
      out = out + ","
    }
    let (a, b) = graph.endpoints(edge)
    out = out +
      "{\"a\":" +
      a.to_string() +
      ",\"b\":" +
      b.to_string() +
      ",\"w\":" +
      graph.edge_data(edge).to_string() +
      ",\"on\":" +
      (if chosen[edge] { "true" } else { "false" }) +
      "}"
  }
  out + "],\"note\":" + "\"" + note + "\"}"
}

///|
fn clamp(node : Int32, limit : Int32) -> Int32 {
  if node < 0 || node >= limit {
    0
  } else {
    node
  }
}
