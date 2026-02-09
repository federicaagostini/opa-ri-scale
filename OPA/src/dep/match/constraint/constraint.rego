package dep.match.constraint

import data.dep.match.constraint.acr_is_matched
import data.dep.match.constraint.entitlement_is_matched
import rego.v1

default constraint_is_matched(_) := true

constraint_is_matched(rule) if {
    some constraint in rule.constraint
    true in [
        acr_is_matched(rule),
        entitlement_is_matched(rule)
    ]
}

constraint_is_matched(rule) if {
    not rule.constraint
}