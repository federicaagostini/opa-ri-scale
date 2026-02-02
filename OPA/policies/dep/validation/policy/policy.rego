package dep.validation.policy

import data.dep.validation.policy.set.set_is_valid
import data.dep.validation.policy.offer.offer_is_valid
import data.dep.validation.policy.agreement.agreement_is_valid
import data.dep.utils.property._property
import rego.v1

default policy_class_is_valid(_) := false
default policy_is_valid(_) := false

policy_class_is_valid(policy) if {
    policy.uid
    policy.type
    some prop in _property
    policy[prop]
}

policy_is_valid(policy) if true in [
    set_is_valid(policy),
    offer_is_valid(policy),
    agreement_is_valid(policy)
]