///|
/// Why a graph was refused.
///
/// Every function that can reject its input raises this and names the node or
/// edge it objected to, so a caller can point at its own input instead of
/// printing a message. A graph-level mistake is a value here, never a process
/// abort: the numbers came from the caller, and the caller can handle them.
///
/// ```mbt check
/// test {
///   let refused = @moongraph.Refused::Cycle(nodes=[0, 1, 0])
///   let line = match refused {
///     Cycle(nodes~) => "a cycle through " + nodes.length().to_string() + " nodes"
///     _ => "something else"
///   }
///   assert_eq(line, "a cycle through 3 nodes")
/// }
/// ```
#derive(Eq, @debug.Debug)
pub(all) suberror Refused {
  /// An edge with a negative weight reached an algorithm that requires
  /// non-negative ones, such as a shortest-path search that settles a node
  /// once. The payload is the edge number that carried it.
  NegativeWeight(edge~ : Int)
  /// The graph has a cycle where an acyclic graph was required. The payload is
  /// one witness: node numbers, first and last equal.
  Cycle(nodes~ : Array[Int])
  /// No route exists between the two nodes, or the supplies of a flow problem
  /// cannot be routed between them.
  Disconnected(from~ : Int, to~ : Int)
  /// The problem has no answer at the limits the caller set, such as a
  /// chromatic number above the colour limit.
  NoSolution
  /// The graph does not have the property the function requires. `kind` is the
  /// property, `what` the reason, so a caller can print one line without
  /// matching every case.
  NotA(kind~ : String, what~ : String)
  /// A node or edge number is outside the graph.
  OutOfRange(node~ : Int)
  /// A text in a graph format could not be read. `at` is a byte offset from the
  /// start of the text; `line` and `column` count from 1. `got` is what was
  /// found and `want` is what was expected, both as short literal text.
  Malformed(
    at~ : Int,
    line~ : Int,
    column~ : Int,
    got~ : String,
    want~ : String
  )
}

///|
pub extend Refused with Eq::{ equal, not_equal }

///|
pub extend Refused with @debug.Debug::{ to_repr }

///|
/// The refusal for a byte offset, with the line and column computed from the
/// text it points into. Parsers report positions in all three units because a
/// caller may be reading a file (line and column) or a byte stream (offset).
pub fn Refused::at_offset(
  text : StringView,
  at : Int,
  got : String,
  want : String,
) -> Refused {
  let mut line = 1
  let mut column = 1
  let limit = if at < text.length() { at } else { text.length() }
  for i in 0..<limit {
    if text[i] == '\n' {
      line = line + 1
      column = 1
    } else {
      column = column + 1
    }
  }
  Refused::Malformed(at~, line~, column~, got~, want~)
}
