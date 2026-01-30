#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")

source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/secrets.sh"

BT=$(curl -s -d "client_id=${CLIENT_ID}" -d "client_secret=${CLIENT_SECRET}" \
      -d "grant_type=client_credentials" -d "scope=policies:read policies:write" \
      "${TOKEN_ENDPOINT}" | jq -r '.access_token')

REPO_ROOT=$(realpath "${SCRIPT_DIR}/..")
OUT_FILE_PATH="${REPO_ROOT}/OPA/policies/dep/${OUT_FILE_NAME}"

curl "${ODRL_API_ENDPOINT}" -L -f -s \
  -H "Authorization: Bearer $BT" | jq \
    > "${OUT_FILE_PATH}"

echo "Policies successfully downloaded in ${OUT_FILE_PATH}"