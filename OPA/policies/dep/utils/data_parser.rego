package dep.utils.data_parser

import rego.v1

parsed_policies contains policy if {
    some policy in data.dep.odrl.policies
}

parsed_policies contains policy if {
    some policy in data.dep.policies
}