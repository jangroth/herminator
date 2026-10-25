# Tasks

## 1. Credential

- [x] 1.1 Generate an ed25519 key pair in the scratchpad and seal the private key as `STATE_EXPORT_SSH_KEY` for `hermes-secrets` in namespace `hermes`; verify `kubeseal --validate` accepts the sealed value
- [x] 1.2 Add the public key to `jangroth/herminator-state` as a deploy key with write access (manual, or `gh repo deploy-key add --allow-write` with the user's OK); verify `gh api repos/jangroth/herminator-state/keys` lists it with `read_only: false`
- [x] 1.3 Delete the local private key; verify no copy remains in the scratchpad

## 2. Export script

- [x] 2.1 Write the export script in the chart: copy allowlisted paths into the work tree, exclude `*.lock`, export only skills absent from or different to `/opt/hermes/skills`, stage, run betterleaks on the staged changes with validation and revocation off, commit only on diff, push; verify by running it locally against a fixture directory containing a bundled-identical skill, a modified skill, a new skill, a `.env`, a `.lock` file, a symlinked top-level `config.yaml` and a symlink inside `memories/` pointing outside the fixture, and checking the resulting tree contains neither link nor target content
- [x] 2.2 Verify, by running the full run loop rather than the script alone, that no commit is created when a fixture file contains a detectable secret (logged with file and rule but not the value) and when the scanner binary is missing or exits with an error
- [x] 2.3 Verify a second run with no changes creates no commit

## 3. Chart

- [x] 3.1 Add `stateExport` values (allowlist, interval 3600, betterleaks image and `required` tag, resources) and the `STATE_EXPORT_SSH_KEY` entry in `sealedsecret.yaml`; verify `helm template` fails without the betterleaks tag and succeeds with it
- [x] 3.2 Add the betterleaks init container, the `state-export` sidecar (Hermes image, uid 1000, `/opt/data` read-only, key file and `known_hosts` mounted only here, never-exiting loop), and the ConfigMap with the script and GitHub host keys; verify `helm template` shows the key volume mounted only in `state-export` and `helm lint` passes
- [x] 3.3 Find the `betterleaks` binary path in `ghcr.io/betterleaks/betterleaks:v1.9.0` and confirm it runs on arm64 (`docker run --platform linux/arm64 … version`); confirm how validation and revocation are disabled in v1, and verify a scan of a fixture containing a real-format token makes no outbound connections
- [x] 3.4 Bump the chart version and add a `CHANGELOG.md` entry linking this change and issue #9

## 4. homekube-apps

- [x] 4.1 Add `stateExport.betterleaks.tag: v1.9.0` with a `# renovate: datasource=docker depName=ghcr.io/betterleaks/betterleaks` marker to the `hermes` Application, and add `ghcr.io/betterleaks/betterleaks` to the plain-semver package rule; verify a Renovate dry run detects it and does not offer `v2.0.0-rc.*`
- [x] 4.2 Add a homekube `CHANGELOG.md` entry; verify it references the homekube-apps commit

## 5. Rollout and verification

- [ ] 5.1 Merge the homekube-apps change, then the chart change; verify ArgoCD is Synced/Healthy and the pod is Running with all containers ready
- [ ] 5.2 Verify the first export landed in `herminator-state` and contains only allowlisted paths (no `.env`, `auth.json`, `sessions/`, `*.db`, `*.lock`)
- [ ] 5.3 Verify isolation: the Hermes container cannot find the key in its filesystem or environment, `kubectl auth can-i get secret/hermes-secrets` for the service account is `no`, and a write under `/opt/data` from the sidecar fails
- [ ] 5.4 Verify failure handling: point the sidecar at an unreachable remote (or wait for a natural failure), confirm it logs and retries, and that the pod stays Ready

## 6. README

- [x] 6.1 Update `README.md`: Status (deployed; images pinned in `homekube-apps` and bumped by Renovate; state exported to `jangroth/herminator-state`), Layout (`openspec/`, `chart/`, `local/`; `docs/specs/` as legacy), and a pointer to `CLAUDE.md` for the working approach; verify every path and link in it resolves

## Workflow follow-up

- Archive the change once verified; the archive PR closes issue #9.
