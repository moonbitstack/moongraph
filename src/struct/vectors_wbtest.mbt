///|
test "the graphical and multigraphical tests agree with the reference" {
  for case in @internal.struct_cases() {
    let holds : Bool = if case.kind == "graphical" {
      is_graphical(case.degrees)
    } else {
      is_multigraphical(case.degrees)
    }
    if holds != case.holds {
      fail(case.kind + " reading differs")
    }
  }
}

///|
test "the digraphical test agrees with the reference" {
  for case in @internal.digraphical_cases() {
    if is_digraphical(case.degrees) != case.holds {
      fail("digraphical reading differs")
    }
  }
}
