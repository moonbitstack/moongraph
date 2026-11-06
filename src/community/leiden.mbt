// The Leiden walk, in its own file because it carries a small weighted graph with it.
//
// Louvain has two known faults: a node that moves alone can cut its old group in two,
// and a group that is only held together through another group disappears once the
// other group leaves. Leiden answers both by refining every group into pieces that are
// each connected before the graph is folded, and by folding the refined pieces rather
// than the coarse groups. The refinement below does exactly that: a node only joins a
// piece that one of its own neighbours already belongs to.

///|
/// A graph with edge weights, which is what the folds of the walk need: once a group
/// of nodes becomes one node, the edges between the groups carry a count.
priv struct Weighted {
  size : Int32
  nbrs : Array[Array[Int32]]
  weights : Array[Array[Double]]
  loops : Array[Double]
  degree : Array[Double]
  total : Double
}

///|
/// The graph as it comes in: weight one on every edge, and a self-loop kept as a loop
/// so that it stays inside whatever group its node ends up in.
fn[G : @moongraph.Topology] Weighted::from_topology(graph : G) -> Weighted {
  let size = @moongraph.Topology::node_count(graph)
  let nbrs : Array[Array[Int32]] = Array::makei(size, fn(_) {
    ([] : Array[Int32])
  })
  let weights : Array[Array[Double]] = Array::makei(size, fn(_) {
    ([] : Array[Double])
  })
  let loops : Array[Double] = Array::make(size, 0.0)
  for edge in 0..<@moongraph.Topology::edge_count(graph) {
    let (a, b) = @moongraph.Topology::endpoints(graph, edge)
    if a < 0 || b < 0 || a >= size || b >= size {
      continue
    }
    if a == b {
      loops[a] = loops[a] + 1.0
      continue
    }
    // Both directions, so that a neighbour lookup is one array read either way.
    nbrs[a].push(b)
    weights[a].push(1.0)
    nbrs[b].push(a)
    weights[b].push(1.0)
  }
  let degree : Array[Double] = Array::make(size, 0.0)
  let mut total = 0.0
  for node in 0..<size {
    let (unique, shared) = tidy(nbrs[node], weights[node])
    nbrs[node] = unique
    weights[node] = shared
    let mut sum = 0.0
    for weight in shared {
      sum = sum + weight
    }
    degree[node] = sum + 2.0 * loops[node]
    total = total + degree[node]
  }
  { size, nbrs, weights, loops, degree, total: total / 2.0, }
}

///|
/// Folds repeated neighbours into one entry, summing their weights, and leaves the
/// list sorted by neighbour number so that two runs agree.
fn tidy(
  nbrs : Array[Int32],
  weights : Array[Double],
) -> (Array[Int32], Array[Double]) {
  let pairs : Array[(Int32, Double)] = Array::makei(nbrs.length(), fn(i) {
    (nbrs[i], weights[i])
  })
  pairs.sort_by(fn(x, y) {
    if x.0 < y.0 {
      -1
    } else if x.0 > y.0 {
      1
    } else {
      0
    }
  })
  let unique : Array[Int32] = []
  let shared : Array[Double] = []
  for pair in pairs {
    if unique.length() > 0 && unique[unique.length() - 1] == pair.0 {
      let last = shared.length() - 1
      shared[last] = shared[last] + pair.1
    } else {
      unique.push(pair.0)
      shared.push(pair.1)
    }
  }
  (unique, shared)
}

///|
/// The graph folded along `label`: one node per label, the edges inside a label kept
/// as a loop, and the edges between labels carrying the sum of what joined them.
fn Weighted::fold(
  self : Weighted,
  label : Array[Int32],
  count : Int32,
) -> Weighted {
  let nbrs : Array[Array[Int32]] = Array::makei(count, fn(_) {
    ([] : Array[Int32])
  })
  let weights : Array[Array[Double]] = Array::makei(count, fn(_) {
    ([] : Array[Double])
  })
  let loops : Array[Double] = Array::make(count, 0.0)
  for node in 0..<self.size {
    let here = label[node]
    loops[here] = loops[here] + self.loops[node]
    for at in 0..<self.nbrs[node].length() {
      let other = self.nbrs[node][at]
      let weight = self.weights[node][at]
      let there = label[other]
      if here == there {
        // The two ends of an inside edge each report it once; half of each adds up
        // to the one edge it is.
        loops[here] = loops[here] + weight / 2.0
      } else {
        nbrs[here].push(there)
        weights[here].push(weight)
      }
    }
  }
  let degree : Array[Double] = Array::make(count, 0.0)
  let mut total = 0.0
  for node in 0..<count {
    let (unique, shared) = tidy(nbrs[node], weights[node])
    nbrs[node] = unique
    weights[node] = shared
    let mut sum = 0.0
    for weight in shared {
      sum = sum + weight
    }
    degree[node] = sum + 2.0 * loops[node]
    total = total + degree[node]
  }
  { size: count, nbrs, weights, loops, degree, total: total / 2.0, }
}

///|
/// Every node takes the community that raises modularity most, starting from `opening`,
/// in a queue that re-admits a node whenever a neighbour moves.
fn Weighted::local_move(
  self : Weighted,
  opening : Array[Int32],
  groups : Int32,
  resolution : Double,
) -> Array[Int32] {
  let size = self.size
  let label = opening.copy()
  if self.total <= 0.0 {
    return label
  }
  let totals : Array[Double] = Array::make(groups, 0.0)
  for node in 0..<size {
    totals[label[node]] = totals[label[node]] + self.degree[node]
  }
  let queue : Array[Int32] = Array::makei(size, fn(i) { i })
  let waiting : Array[Bool] = Array::make(size, true)
  let mut head = 0
  let square = 2.0 * self.total * self.total
  while head < queue.length() {
    let node = queue[head]
    head = head + 1
    waiting[node] = false
    let own = label[node]
    let weight = self.degree[node]
    // Compare the gain of every community the node touches, with the node taken out
    // of its own first so that staying put is scored like any other move.
    totals[own] = totals[own] - weight
    let shared : Array[Int32] = []
    let amount : Array[Double] = []
    for at in 0..<self.nbrs[node].length() {
      let there = label[self.nbrs[node][at]]
      let edge = self.weights[node][at]
      let mut found = -1
      for i in 0..<shared.length() {
        if shared[i] == there {
          found = i
          break
        }
      }
      if found >= 0 {
        amount[found] = amount[found] + edge
      } else {
        shared.push(there)
        amount.push(edge)
      }
    }
    // Staying put is scored the same way as moving, and wins every tie, which is
    // what keeps the walk from drifting on rounding noise.
    let mut keep = -resolution * weight * totals[own] / square
    for i in 0..<shared.length() {
      if shared[i] == own {
        keep = amount[i] / self.total -
          resolution * weight * totals[own] / square
        break
      }
    }
    let mut best = own
    let mut best_gain = keep
    for i in 0..<shared.length() {
      let there = shared[i]
      if there == own {
        continue
      }
      let gain = amount[i] / self.total -
        resolution * weight * totals[there] / square
      if gain > best_gain + 1.0e-12 {
        best_gain = gain
        best = there
      }
    }
    label[node] = best
    totals[best] = totals[best] + weight
    if best != own {
      for at in 0..<self.nbrs[node].length() {
        let other = self.nbrs[node][at]
        if !waiting[other] {
          waiting[other] = true
          queue.push(other)
        }
      }
    }
  }
  label
}

///|
/// Splits every community into pieces that are each connected: a node only joins a
/// piece that one of its own neighbours is already in, and only when the weight behind
/// the join is enough to call the two well connected.
fn Weighted::refine(
  self : Weighted,
  partition : Array[Int32],
  groups : Int32,
  resolution : Double,
) -> Array[Int32] {
  let size = self.size
  let label : Array[Int32] = Array::makei(size, fn(i) { i })
  if self.total <= 0.0 {
    return label
  }
  let sizes : Array[Int32] = Array::make(size, 1)
  let members : Array[Array[Int32]] = Array::makei(groups, fn(_) {
    ([] : Array[Int32])
  })
  for node in 0..<size {
    members[partition[node]].push(node)
  }
  let limit = 2.0 * self.total
  for group in members {
    for node in group {
      let here = label[node]
      let shared : Array[Int32] = []
      let amount : Array[Double] = []
      for at in 0..<self.nbrs[node].length() {
        let other = self.nbrs[node][at]
        if partition[other] != partition[node] || label[other] == here {
          continue
        }
        let there = label[other]
        let edge = self.weights[node][at]
        let mut found = -1
        for i in 0..<shared.length() {
          if shared[i] == there {
            found = i
            break
          }
        }
        if found >= 0 {
          amount[found] = amount[found] + edge
        } else {
          shared.push(there)
          amount.push(edge)
        }
      }
      let mut best = -1
      let mut best_edge = 0.0
      for i in 0..<shared.length() {
        if amount[i] > best_edge {
          best_edge = amount[i]
          best = shared[i]
        }
      }
      // Well connected: the weight from the node to the piece has to carry at least
      // its share of the whole graph. The weight from the node alone is a lower bound
      // on the weight between the two pieces, so this errs towards keeping them apart,
      // which is the safe direction: pieces stay connected either way.
      if best >= 0 &&
        best_edge >=
        resolution * self.degree[node] * sizes[best].to_double() / limit {
        sizes[here] = sizes[here] - 1
        label[node] = best
        sizes[best] = sizes[best] + 1
      }
    }
  }
  label
}

///|
/// Renumbers labels to a dense range, and answers how many there are.
fn densely(labels : Array[Int32], limit : Int32) -> (Array[Int32], Int32) {
  let remap : Array[Int32] = Array::make(limit, -1)
  let out : Array[Int32] = Array::make(labels.length(), 0)
  let mut next = 0
  for i in 0..<labels.length() {
    let label = labels[i]
    if label >= 0 && label < limit {
      if remap[label] < 0 {
        remap[label] = next
        next = next + 1
      }
      out[i] = remap[label]
    }
  }
  (out, next)
}

///|
/// The whole walk: move, refine, fold, and repeat on the folded graph.
///
/// The point of folding the refined pieces rather than the coarse groups is that the
/// coarse partition survives the fold: the next local move starts from it, so a run
/// never throws away the progress of the level below.
fn[G : @moongraph.Topology] leiden_walk(
  graph : G,
  resolution : Double,
  rounds : Int32,
) -> @moongraph.Partition {
  let n = @moongraph.Topology::node_count(graph)
  if n == 0 {
    return { label: ([] : Array[Int32]), count: 0, }
  }
  let origin = Weighted::from_topology(graph)
  let mut work = origin
  // Two maps run together: where each original node sits in the folded graph, and
  // which coarse group it ended up in. They are not the same thing — a folded node is
  // a refined piece, and several pieces make up one group.
  let seat : Array[Int32] = Array::makei(n, fn(i) { i })
  let label : Array[Int32] = Array::makei(n, fn(i) { i })
  let mut opening : Array[Int32] = Array::makei(n, fn(i) { i })
  let mut groups = n
  for _ in 0..<rounds {
    let moved = work.local_move(opening, groups, resolution)
    if same_partition(moved, opening, groups) {
      break
    }
    let (moved, moved_count) = densely(moved, groups)
    let piece = work.refine(moved, moved_count, resolution)
    let (piece, piece_count) = densely(piece, work.size)
    for node in 0..<n {
      // The answer is the coarse partition; the pieces are only what the graph is
      // folded along.
      label[node] = moved[seat[node]]
      seat[node] = piece[seat[node]]
    }
    if piece_count == work.size {
      break
    }
    // Each piece belongs to exactly one coarse group; that is the partition the next
    // level starts from.
    let owner : Array[Int32] = Array::make(piece_count, 0)
    for node in 0..<work.size {
      owner[piece[node]] = moved[node]
    }
    let (next_opening, next_groups) = densely(owner, moved_count)
    work = work.fold(piece, piece_count)
    opening = next_opening
    groups = next_groups
  }
  let (labels, total) = densely(label, groups)
  // One last local move on the graph as it came in: folding rounds the weights and
  // can leave a node one step away from a better group.
  let polished = origin.local_move(labels, total, resolution)
  let (polished, _) = densely(polished, total)
  split_apart(graph, polished)
}

///|
/// Whether two labelings describe the same partition.
fn same_partition(a : Array[Int32], b : Array[Int32], groups : Int32) -> Bool {
  let forward : Array[Int32] = Array::make(groups, -1)
  let back : Array[Int32] = Array::make(groups, -1)
  for i in 0..<a.length() {
    let here = a[i]
    let there = b[i]
    if forward[here] < 0 {
      forward[here] = there
    }
    if back[there] < 0 {
      back[there] = here
    }
    if forward[here] != there || back[there] != here {
      return false
    }
  }
  true
}

///|
/// Takes each community apart into its connected pieces.
///
/// The refinement above keeps every community connected on the graph it ran on, and
/// folding keeps that property, but a node that moved during the last local step can
/// still leave a piece behind. This is the cheap check that makes the promise hold for
/// the graph the caller actually passed in.
fn[G : @moongraph.Topology] split_apart(
  graph : G,
  labels : Array[Int32],
) -> @moongraph.Partition {
  let n = @moongraph.Topology::node_count(graph)
  let out : Array[Int32] = Array::make(n, -1)
  let mut next = 0
  for start in 0..<n {
    if out[start] >= 0 {
      continue
    }
    out[start] = next
    let queue : Array[Int32] = [start]
    let mut head = 0
    while head < queue.length() {
      let node = queue[head]
      head = head + 1
      for nbr in @moongraph.Topology::neighbors(graph, node) {
        if out[nbr] < 0 && labels[nbr] == labels[start] {
          out[nbr] = next
          queue.push(nbr)
        }
      }
    }
    next = next + 1
  }
  { label: out, count: next, }
}
