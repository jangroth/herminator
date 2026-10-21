# Tasks

## 1. Pin and detect in homekube-apps

- [x] 1.1 Add `helm.valuesObject` to `applications/wave-03-apps/hermes.yaml` pinning `image.tag: v0.22.2` and `tailscale.tag: v1.104.2`, each with a marker comment; verify `helm template` of the chart with those values renders the pinned images
- [x] 1.2 Add a `customManagers` regex entry and a `packageRules` entry (`allowedVersions` plain semver) to `renovate.json`; verify the file validates with `renovate-config-validator`
- [x] 1.3 Run a Renovate local dry run; verify it detects both pins and proposes no `rc.*`, `-arm64`, `-amd64` or `-desktop` tags (if the built-in `argocd` manager already detects them, drop the regex entry)
- [x] 1.4 Decide on `pinDigests` from the dry run output and record the outcome in design.md

## 2. Roll out the pin

- [x] 2.1 Verify the latest scheduled `hermes-daily-backup` of the `hermes-data` PVC is Completed in Longhorn and taken after the last config change
- [x] 2.2 Merge the homekube-apps change; verify ArgoCD shows `hermes` Synced/Healthy and the pod restarted onto the new images
- [x] 2.3 Verify the pod runs Hermes `v0.22.2` and Tailscale `1.104.2` (`hermes --version`, `tailscale version`), the dashboard loads and a Dex login succeeds

## 3. Remove the floating default in this repo

- [x] 3.1 Make `image.tag` and `tailscale.tag` required in `chart/values.yaml` and `deployment.yaml`, and drop `appVersion` from `Chart.yaml`; verify `helm template` without overrides fails and with overrides succeeds
- [ ] 3.2 Pin the image in `local/docker-compose.yml`; verify the local stack starts
- [ ] 3.3 Bump chart version to 0.1.10 and verify ArgoCD syncs clean with no pod change (the images were already pinned in 2.2)

## 4. Record

- [x] 4.1 Add Decision 012 to `DECISIONS.md` and an entry to `CHANGELOG.md`; verify both link to this change
- [ ] 4.2 Add matching entries to homekube's `DECISIONS.md` and `CHANGELOG.md`; verify they reference the herminator decision

## Workflow follow-up

- Archive the change after the rollout is verified.
