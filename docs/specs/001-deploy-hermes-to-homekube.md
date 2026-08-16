# Spec 001 — Deploy Hermes Agent to homekube

**Status:** Draft
**Date:** 2026-08-14
**Revised:** 2026-08-16 — review pass against the live cluster, plus a same-day second pass fixing internal contradictions found in spec review; see "Revisions" below.

## Problem

The local Docker Compose setup was a trial to see what Hermes Agent looks like and how it behaves — that trial is done. We're now rolling Hermes Agent out properly onto the homekube Raspberry Pi cluster: always-on, reachable the same way the cluster's other personal-dashboard apps are, and without the dashboard sitting behind weak HTTP basic auth.

## Current State

- `local/docker-compose.yml`: single `hermes` service, `nousresearch/hermes-agent:latest`, gateway API on `8642`, dashboard on `9119` (loopback-only), bind-mounts `~/.hermes` → `/opt/data`, dashboard protected by HTTP basic auth, placeholder `API_SERVER_KEY`.
- `~/.hermes` (~370MB): sqlite state (`state`/`kanban`/`projects`/`response_store`.db), sessions, workspace, logs, config/auth files. Confirmed disposable — no migration needed.
- No real LLM provider secrets configured yet (fresh start; today's env values are all placeholders).
- Image confirmed arm64-capable (already run locally on Apple Silicon).
- hermes ships a documented, built-in **self-hosted OIDC** dashboard-auth mode (config keys `dashboard.oauth.provider: self-hosted` / `dashboard.oauth.self_hosted.*`, env `HERMES_DASHBOARD_OIDC_*`) explicitly meant for providers like Authentik/Keycloak/Authelia/Zitadel — Dex qualifies as a generic OIDC provider for this purpose. Docs: [Web Dashboard](https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard), [Environment Variables](https://hermes-agent.nousresearch.com/docs/reference/environment-variables).
- homekube (`/Users/jan/Projects/kube/homekube`): ArgoCD app-of-apps GitOps (`homekube-apps` repo), Cilium LB-IPAM VIP pool `192.168.86.241–251` (already Tailscale-reachable via the pi nodes' advertised subnet route `192.168.86.240/28` — no separate Tailscale operator needed), Longhorn storage, sealed-secrets, Dex OIDC IdP already federated with ArgoCD and Grafana via `staticClients`, cert-manager with a `homekube-ca` internal ClusterIssuer, no ingress controller (deferred cluster-wide).

### Verified against the live cluster (2026-08-16)

Facts below were checked directly, not assumed. They change several implementation details — see "Revisions".

| Claim | Result |
|---|---|
| `192.168.86.246` free | **Yes.** In use: `.241` argocd-server, `.242` longhorn-ui, `.243` grafana, `.244` dex, `.245` homepage. |
| Dex issuer URL | **`https://pi0.taild13083.ts.net/dex`** — a MagicDNS hostname, *not* the `.244` VIP. Both ArgoCD and Grafana use this exact string. |
| Dex TLS | Serves HTTPS on `:5554` (svc port `443`) with the `dex-tls` cert from `homekube-ca`; plaintext HTTP on `:5556`. |
| How existing clients trust `homekube-ca` | Two different answers. ArgoCD embeds the CA PEM as `rootCA:` in `argocd-cm`'s `oidc.config`. Grafana avoids the problem — browser-facing `auth_url` is HTTPS, but `token_url`/`api_url` point at plaintext `http://dex.dex.svc.cluster.local:5556/dex`. |
| `ai.taild13083.ts.net` resolvable from a pod | **No — NXDOMAIN.** Confirmed with a busybox pod against CoreDNS. |
| `pi0.taild13083.ts.net` resolvable from a pod | Yes, but only because CoreDNS has an explicit `hosts { 192.168.86.244 pi0.taild13083.ts.net }` override. Nothing resolves tailnet names generally. |
| sealed-secrets | Running, but in **`kube-system`** (not a `sealed-secrets` namespace); `sealedsecrets.bitnami.com` CRD present. |
| ClusterIssuers | `homekube-ca` and `selfsigned-bootstrap`, both Ready. Existing `Certificate`s: argocd, dex, grafana — same shape as ours. |
| StorageClass | `longhorn` is default, `ALLOWVOLUMEEXPANSION=true`, **`RECLAIMPOLICY=Delete`**. |
| Upstream issue #42780 | **Real**, and matches the described symptom: *"[Bug]: HERMES_DASHBOARD_PUBLIC_URL not respected for self-hosted OIDC callback in Docker / reverse proxy setup"*, opened 2026-06-09. Note it is **closed** — the fix may already be in the tag we pin. |

## Decisions (confirmed with user, 2026-08-14)

1. **Manifest format: Helm chart**, maintained in *this* repo (`chart/`). homekube-apps' ArgoCD `Application` references it as a git source — same app-of-apps shape as the `dex` app (chart-based), not the vendored-raw-manifests shape used for Homepage.
2. **Exposure:** dedicated Cilium LB-IPAM VIP (`192.168.86.246`, next free in the pool), reachable via the cluster's existing Tailscale subnet route — same pattern as Homepage/Grafana/Longhorn/Dex. No Wi-Fi-only access, no new Tailscale-operator component.
3. **No basic auth.** Dashboard auth uses hermes's built-in self-hosted OIDC, federated to homekube's existing Dex — same shape as ArgoCD/Grafana's Dex `staticClients`. Because homekube has no ingress controller, and both ArgoCD and Grafana went HTTPS-only when they joined Dex, hermes gets a small TLS-terminating **nginx sidecar** in front of its plaintext dashboard port, certificate issued by the existing `homekube-ca` ClusterIssuer.
   *[Revised 2026-08-16]* The OIDC **issuer** is `https://pi0.taild13083.ts.net/dex`, not the `.246` or `.244` IP — issuer matching is strict and an IP form fails discovery and `iss` validation. hermes must also trust `homekube-ca` to complete the back-channel token exchange; mechanism is an open question (see below).
4. **Dex client secret is a plain shared string, not sealed** — reuses homekube's own DECISION-040 precedent: an internal, Tailscale-gated shared secret between two trusted in-cluster OIDC endpoints is low-value and not worth sealed-secrets ceremony. Trivial to upgrade later if that judgment changes.
5. **Storage:** fresh Longhorn PVC. No migration of existing `~/.hermes` data — user confirmed none of it is precious.
6. **Cross-repo bookkeeping:** this repo owns its own spec/decision/changelog. homekube's own `DECISIONS.md`/`CHANGELOG.md`/README "Deployed Components" table also get an entry once the ArgoCD Application actually lands there, per homekube's own "source reflects runtime" convention.
7. **Issue tracking:** herminator's own GitHub Issues — it's a distinct app/product, not cluster infra, so it doesn't join the shared `jangroth/homekube` tracker. Reuses homekube's `agent-safe` label convention: an issue gets `agent-safe` only if it's an unambiguous, reversible, PR-only fix with no open design decision and no physical/external-account step.
8. **LLM connectivity: Aperture by Tailscale**, matching the already-validated local config (`provider: aperture`, `type: openai_compatible`, `base_url: http://ai.taild13083.ts.net/v1`). The hermes pod gets a third container — the official `tailscale/tailscale` sidecar — giving it its own tailnet node identity to reach Aperture. Scoped entirely to this repo's chart; no changes to homekube's shared cluster networking. Resolves "real LLM provider secret management" as a separate concern: Aperture centralizes provider keys server-side, hermes never holds them.
   *[Revised 2026-08-16]* The sidecar delivers **routing but not name resolution**, and it opens an unintended inbound path. Both are addressed in "Constraints discovered in review" below; the decision itself stands.

## Revisions (2026-08-16)

A review pass checked the spec's factual claims against the live cluster. The approach survives; these details did not.

**Corrected:**
- Decision 8's premise that the sidecar provides "MagicDNS resolution + routing" is half right — see Constraint A. This also corrects DECISIONS.md #007, which is annotated accordingly.
- The Dex issuer is a MagicDNS hostname, not an IP (Decision 3).
- sealed-secrets lives in `kube-system`.

**Added to scope:** `hostAliases` for Aperture, `--shields-up` on the sidecar, `strategy: Recreate`, PVC retention annotations, a CA-trust path to Dex, and a real `API_SERVER_KEY`.

### Second pass (2026-08-16, spec review)

A consistency review of the spec itself (not the cluster) caught one contradiction and two details that would not have worked as written:

- **`API_SERVER_KEY` is now sealed.** The Approach table had it in the plain `Secret` and in `values.yaml` while the acceptance criteria required it "sealed, never plaintext in any commit" — both couldn't be true. Resolved toward sealed: Constraint B makes this key the *only* guard on `:8642`, which is exactly the "real blast radius" test that separates sealed from plain (Decision 4).
- **The tailscale state-Secret RBAC could never have worked.** RBAC `resourceNames` cannot constrain the `create` verb, so a Role scoped to one named Secret cannot allow tailscaled to *create* that Secret at runtime. The chart now templates an empty state Secret; tailscaled only ever `get`/`update`/`patch`es it.
- **The loopback-bound dashboard breaks default probes.** kubelet directs `tcpSocket`/`httpGet` probes at the *pod IP*, so a probe on `:9119` would always fail once the dashboard binds `127.0.0.1` (Constraint B) — instant crashloop. Probes moved to `:8642` (hermes container) and `:443` (nginx).
- Smaller items: `TS_USERSPACE=false` must be set explicitly — containerboot defaults to userspace mode, in which the hermes container's outbound traffic would *not* transparently reach Aperture and Decision 8 silently fails. Never add `--accept-routes` to the sidecar — it would hairpin in-pod traffic to the `192.168.86.240/28` VIPs (including Dex at `.244`) out over the tailnet. The Tailscale auth key must be **reusable, tagged, non-ephemeral** (state persists across restarts; an ephemeral key deletes the device when it goes offline, defeating the no-orphaned-device acceptance check). And hermes's actual OIDC callback path must be confirmed before the Dex `redirectURIs` entry lands — `/auth/callback` is currently an assumption.

## Constraints discovered in review

### A. Aperture's MagicDNS name does not resolve inside the pod

`ai.taild13083.ts.net` returns **NXDOMAIN** from a cluster pod (verified). The Tailscale sidecar shares the pod's *network* namespace — routes and the `tailscale0` interface — but **not `/etc/resolv.conf`**, which kubelet writes per-container. So hermes resolves via CoreDNS, gets NXDOMAIN, and never reaches the tailnet route that is sitting right there. This is consistent with homekube's own Decision 013 (pods deliberately kept on public resolvers); the cluster's existing workaround for the one tailnet name it needs is a hardcoded CoreDNS `hosts` entry for `pi0`.

**Chosen fix:** pod-level `hostAliases` pinning Aperture's `100.x` tailnet address. Keeps Decision 8's "no changes to homekube's shared cluster networking" promise, unlike extending the CoreDNS `hosts` block. Requires Aperture's tailnet IP, which is stable per-node; record it in `values.yaml` with a comment explaining why it is an IP and not a name.

*Rejected:* `dnsPolicy: None` + `dnsConfig` listing `100.100.100.100` — works, but makes every DNS lookup in the pod depend on tailscaled having finished starting, for one hostname's benefit.

### B. The Tailscale sidecar exposes the whole pod to the tailnet

In kernel mode the pod acquires its own tailnet identity, and the Compose config binds `HERMES_DASHBOARD_HOST=0.0.0.0` and `API_SERVER_HOST=0.0.0.0`. Carried over unchanged, any tailnet device could reach `http://hermes-aperture:9119` — the dashboard, plaintext, no TLS, no Dex — and `:8642`, which this spec declares "internal only (ClusterIP)". That silently defeats Decision 3.

**Fix, all three:**
- `TS_EXTRA_ARGS=--shields-up` on the sidecar — blocks inbound connections to the tailnet node entirely. It only ever needs to make outbound calls to Aperture.
- Bind the dashboard to `127.0.0.1`. nginx is in the same network namespace, so it still proxies fine, and the dashboard becomes unreachable by any path except the TLS/OIDC front door.
- Keep the gateway on `0.0.0.0` so the ClusterIP Service still works for future in-cluster consumers, and give `API_SERVER_KEY` a real generated value — it is now the only thing guarding `:8642` in-cluster, and today it is the placeholder string `your-custom-local-secret`. Being a real guard, it ships **sealed** alongside the Tailscale auth key, not in the plain Secret (second-pass revision).

### C. hermes must trust `homekube-ca` to talk to Dex

Dex serves its issuer over TLS with a `homekube-ca`-signed cert, so hermes's back-channel discovery and token exchange will fail x509 verification out of the box. Both existing clients had to solve this and solved it differently (ArgoCD embeds `rootCA:`; Grafana routes the back channel over plaintext ClusterIP). Note Grafana can only split channels because it configures each endpoint URL individually — hermes's self-hosted OIDC surface looks issuer-only + discovery, so the Grafana route is likely unavailable to us. Which options hermes actually supports is not yet known — see Open Questions. This must be settled **before** writing `templates/deployment.yaml`, since the three candidate fixes have different chart shapes.

## MVP Scope

**In:**
- hermes-agent pod running on homekube, Longhorn-backed persistent `/opt/data`
- Dashboard reachable at `https://192.168.86.246`, Dex-authenticated, no basic auth
- Gateway API (`8642`) internal only (ClusterIP), guarded by a real generated `API_SERVER_KEY`
- LLM connectivity via Aperture, reached through a Tailscale sidecar in the hermes pod (Decision 8), with `hostAliases` for name resolution (Constraint A) and `--shields-up` to keep the sidecar outbound-only (Constraint B)
- Tailscale auth key sealed via sealed-secrets (`SealedSecret`, decrypted in-cluster) — not plaintext in git, unlike the low-value Dex secret (Decision 2 doesn't apply here; this key has real blast radius)
- ArgoCD-managed (this repo's Helm chart as the git source), auto-sync + self-heal
- Sane chart defaults for a Pi 5 node; no tuning pass

**Deferred — explicitly out of scope for MVP, tracked as follow-up issues in this repo:**
- Exposing/protecting the gateway API externally
- Observability: Prometheus scrape / Grafana dashboard / Homepage tile
- Longhorn backup/snapshot policy for the PVC
- Resource request/limit tuning based on observed usage
- CI (chart lint, etc.) for this repo
- HA / multiple replicas — not applicable, hermes is single-instance by design (sqlite + lockfiles)

## Approach

### 1. Helm chart (`chart/`)

| File | Contents |
|---|---|
| `Chart.yaml` | `hermes`, `version: 0.1.0` (must be valid SemVer — "v0" is not) |
| `values.yaml` | image tag, VIP, OIDC issuer/client id/secret, Aperture base URL **and pinned tailnet IP** (Constraint A), **sealed** ciphertexts for both the Tailscale auth key and `API_SERVER_KEY` (never the plaintext values — second-pass revision), resource requests/limits, PVC size |
| `templates/pvc.yaml` | Longhorn-backed `PersistentVolumeClaim`, RWO, default 5Gi (current usage ~370MB + headroom). Annotated `helm.sh/resource-policy: keep` and `argocd.argoproj.io/sync-options: Prune=false` — the default StorageClass reclaims `Delete`, so an app delete or an immutable-field change would otherwise destroy the volume, and there is no backup policy yet (deferred) |
| `templates/configmap.yaml` | hermes `config.yaml` overrides — `dashboard.public_url` (see gotcha below), OIDC issuer `https://pi0.taild13083.ts.net/dex`, and `provider: aperture` — plus the nginx sidecar config |
| `templates/secret.yaml` | plain (unsealed — Decision 4) `Secret` holding `HERMES_DASHBOARD_OIDC_CLIENT_SECRET` only — `API_SERVER_KEY` moved to the SealedSecret (second-pass revision) |
| `templates/sealedsecret.yaml` | `SealedSecret` (bitnami-labs/sealed-secrets, running in homekube's `kube-system`) holding the Tailscale auth key (`TS_AUTHKEY`) and `API_SERVER_KEY` — both real credentials, encrypted at rest in git, decrypted in-cluster only. The auth key must be **reusable, tagged, non-ephemeral** (second-pass revision). Seal for namespace `hermes` specifically; SealedSecrets are scoped to namespace + name |
| `templates/serviceaccount.yaml` | scoped `ServiceAccount` + `Role`/`RoleBinding` (`get`/`update`/`patch` on the one named state Secret via `resourceNames`) so the Tailscale sidecar can persist its node state via `TS_STATE=kube:<secret-name>` — the one exception to "no custom RBAC for MVP". **The chart templates the state Secret itself, empty** — RBAC `resourceNames` cannot constrain `create`, so a scoped Role could never let tailscaled create it at runtime (second-pass revision); pre-creating it keeps the Role tight. ArgoCD must not fight tailscaled's writes to it: add an `ignoreDifferences` entry for the Secret's `data` in the Application |
| `templates/certificate.yaml` | cert-manager `Certificate`, issued by `homekube-ca` ClusterIssuer, `ipAddresses: ["192.168.86.246"]`, output secret `hermes-tls` |
| `templates/deployment.yaml` | `replicas: 1`, **`strategy: Recreate`** (RWO Longhorn volume — the default RollingUpdate deadlocks waiting for the old pod to release it, and any overlap risks concurrent writers on the sqlite files; the spec already notes hermes is single-instance by design). `hostAliases` for Aperture (Constraint A). Three containers: `hermes` (PVC at `/opt/data`, configmap mount, `envFrom` secrets, dashboard bound to `127.0.0.1:9119`, gateway on `0.0.0.0:8642`), `nginx` sidecar (mounts `hermes-tls`, terminates `:443`, proxies to `127.0.0.1:9119` with `X-Forwarded-*` headers), and `tailscale` sidecar (official `tailscale/tailscale` image, `NET_ADMIN` + `/dev/net/tun`, **`TS_USERSPACE=false`** — containerboot defaults to userspace mode, which breaks transparent outbound routing; second-pass revision — `TS_AUTHKEY` from the sealed secret, `TS_STATE=kube:<secret-name>`, `TS_EXTRA_ARGS=--shields-up`, **no `--accept-routes`**, hostname `hermes-aperture`). Probes: `tcpSocket` on `:8642` for hermes and `:443` for nginx — never `:9119`, which binds loopback while kubelet probes the pod IP (second-pass revision) |
| `templates/service.yaml` | `type: LoadBalancer`, `io.cilium/lb-ipam-ips: "192.168.86.246"`, port 443 → nginx sidecar only |

No `namespace.yaml` template — the `hermes` namespace is created via the ArgoCD Application's `CreateNamespace=true` sync option, matching Dex/Homepage.

### 2. Known gotcha: `dashboard.public_url`

hermes has a documented bug ([upstream issue #42780](https://github.com/NousResearch/hermes-agent/issues/42780)) where `HERMES_DASHBOARD_PUBLIC_URL` isn't reliably honored for the OIDC callback URL in Docker. Confirmed workaround: set `dashboard.public_url` directly in the mounted `config.yaml` instead of the env var. The chart's `configmap.yaml` does this directly (`https://192.168.86.246`).

The issue is **closed** upstream, so the fix may already be present in the tag we pin. Setting `public_url` in `config.yaml` is correct either way, so keep the workaround; just don't treat the env var as broken-by-definition when debugging.

### 3. Dex changes (homekube-apps repo, separate change when we get there)

Add to `dex.yaml`'s inline `staticClients` (note: this renders into the `dex` **Secret**, not a ConfigMap):

```yaml
- id: hermes
  name: Hermes
  secret: hermes-dex-client-secret   # plain shared string, see Decision 4
  redirectURIs:
    - https://192.168.86.246/auth/callback
```

The `/auth/callback` path is an **assumption** — confirm hermes's actual self-hosted-OIDC callback path from its docs (same page as the Constraint C check) before landing this. A mismatch fails the flow with Dex's least helpful error.

New `applications/wave-03-apps/hermes.yaml` ArgoCD `Application`: git source → this repo (`chart/`), destination namespace `hermes`, `argocd.argoproj.io/sync-wave: "3"` (after Dex/wave 02, alongside Homepage), `automated: {prune: true, selfHeal: true}`, `syncOptions: [CreateNamespace=true]`, plus the `ignoreDifferences` entry for the tailscale state Secret. Append to root `applications/kustomization.yaml`. homekube's own `DECISIONS.md`/`CHANGELOG.md`/README get an entry (Decision 6).

### 4. Rollout order

1. Confirm `192.168.86.246` is still free (`kubectl get svc -A | grep LoadBalancer`) and that `homekube-ca`/cert-manager are healthy.
2. Settle Constraint C — determine how hermes accepts a custom CA (the Grafana plaintext-back-channel route is likely unavailable; see Constraint C) — and confirm the OIDC callback path for Dex's `redirectURIs` while on the same docs page. This gates the deployment template.
3. Get Aperture's tailnet IP for `hostAliases` (Constraint A).
4. Build the chart in this repo; `helm lint` / `helm template` locally.
5. Generate the shared Dex client secret string. Generate `API_SERVER_KEY` and mint a reusable, tagged, non-ephemeral Tailscale auth key; seal both for namespace `hermes`.
6. **Push this repo's chart first** — the ArgoCD Application must not exist before its git source does, or it lands Unknown/Degraded and thrashes under `selfHeal` + `prune`.
7. Land the homekube-apps changes (Dex static client + new `hermes.yaml` Application), sync, verify Dex serves the new client.
8. Sync the hermes Application.
9. Walk the acceptance list below.
10. Update homekube's docs per Decision 6.

## Acceptance

- [ ] `kubectl get pods -n hermes` — Running, all three containers ready
- [ ] `https://192.168.86.246` from a Tailscale-connected client redirects to Dex login; completing it lands back on the authenticated hermes dashboard
- [ ] hermes completes OIDC discovery against `https://pi0.taild13083.ts.net/dex` with no x509 error in its logs (Constraint C)
- [ ] No basic auth anywhere — old `HERMES_DASHBOARD_BASIC_AUTH_*` vars gone entirely
- [ ] From another tailnet device, `hermes-aperture:9119` and `:8642` are **not** reachable — `--shields-up` holds and the dashboard has no non-TLS, non-OIDC path (Constraint B)
- [ ] `/opt/data` actually persists across a pod restart (PVC bound, Longhorn-backed — `kubectl get pvc -n hermes`)
- [ ] A rollout completes rather than deadlocking on the RWO volume — proves `strategy: Recreate`
- [ ] Tailscale sidecar shows up as its own device in the tailnet admin console; hermes can reach Aperture and complete an actual LLM request through it
- [ ] Sidecar survives a pod restart without creating a duplicate/orphaned tailnet device (state persistence via the Kubernetes-Secret store works, and ArgoCD is not reverting it)
- [ ] ArgoCD shows the app Synced/Healthy
- [ ] No plaintext *high-value* credentials in git — the Dex client secret is accepted as low-value per Decision 4, but the Tailscale auth key (Decision 8) and `API_SERVER_KEY` are sealed, never plaintext in any commit

## Open Questions

- **Constraint C — how does hermes trust `homekube-ca`?** Three candidates, in preference order: (a) a native custom-CA option in its self-hosted OIDC config, if one exists; (b) mount the CA PEM into the container and point `SSL_CERT_FILE`/`REQUESTS_CA_BUNDLE` at it; (c) Grafana's approach — browser-facing auth URL over HTTPS, back-channel token/userinfo over plaintext `http://dex.dex.svc.cluster.local:5556/dex`. **(c) is likely off the table** — it requires per-endpoint URL config, and hermes's OIDC surface appears issuer-only + discovery. Expect the answer to be (b); check (a) as a formality. Needs a docs check or an experiment before the chart is written.
- Exact resource requests/limits — starting with a conservative guess (~512Mi/500m request, 1Gi/1cpu limit); revisit once real usage is observed (deferred item).
- Health-probe paths for hermes's dashboard/gateway aren't documented anywhere I've found — starting with `tcpSocket` probes on `:8642` (hermes) and `:443` (nginx); `:9119` is unusable for probes since it binds loopback and kubelet probes the pod IP. Tighten if hermes ships real `/healthz`-style endpoints.
- Whether the chart's version should track upstream image tags 1:1 or pin more conservatively — not blocking MVP.
- Whether Aperture's tailnet IP should be reserved/pinned on the Tailscale side, given `hostAliases` hardcodes it (Constraint A). Low risk, but a silent breakage if that node is ever recreated.
