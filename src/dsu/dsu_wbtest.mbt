// The differential test: every operation is answered twice, once by the forest and once by a
// naive array of labels that relabels a whole piece on every merge, and the two answers must
// agree at every step. The naive one is O(n) a merge, which is the price of being obvious.

///|
/// A reference disjoint set: one label per element, relabelled across the whole piece on a
/// merge. It is correct by construction and slow on purpose.
struct Naive {
  label : Array[Int32]
}

///|
fn naive_new(count : Int32) -> Naive {
  let label : Array[Int32] = Array::make(count, 0)
  for i in 0..<count {
    label[i] = i
  }
  { label, }
}

///|
fn Naive::union(self : Naive, a : Int32, b : Int32) -> Bool {
  if self.label[a] == self.label[b] {
    false
  } else {
    let old = self.label[b]
    let new = self.label[a]
    for i in 0..<self.label.length() {
      if self.label[i] == old {
        self.label[i] = new
      }
    }
    true
  }
}

///|
fn Naive::same(self : Naive, a : Int32, b : Int32) -> Bool {
  self.label[a] == self.label[b]
}

///|
fn Naive::size(self : Naive, node : Int32) -> Int32 {
  let mut total = 0
  let target = self.label[node]
  for i in 0..<self.label.length() {
    if self.label[i] == target {
      total = total + 1
    }
  }
  total
}

///|
fn Naive::count(self : Naive) -> Int32 {
  let seen : Array[Int32] = []
  for i in 0..<self.label.length() {
    if !seen.contains(self.label[i]) {
      seen.push(self.label[i])
    }
  }
  seen.length()
}

///|
/// A piece list from the naive labels, in the order each piece first appears, so it can be
/// compared with `groups`.
fn Naive::groups(self : Naive) -> Array[Array[Int32]] {
  let n = self.label.length()
  let roots : Array[Int32] = []
  let out : Array[Array[Int32]] = []
  for i in 0..<n {
    let root = self.label[i]
    let mut at = -1
    for k in 0..<roots.length() {
      if roots[k] == root {
        at = k
      }
    }
    if at < 0 {
      roots.push(root)
      out.push([i])
    } else {
      out[at].push(i)
    }
  }
  out
}

///|
test "the forest agrees with a naive relabelling at every step" {
  let rng = @moonrand.seeded(b"dsu-diff")
  let n = 12
  let forest = Dsu::new(n)
  let naive = naive_new(n)
  for step in 0..<400 {
    let a = @moonrand.randint(rng, 0, 11).to_int()
    let b = @moonrand.randint(rng, 0, 11).to_int()
    if step % 3 == 0 {
      let mine = forest.union(a, b)
      let theirs = naive.union(a, b)
      if mine != theirs {
        fail(
          "union(" +
          a.to_string() +
          ", " +
          b.to_string() +
          ") differs at step " +
          step.to_string(),
        )
      }
    } else if forest.same(a, b) != naive.same(a, b) {
      fail(
        "same(" +
        a.to_string() +
        ", " +
        b.to_string() +
        ") differs at step " +
        step.to_string(),
      )
    }
    if forest.size(a) != naive.size(a) {
      fail("size(" + a.to_string() + ") differs at step " + step.to_string())
    }
    if forest.count() != naive.count() {
      fail("count differs at step " + step.to_string())
    }
    if forest.groups() != naive.groups() {
      fail("groups differ at step " + step.to_string())
    }
  }
}

///|
test "a fresh forest has one piece per number" {
  let forest = Dsu::new(5)
  assert_eq(forest.count(), 5)
  assert_eq(forest.length(), 5)
  assert_eq(forest.size(3), 1)
  assert_false(forest.same(0, 1))
  assert_true(forest.union(0, 1))
  assert_true(forest.same(0, 1))
  assert_eq(forest.size(0), 2)
  assert_eq(forest.count(), 4)
  // Merging what is already one piece answers false and changes nothing.
  assert_false(forest.union(1, 0))
  assert_eq(forest.count(), 4)
}

///|
test "a union chain joins every number into one piece" {
  let forest = Dsu::new(8)
  for i in 0..<7 {
    forest.union(i, i + 1) |> ignore
  }
  assert_eq(forest.count(), 1)
  assert_eq(forest.size(0), 8)
  for i in 0..<8 {
    assert_true(forest.same(0, i))
  }
}
