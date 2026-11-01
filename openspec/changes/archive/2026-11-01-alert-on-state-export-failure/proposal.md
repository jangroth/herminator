# Proposal

Source issue: [#13](https://github.com/jangroth/herminator/issues/13)

## Why

A state export that keeps failing goes unnoticed. The causes include a secret-scan finding, a scanner error, a rejected push, a revoked deploy key and GitHub being down. The sidecar logs and retries, and the pod stays Ready by design, so the only symptom is that `herminator-state` stops updating. Homekube already routes Alertmanager alerts to Telegram, so a stale export can use the same path.

## What Changes

- The sidecar exposes Prometheus metrics: the time of the last successful run, and the time and outcome of the last run. A successful run is one that pushed, or found nothing to push.
- `export.sh` exits with distinct codes for a scan finding, a scanner error and any other failure, so the outcome metric says why a run failed.
- The chart adds a `PodMonitor` and a `PrometheusRule`. The alert fires when no export has succeeded for 12 hours, including when the metrics disappear, and goes to the existing Telegram route.
- Fix: the failure log line reports `exit 0` instead of the real exit code.

## Capabilities

### New Capabilities

### Modified Capabilities
- `state-export`: a persistent export failure raises an alert, and failure logs carry the real exit code.

## Impact

- `chart/files/state-export/run.sh` and `export.sh`, and a new `metrics.py`.
- `chart/templates/deployment.yaml` (metrics port) and a new `chart/templates/state-export-monitoring.yaml` (`PodMonitor`, `PrometheusRule`).
- `chart/values.yaml` (alert threshold, metrics port), `chart/Chart.yaml` version, `CHANGELOG.md`.
- No `homekube-apps` change. Prometheus already selects `PodMonitor`s and `PrometheusRule`s labelled `release: prometheus` in every namespace, and every alert that isn't `severity: info` already goes to Telegram.
