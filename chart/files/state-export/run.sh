#!/bin/bash
# Never exits: a crashlooping sidecar would make the pod NotReady.
set -uo pipefail

INTERVAL=${STATE_EXPORT_INTERVAL:-3600}
METRICS=${STATE_EXPORT_METRICS:-/work/metrics.prom}
METRICS_PORT=${STATE_EXPORT_METRICS_PORT:-9464}
mkdir -p "$HOME"

# ssh rejects keys readable by others; the secret volume can't be owned by uid 1000.
if [[ -n ${STATE_EXPORT_KEY_SOURCE:-} ]]; then
  install -m 600 "$STATE_EXPORT_KEY_SOURCE" "$STATE_EXPORT_KEY" ||
    echo "could not install deploy key" >&2
fi

rm -f "$METRICS"
python3 -I "$(dirname "$0")/metrics.py" "$METRICS" "$METRICS_PORT" &

last_success=
write_metrics() {
  local now=$1 rc=$2
  {
    if [[ -n $last_success ]]; then
      echo "# HELP hermes_state_export_last_success_timestamp_seconds Time of the last export run that succeeded."
      echo "# TYPE hermes_state_export_last_success_timestamp_seconds gauge"
      echo "hermes_state_export_last_success_timestamp_seconds $last_success"
    fi
    echo "# HELP hermes_state_export_last_run_timestamp_seconds Time of the last export run."
    echo "# TYPE hermes_state_export_last_run_timestamp_seconds gauge"
    echo "hermes_state_export_last_run_timestamp_seconds $now"
    echo "# HELP hermes_state_export_last_run_exit_code Exit code of the last export run: 3 scan finding, 4 scanner error."
    echo "# TYPE hermes_state_export_last_run_exit_code gauge"
    echo "hermes_state_export_last_run_exit_code $rc"
  } >"$METRICS.tmp" && mv -f "$METRICS.tmp" "$METRICS"
}

while true; do
  # A separate process, so set -e inside export.sh isn't suppressed.
  bash "$(dirname "$0")/export.sh"
  rc=$?
  now=$(date +%s)
  if ((rc == 0)); then
    last_success=$now
  else
    echo "$(date -u +%FT%TZ) export failed (exit $rc); retrying in ${INTERVAL}s" >&2
  fi
  write_metrics "$now" "$rc" || echo "could not write metrics" >&2
  sleep "$INTERVAL"
done
