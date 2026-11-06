///|
/// A dense V by V grid of cells, one edge payload per cell.
///
/// A cell holds at most one edge, so this type cannot represent parallel edges;
/// its edge numbers are the cell index `from * V + to`. That identity is what
/// makes it the right store for the passes that consult every pair: all-pairs
/// weights, transitive closure, a capacity grid read from a table.
///
/// A matrix is directed. Each cell is an edge from its row to its column; write
/// both cells to model an undirected edge.
///
/// ```mbt check
/// test {
///   let m : @moongraph.Matrix[Double] = @moongraph.Matrix::new(3)
///   m.set(0, 2, 1.5)
///   assert_eq(m.get(0, 2), Some(1.5))
///   assert_eq(m.get(2, 0), None)
///   assert_eq(m.edge_count(), 1)
///   assert_eq(m.neighbors(0), [2][:])
/// }
/// ```
pub struct Matrix[E] {
  n : Int32
  cells : Array[E?]
  mut live : Int32
  nbr_scratch : Array[Int32]
  inc_scratch : Array[Int32]
  in_nbr_scratch : Array[Int32]
  in_inc_scratch : Array[Int32]
  empty : Array[Int32]
}

///|
/// A matrix of `nodes` rows and columns with every cell empty.
pub fn[E] Matrix::new(nodes : Int32) -> Matrix[E] {
  let n = if nodes > 0 { nodes } else { 0 }
  Matrix::{
    n,
    cells: Array::make(n * n, (None : E?)),
    live: 0,
    nbr_scratch: [],
    inc_scratch: [],
    in_nbr_scratch: [],
    in_inc_scratch: [],
    empty: [],
  }
}

///|
/// The payload of a cell, or `None` when it is empty or the coordinates are
/// outside the matrix.
pub fn[E] Matrix::get(self : Matrix[E], from : Int32, to : Int32) -> E? {
  if from < 0 || from >= self.n || to < 0 || to >= self.n {
    return None
  }
  self.cells[from * self.n + to]
}

///|
/// Writes a cell, adding an edge when it was empty and replacing the payload when
/// it was not.
pub fn[E] Matrix::set(
  self : Matrix[E],
  from : Int32,
  to : Int32,
  data : E,
) -> Unit {
  if from < 0 || from >= self.n || to < 0 || to >= self.n {
    return
  }
  let at = from * self.n + to
  if self.cells[at] is None {
    self.live = self.live + 1
  }
  self.cells[at] = Some(data)
}

///|
/// Empties a cell.
pub fn[E] Matrix::remove(self : Matrix[E], from : Int32, to : Int32) -> Unit {
  if from < 0 || from >= self.n || to < 0 || to >= self.n {
    return
  }
  let at = from * self.n + to
  if self.cells[at] is Some(_) {
    self.live = self.live - 1
  }
  self.cells[at] = None
}

///|
/// Every edge of the matrix, as `(from, to)` pairs in cell order.
pub fn[E] Matrix::edges(self : Matrix[E]) -> Array[(Int32, Int32)] {
  let out : Array[(Int32, Int32)] = []
  for from in 0..<self.n {
    for to in 0..<self.n {
      if self.cells[from * self.n + to] is Some(_) {
        out.push((from, to))
      }
    }
  }
  out
}

///|
pub impl[E] Topology for Matrix[E] with fn node_count(self) {
  self.n
}

///|
pub impl[E] Topology for Matrix[E] with fn edge_count(self) {
  self.live
}

///|
pub impl[E] Topology for Matrix[E] with fn directed(_self) {
  true
}

///|
pub impl[E] Topology for Matrix[E] with fn neighbors(self, node) {
  if node < 0 || node >= self.n {
    return self.empty[:]
  }
  self.nbr_scratch.clear()
  let row = node * self.n
  for to in 0..<self.n {
    if self.cells[row + to] is Some(_) {
      self.nbr_scratch.push(to)
    }
  }
  self.nbr_scratch[:]
}

///|
pub impl[E] Topology for Matrix[E] with fn incident(self, node) {
  if node < 0 || node >= self.n {
    return self.empty[:]
  }
  self.inc_scratch.clear()
  let row = node * self.n
  for to in 0..<self.n {
    if self.cells[row + to] is Some(_) {
      self.inc_scratch.push(row + to)
    }
  }
  self.inc_scratch[:]
}

///|
pub impl[E] Topology for Matrix[E] with fn endpoints(self, edge) {
  if edge < 0 || edge >= self.n * self.n {
    return (-1, -1)
  }
  (edge / self.n, edge % self.n)
}

///|
pub impl[E] Inbound for Matrix[E] with fn in_neighbors(self, node) {
  if node < 0 || node >= self.n {
    return self.empty[:]
  }
  self.in_nbr_scratch.clear()
  for from in 0..<self.n {
    if self.cells[from * self.n + node] is Some(_) {
      self.in_nbr_scratch.push(from)
    }
  }
  self.in_nbr_scratch[:]
}

///|
pub impl[E] Inbound for Matrix[E] with fn in_incident(self, node) {
  if node < 0 || node >= self.n {
    return self.empty[:]
  }
  self.in_inc_scratch.clear()
  for from in 0..<self.n {
    if self.cells[from * self.n + node] is Some(_) {
      self.in_inc_scratch.push(from * self.n + node)
    }
  }
  self.in_inc_scratch[:]
}

///|
pub extend Matrix with Topology::{
  node_count,
  edge_count,
  directed,
  neighbors,
  incident,
  endpoints,
}

///|
pub extend Matrix with Inbound::{in_neighbors, in_incident}
