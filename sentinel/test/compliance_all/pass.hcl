# pass test for compliance_all.sentinel - expects main = true
mock "tfplan/v2" {
  module {
    source = "../../testdata/mock-tfplan-pass.sentinel"
  }
}

mock "tfconfig/v2" {
  module {
    source = "../../testdata/mock-tfconfig-pass.sentinel"
  }
}

test {
  rules = {
    main = true
  }
}
