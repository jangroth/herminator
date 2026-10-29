# Tasks

## 1. Run outcome and metrics

- [x] 1.1 Make `export.sh` exit 3 on scan findings and 4 on scanner errors, and fix `run.sh` to capture `rc=$?` before logging. Verify in the Hermes image with the fixture harness that the loop logs `exit 3` for a planted secret, `exit 4` for a missing scanner and `exit 1` for an unreachable remote.
- [x] 1.2 After each run, have `run.sh` write the three gauges to a temp file on `/work` and rename it into place, with the success timestamp only after a success. Verify the file contents with the fixture after a success, a failure, and a success that follows a failure.
- [x] 1.3 Write `chart/files/state-export/metrics.py` serving the file at `/metrics` on port 9464, with an empty body before the first run. Start it from `run.sh`. Verify with `curl` inside the image (as uid 1000, `--network none`) that the output parses as Prometheus text format.

## 2. Chart

- [x] 2.1 Add the `metrics` container port to `state-export`, add `metrics.py` to the `hermes-state-export` ConfigMap, and add `stateExport.alerting` values (`enabled: true`, `staleAfterHours: 12`). Verify with `helm template` that the `hermes` Service still exposes only its existing ports.
- [x] 2.2 Add `state-export-monitoring.yaml` with the `PodMonitor` and the `PrometheusRule` (two rules: `HermesStateExportStale` and `HermesStateExportMissing` on `absent`; `severity: warning`; `release: prometheus` labels; description translating exit codes 3 and 4). Verify that `helm template` renders both with `enabled: true` and neither with `false`, and that `helm lint` passes.
- [x] 2.3 Bump the chart version and add a `CHANGELOG.md` entry linking this change and issue #13. Verify `openspec validate alert-on-state-export-failure --strict` passes.

## 3. Rollout

- [ ] 3.1 After merge, verify ArgoCD is Synced/Healthy, the pod is ready, and Prometheus lists the `state-export` target as up (Prometheus API through `kubectl port-forward`).
- [ ] 3.2 Verify the `hermes-state-export` rule group is loaded and inactive. Run each alert expression through the Prometheus API with a 60-second threshold in place of 12 hours, and confirm it returns a series only when the threshold is exceeded.
- [ ] 3.3 Verify end to end with a test copy of the stale rule, applied by hand in the `hermes` namespace with its own alert name, a 2-minute threshold and no `for`. The last success is normally up to an hour old, so it fires without breaking anything. Confirm the alert reaches Telegram, then delete the test rule and confirm the alert resolves.

## Workflow follow-up

- Archive the change once verified. The archive PR closes issue #13.
