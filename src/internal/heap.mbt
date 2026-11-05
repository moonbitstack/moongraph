// A binary min-heap over (cost, item) pairs.
//
// The algorithms that grow a region by cheapest edge need nothing more: push an
// entry, pop the smallest. A decrease-key costs a push of a second entry, which
// is the lazy variant and is what the constant factor of the usual
// implementation is built on.

///|
/// A binary min-heap keyed by a cost, with the item number deciding ties so that
/// two runs over the same graph pop in the same order.
pub struct Heap {
  costs : Array[Double]
  items : Array[Int]
}

///|
pub fn Heap::new() -> Heap {
  { costs: [], items: [] }
}

///|
pub fn Heap::is_empty(self : Heap) -> Bool {
  self.items.length() == 0
}

///|
/// How many entries are waiting.
pub fn Heap::size(self : Heap) -> Int {
  self.items.length()
}

///|
/// Adds an entry.
pub fn Heap::push(self : Heap, cost : Double, item : Int) -> Unit {
  self.costs.push(cost)
  self.items.push(item)
  let mut at = self.items.length() - 1
  while at > 0 {
    let parent = (at - 1) / 2
    if self.before(at, parent) {
      self.swap(at, parent)
      at = parent
    } else {
      break
    }
  }
}

///|
/// Removes and returns the smallest entry.
pub fn Heap::pop(self : Heap) -> (Double, Int)? {
  let last = self.items.length() - 1
  if last < 0 {
    return None
  }
  let out = (self.costs[0], self.items[0])
  self.costs[0] = self.costs[last]
  self.items[0] = self.items[last]
  self.costs.pop() |> ignore
  self.items.pop() |> ignore
  let mut at = 0
  let total = self.items.length()
  while true {
    let left = at * 2 + 1
    let right = left + 1
    let mut best = at
    if left < total && self.before(left, best) {
      best = left
    }
    if right < total && self.before(right, best) {
      best = right
    }
    if best == at {
      break
    }
    self.swap(at, best)
    at = best
  }
  Some(out)
}

///|
fn Heap::before(self : Heap, a : Int, b : Int) -> Bool {
  if self.costs[a] < self.costs[b] {
    true
  } else if self.costs[a] > self.costs[b] {
    false
  } else {
    self.items[a] < self.items[b]
  }
}

///|
fn Heap::swap(self : Heap, a : Int, b : Int) -> Unit {
  let cost = self.costs[a]
  self.costs[a] = self.costs[b]
  self.costs[b] = cost
  let item = self.items[a]
  self.items[a] = self.items[b]
  self.items[b] = item
}
