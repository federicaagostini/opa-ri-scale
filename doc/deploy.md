# Deploy and configure an OPA server

To expose an OPA server which downloads the remote bundle and makes policy decisions we can use Docker. Here are shown also other means, such as Ansible or the RPM which both install the OPA CLI. In this documentation we also explain how to further customize the OPA service configuration.

## Deployment

### Docker container

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

The `run` command of the OPA CLI may accept further options; please check the [OPA run CLI options](#opa-run-cli-options) section.
Also, in order to polulate your configuration file please refer to the [Configuration](#configuration) section. 

### Ansible

In order to configure and start OPA with Ansible you require that the Ansible command line is installed in the machine where OPA runs.

Install Ansible with

```bash
dnf install ansible -y
```

Clone this repo and add the required Personal Access Token (with at least the `read:packages` and `read:project` scopes) to download the OPA bundle from GitHub

```bash
git clone https://github.com/RI-SCALE/opa-ri-scale.git
echo "opa_pat: \"ghp_xxxx\"" > ansible/vars/secrets.yml
```

Run the Ansible playbook (from any user able to be root) with

```bash
ansible-playbook -i ansible/inventory ansible/site.yml
```

OPA is embedded as systemd unit; verify that it has started successfully

```bash
$ systemctl status opa
● opa.service - Open Policy Agent
     Loaded: loaded (/etc/systemd/system/opa.service; enabled; preset: disabled)
     Active: active (running) since Tue 2026-02-24 19:25:26 CET; 8min ago
   Main PID: 623530 (opa)
      Tasks: 9 (limit: 48652)
     Memory: 14.3M (peak: 16.7M)
        CPU: 380ms
     CGroup: /system.slice/opa.service
             └─623530 /usr/bin/opa run -s -c /etc/opa/config.yaml --addr https://0.0.0.0:8181 --authentication=token --authorization=basic --tls-cert-file /etc/opa/hostcert.pem --tls-private-key-file /etc/opa/hostkey.pem --log-level info --log-format json-pretty

Feb 24 19:25:26 tape-dev.cloudcnaf systemd[1]: Started Open Policy Agent.
```

In case you want to modify some flag passed to the `opa run` command please edit the `/etc/sysconfig/opa` file.

Ansible creates a self-signed certificate for OPA: in a production environment you should sobstitute the certificate
(`/etc/opa/hostcert.pem`) and key (`/etc/opa/hostkey.pem`) files.


### RPM

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

The `opa run` command may accept further options; please check the [OPA run CLI options](#opa-run-cli-options) section.
Also, in order to polulate your configuration file please refer to the [Configuration](#configuration) section. 

#### Start and stop OPA

This repo contains scripts to [start](./scripts/start-opa.sh) (with defaults) and [stop](./scripts/stop-opa.sh) OPA. The scripts can be run by any folder.

The available configuration parameters to start the script are:

* `-c|--config`: path to configuration file (default is _config.yaml_)
* `-p|--port`: OPA server port (default is _8181_)
* `--cert`: path to server certificate (default is _hostcert.pem_)
* `--key`: path to server private key (default is _hostkey.pem_)
* `--log-level`: set the log level (default is _info_)
* `--access-log`: path to access log (default is in _/var/log/opa/access.log_)
* `--error-log`: path to error log (default is in _/var/log/opa/error.log_)

To and stop OPA, add the folder to the PATH variable and type

```bash
PATH=$PATH:<path-to-scripts>
start-opa.sh
stop-opa.sh
```

### OPA run CLI options

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

## Configuration

A minimal configuration YAML file for OPA would be

```yml
services:
  gh:
    url: https://ghcr.io
    type: oci

bundles:
  dep:
    service: gh
    resource: ghcr.io/ri-scale/opa-dep:latest

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

or _Bearer_ authentication, after creating your GitHub Personal Access Token (PAT) with at least `read:packages` and `read:project` scopes:

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

A comprensive OPA configuration file would be

```yml
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
    resource: ghcr.io/ri-scale/opa-dep:latest
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

For other configuration parameters see the [OPA documentation](https://www.openpolicyagent.org/docs/configuration).



