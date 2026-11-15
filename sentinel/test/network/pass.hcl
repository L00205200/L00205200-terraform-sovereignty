# pass test for network.sentinel - expects main = true
mock "tfplan/v2" {
  module {
    source = "../../testdata/mock-tfplan-pass.sentinel"
  }
}

test {
  rules = {
    main = true
  }
}
