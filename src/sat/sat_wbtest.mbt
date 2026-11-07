// The differential test: random clause sets over a few variables, answered twice — by the
// implication graph here, and by trying all 2^n assignments. The two must agree on whether a
// solution exists, and any solution the graph hands back must satisfy every clause.

///|
/// Whether bit `at` of `mask` is set.
fn bit_at(mask : Int32, at : Int32, powers : Array[Int32]) -> Bool {
  mask / powers[at] % 2 == 1
}

///|
test "two-sat agrees with a brute-force assignment search" {
  let rng = @moonrand.seeded(b"sat-diff")
  let n = 5
  let powers = [1, 2, 4, 8, 16, 32]
  for round in 0..<40 {
    let sat = TwoSat::new(n)
    let ci : Array[Int32] = []
    let cf : Array[Bool] = []
    let cj : Array[Int32] = []
    let cg : Array[Bool] = []
    let m = 1 + @moonrand.randint(rng, 0, 10).to_int()
    for _ in 0..<m {
      let i = @moonrand.randint(rng, 0, 4).to_int()
      let j = @moonrand.randint(rng, 0, 4).to_int()
      let f = @moonrand.randint(rng, 0, 1).to_int() == 1
      let g = @moonrand.randint(rng, 0, 1).to_int() == 1
      ci.push(i)
      cf.push(f)
      cj.push(j)
      cg.push(g)
      sat.add_clause(i, f, j, g)
    }
    // Brute force: is there a mask that makes every clause true?
    let mut reference = false
    for mask in 0..<powers[n] {
      let mut ok = true
      for k in 0..<m {
        let first = bit_at(mask, ci[k], powers) == cf[k]
        let second = bit_at(mask, cj[k], powers) == cg[k]
        if !(first || second) {
          ok = false
        }
      }
      if ok {
        reference = true
      }
    }
    if sat.satisfiable() != reference {
      fail(
        "round " +
        round.to_string() +
        ": satisfiability differs from brute force",
      )
    }
    match sat.answer() {
      Some(answer) =>
        for k in 0..<m {
          let first = answer[ci[k]] == cf[k]
          let second = answer[cj[k]] == cg[k]
          if !(first || second) {
            fail(
              "round " +
              round.to_string() +
              ": the answer breaks clause " +
              k.to_string(),
            )
          }
        }
      None => ()
    }
  }
}

///|
test "a variable and its negation cannot both be required" {
  let sat = TwoSat::new(1)
  sat.add_clause(0, true, 0, true)
  sat.add_clause(0, false, 0, false)
  assert_false(sat.satisfiable())
  match sat.answer() {
    Some(_) => fail("an instance requiring x and not x cannot be satisfied")
    None => ()
  }
}

///|
test "one clause is satisfied by three of the four assignments" {
  let sat = TwoSat::new(1)
  sat.add_clause(0, true, 0, true)
  assert_true(sat.satisfiable())
  match sat.answer() {
    Some(answer) => assert_true(answer[0])
    None => fail("a unit clause always has a solution")
  }
}

///|
test "two clauses force the variables apart" {
  let sat = TwoSat::new(2)
  sat.add_clause(0, true, 1, true)
  sat.add_clause(0, false, 1, false)
  assert_true(sat.satisfiable())
  match sat.answer() {
    Some(answer) =>
      if answer[0] == answer[1] {
        fail("the two variables should differ")
      }
    None => fail("the instance is satisfiable")
  }
}
