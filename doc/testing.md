# Develop and test OPA policies

This repo holds the [Open Policy Agent](https://www.openpolicyagent.org/) authorization rules which are applied in the context of the RI-SCALE project.

Any commit to the `OPA/src` directory will trigger a GitHub workflow which downloads the static policies in ODRL format from the API (https://odrl-repo.dep.dev.rciam.grnet.gr/policies (*)) and builds a bundle of policies and rego files for OPA. The bundle is published on the GitHub registry (`ghcr.io/ri-scale/opa-dep:latest`) and its access is limited to people in the same organization.

## Set the environment 

### docker compose

A [docker-compose](../docker-compose.yml) file is provided both for developing OPA policies and testing the integration with OPA.

The compose file contains 4 services:
- `opa-local`:  runs the policies locally and a live reload is also applied (useful for **development**). Within the docker network it is reachable at http://opa-local.test.example:8181
- `opa-bundle`: exposes an OPA server which pulls the policies from the private bundle contained in the GitHub registry, reachable at http://opa-bundle.test.example:8182 (within the docker network)
- `opa-override`: it loads the bundle contained in the GitHub registry plus a local bundle of the `OPA/override` folder, used as example for DEP-platforms willing to override policies. It is reachable at http://opa-override.test.example:8183 (within the docker network)
- `client`: client container used to test the OPA integration.

### Secrets

The access to the bundle hosted on the GitHub private registry is limited to people in the same organization, so you need to creat a GitHub Personal Access Token with at least `read:packages` and `read:project` scopes and add it either to
- the environment variable `GHCR_TOKEN`, or
- add it in the [.env](../.env) file.

### Build bundle

Before to run the compose, you need to build an example overriding policy bundle.

Download the OPA command line with (please check the [documentation](https://www.openpolicyagent.org/docs#1-download-opa))

```bash
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
chmod +x opa
```
and build the bundle as follows:

```bash
./opa build -b OPA/override --output override.tar.gz
```

It is gitignored so you will not need to commit anything. In case you are a DEP-platfromt, you can use this example bundle
to create your own policies, or override and test them with the `opa-override` container. In case, follow the [Override OPA policies](./override-policies.md) procedure.

### (Optional) Download ODRL policies

The list of ODRL policies are exposed by an API and synched in OPA through the GitHub Workflow, so they are already exposed in the bundle. In case you want to download them by yourself, you need an access token issued by the EGI AAI dev instance, with client credentials flow and `policies:read` scope. Then configure the client credentials before to launch the script:

```bash
CLIENT_ID=changeme
CLIENT_SECRET=changeme
```

To check the policies and save them in the `data` file run

```bash
./scripts/get-policies.sh
```

## Test

For the next tests, run the services and enter in the `client` container:

```bash
docker compose up -d
docker compose exec client bash
```

### Query OPA

In order to query OPA, you need to obtain a bearer token issued by the [iam-riscale](https://iam-riscale.cloud.cnaf.infn.it/), otherwise you can add the list of trusted issuers to the [data](../OPA/src/system/authz/data.yaml) file. For instance, with the client credential flows it would be like

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

Now we want to test write operations such to delete the list of allowed token issuers. For this, the access token also has to contain proper groups (which can be added to the [data](../OPA/src/system/authz/data.yaml) file), so you need to perform an authorization or device code flow. `oidc-agent` is installed in the container if you need it, or you can use the script `/scripts/dc-get-access-token.sh` (requires you have already registered a client on the AAI).

By deleting the list of allowed token issuers from the local OPA, you will no longer be able to access the APIs (the behavior will be back normal when you restart OPA):

```bash
$ curl http://opa-local.test.example:8181/v1/data/system/authz/tokens -H "Authorization: Bearer $BT" -XDELETE -s | jq
$ curl http://opa-local.test.example:8181/v1/data/system/authz -H "Authorization: Bearer $BT" -s | jq
{
  "code": "unauthorized",
  "message": "Unauthorized resource access"
}
```

while if you want to delete it from the bundle, the operation is not allowed by OPA

```bash
$ curl http://opa-bundle.test.example:8182/v1/data/system/authz/tokens -H "Authorization: Bearer $BT
" -X DELETE -s | jq
{
  "code": "invalid_parameter",
  "message": "all paths owned by bundle \"dep\""
}
```


(*) The ODRL Policy Repository API is specified in https://github.com/RI-SCALE/odrl-policy-repository-api, and a Swagger-based example is available at https://odrl-repo.dep.dev.rciam.grnet.gr/q/swagger-ui/
