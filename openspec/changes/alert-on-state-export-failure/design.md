# Design

## Context

See proposal.md for motivation, and `specs/state-export/spec.md` for the requirements.

- `run.sh` loops forever: `bash export.sh || echo "… export failed (exit $?) …"`. The `$(date …)` command in the same `echo` runs before `$?` is expanded and resets it to 0.
- `export.sh` exits 1 for every failure, and logs scan findings and scanner errors separately.
- Prometheus (`kube-prometheus-stack` 90.2.0) uses `podMonitorSelector` and `ruleSelector` `{release: prometheus}`, with empty namespace selectors, so it selects from all namespaces. The `hermes` namespace has no network policies.
- The Alertmanager route sends everything except `severity: info` to Telegram, with `repeat_interval: 12h`.
- The sidecar runs as uid 1000 with a fixed `PATH`. `/usr/bin/python3` (3.13) is available.

## Goals / Non-Goals

**Goals:**
- One alert that catches any cause of a stale export, including the sidecar or its metrics being gone.
- No changes outside this chart.

**Non-Goals:**
- Alerting on single failed runs. Transient GitHub errors resolve themselves within 12 hours.
- Grafana dashboards.
- Alerting on Hermes itself.

## Decisions

**Staleness, not failure counting.** The alert expression is `time() - hermes_state_export_last_success_timestamp_seconds > 43200`, or-ed with `absent(hermes_state_export_last_success_timestamp_seconds)`. It has `for: 15m` on the first part and `for: 12h` on the `absent` part, written as two rules in one group. Staleness covers causes nobody listed in advance. *Alternative:* alert on consecutive failures. Rejected because it misses a sidecar that has stopped running altogether.

**Metrics.** These are gauges in Prometheus text format:
- `hermes_state_export_last_success_timestamp_seconds`: written only after a success, so it is absent until the first one. That makes the never-succeeded case fall into the `absent` rule.
- `hermes_state_export_last_run_timestamp_seconds`
- `hermes_state_export_last_run_exit_code`

`run.sh` writes them to a file on the `/work` `emptyDir` after each run: written to a temp file, then renamed over the old one, so a scrape never sees a half-written file. Alert annotations include the last exit code.

**Distinct exit codes.** `export.sh` exits 3 on a scan finding, 4 on a scanner error and 1 on anything else, whether from `set -e` or an explicit failure. The alert description translates 3 and 4. *Alternative:* a `reason` label. Rejected because it adds a label value per outcome for no gain with one sidecar.

**Metrics server.** A new `metrics.py` (`python3 -I`, standard library `http.server`) serves the metrics file at `/metrics` on port 9464, named `metrics`. Before the first run finishes it serves an empty body. `run.sh` starts it in the background. If it dies, the `absent` rule fires after 12 hours. *Alternative:* the node-exporter textfile collector. Rejected because it needs a hostPath shared with the node. *Alternative:* a Pushgateway. Rejected because none is running in homekube.

**Exposure.** The port is declared on the container only, not on the `hermes` Service, so it is reachable only inside the cluster network and never through the LoadBalancer VIP. The metrics contain only timestamps and an exit code.

**Chart resources.** A new template `state-export-monitoring.yaml` holds the `PodMonitor` (selecting `app.kubernetes.io/name: hermes`, port `metrics`, interval 60s) and the `PrometheusRule` (group `hermes-state-export`, `severity: warning`). Both are labelled `release: prometheus`. They are gated by `stateExport.alerting.enabled`, default `true`, so the chart still renders where the CRDs don't exist. The threshold is `stateExport.alerting.staleAfter: 12h`.

**Exit-code log fix.** `run.sh` captures `rc=$?` straight after `export.sh` returns, and uses `$rc` both in the log line and in the metrics.

## Risks / Trade-offs

- [12 hours is slow for a scan block] → Chosen deliberately. Exports aren't urgent, and Telegram repeats every 12 hours while the alert is active.
- [Pod restarts reset the metrics; the success timestamp is absent until the first run] → The first run starts immediately on container start, and the `absent` rule waits 12 hours.
- [A wrong label or selector means Prometheus never scrapes, and only the `absent` rule would notice, 12 hours later] → Rollout tasks check the target and the rule in Prometheus directly.

## Migration Plan

1. Merge. ArgoCD applies the new resources and rolls the pod.
2. Rollback: revert. The `PodMonitor` and `PrometheusRule` are pruned with it.
