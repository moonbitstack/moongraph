// Reading and writing the text formats.
//
// Every reader reports a refusal with the byte offset, the line and the column, because a
// caller looking at a file wants a place to jump to and a caller reading a stream wants an
// offset.

///|
/// A graph as an edge list: one `from to` pair per line, an optional third column for the
/// weight, and `#` for comments.
///
/// ```mbt check
/// test {
///   let g : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::from_edges(
///     [(0, 1)],
///     node=(),
///     edge=(),
///     directed=false,
///   )
///   assert_eq(@io.edge_list(g), "0 1\n")
/// }
/// ```
pub fn[G : @moongraph.Topology] edge_list(
  graph : G,
  data~ : Bool = false,
) -> String {
  let mut out = if @moongraph.Topology::directed(graph) {
    "# directed\n"
  } else {
    ""
  }
  for edge in 0..<@moongraph.Topology::edge_count(graph) {
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    if a < 0 || b < 0 {
      continue
    }
    out = out + a.to_string() + " " + b.to_string()
    if data {
      out = out + " 1"
    }
    out = out + "\n"
  }
  out
}

///|
/// The graph an edge list describes.
///
/// A line that does not hold two numbers is refused with the offset it starts at.
pub fn parse_edges(
  text : StringView,
  directed~ : Bool = false,
) -> @moongraph.Graph[Unit, Double] raise @moongraph.Refused {
  let graph : @moongraph.Graph[Unit, Double] = @moongraph.Graph::new(directed~)
  for (offset, line) in lines_of(text) {
    let trimmed = line.trim()
    if trimmed.length() == 0 || trimmed[0] == '#' {
      continue
    }
    let fields = fields_of(trimmed)
    if fields.length() < 2 {
      raise @moongraph.Refused::at_offset(
        text, offset, line, "two node numbers",
      )
    }
    let a = match to_int(fields[0]) {
      Some(value) => value
      None =>
        raise @moongraph.Refused::at_offset(text, offset, fields[0], "a number")
    }
    let b = match to_int(fields[1]) {
      Some(value) => value
      None =>
        raise @moongraph.Refused::at_offset(text, offset, fields[1], "a number")
    }
    let weight = if fields.length() > 2 {
      match to_double(fields[2]) {
        Some(value) => value
        None =>
          raise @moongraph.Refused::at_offset(
            text,
            offset,
            fields[2],
            "a number",
          )
      }
    } else {
      1.0
    }
    while graph.node_count() <= a || graph.node_count() <= b {
      graph.add_node(()) |> ignore
    }
    graph.add_edge(a, b, weight) |> ignore
  }
  graph
}

///|
/// A graph as an adjacency list: one line per node, starting with its number.
pub fn[G : @moongraph.Topology] adjacency_list(graph : G) -> String {
  let n = @moongraph.Topology::node_count(graph)
  let mut out = if @moongraph.Topology::directed(graph) {
    "# directed\n"
  } else {
    ""
  }
  for node in 0..<n {
    out = out + node.to_string()
    for nbr in @moongraph.Topology::neighbors(graph, node) {
      out = out + " " + nbr.to_string()
    }
    out = out + "\n"
  }
  out
}

///|
/// The graph an adjacency list describes.
pub fn parse_adjacency(
  text : StringView,
  directed~ : Bool = false,
) -> @moongraph.Graph[Unit, Unit] raise @moongraph.Refused {
  let graph : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new(directed~)
  for (offset, line) in lines_of(text) {
    let trimmed = line.trim()
    if trimmed.length() == 0 || trimmed[0] == '#' {
      continue
    }
    let fields = fields_of(trimmed)
    let node = match to_int(fields[0]) {
      Some(value) => value
      None =>
        raise @moongraph.Refused::at_offset(text, offset, fields[0], "a number")
    }
    while graph.node_count() <= node {
      graph.add_node(()) |> ignore
    }
    for i in 1..<fields.length() {
      let nbr = match to_int(fields[i]) {
        Some(value) => value
        None =>
          raise @moongraph.Refused::at_offset(
            text,
            offset,
            fields[i],
            "a number",
          )
      }
      while graph.node_count() <= nbr {
        graph.add_node(()) |> ignore
      }
      if directed || node <= nbr {
        graph.add_edge(node, nbr, ()) |> ignore
      }
    }
  }
  graph
}

///|
/// A graph in GML: a nested list of key and value.
pub fn[G : @moongraph.Topology] gml(graph : G) -> String {
  let n = @moongraph.Topology::node_count(graph)
  let mut out = "graph [\n"
  if @moongraph.Topology::directed(graph) {
    out = out + "  directed 1\n"
  }
  for node in 0..<n {
    out = out + "  node [\n    id " + node.to_string() + "\n  ]\n"
  }
  for edge in 0..<@moongraph.Topology::edge_count(graph) {
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    if a < 0 || b < 0 {
      continue
    }
    out = out +
      "  edge [\n    source " +
      a.to_string() +
      "\n    target " +
      b.to_string() +
      "\n  ]\n"
  }
  out + "]\n"
}

///|
/// The graph a GML document describes.
pub fn parse_gml(
  text : StringView,
) -> @moongraph.Graph[Unit, Unit] raise @moongraph.Refused {
  let tokens = gml_tokens(text)
  if tokens.length() == 0 || tokens[0] != "graph" {
    raise @moongraph.Refused::at_offset(
      text, 0, "the start of the document", "graph [",
    )
  }
  // The direction is a property of the whole graph, so it is read before the graph exists.
  let mut directed = false
  for i in 0..<tokens.length() {
    if tokens[i] == "directed" &&
      i + 1 < tokens.length() &&
      tokens[i + 1] == "1" {
      directed = true
    }
  }
  let graph : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new(directed~)
  let mut inside_node = false
  let mut inside_edge = false
  let mut source = -1
  let mut at = 0
  while at < tokens.length() {
    let token = tokens[at]
    if token == "node" {
      inside_node = true
      at = at + 1
    } else if token == "edge" {
      inside_edge = true
      at = at + 1
    } else if token == "id" && inside_node && at + 1 < tokens.length() {
      match to_int(tokens[at + 1]) {
        Some(value) =>
          while graph.node_count() <= value {
            graph.add_node(()) |> ignore
          }
        None => ()
      }
      at = at + 2
    } else if token == "source" && inside_edge && at + 1 < tokens.length() {
      source = to_int(tokens[at + 1]).unwrap_or(-1)
      at = at + 2
    } else if token == "target" && inside_edge && at + 1 < tokens.length() {
      let target = to_int(tokens[at + 1]).unwrap_or(-1)
      if source >= 0 && target >= 0 {
        while graph.node_count() <= source || graph.node_count() <= target {
          graph.add_node(()) |> ignore
        }
        graph.add_edge(source, target, ()) |> ignore
      }
      inside_edge = false
      at = at + 2
    } else if token == "]" {
      inside_edge = false
      inside_node = false
      at = at + 1
    } else {
      at = at + 1
    }
  }
  graph
}

///|
/// The words of a GML document, in order.
fn gml_tokens(text : StringView) -> Array[String] {
  let out : Array[String] = []
  let mut at = 0
  while at < text.length() {
    let c = text[at]
    if c == ' ' || c == '\n' || c == '\r' || c == '\t' {
      at = at + 1
    } else if c == '[' || c == ']' {
      out.push(if c == '[' { "[" } else { "]" })
      at = at + 1
    } else if c == '"' {
      let mut end = at + 1
      while end < text.length() && text[end] != '"' {
        end = end + 1
      }
      out.push(text.exact_view(start=at + 1, end~).to_owned())
      at = end + 1
    } else {
      let mut end = at
      while end < text.length() &&
            text[end] != ' ' &&
            text[end] != '\n' &&
            text[end] != '\r' &&
            text[end] != '\t' &&
            text[end] != '[' &&
            text[end] != ']' {
        end = end + 1
      }
      out.push(text.exact_view(start=at, end~).to_owned())
      at = end
    }
  }
  out
}

///|
/// A graph in Pajek's format: a vertex count, then the arcs.
pub fn[G : @moongraph.Topology] pajek(graph : G) -> String {
  let n = @moongraph.Topology::node_count(graph)
  let mut out = "*Vertices " + n.to_string() + "\n"
  for node in 0..<n {
    out = out + " " + (node + 1).to_string() + "\n"
  }
  out = out +
    (if @moongraph.Topology::directed(graph) { "*Arcs\n" } else { "*Edges\n" })
  for edge in 0..<@moongraph.Topology::edge_count(graph) {
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    if a < 0 || b < 0 {
      continue
    }
    out = out + (a + 1).to_string() + " " + (b + 1).to_string() + "\n"
  }
  out
}

///|
/// The graph a Pajek document describes. Node numbers are shifted down by one, because the
/// format counts from one.
pub fn parse_pajek(
  text : StringView,
) -> @moongraph.Graph[Unit, Unit] raise @moongraph.Refused {
  let mut directed = false
  for (_, line) in lines_of(text) {
    let trimmed = line.trim()
    if trimmed.length() > 0 && starts_with(trimmed, "*arcs") {
      directed = true
    }
  }
  let graph : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new(directed~)
  let mut counting = false
  for (offset, line) in lines_of(text) {
    let trimmed = line.trim()
    if trimmed.length() == 0 {
      continue
    }
    if trimmed[0] == '*' {
      if starts_with(trimmed, "*vertices") {
        counting = true
        let fields = fields_of(trimmed)
        if fields.length() > 1 {
          match to_int(fields[1]) {
            Some(count) =>
              for _ in 0..<count {
                graph.add_node(()) |> ignore
              }
            None =>
              raise @moongraph.Refused::at_offset(
                text,
                offset,
                fields[1],
                "a vertex count",
              )
          }
        }
      } else if starts_with(trimmed, "*arcs") {
        counting = false
      } else if starts_with(trimmed, "*edges") {
        counting = false
      } else {
        counting = false
      }
      continue
    }
    if counting {
      continue
    }
    let fields = fields_of(trimmed)
    if fields.length() >= 2 {
      let a = to_int(fields[0]).unwrap_or(0) - 1
      let b = to_int(fields[1]).unwrap_or(0) - 1
      if a >= 0 && b >= 0 {
        while graph.node_count() <= a || graph.node_count() <= b {
          graph.add_node(()) |> ignore
        }
        graph.add_edge(a, b, ()) |> ignore
      }
    }
  }
  graph
}

///|
/// A graph in graph6: the node count in the first bytes, then one bit per possible edge.
pub fn[G : @moongraph.Topology] graph6(graph : G) -> String {
  let n = @moongraph.Topology::node_count(graph)
  let bits : Array[Bool] = []
  for j in 1..<n {
    for i in 0..<j {
      bits.push(joined(graph, i, j))
    }
  }
  count_header(n) + pack_bits(bits)
}

///|
/// The graph a graph6 string describes.
pub fn parse_graph6(
  text : StringView,
) -> @moongraph.Graph[Unit, Unit] raise @moongraph.Refused {
  let body = text.trim().to_owned()
  if body.length() == 0 {
    raise @moongraph.Refused::at_offset(text, 0, "", "a graph6 string")
  }
  let (n, skip) = match read_count(body, 0) {
    Some(value) => value
    None => raise @moongraph.Refused::at_offset(text, 0, body, "a node count")
  }
  let graph : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new(
    directed=false,
  )
  for _ in 0..<n {
    graph.add_node(()) |> ignore
  }
  let bits = unpack_bits(body, skip)
  let mut at = 0
  for j in 1..<n {
    for i in 0..<j {
      if at < bits.length() && bits[at] {
        graph.add_edge(i, j, ()) |> ignore
      }
      at = at + 1
    }
  }
  graph
}

///|
/// A graph in sparse6, which stores only the edges that are there, in the format's own
/// bytes.
///
/// The text is the format's bytes rather than a rendering of them: the node count in
/// one, four or eight bytes, then each edge as a node number in `k` bits, where `k` is
/// what `n - 1` needs. Edges are written by their higher endpoint, in ascending order,
/// and an edge at the same endpoint as the one before it drops the number it repeats; a
/// run of equal numbers is therefore one number and a flag per edge.
///
/// Self loops and parallel edges are part of the format, and this library's graphs carry
/// both, so they are written as they are. The tail is filled with one bits, which no pair
/// can use, and the one case where that filler would read as a loop on the last node is
/// filled with a zero first.
pub fn[G : @moongraph.Topology] sparse6(graph : G) -> String {
  let n = @moongraph.Topology::node_count(graph)
  let width = node_width(n)
  let ends : Array[(Int32, Int32)] = []
  for edge in 0..<@moongraph.Topology::edge_count(graph) {
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    if a >= 0 && a < n && b >= 0 && b < n {
      ends.push(if a < b { (b, a) } else { (a, b) })
    }
  }
  ends.sort_by(fn(left, right) {
    if left.0 != right.0 {
      left.0 - right.0
    } else {
      left.1 - right.1
    }
  })
  let bits : Array[Bool] = []
  let mut current = 0
  for pair in ends {
    let (high, low) = pair
    if high == current {
      bits.push(false)
      push_bits(bits, low, width)
    } else if high == current + 1 {
      current = high
      bits.push(true)
      push_bits(bits, low, width)
    } else {
      current = high
      bits.push(true)
      push_bits(bits, high, width)
      bits.push(false)
      push_bits(bits, low, width)
    }
  }
  let padding = (6 - bits.length() % 6) % 6
  // A run of one bits moves the reader's node up to the last one, where the pair would
  // read as a loop on it. A zero first sends those bits through the "skip to this node"
  // branch instead, which adds no edge. The format spends that bit only for a node count
  // that is a power of two below 64, the last node having no edge, and enough room to
  // carry the flag; the reference implementation of the format is what these three
  // conditions are read from, so the bytes match it graph for graph.
  if width < 6 && n == 1 << width && padding >= width && current < n - 1 {
    bits.push(false)
    for _ in 1..<padding {
      bits.push(true)
    }
  } else {
    for _ in 0..<padding {
      bits.push(true)
    }
  }
  ":" + count_header(n) + pack_bits(bits)
}

///|
/// How many bits a node number takes in sparse6: enough for `n - 1`, and one at least.
fn node_width(n : Int32) -> Int32 {
  let mut width = 1
  while 1 << width < n {
    width = width + 1
  }
  width
}

///|
/// The graph a sparse6 string describes.
///
/// The leading `>>sparse6<<` that files use as a format marker is accepted and dropped;
/// the `:` that starts the data is required. A pair that is cut off at the end of the
/// text is discarded, as the format asks, and a run of filler ones stops the walk rather
/// than adding an edge the writer never meant.
pub fn parse_sparse6(
  text : StringView,
) -> @moongraph.Graph[Unit, Unit] raise @moongraph.Refused {
  let trimmed = text.trim().to_owned()
  let body = if trimmed.has_prefix(">>sparse6<<") {
    trimmed.exact_view(start=11, end=trimmed.length()).to_owned()
  } else {
    trimmed
  }
  if body.length() == 0 || body[0] != ':' {
    raise @moongraph.Refused::at_offset(text, 0, body, "a sparse6 string")
  }
  let (n, skip) = match read_count(body, 1) {
    Some(value) => value
    None => raise @moongraph.Refused::at_offset(text, 1, body, "a node count")
  }
  let graph : @moongraph.Graph[Unit, Unit] = @moongraph.Graph::new(
    directed=false,
  )
  for _ in 0..<n {
    graph.add_node(()) |> ignore
  }
  let width = node_width(n)
  let bits = unpack_bits(body, 1 + skip)
  let mut at = 0
  let mut high = 0
  while at < bits.length() {
    let flag = bits[at]
    at = at + 1
    if at + width > bits.length() {
      // A pair the text ran out on: the format says to drop it.
      break
    }
    let mut value = 0
    for _ in 0..<width {
      value = (value << 1) | (if bits[at] { 1 } else { 0 })
      at = at + 1
    }
    if flag {
      high = high + 1
    }
    if value >= n || high >= n {
      break
    }
    if value > high {
      high = value
    } else {
      graph.add_edge(value, high, ()) |> ignore
    }
  }
  graph
}

///|
/// A graph in a plain form, which is its adjacency list.
pub fn[G : @moongraph.Topology] text(graph : G) -> String {
  adjacency_list(graph)
}

///|
/// The lines of a text with the byte offset each starts at.
fn lines_of(text : StringView) -> Array[(Int32, String)] {
  let out : Array[(Int32, String)] = []
  let mut at = 0
  let mut start = 0
  while at < text.length() {
    if text[at] == '\n' {
      out.push((start, text.exact_view(start~, end=at).to_owned()))
      at = at + 1
      start = at
    } else {
      at = at + 1
    }
  }
  if start < text.length() {
    out.push((start, text.exact_view(start~, end=text.length()).to_owned()))
  }
  out
}

///|
/// The words of a line, split on spaces and tabs.
fn fields_of(line : StringView) -> Array[String] {
  let out : Array[String] = []
  let mut at = 0
  while at < line.length() {
    while at < line.length() &&
          (line[at] == ' ' || line[at] == '\t' || line[at] == '\r') {
      at = at + 1
    }
    let start = at
    while at < line.length() &&
          line[at] != ' ' &&
          line[at] != '\t' &&
          line[at] != '\r' {
      at = at + 1
    }
    if at > start {
      out.push(line.exact_view(start~, end=at).to_owned())
    }
  }
  out
}

///|
/// Whether the text begins with the prefix.
fn starts_with(text : StringView, prefix : String) -> Bool {
  if text.length() < prefix.length() {
    return false
  }
  let mut same = true
  for i in 0..<prefix.length() {
    if text[i] != prefix[i] {
      same = false
      break
    }
  }
  same
}

///|
/// An integer, or `None` when the text is not one.
fn to_int(text : String) -> Int32? {
  if text.length() == 0 {
    return None
  }
  let mut at = 0
  let mut sign = 1
  if text[0] == '-' {
    sign = -1
    at = 1
  } else if text[0] == '+' {
    at = 1
  }
  if at >= text.length() {
    return None
  }
  let mut value = 0
  while at < text.length() {
    let digit = text[at].to_int() - '0'.to_int()
    if digit < 0 || digit > 9 {
      return None
    }
    value = value * 10 + digit
    at = at + 1
  }
  Some(sign * value)
}

///|
/// A decimal number, or `None` when the text is not one. The exponent form is not needed by
/// any of these formats and is refused rather than half read.
fn to_double(text : String) -> Double? {
  if text.length() == 0 {
    return None
  }
  let mut at = 0
  let mut sign = 1.0
  if text[0] == '-' {
    sign = -1.0
    at = 1
  } else if text[0] == '+' {
    at = 1
  }
  let mut whole = 0.0
  let mut digits = 0
  while at < text.length() {
    let digit = text[at].to_int() - '0'.to_int()
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
  if at < text.length() && text[at] == '.' {
    at = at + 1
    let mut scale = 0.1
    while at < text.length() {
      let digit = text[at].to_int() - '0'.to_int()
      if digit < 0 || digit > 9 {
        return None
      }
      whole = whole + digit.to_double() * scale
      scale = scale / 10.0
      at = at + 1
    }
  }
  if at < text.length() {
    return None
  }
  Some(sign * whole)
}

///|
/// The header both bit-string formats write for a node count: one byte below 63, four
/// up to 258047, and eight above it, the wider forms opening with 126.
fn count_header(n : Int32) -> String {
  if n < 63 {
    codes_to_string([n + 63])
  } else if n <= 258047 {
    codes_to_string([
      126,
      (n >> 12) + 63,
      ((n >> 6) & 0x3F) + 63,
      (n & 0x3F) + 63,
    ])
  } else {
    codes_to_string([
      126,
      126,
      ((n >> 30) & 0x3F) + 63,
      ((n >> 24) & 0x3F) + 63,
      ((n >> 18) & 0x3F) + 63,
      ((n >> 12) & 0x3F) + 63,
      ((n >> 6) & 0x3F) + 63,
      (n & 0x3F) + 63,
    ])
  }
}

///|
/// The node count a header gives, and how many bytes it took: `(n, bytes)`.
///
/// The first byte says which of the three forms it is, so a text that stops in the
/// middle of a wide header is refused rather than read as a smaller graph.
fn read_count(body : String, from : Int32) -> (Int32, Int32)? {
  if from >= body.length() {
    return None
  }
  let first = body[from].to_int() - 63
  if first < 0 || first > 63 {
    return None
  }
  if first < 63 {
    return Some((first, 1))
  }
  if from + 4 > body.length() {
    return None
  }
  let second = body[from + 1].to_int() - 63
  let skip = if second < 63 { 1 } else { 2 }
  let bytes = if skip == 1 { 4 } else { 8 }
  if from + bytes > body.length() {
    return None
  }
  let mut n = 0
  for i in skip..<bytes {
    let value = body[from + i].to_int() - 63
    if value < 0 || value > 63 {
      return None
    }
    n = (n << 6) | value
  }
  Some((n, bytes))
}

///|
fn pack_bits(bits : Array[Bool]) -> String {
  let codes : Array[Int32] = []
  let mut at = 0
  while at < bits.length() {
    let mut value = 0
    for i in 0..<6 {
      value = value << 1
      if at + i < bits.length() && bits[at + i] {
        value = value | 1
      }
    }
    codes.push(value + 63)
    at = at + 6
  }
  codes_to_string(codes)
}

///|
fn unpack_bits(body : String, from : Int32) -> Array[Bool] {
  let out : Array[Bool] = []
  for i in from..<body.length() {
    let value = body[i].to_int() - 63
    for bit in 0..<6 {
      out.push((value & (1 << (5 - bit))) != 0)
    }
  }
  out
}

///|
fn push_bits(bits : Array[Bool], value : Int32, width : Int32) -> Unit {
  for i in 0..<width {
    bits.push((value & (1 << (width - 1 - i))) != 0)
  }
}

///|
fn codes_to_string(codes : Array[Int32]) -> String {
  let out = StringBuilder()
  for code in codes {
    out.write_char(code.unsafe_to_char())
  }
  out.to_string()
}

///|
/// Whether an edge joins the two nodes.
fn[G : @moongraph.Topology] joined(graph : G, a : Int32, b : Int32) -> Bool {
  for nbr in @moongraph.Topology::neighbors(graph, a) {
    if nbr == b {
      return true
    }
  }
  false
}
