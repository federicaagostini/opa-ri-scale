package dep.validation.rule

import dep.validation.rule.rule_is_valid
import rego.v1

default prohibition_is_valid(_) := false

prohibition_is_valid(rule) if {
    rule_is_valid(rule)
    rule.target
}