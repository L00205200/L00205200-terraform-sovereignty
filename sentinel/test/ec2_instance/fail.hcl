# fail test for ec2_instance.sentinel - expects main = false
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
