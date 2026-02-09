package system.authz

import rego.v1

import data.system.authz.issuers as issuers
import data.system.authz.groups as groups

default allow := {
	"allowed": false,
	"reason": "Unauthorized resource access",
}

allow := {"allowed": true} if {
	_payload(input.identity).iss in issuers
	input.method in _query_methods
}

allow := {"allowed": true} if {
	_payload(input.identity).iss in issuers
	some group in _payload(input.identity)["wlcg.groups"]
	group in groups
	input.method in _update_methods
}

allow := {"allowed": true} if {
	_payload(input.identity).iss in issuers
	some group in _payload(input.identity).entitlements
	group in groups
	input.method in _update_methods
}

allow := {"allowed": false, "reason": reason} if {
	not input.identity
	reason := "Missing bearer token"
}

