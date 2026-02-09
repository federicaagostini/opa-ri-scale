package dep.match

import data.dep.utils.parsed_policies
import data.dep.utils._rule
import data.dep.match.action_is_matched
import data.dep.match.target_is_matched
import data.dep.match.assegnee_is_matched
import data.dep.match.constraint.constraint_is_matched
import rego.v1

matched_policies contains policy if {
	some policy in parsed_policies
	some rule_type in _rule
	some rule in policy[rule_type]
	action_is_matched(rule)
	target_is_matched(rule)
    assegnee_is_matched(rule)
    constraint_is_matched(rule)
}