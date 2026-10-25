#!/bin/bash
# Never exits: a crashlooping sidecar would make the pod NotReady.
set -uo pipefail

INTERVAL=${STATE_EXPORT_INTERVAL:-3600}
mkdir -p "$HOME"

# ssh rejects keys readable by others; the secret volume can't be owned by uid 1000.
if [[ -n ${STATE_EXPORT_KEY_SOURCE:-} ]]; then
  install -m 600 "$STATE_EXPORT_KEY_SOURCE" "$STATE_EXPORT_KEY" ||
    echo "could not install deploy key" >&2
fi

while true; do
  # A separate process, so set -e inside export.sh isn't suppressed by ||.
  bash "$(dirname "$0")/export.sh" || echo "$(date -u +%FT%TZ) export failed (exit $?); retrying in ${INTERVAL}s" >&2
  sleep "$INTERVAL"
done
