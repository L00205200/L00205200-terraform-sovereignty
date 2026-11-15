# fail test for compliance_all.sentinel - expects main = false
mock "tfplan/v2" {
  module {
    source = "../../testdata/mock-tfplan-fail.sentinel"
  }
}

mock "tfconfig/v2" {
  module {
    source = "../../testdata/mock-tfconfig-fail.sentinel"
  }
}

test {
  rules = {
    main = false
  }
}
