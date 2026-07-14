# Open Policy Agent for RI-SCALE

This repo holds the [Open Policy Agent](https://www.openpolicyagent.org/) authorization rules which are applied in the context of the RI-SCALE project.

Every 12 hours a GitHub workflow downloads the static policies in ODRL format from the API (https://odrl-repo.dep.dev.rciam.grnet.gr/policies (*)) and builds a bundle of policies and rego files for OPA. The bundle is published on the GitHub registry (`ghcr.io/ri-scale/opa-dep:latest`), so that RI communities can deploy an OPA service which reads the remote bundle and optionally adds further policies. Access to the bundle is limited to people in the same organization, so you will require a  Personal Access Token or basic authentication with username/password.

The `doc` folder contains further documentation for this project, in particular:
- [Deploy an OPA server](./doc/deploy.md)
- [Override the OPA policies (for DEP-specific platforms)](./doc/override-policies.md).
- [Develop and test OPA policies](./doc/testing.md)

(*) The ODRL Policy Repository API is specified in https://github.com/RI-SCALE/odrl-policy-repository-api, and a Swagger-based example is available at https://odrl-repo.dep.dev.rciam.grnet.gr/q/swagger-ui/
