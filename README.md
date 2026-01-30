# Open Policy Agent for RI-SCALE

This repo holds the [Open Policy Agent](https://www.openpolicyagent.org/) authorization rules which are applied in the context of the RI-SCALE project.

Any commit to the `OPA/policies` directory will trigger a GitHub workflow which downloads the static policies in ODRL format from the API (https://odrl-repo.dep.dev.rciam.grnet.gr/policies) and builds a bundle of policies and rego files for OPA. The bundle is published on the GitHub registry (`ghcr.io/federicaagostini/opa-dep:latest`), so that RI communities can deploy an OPA service which reads the remote bundle and optionally adds further policies.

Also, here we setup a basic deployment with docker compose to test the workflow. A way to deploy OPA is shown in this README.
