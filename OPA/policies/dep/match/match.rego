package dep.match

import data.dep.utils.parsed_policies
import data.dep.utils._property
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
	some prop in _property
	some property in policy[prop]
	input.action == property.action
	input.resource.id == property.target
	some constraint in property.constraint
	some entitlement in input.token.entitlements
	entitlement == constraint.rightOperand
}