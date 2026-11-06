// A worked example: build a small map, find the cheapest route, print it, and write the
// graph out in two formats so the output can be checked by eye.

///|
fn main {
  let map : @moongraph.Graph[String, Double] = @moongraph.Graph::new(
    directed=false,
  )
  let names = ["harbour", "market", "station", "hill", "museum"]
  for name in names {
    map.add_node(name) |> ignore
  }
  map.add_edge(0, 1, 4.0) |> ignore
  map.add_edge(0, 2, 1.0) |> ignore
  map.add_edge(2, 1, 2.0) |> ignore
  map.add_edge(1, 3, 5.0) |> ignore
  map.add_edge(2, 3, 8.0) |> ignore
  map.add_edge(3, 4, 3.0) |> ignore

  let cost = map.weights(fn(fare) { fare })
  let paths = @path.dijkstra(map, 0, weight=cost) catch {
    @moongraph.Refused::NegativeWeight(edge~) => {
      println("edge " + edge.to_string() + " costs less than nothing")
      return
    }
    _ => {
      println("the search was refused")
      return
    }
  }

  println("route from " + map.node_data(0) + " to " + map.node_data(4))
  match paths.path_to(4) {
    Some(route) => {
      for node in route {
        println(
          "  " +
          map.node_data(node) +
          " at " +
          paths.distance[node].unwrap().to_string(),
        )
      }
      let total = paths.distance[4].unwrap()
      println("total fare: " + total.to_string())
    }
    None => println("  no route")
  }

  println("")
  println("as an edge list:")
  println(@io.edge_list(map))
  println("as graph6: " + @io.graph6(map))
}
