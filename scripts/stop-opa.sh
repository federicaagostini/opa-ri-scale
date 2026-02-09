#!/bin/bash
set -euo pipefail


PID_FILE="opa.pid"
LOG_DIR="/var/log/opa"

ACCESS_LOG="$LOG_DIR/access.log"
ERROR_LOG="$LOG_DIR/error.log"

DATE=$(date +"%Y%m%d")

if [[ ! -f "$PID_FILE" ]]; then
  echo "OPA not running (PID file $PID_FILE not found)."
  exit 0
fi

PID=$(cat "$PID_FILE")

if kill -0 "$PID" 2>/dev/null; then
  echo "Stopping OPA (PID $PID)..."
  kill "$PID"

  for i in {1..10}; do
    if ! kill -0 "$PID" 2>/dev/null; then
      break
    fi
    sleep 1
  done

  if kill -0 "$PID" 2>/dev/null; then
    echo "Forcing OPA shutdown..."
    kill -9 "$PID"
  fi
else
  echo "OPA process with PID $PID not found."
fi

rm -f "$PID_FILE"

rotate_log() {
  local file="$1"
 
  if [[ -f "$file" ]]; then
    local filename=$(basename "$file")
    local suffix="${filename%.log}" 
    mv "$file" "$LOG_DIR/${DATE}_${suffix}.log"
    echo "Rotated $file → ${DATE}_${suffix}.log"
  fi
}

rotate_log "$ACCESS_LOG"
rotate_log "$ERROR_LOG"

echo "OPA stopped successfully."
echo ""
