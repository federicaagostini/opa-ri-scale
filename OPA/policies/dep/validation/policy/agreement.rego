package dep.validation.policy

import data.dep.validation.policy.policy_class_is_valid
import data.data.dep.utils._property
import rego.v1

default agreement_is_valid(_) := false

agreement_is_valid(policy) if {
    policy_class_is_valid(policy)
    policy.type == "Agreement"
    some prop in _property
    some property in policy[prop]
    property.assegnee
    property.assegner
}