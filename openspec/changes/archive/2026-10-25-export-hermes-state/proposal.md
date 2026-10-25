# Proposal

Source issue: [#9](https://github.com/jangroth/herminator/issues/9)

## Why

Hermes rewrites its own config, skills, cron jobs and memories at runtime, on the PVC (Decision 009). None of that is visible in git, so there is no way to see how Hermes changes over time or to diff it across upgrades. A read-only export of the readable part of that state to a private repo gives that history without taking control away from Hermes.

## What Changes

- Add a `state-export` sidecar to the hermes pod. It reads `/opt/data` read-only and pushes allowlisted paths to the private repo `jangroth/herminator-state` on a fixed interval.
- Exported: `config.yaml`, `SOUL.md`, `memories/`, `cron/jobs.json`, `scripts/`, the job output directories, and skills that Hermes created or modified. Unchanged bundled skills, secrets, databases, logs and caches are never exported.
- A secret scan runs before every push; any finding blocks that push.
- The push credential is a deploy key for `herminator-state` only, added to the existing `hermes-secrets` SealedSecret and mounted into the sidecar alone.
- Add a pinned `betterleaks` image for the scan, pinned in `homekube-apps` and tracked by Renovate like the other images.

## Capabilities

### New Capabilities
- `state-export`: what part of Hermes' runtime state is published to git, how often, and the guarantees that keep secrets and the credential away from Hermes and out of the repo.

### Modified Capabilities

## Impact

- This repo: `chart/templates/deployment.yaml` (sidecar, init container, volumes), `chart/templates/sealedsecret.yaml` and `chart/values.yaml` (deploy key, allowlist, interval), a new export script in the chart, `CHANGELOG.md`.
- `homekube-apps`: `betterleaks` tag pin under `helm.valuesObject` and its Renovate rule; matching homekube `CHANGELOG.md` entry.
- GitHub: deploy key with write access on `jangroth/herminator-state` (manual step).
- Not a backup: conversation history and secrets are not exported, so the repo cannot restore Hermes. Longhorn remains the backup.
