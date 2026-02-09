package dep.match

import data.dep.utils.parsed_policies
import data.dep.utils._rule
import rego.v1

matched_policies contains policy if {
	some policy in parsed_policies
	input.action == policy.action
	input.resource.id == policy.target
	some constraint in policy.constraint
	input.token.acr == constraint.acr
	some entitlement in input.token.entitlements
	entitlement == policy.assignee
}

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