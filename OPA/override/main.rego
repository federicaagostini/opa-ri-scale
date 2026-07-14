package override

import rego.v1

default allow := false

allow if {
    some policy in data.dep.policies
    policy.type == "Set"
}
