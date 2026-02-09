package dep

import data.dep.match.matched_policies
import data.dep.validation.policy.policy_is_valid
import dep.validation.rule.rule_is_valid

import rego.v1

default allow := false
default allow_and_valid := false

allow if {
    count(matched_policies) > 0
}

allow_and_valid if {
    allow
    some policy in matched_policies
    policy_is_valid(policy)
    rule_is_valid(policy)
}