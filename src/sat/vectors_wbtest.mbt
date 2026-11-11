// The reference solver's reading of each instance, replayed. A two-variable instance can have
// many models, so the test holds the answer to the two things every model agrees on — whether
// one exists, and which variables are true or false in all of them — and to the clauses
// themselves, which every model has to satisfy.

///|
/// Whether an assignment makes the clause true.
fn holds(clause : (Int32, Bool, Int32, Bool), values : Array[Bool]) -> Bool {
  let (i, f, j, g) = clause
  values[i] == f || values[j] == g
}

///|
test "every instance is decided as the reference decides it" {
  for case in @internal.sat_cases() {
    let instance = TwoSat::new(case.variables)
    for clause in case.clauses {
      let (i, f, j, g) = clause
      instance.add_clause(i, f, j, g)
    }
    let answer = instance.answer()
    if instance.satisfiable() != case.satisfiable {
      fail(case.name + ": the instance is decided the other way")
    }
    match answer {
      None =>
        if case.satisfiable {
          fail(case.name + ": no assignment, where the reference found one")
        }
      Some(values) => {
        if !case.satisfiable {
          fail(case.name + ": an assignment, where the reference found none")
        }
        if values.length() != case.variables {
          fail(case.name + ": the assignment is not one value per variable")
        }
        for clause in case.clauses {
          if !holds(clause, values) {
            fail(case.name + ": the assignment leaves a clause false")
          }
        }
        for variable in case.forced_true {
          if !values[variable] {
            fail(
              case.name +
              ": variable " +
              variable.to_string() +
              " is false in every model",
            )
          }
        }
        for variable in case.forced_false {
          if values[variable] {
            fail(
              case.name +
              ": variable " +
              variable.to_string() +
              " is true in every model",
            )
          }
        }
      }
    }
  }
}

///|
test "the answer is the same one twice" {
  for case in @internal.sat_cases() {
    let instance = TwoSat::new(case.variables)
    for clause in case.clauses {
      let (i, f, j, g) = clause
      instance.add_clause(i, f, j, g)
    }
    let first = instance.answer()
    let second = instance.answer()
    if first is Some(one) {
      match second {
        Some(other) =>
          for variable in 0..<case.variables {
            if one[variable] != other[variable] {
              fail(case.name + ": two readings of one instance differ")
            }
          }
        None => fail(case.name + ": the second reading found no assignment")
      }
    } else if second is Some(_) {
      fail(case.name + ": the second reading found an assignment")
    }
  }
}

///|
test "a clause that names one variable twice pins it" {
  // The encoding a caller reaches for when it wants to say "this variable is true": the
  // degenerate clause is the one case where the answer is not a choice.
  let alone = TwoSat::new(1)
  alone.add_clause(0, true, 0, true)
  assert_eq(alone.answer(), Some([true]))
  let forced = TwoSat::new(2)
  forced.add_clause(0, true, 0, true)
  forced.add_clause(0, false, 1, true)
  assert_eq(forced.answer(), Some([true, true]))
  let contradiction = TwoSat::new(1)
  contradiction.add_clause(0, true, 0, true)
  contradiction.add_clause(0, false, 0, false)
  assert_eq(contradiction.answer(), None)
}
