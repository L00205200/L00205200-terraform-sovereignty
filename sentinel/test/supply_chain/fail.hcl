# fail test for supply_chain.sentinel - expects main = false
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
