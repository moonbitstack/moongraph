// GraphML: nodes and edges with named data, in XML.

///|
/// The keys a document declares, so that a caller can tell a label from a weight.
pub(all) struct Keys {
  /// The key names, in the order the document declares them.
  names : Array[String]
  /// Whether each key applies to nodes (`true`) or edges (`false`).
  on_nodes : Array[Bool]
}

///|
/// A graph carrying node labels and edge weights.
pub(all) struct Loaded {
  /// The graph: the payload of a node is its label, the payload of an edge its weight.
  graph : @moongraph.Graph[String, Double]
  /// The keys the document declared.
  keys : Keys
}

///|
/// Writes a graph as GraphML.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[String, Double] = @moongraph.Graph::new()
///   g.add_node("a") |> ignore
///   g.add_node("b") |> ignore
///   g.add_edge(0, 1, 1.5) |> ignore
///   let text = @graphml.write(g)
///   assert_true(text.has_prefix("<?xml"))
/// }
/// ```
pub fn[G : @moongraph.Topology] write(
  graph : G,
  labels~ : (Int) -> String = fn(node) { node.to_string() },
  weight~ : (Int) -> Double = fn(_) { 1.0 },
) -> String {
  let mut out = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
  out = out + "<graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\">\n"
  out = out + "  <key id=\"label\" for=\"node\" attr.name=\"label\" attr.type=\"string\"/>\n"
  out = out + "  <key id=\"weight\" for=\"edge\" attr.name=\"weight\" attr.type=\"double\"/>\n"
  out = out +
    "  <graph id=\"G\" edgedefault=\"" +
    (if @moongraph.Topology::directed(graph) { "directed" } else { "undirected" }) +
    "\">\n"
  for node in 0..<@moongraph.Topology::node_count(graph) {
    out = out + "    <node id=\"n" + node.to_string() + "\">\n"
    out = out + "      <data key=\"label\">" + escape(labels(node)) + "</data>\n"
    out = out + "    </node>\n"
  }
  for edge in 0..<@moongraph.Topology::edge_count(graph) {
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    if a < 0 || b < 0 {
      continue
    }
    out = out + "    <edge source=\"n" + a.to_string() + "\" target=\"n" + b.to_string() +
      "\">\n"
    out = out + "      <data key=\"weight\">" + weight(edge).to_string() + "</data>\n"
    out = out + "    </edge>\n"
  }
  out + "  </graph>\n</graphml>\n"
}

///|
/// Reads a GraphML document.
///
/// A document that is not GraphML, or that names an edge between nodes it never declared,
/// is refused with the position the XML parser reports.
pub fn read(text : StringView) -> Loaded raise @moongraph.Refused {
  let document = @xml.loads(text.to_owned()) catch {
    @moonxml.Refused::Malformed(at~, why~) =>
      raise @moongraph.Refused::at_offset(text, at, why, "well formed XML")
    error => raise @moongraph.Refused::NotA(kind="GraphML", what=error.to_string())
  }
  let root = match document.document_element() {
    Some(element) => element
    None => raise @moongraph.Refused::NotA(kind="GraphML", what="the document has no root")
  }
  if local_name(root) != "graphml" {
    raise @moongraph.Refused::NotA(kind="GraphML", what="the root is not graphml")
  }
  // The keys first, so a data element can be matched to what it means.
  let names : Array[String] = []
  let on_nodes : Array[Bool] = []
  for child in root.child_elements() {
    if local_name(child) == "key" {
      let name = child.attr("attr.name").unwrap_or(child.attr("id").unwrap_or(""))
      let for_nodes = child.attr("for").unwrap_or("all") != "edge"
      names.push(name)
      on_nodes.push(for_nodes)
    }
  }
  let graph_element = {
    let mut found = None
    for child in root.child_elements() {
      if local_name(child) == "graph" {
        found = Some(child)
      }
    }
    match found {
      Some(element) => element
      None =>
        raise @moongraph.Refused::NotA(kind="GraphML", what="the document has no graph")
    }
  }
  let directed = graph_element.attr("edgedefault").unwrap_or("undirected") == "directed"
  let graph : @moongraph.Graph[String, Double] = @moongraph.Graph::new(directed~)
  let index : Array[(String, Int)] = []
  for child in graph_element.child_elements() {
    if local_name(child) == "node" {
      let id = child.attr("id").unwrap_or("")
      let label = data_of(child, "label").unwrap_or(id)
      let node = graph.add_node(label)
      index.push((id, node))
    }
  }
  for child in graph_element.child_elements() {
    if local_name(child) == "edge" {
      let source = child.attr("source").unwrap_or("")
      let target = child.attr("target").unwrap_or("")
      let weight = match data_of(child, "weight") {
        Some(text) =>
          match to_double(text) {
            Some(value) => value
            None => 1.0
          }
        None => 1.0
      }
      let pair = (lookup(index, source), lookup(index, target))
      match pair {
        (Some(a), Some(b)) => graph.add_edge(a, b, weight) |> ignore
        _ =>
          raise @moongraph.Refused::NotA(
            kind="GraphML",
            what="an edge names a node the document never declared",
          )
      }
    }
  }
  { graph, keys: { names, on_nodes } }
}

///|
/// The element's name without the namespace the document declares for it.
fn local_name(element : @moonxml.Element) -> String {
  @moonxml.local_of(element.name)
}

///|
/// The text of the `data` element under a node or edge whose key is the given name.
fn data_of(element : @moonxml.Element, key : String) -> String? {
  let mut found : String? = None
  for child in element.child_elements() {
    if local_name(child) == "data" && child.attr("key").unwrap_or("") == key {
      found = Some(child.text())
    }
  }
  found
}

///|
fn lookup(index : Array[(String, Int)], id : String) -> Int? {
  let mut found : Int? = None
  for (name, node) in index {
    if name == id {
      found = Some(node)
    }
  }
  found
}

///|
/// The four characters XML cannot carry raw, replaced by their entities. The ampersand
/// goes first, or every entity this function writes would be escaped again.
fn escape(text : String) -> String {
  let escaped = text.replace(old="&", new="&amp;")
  let escaped = escaped.replace(old="<", new="&lt;")
  let escaped = escaped.replace(old=">", new="&gt;")
  escaped.replace(old="\"", new="&quot;")
}

///|
fn to_double(text : String) -> Double? {
  let trimmed = text.trim()
  if trimmed.length() == 0 {
    return None
  }
  let mut at = 0
  let mut sign = 1.0
  if trimmed[0] == '-' {
    sign = -1.0
    at = 1
  }
  let mut whole = 0.0
  let mut digits = 0
  while at < trimmed.length() {
    let digit = trimmed[at].to_int() - '0'.to_int()
    if digit < 0 || digit > 9 {
      break
    }
    whole = whole * 10.0 + digit.to_double()
    digits = digits + 1
    at = at + 1
  }
  if digits == 0 {
    return None
  }
  if at < trimmed.length() && trimmed[at] == '.' {
    at = at + 1
    let mut scale = 0.1
    while at < trimmed.length() {
      let digit = trimmed[at].to_int() - '0'.to_int()
      if digit < 0 || digit > 9 {
        return None
      }
      whole = whole + digit.to_double() * scale
      scale = scale / 10.0
      at = at + 1
    }
  }
  Some(sign * whole)
}
