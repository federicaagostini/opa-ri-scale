#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(dirname "$(realpath "$0")")

CONFIG_FILE="config.yaml"
PORT="8181"
CERT_FILE="hostcert.pem"
KEY_FILE="hostkey.pem"
LOG_LEVEL="info"
ACCESS_LOG="/var/log/opa/access.log"
ERROR_LOG="/var/log/opa/error.log"
PID_FILE="${SCRIPT_DIR}/opa.pid"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--config) CONFIG_FILE="$2"; shift 2 ;;
    -p|--port) PORT="$2"; shift 2 ;;
    --cert) CERT_FILE="$2"; shift 2 ;;
    --key) KEY_FILE="$2"; shift 2 ;;
    --log-level) LOG_LEVEL="$2"; shift 2 ;;
    --access-log) ACCESS_LOG="$2"; shift 2 ;;
    --error-log) ERROR_LOG="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo ""
      echo "Options:"
      echo "  -c|--config       Config file (default: $CONFIG_FILE)"
      echo "  -p|--port         Server port (default: $PORT)"
      echo "  --cert            TLS certificate path (default: $CERT_FILE)"
      echo "  --key             TLS private key path (default: $KEY_FILE)"
      echo "  --log-level       Log level (default: $LOG_LEVEL)"
      echo "  --access-log      Path to access log (default: $ACCESS_LOG)"
      echo "  --error-log       Path to error log (default: $ERROR_LOG)"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

mkdir -p "$(dirname "$ACCESS_LOG")"
mkdir -p "$(dirname "$ERROR_LOG")"

echo "Starting OPA with:"
echo "  config:      $CONFIG_FILE"
echo "  port:        $PORT"
echo "  cert:        $CERT_FILE"
echo "  key:         $KEY_FILE"
echo "  log-level:   $LOG_LEVEL"
echo "  access-log:  $ACCESS_LOG"
echo "  error-log:   $ERROR_LOG"

opa run -s -c "$CONFIG_FILE" \
  --addr "https://0.0.0.0:$PORT" \
  --authentication=token \
  --authorization=basic \
  --tls-cert-file "$CERT_FILE" \
  --tls-private-key-file "$KEY_FILE" \
  --log-level "$LOG_LEVEL" \
  --log-format text \
  > "$ACCESS_LOG" 2> "$ERROR_LOG" &
  echo $! > "$PID_FILE"

echo "OPA started (PID $(cat $PID_FILE))"