# fail test for network.sentinel - expects main = false
mock "tfplan/v2" {
  module {
    source = "../../testdata/mock-tfplan-fail.sentinel"
  }
}

test {
  rules = {
    main = false
  }
}
