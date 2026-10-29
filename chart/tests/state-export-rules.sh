#!/bin/bash
# Unit-test the state-export PrometheusRule with promtool. Needs helm, yq, docker.
set -euo pipefail

cd "$(dirname "$0")"
# Under the repo, so Docker Desktop can mount it.
tmp=$(mktemp -d "$PWD/.tmp.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

helm template .. --set image.tag=test --set stateExport.betterleaks.tag=test \
  --set tailscale.tag=test --show-only templates/state-export-monitoring.yaml |
  yq 'select(.kind == "PrometheusRule") | .spec' >"$tmp/state-export-rules.yaml"
cp state-export-rules.test.yaml "$tmp/"

docker run --rm -v "$tmp:/t:ro" -w /t --entrypoint promtool prom/prometheus:v3.5.0 \
  check rules state-export-rules.yaml
docker run --rm -v "$tmp:/t:ro" -w /t --entrypoint promtool prom/prometheus:v3.5.0 \
  test rules state-export-rules.test.yaml
