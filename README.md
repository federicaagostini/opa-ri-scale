# Open Policy Agent for RI-SCALE

This repo holds the [Open Policy Agent](https://www.openpolicyagent.org/) authorization rules which are applied in the context of the RI-SCALE project.

Any commit to the `OPA/policies` directory will trigger a GitHub workflow which downloads the static policies in ODRL format from the API (https://odrl-repo.dep.dev.rciam.grnet.gr/policies) and builds a bundle of policies and rego files for OPA. The bundle is published on the GitHub registry (`ghcr.io/federicaagostini/opa-dep:latest`), so that RI communities can deploy an OPA service which reads the remote bundle and optionally adds further policies.

Also, here we setup a basic deployment with docker compose to test the workflow. A way to deploy OPA is shown in this README.

## Deploy

## Test

We can use the [docker-compose](./docker-compose.yml) file to test the integration with OPA. It contains 3 services:
- `opa-bundle`: exposes an OPA server which pulls the policies from the bundle contained in the GitHub registry,reachable at http://opa-bundle.test.example:8182 (within the docker network)
- `opa-local`:  runs the policies locally and a live reload is also applied (useful for development). Within the docker network it is reachable at http://opa-local.test.example:8181
- `client`: client container used to test the OPA integration.

For the next tests, run the services and enter in the `client` container:

```bash
docker compose up -d
docker compose exec client bash
```

### Query OPA

In order to query OPA, you need to obtain a bearer token issued by the [IAM DEV](https://iam-dev.cloud.cnaf.infn.it), otherwise you can add the list of trusted issuers to the [data](./OPA/policies/system/authz/data.yaml) file. For instance, with the client credential flows it would be like

```bash
CLIENT_ID=my-client-id
CLIENT_SECRET=my-client-secret
TOKEN_ENDPOINT=token-endpoint
BT=$(curl -s -d "client_id=${CLIENT_ID}" -d "client_secret=${CLIENT_SECRET}" \
      -d "grant_type=client_credentials" "${TOKEN_ENDPOINT}" | jq -r '.access_token')
```

Evaluate both OPAs with an input file already present in the client container as example with

```bash
$ curl http://opa-bundle.test.example:8182/v1/data/dep/allow -d@/opa-examples/input.json -H "Authorization: Bearer $BT" -s | jq
{
  "result": true
}
$ curl http://opa-local.test.example:8181/v1/data/dep/allow -d@/opa-examples/input.json -H "Authorization: Bearer $BT" -s | jq
{
  "result": true
}
```

Now we want to test write operations such to delete the list of allowed token issuers. For this, the access token also has to contain proper groups (which can be added to the [data](./OPA/policies/system/authz/data.yaml) file), so you need to perform an authorization or device code flow. `oidc-agent` is installed in the container if you need it, or you can use the script `/scripts/dc-get-access-token.sh` (requires you have already registered a client on the AAI).

By deleting the list of allowed token issuers from the local OPA, you will no longer be able to access the APIs (the behavior will be back normal when you restart OPA):

```bash
$ curl http://opa-local.test.example:8181/v1/data/system/authz/issuers -H "Authorization: Bearer $BT" -XDELETE -s | jq
$ curl http://opa-local.test.example:8181/v1/data/system/authz -H "Authorization: Bearer $BT" -s | jq
{
  "code": "unauthorized",
  "message": "Unauthorized resource access"
}
```

while if you want to delete it from the bundle, the operation is not allowed by OPA

```bash
$ curl http://opa-bundle.test.example:8182/v1/data/system/authz/issuers -H "Authorization: Bearer $BT
" -X DELETE -s | jq
{
  "code": "invalid_parameter",
  "message": "all paths owned by bundle \"dep\""
}
```

### Download ODRL policies

The list of ODRL policies are exposed by an API and synched in OPA.

To contact the API you need an access token issued by the EGI AAI dev instance, with client credential flow and `policies:read` scope. Then configure the client credentials before to launch the script:

```bash
CLIENT_ID=changeme
CLIENT_SECRET=changeme
```

To check the policies and save them in the `data` file run

```bash
./scripts/get-policies.sh
```