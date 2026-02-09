# Open Policy Agent for RI-SCALE

This repo holds the [Open Policy Agent](https://www.openpolicyagent.org/) authorization rules which are applied in the context of the RI-SCALE project.

Any commit to the `OPA/policies` directory will trigger a GitHub workflow which downloads the static policies in ODRL format from the API (https://odrl-repo.dep.dev.rciam.grnet.gr/policies) and builds a bundle of policies and rego files for OPA. Moreover, the same job runs every 12 hours in order to keep the policies updated. The bundle is published on the GitHub registry (`ghcr.io/federicaagostini/opa-dep:latest`), so that RI communities can deploy an OPA service which reads the remote bundle and optionally adds further policies. Access to the bundle is limited to people in the same organization, so you will require a  Personal Access Token or basic authentication with username/password.

Also, here we setup a basic deployment with docker compose to test the workflow. A way to deploy OPA is shown in this README.

## Test

We can use the [docker-compose](./docker-compose.yml) file to test the integration with OPA. It contains 3 services:
- `opa-bundle`: exposes an OPA server which pulls the policies from the private bundle contained in the GitHub registry, reachable at http://opa-bundle.test.example:8182 (within the docker network)
- `opa-local`:  runs the policies locally and a live reload is also applied (useful for development). Within the docker network it is reachable at http://opa-local.test.example:8181
- `client`: client container used to test the OPA integration.

To connect to the bundle hosted on the GitHub private registry please add your GitHub Personal Access Token with at least `read:packages`, `read:project` and `repo` scopes in the [.env](./.env) file.

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

## Deploy

To expose an OPA server which downloads the remote bundle and makes policy decisions we can use docker or the RPM which install the OPA CLI.

### OPA Configuration

A minimal configuration YAML file for OPA would be

```yml
services:
  gh:
    url: https://ghcr.io
    type: oci

bundles:
  dep:
    service: gh
    resource: ghcr.io/federicaagostini/opa-dep:latest

default_decision: dep
```

To connect to the OPA bundle hosted on the GitHub private registry you require authorization, so you can use _Basic_ credentials with

```yml
services:
  gh:
    credentials:
      bearer:
        scheme: "Basic"
        token: "<username>:<password>"
```

or _Bearer_ authentication, after creating your GitHub Personal Access Token (PAT) with at least `read:packages`, `read:project` and `repo` scopes:

```yml
services:
  gh:
    credentials:
      bearer:
        scheme: "Bearer"
        token: "<PAT>"
```

If you require to apply authorization policies also to OPA APIs, please add

```yaml
default_authorization_decision: /system/authz/allow
```

If you want to persist the bundle, add

```yml
bundles:
  dep:
    persist: true

persistence_directory: /directory/for/persistence
```

in case you want to customize the polling period, add

```yml
bundles:
  dep:
    polling:
      min_delay_seconds: 10 # default to 300
      max_delay_seconds: 20 # default to 600
```

If you want to log decision information, including request body, response body (that are also shown with the logging level set to DEBUG) and methrics add

```yml
decision_logs:
  console: true
```

For other configuration parameters see the [OPA documentation](https://www.openpolicyagent.org/docs/configuration).

### Run with Docker

To run opa with docker the minimal arguments required (note that access and error logs are swaped in OPA) are

```bash
docker run -p <server-port>:<server-port> \
  -v <path-to-config-file>:/etc/opa/opa-conf.yaml \
  -v /var/log/opa:/logs \
  openpolicyagent/opa:latest \
  run -s -c /etc/opa/opa-conf.yaml --addr http://localhost:<server-port> \
  > ./logs/error.log \
  2> ./logs/access.log &
```

### Run with RPM

We have made available OPA trough RPM. The RPM just downloads the last OPA cli and installs it in the OS.

Add the CNAF repofile for OPA

```bash
wget -O /etc/yum.repos.d/opa.repo https://repo.cloud.cnaf.infn.it/repository/opa/opa.repo
```

update the available repofiles and install OPA

```bash
dnf makecache
dnf install -y opa
```

Run OPA with the minimum arguments required (note that access and error logs are swaped in OPA)

```bash
opa run -s -c <path-to-config-file> --addr http://localhost:<server-port> \
  > ./logs/error.log \
  2> ./logs/access.log &
```

### Run configurations

The `opa run` command allows you to add several flags, for instance

- `authentication`: set the authentication schema. Possible values are token, tls, off
- `authorization`: set the authorization schema. Possible values are basic, off
- `config-file`: path for the configuration file
- `log-level`: set the log level. Possible values are debug, info, error
- `log-format`: set log format. Possible values are text, json, json-pretty
- `watch`: supports a live reload for the OPA source code (_rego_)
- `set`: requires a key-value string which overrides the configuration

Fore a full list of configuration please check the [documentation](https://www.openpolicyagent.org/docs/cli#run).

#### TLS

In a production environment we strongly recomand to expose OPA with HTTPS.
So, first of all request a certificate for the OPA instance and add the following flags to the `opa run` commands

```bash
--tls-cert-file <path-to-certificate>.pem --tls-private-key-file <path-to-private-key>.pem
```

you should also modify the `addr` flag with something like

```bash
--addr https://0.0.0.0:<server-port>
```

### Start and stop OPA

This repo contains scripts to [start](./scripts/start-opa.sh) (with defaults) and [stop](./scripts/stop-opa.sh) OPA. The scripts can be run by any folder.

The available configuration parameters to start the script are:

* `-c|--config`: path to configuration file (default is _config.yaml_)
* `-p|--port`: OPA server port (default is _8181_)
* `--cert`: path to server certificate (default is _hostcert.pem_)
* `--key`: path to server private key (default is _hostkey.pem_)
* `--log-level`: set the log level (default is _info_)
* `--access-log`: path to access log (default is in _/var/log/opa/access.log_)
* `--error-log`: path to error log (default is in _/var/log/opa/error.log_)

### Wrap-up

Install OPA via RPM

```bash
wget -O /etc/yum.repos.d/opa.repo https://repo.cloud.cnaf.infn.it/repository/opa/opa.repo
dnf makecache
dnf install -y opa
```

Add a comprensive OPA configuration

```yaml
services:
  gh:
    url: https://ghcr.io
    type: oci
    credentials:
      bearer:
        scheme: "Bearer"
        token: "<PAT>"

bundles:
  dep:
    service: gh
    resource: ghcr.io/federicaagostini/opa-dep:latest
    persist: true
    polling:
      min_delay_seconds: 100
      max_delay_seconds: 200

default_decision: dep
default_authorization_decision: /system/authz/allow

persistence_directory: /tmp/opa

decision_logs:
  console: true
```

and run OPA server with

```bash
./scripts/start-opa.sh
```