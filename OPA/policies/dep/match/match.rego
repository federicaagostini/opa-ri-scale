package dep.match

import data.dep.utils.parsed_policies
import data.dep.utils._rule
import rego.v1

# Policy parsed as from local data
matched_policies contains policy if {
	some policy in parsed_policies
	some rule_type in _rule
	some rule in policy[rule_type]
	input.action == rule.action
	input.resource.id == rule.target
    some entitlement in input.token.entitlements
	entitlement == rule.assignee
    some constraint in rule.constraint
	input.token.acr == constraint.rightOperand
}

# Policy parsed as from API
matched_policies contains policy if {
	some policy in parsed_policies
	some rule_type in _rule
	some rule in policy[rule_type]
	input.action == rule.action
	input.resource.id == rule.target
	some constraint in rule.constraint
	some entitlement in input.token.entitlements
	entitlement == constraint.rightOperand
}