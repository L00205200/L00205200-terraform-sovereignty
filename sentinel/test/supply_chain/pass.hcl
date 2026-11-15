# pass test for supply_chain.sentinel - expects main = true
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
