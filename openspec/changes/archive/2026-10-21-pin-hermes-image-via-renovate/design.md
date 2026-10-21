# Design

## Context

See proposal.md for motivation. The ArgoCD `Application` (`homekube-apps/applications/wave-03-apps/hermes.yaml`) points at this repo's `chart/` at `HEAD` with no Helm values, so the image comes from `chart/values.yaml` (`nousresearch/hermes-agent:latest`, `tailscale/tailscale:latest`). `homekube-apps/renovate.json` runs weekly with the `argocd`, `kubernetes` and `github-actions` managers over `applications/*.yaml`, with `automerge: false`.

Docker Hub (checked 2026-10-21) publishes plain `vX.Y.Z` multi-arch tags alongside `rc.*`, per-arch and `-desktop` variants; `latest` and `stable` currently resolve to `v0.22.2`.

## Goals / Non-Goals

**Goals:**
- The pinned version lives in `homekube-apps`, where Renovate already operates.
- The first pin is a deliberate upgrade: the cluster runs Hermes v0.20.4 and Tailscale 1.104.1 (stale cached `latest`), neither pinnable by tag, so the initial pins are `v0.22.2` and `v1.104.2`.

**Non-Goals:**
- Migrating Hermes' runtime-owned `config.yaml` across versions (Decision 009).
- Managing the hardcoded `nginx:stable` init container, unless moved into values.

## Decisions

**Pin via `helm.valuesObject` in the Application, not in `values.yaml`.** The `homekube-apps` repo owns the Application wiring (cross-repo boundary), and Renovate runs there. Alternative: pin in `chart/values.yaml` and run Renovate on this repo. Rejected: adds a second Renovate config and splits version control across repos.

**Custom regex manager for detection.** The built-in `argocd` manager reads chart and git `targetRevision` and kustomize images; it is not expected to read `valuesObject`. A `customManagers` regex keyed on a marker comment feeds the `docker` datasource. Alternative: `helm.parameters`. Same detection gap. To verify with a Renovate dry run before relying on it; if the built-in manager already detects the pin, drop the regex.

**Restrict updates to plain semver.** `packageRules` with `allowedVersions: "/^v\\d+\\.\\d+\\.\\d+$/"` for `nousresearch/hermes-agent`, excluding `rc.*`, arch and `-desktop` tags. Alternative: `versioning: semver` alone. Rejected as less explicit.

**Tag-only for now; digest pinning deferred.** `pinDigests` guards against repushed tags (the Tailscale `v1.104.1` tag was observed pointing at a different digest than the one a node pulled earlier). A dry run with `pinDigests: true` and a `currentDigest` capture group proposed no digest pin; a custom regex manager likely needs an `autoReplaceStringTemplate` first. Not pursued here; revisit as its own change.

**Remove the floating default.** `chart/values.yaml` `image.tag` becomes required (Helm `required`), so a missing override fails at render time. Alternative: keep `latest` as a fallback. Rejected: it hides a missing override.

## Risks / Trade-offs

- [Renovate may not detect `valuesObject`] → Custom manager plus a local dry run (task 1.3) before merging.
- [Frequent releases mean PR noise] → Weekly schedule stays; optional rule isolating `0.x` minor bumps.
- [The first pin upgrades Hermes two minor versions (0.20.4 to 0.22.2), and a `config.yaml` or PVC schema change may not downgrade cleanly] → rely on the nightly PVC backup (changes since it are lost on restore); verify login and dashboard after.
- [Removing the default breaks renders that lack the override, including `local/docker-compose.yml`] → Land the `homekube-apps` override first and verify the local setup (tasks 2 and 3.2).

## Migration Plan

1. Confirm the latest nightly Longhorn backup of the `hermes-data` PVC completed; no extra backup is taken.
2. Land the `homekube-apps` override and Renovate config (pins `v0.22.2` / `v1.104.2`); the pod restarts onto the new images.
3. Confirm ArgoCD Synced/Healthy, the pod image is `v0.22.2`, and the dashboard and a Dex login work with the runtime-owned `config.yaml` carried over from v0.20.4.
4. Merge the chart change removing the `latest` default and bump the chart version.
5. Rollback: revert the relevant commit; ArgoCD resyncs. If `config.yaml` or PVC state was migrated by v0.22.2, restore the backup from step 1.
