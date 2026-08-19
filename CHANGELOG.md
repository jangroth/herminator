# Changelog

All notable changes to the herminator project.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Entries are reverse-chronological; each dated section groups changes by type:

- **Added** — new components, files, or capabilities
- **Changed** — modifications to existing config, versions, or behaviour
- **Removed** — deletions and decommissioning
- **Fixed** — bug fixes
- **Operational** — manual interventions, recoveries, one-off ops actions
- **Decisions** — links to `DECISIONS.md` entries created on this day

## 2026-08-19

### Fixed

- `chart/templates/deployment.yaml`: hermes container used `command: ["gateway", "run"]`, which replaces the image's ENTRYPOINT and crashlooped with `exec: "gateway": executable file not found in $PATH`. Changed to `args:`, keeping the image's own entrypoint dispatcher intact. Bumps chart to 0.1.1.
- `chart/templates/configmap.yaml`: nginx forwarded the external Host header (`192.168.86.246`) straight through to the loopback-bound dashboard, which rejected it with "Invalid Host header" — the dashboard's DNS-rebinding guard requires Host to match `HERMES_DASHBOARD_HOST`/`PORT` (`127.0.0.1:9119`). Pinned `proxy_set_header Host 127.0.0.1:9119;`, moved the original host to `X-Forwarded-Host`. Bumps chart to 0.1.2.
- `chart/values.yaml`: tailscale sidecar crashlooped with `invalid key: API key does not exist` — the sealed `TS_AUTHKEY` didn't match any key in the tailnet's admin console. Resealed the correct key. Bumps chart to 0.1.3.

## 2026-08-18

### Added

- Generated `API_SERVER_KEY` (real value, `openssl rand -base64 32`) and sealed it into `chart/templates/sealedsecret.yaml` via `kubeseal --raw`, namespace `hermes`, name `hermes-secrets` — replaces `values.yaml`'s empty `sealedSecret.encryptedApiServerKey` placeholder.

### Operational

- Minted a reusable, tagged (`tag:hermes`), non-ephemeral Tailscale auth key for the hermes sidecar via the Tailscale admin console. Sealed the same way as `API_SERVER_KEY` (`sealedSecret.encryptedTsAuthKey`); plaintext never touched disk or was committed. Chart re-linted clean with both ciphertexts in place. Spec 001 rollout step 5 done — next is pushing this repo (step 6) before touching `homekube-apps`.

## 2026-08-17

### Added

- `chart/` — Helm chart implementing Spec 001: `Chart.yaml`, `values.yaml`, and templates for the PVC, ConfigMap (hermes `config.yaml`, `homekube-ca.crt`, nginx config), SealedSecret shape, ServiceAccount/Role/RoleBinding + pre-created tailscale state Secret, cert-manager `Certificate`, three-container `Deployment` (hermes/nginx/tailscale), and split LoadBalancer (443) / ClusterIP (8642) Services. Validated with `helm lint` and `helm template` + `kubectl apply --dry-run=client` against the live cluster's API schema — no live resources created.

### Fixed

- Spec 001's Constraint C (how hermes trusts `homekube-ca`) resolved as "mount the CA cert + CA-bundle env vars" — see [DECISIONS.md #008](DECISIONS.md#008).
- Spec 001's assumption of a shared Dex client secret (Decision 2, `templates/secret.yaml`) was wrong: hermes's self-hosted OIDC is a public PKCE client with no client secret. Removed the plain-Secret template; see [DECISIONS.md #002 amendment](DECISIONS.md#002--dex-client-secret-is-a-plain-shared-string-not-sealed-2026-08-14).
- `templates/service.yaml`'s single-Service design (from the spec's Approach table) couldn't actually keep the gateway internal-only — a `LoadBalancer`-type Service exposes every port it lists on the external VIP. Split into two Services: `hermes` (LoadBalancer, 443 only) and `hermes-gateway` (ClusterIP, 8642).
- Tailscale sidecar's state-persistence env var corrected from the spec's `TS_STATE=kube:<secret-name>` to the actually-documented `TS_KUBE_SECRET=<secret-name>` (confirmed against Tailscale's own Docker parameter reference).

### Decisions

- [008](DECISIONS.md#008) hermes trusts `homekube-ca` via a mounted CA cert + CA-bundle env vars.

## 2026-08-16

### Changed

- `docs/specs/001-deploy-hermes-to-homekube.md` — review pass against the live cluster. Added a "Verified against the live cluster" table (VIP availability, Dex issuer/TLS, CoreDNS behaviour, sealed-secrets location, StorageClass reclaim policy, upstream issue #42780 confirmed real but closed) and a "Constraints discovered in review" section covering three implementation blockers.
- Spec scope additions: `hostAliases` for Aperture name resolution, `TS_EXTRA_ARGS=--shields-up` and loopback-bound dashboard, `strategy: Recreate` with `replicas: 1`, PVC retention annotations (`helm.sh/resource-policy: keep` + `Prune=false`), a real generated `API_SERVER_KEY`, and `ignoreDifferences` for the tailscale state Secret.
- Spec corrections: Dex issuer is `https://pi0.taild13083.ts.net/dex`, not an IP; sealed-secrets runs in `kube-system`; `Chart.yaml` version must be valid SemVer; rollout order fixed so the chart is pushed before the ArgoCD Application exists.

### Fixed

- Spec second pass (spec-consistency review, same day): resolved the `API_SERVER_KEY` contradiction (was in the plain `Secret` *and* `values.yaml` while acceptance required it sealed — now sealed alongside the Tailscale auth key); tailscale state Secret now templated empty in the chart, since RBAC `resourceNames` cannot constrain `create` and the previous "tailscaled creates it under a scoped Role" design could never work; probes moved off the loopback-bound `:9119` (kubelet probes the pod IP) to `:8642`/`:443`; `TS_USERSPACE=false` made explicit and `--accept-routes` explicitly forbidden on the sidecar; Tailscale auth key pinned to reusable/tagged/non-ephemeral; Grafana-style plaintext back channel flagged as likely unavailable for Constraint C; hermes's OIDC callback path flagged as unverified before the Dex `redirectURIs` entry lands.
- `DECISIONS.md` [007](DECISIONS.md#007) amended a second time — its scoped-Role state-Secret design was unimplementable (`resourceNames` vs `create`), and `TS_USERSPACE=false` / no-`--accept-routes` made explicit. Decision stands.
- `DECISIONS.md` [007](DECISIONS.md#007) amended — its rationale claimed the Tailscale sidecar provides MagicDNS resolution. Verified false: the sidecar shares the network namespace but not `/etc/resolv.conf`. Decision stands; the gap is closed chart-side with `hostAliases`.

## 2026-08-14

### Added

- Repo scaffolding: `CLAUDE.md` (working approach), `DECISIONS.md`, this changelog.
- `docs/specs/001-deploy-hermes-to-homekube.md` — draft spec for deploying Hermes Agent onto the homekube Raspberry Pi cluster as a Helm chart, Dex-authenticated, Cilium-VIP/Tailscale-reachable.
- Spec updated: LLM connectivity via Aperture by Tailscale, reached through a Tailscale sidecar in the hermes pod; Tailscale auth key sealed via sealed-secrets.

### Decisions

- [001](DECISIONS.md#001) Dashboard auth via Dex-federated self-hosted OIDC, not basic auth.
- [002](DECISIONS.md#002) Dex client secret as a plain shared string, not sealed.
- [003](DECISIONS.md#003) Helm chart as the manifest format.
- [004](DECISIONS.md#004) Exposure via Cilium LB-IPAM VIP over the existing Tailscale subnet route.
- [005](DECISIONS.md#005) Fresh Longhorn PVC, no data migration.
- [006](DECISIONS.md#006) Issues tracked in this repo, not the shared homekube tracker.
- [007](DECISIONS.md#007) hermes reaches Aperture via a Tailscale sidecar in its own pod, not cluster-wide egress.
