# Override the OPA policies

This repo contains a [docker-compose](../docker-compose.yml) file with the `opa-override` service which showcase how to override the OPA policies (as shown in the [Develop and test OPA policies](./testing) documentation) -- useful for DEP-specific platforms.

Basically, the OPA service can load more bundles, so one should be the general one from this repo, and another one can be dedicated to the overriding policies.

To know more about multiple bundles, please check the [OPA documentation](https://www.openpolicyagent.org/docs/management-bundles).

## Configuration

An example of the OPA configuration could be


```
services:
  gh:
    url: https://ghcr.io
    type: oci
    credentials:
      bearer:
        scheme: "Bearer"
        token: ${GHCR_TOKEN}
  local:
    url: file://

bundles:
  dep:
    service: gh
    resource: ghcr.io/ri-scale/opa-dep:allow-overriding-policies
    polling:
      min_delay_seconds: 10
      max_delay_seconds: 20
  override:
    service: local
    resource: file:////etc/opa/override.tar.gz

default_decision: dep
default_authorization_decision: /system/authz/allow
```

where the `local` service can be a bundle located in `/etc/opa/override.tar.gz` (its source code lays in the [override](../OPA/override) folder). For a community platform, you can also publish your bundle on the GitHub registry as we do here: in this case you can take inspiration from the GitHub Workflow file (i.e. `.github/workflows/publish-bundle.yml`).

## Build local bundle

In case you use your local bundle, download the OPA command line first (please check the [documentation](https://www.openpolicyagent.org/docs#1-download-opa))

```bash
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
chmod +x opa
```
and build the bundle as follows:

```bash
./opa build -b OPA/override --output override.tar.gz
```

## Implementation

OPA can merge different packages under the same `data` namespace if loading different bundles in one running server, i.e. if the service is configured as the above section. In this way, the external library can read the common OPA data (which is policies, rules, whathever) and add a custom logic.

### No modification to the common module

_No modification to the common module_ (this repo) means that the DEP-platform should enforce policy decisions to their own custom `/v1/data/override/allow` endpoint instead of the commont `/v1/data/dep/allow` one.

In this case, we can just add a new package which overrides the default behavior, such as

```rego
package override

import rego.v1

default allow := false

allow if {
    some policy in data.dep.policies
    policy.type == "Set"
}
```

### Modifying the common module

Here the developers of this repo have more power about how the authorization is enforced, i.e. we should enable to extend some specific package. This means that if we want to allow to override for instance the `data.dep.allow` object (which is the core) we need to modify our _main_ class as follows

```rego
package dep

import data.dep.match.matched_policies
import data.dep.validation.policy.policy_is_valid
import data.dep.validation.rule.rule_is_valid

import rego.v1

default allow := false

allow if data.override.allow

allow if {
    not data.override.allow
    some policy in matched_policies
    policy_is_valid(policy)
    rule_is_valid(policy)
}
```

In this way, the repo logic is applied only if the `override` package is not loaded and the platforms can still query the `/v1/data/dep/allow` endpoint. This example is the one reported in the docker-compose file, even if it is more realistic to just allow adding a _data_ file.

## Test

Let's test that the multiple bundle is loaded with the docker-compose in this repo.

Start the compose file from the root

```bash
docker compose up -d
docker compose exec client bash
```

Please ask for an access token from the [RI-SCALE INDIGO IAM](https://iam-riscale.cloud.cnaf.infn.it) instance and add it to the `BT` shall variable

```
BT=eyJraWQiOiJyc2ExIiwiYWxnIjoiUlMyNTYifQ.eyJzdWIiOiI3Yzc3MDcwMS1mYjU5LTQ0NmEtYjQxNC1hMjI2Zjk1ODY5MjciLCJzY29wZSI6Im9wZW5pZCBwcm9maWxlIiwiaXNzIjoiaHR0cHM6Ly9pYW0tcmlzY2FsZS5jbG91ZC5jbmFmLmluZm4uaXQvIiwiZXhwIjoxNzgxNjQ1MTYzLCJpYXQiOjE3ODE2NDE1NjMsImp0aSI6ImMxOTU0ZjQyLWNiMDUtNGJjYS1iMWM0LWRhZWM1ZWY3YjZkMiIsImNsaWVudF9pZCI6ImQ4NThhMzMwLTA0MmEtNGFiYy1hZTYyLWVjMTU0ZWU0ZWNhNyJ9...
```

The default behavior is that given the example input the user is not allowed to perform an operation

```bash
$ curl http://opa-bundle:8182/v1/data/dep/allow_and_valid -H "Authorization: Bearer $BT" -s | jq
{
  "result": false
}
```

but the override bundle sets an allow policy:

```bash
$ curl http://opa-override:8183/v1/data/dep/allow_and_valid -H "Authorization: Bearer $BT" -s | jq
{
  "result": true
}
```