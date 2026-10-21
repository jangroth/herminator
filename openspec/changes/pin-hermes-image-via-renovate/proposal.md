# Proposal

## Why

The Hermes image is `nousresearch/hermes-agent:latest` with `pullPolicy: IfNotPresent`. The running version depends on whichever image a node last cached, bumping the chart never changes it, and there is no record or rollback point. Hermes now holds credentials and will run unattended agent work, so the running version must be known and upgrades must be deliberate.

## What Changes

- Pin the Hermes image (tag, plus digest if Renovate handles it cleanly) in the `homekube-apps` ArgoCD `Application` via Helm `valuesObject`, not in this chart.
- Extend `homekube-apps/renovate.json` so Renovate opens a PR for each new stable Hermes release (plain `vX.Y.Z` tags only; no `rc.*`, `-amd64`, `-arm64` or `-desktop`).
- Remove the floating `latest` default from `chart/values.yaml` and `Chart.yaml` `appVersion` so a missing override fails visibly.
- Pin the Tailscale sidecar image through the same mechanism.
- **BREAKING** (deploy-time only): rendering the chart without an image override no longer yields a working default; the `homekube-apps` override must land first.

## Capabilities

### New Capabilities
- `image-version-pinning`: deployed container images are pinned to explicit versions, and version changes arrive only as reviewed PRs.

### Modified Capabilities

## Impact

- This repo: `chart/values.yaml`, `chart/Chart.yaml`, chart version bump, `local/docker-compose.yml` image reference, `DECISIONS.md`, `CHANGELOG.md`.
- `homekube-apps` (separate repo): `applications/wave-03-apps/hermes.yaml`, `renovate.json`; matching entries in homekube's `DECISIONS.md` and `CHANGELOG.md`.
- Out of scope: migrating Hermes' runtime-owned `config.yaml` across versions (Decision 009), and the hardcoded `nginx:stable` init container unless it is moved into values.
