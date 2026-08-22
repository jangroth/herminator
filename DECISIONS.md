# Decision Log

Newest decision first. Captures **why**. See `CHANGELOG.md` for **what was done**.

## 009 — config.yaml is seeded once from the ConfigMap, then owned by the runtime (2026-08-21)

**Decision:** the chart's `config.yaml` is no longer live-mounted into the hermes container. An init container copies it from the `hermes-config` ConfigMap onto the PVC (`/opt/data/config.yaml`) only when no file exists there yet; from then on the running instance owns and rewrites it (`chown 1000:1000` so the hermes uid can write).

**Rationale:** hermes is designed to rewrite its own config at runtime — the dashboard's model-assignment save path calls `save_config` → `atomic_yaml_write` → `os.replace`, which requires a normal writable file in a writable directory. The previous ConfigMap `subPath` mount made the file immutable, so `POST /api/model/set` always failed with `EROFS`. Seeding into the data dir matches how hermes runs on a normal install.

**Trade-offs accepted:** GitOps immutability for this one file — chart-side `config.yaml` changes (e.g. a new Dex issuer or `public_url`) no longer propagate to a running instance; runtime state wins. Escape hatch: edit the file in-pod, or delete `/opt/data/config.yaml` and restart the pod to re-seed (loses runtime edits). A boot-time merge of seed over runtime state was rejected: extra tooling in the init container plus per-key ambiguity about which side wins, for a single-instance homelab deployment.

---

## 008 — hermes trusts `homekube-ca` via a mounted CA cert + CA-bundle env vars, not a native config option (2026-08-17)

**Decision:** Constraint C (Spec 001) is resolved as option (b): the chart's `configmap.yaml` carries `homekube-ca-secret`'s `ca.crt` as a literal, mounted into the hermes container at `/etc/ssl/certs/homekube/homekube-ca.crt`, with `NODE_EXTRA_CA_CERTS`, `SSL_CERT_FILE`, and `REQUESTS_CA_BUNDLE` all pointed at it.

**Rationale:** hermes's self-hosted OIDC docs document no native custom-CA config key (option (a), checked and absent). homekube already solved this exact problem for Homepage's ArgoCD widget — also HTTPS-only, also `homekube-ca`-signed — with a ConfigMap + `NODE_EXTRA_CA_CERTS`; same fix, same cluster, proven precedent. hermes's runtime language isn't confirmed, so all three standard CA-bundle env vars are set together rather than guessing Node vs. Python; unused ones are harmless.

**Trade-offs accepted:** none — this is a public CA certificate, not a secret, and the pattern is already running elsewhere in the cluster.

---

## 007 — hermes reaches Aperture via a Tailscale sidecar in its own pod, not cluster-wide egress (2026-08-14)

**Decision:** LLM connectivity goes through Aperture by Tailscale (`http://ai.taild13083.ts.net/v1`), matching the already-validated local config (`~/.hermes/config.yaml`: `provider: aperture`, `type: openai_compatible`). hermes's `OPENAI_BASE_URL`/`OPENAI_API_KEY` point at it. To reach it from the cluster, the hermes pod gets a third container: the official `tailscale/tailscale` sidecar, giving the pod its own tailnet node identity (MagicDNS resolution + routing to Aperture). This is scoped entirely to herminator's chart — no changes to homekube's shared cluster networking.

**Rationale:** homekube's own Decision 013 (pod DNS deliberately kept on public resolvers because `100.100.100.100`/MagicDNS "is only reachable via the Tailscale virtual interface — not from pod network namespaces that route through eth0") and Decision 032 (`tailscale0` added to Cilium devices only for *inbound* VIP traffic, not pod-initiated egress) together mean pods have no path to tailnet peers today. Fixing that cluster-wide would be a homekube-repo change to working shared networking, with real regression risk to the existing inbound VIP path (rejected in favor of contained blast radius — see prior turn's discussion). A per-pod Tailscale sidecar is the standard, self-contained way to give one workload its own tailnet presence without touching cluster-wide routing/DNS.

**Amended 2026-08-16 (decision stands, rationale partly wrong):** the claim above that the sidecar gives the pod "MagicDNS resolution + routing" is only half right. The sidecar shares the pod's *network* namespace — routes and `tailscale0` — but **not `/etc/resolv.conf`**, which kubelet writes per-container. Verified on the live cluster: `ai.taild13083.ts.net` returns NXDOMAIN from a pod, while `pi0.taild13083.ts.net` resolves only because CoreDNS carries an explicit `hosts` override for it. So homekube's Decision 013 (cited below) constrains this more tightly than assumed: the sidecar fixes reachability, not naming. Resolved chart-side with pod `hostAliases` pinning Aperture's tailnet IP, preserving this decision's "no changes to homekube's shared cluster networking" property. A second gap surfaced in the same review: a kernel-mode sidecar also makes the pod *inbound*-reachable from the tailnet, bypassing the nginx/Dex front door — closed with `TS_EXTRA_ARGS=--shields-up` plus binding the dashboard to loopback. See Spec 001, "Constraints discovered in review".

**Amended 2026-08-16, second pass (decision stands, two implementation details corrected):** the trade-offs paragraph's "Role (get/update on one named Secret)" cannot work as stated — RBAC `resourceNames` cannot constrain the `create` verb, so a scoped Role can never let tailscaled create its state Secret at runtime. The chart pre-creates the Secret empty instead, and the Role grants `get`/`update`/`patch` on it by name. Also made explicit: the sidecar needs `TS_USERSPACE=false` (containerboot defaults to userspace mode, in which the transparent outbound routing this decision relies on silently doesn't exist) and must never enable `--accept-routes` (would hairpin in-pod traffic to the `192.168.86.240/28` VIPs out over the tailnet). See Spec 001, "Revisions — Second pass".

**Trade-offs accepted:** this introduces the deployment's first genuine high-value secret — a Tailscale auth key for the sidecar to join the tailnet (unlike Decision 2's deliberately-low-value Dex client secret, a leaked tailnet auth key has real blast radius). Unlike the Dex secret, it is **not** shipped as a plain `Secret` — it goes through sealed-secrets (already running in homekube), same as any other genuinely sensitive credential would. Also needs `NET_ADMIN` + `/dev/net/tun` on the sidecar container (more privileged than hermes's plain container), and some form of state persistence so the sidecar's node identity survives pod restarts without leaving orphaned devices in the tailnet admin console — defaulting to the tailscale image's built-in Kubernetes-Secret state store (`TS_STATE=kube:<secret-name>`), which needs a small scoped ServiceAccount+Role (get/update on one named Secret) — revising this repo's earlier assumption of "no custom RBAC needed for MVP." Alternative would be a dedicated small PVC instead of the Secret store; defaulting to the Secret store as it avoids an extra volume for MVP. Also reframes "real LLM provider secret management" rather than eliminating it: Aperture centralizes *provider* routing/keys server-side (hermes itself never holds OpenAI/Anthropic/etc. keys), but the Tailscale auth key is a new real secret in its place — sealed-secrets wiring is now in MVP scope, not deferred.

**Amended 2026-08-22 (correcting a claim, live since chart 0.1.5 / 2026-08-19):** the 2026-08-16 amendment above says Constraint B was closed by "binding the dashboard to loopback." That was live briefly but turned out to be **backwards**: `HERMES_DASHBOARD_HOST=127.0.0.1` doesn't just narrow the dashboard's listen scope, it makes hermes itself disable its Dex OAuth gate (`__HERMES_AUTH_REQUIRED__=false`) and apply loopback-only WebSocket Origin rules — so the loopback bind shipped a dashboard with **no auth at all**, the opposite of Decision 3's intent, plus chat WebSockets reconnect-looping (code 1006) since nginx's proxied Origin didn't match. Found and fixed same-day: dashboard now binds `0.0.0.0`, matching Constraint B's own inbound-exposure worry — but that risk is covered by the *other* two legs of the original fix (`--shields-up` on the sidecar, and the dashboard having no Service/route to it except through the nginx/Dex front door), which don't depend on the loopback bind at all. See `herminator@cd67b75`, chart 0.1.5, and [Spec 001](docs/specs/001-deploy-hermes-to-homekube.md)'s Constraint B section (corrected same day) and its 2026-08-22 acceptance verification.

---

## 006 — Issues tracked in this repo, not the shared `jangroth/homekube` tracker, reusing the `agent-safe` label convention (2026-08-14)

**Decision:** herminator's open work items are tracked as GitHub Issues on this repo, not folded into homekube's shared `jangroth/homekube` tracker. Adopts homekube's `agent-safe` label as-is: an issue is labelled `agent-safe` only when it's an unambiguous, reversible, PR-only fix with no open design decision and no physical/external-account step.

**Rationale:** homekube centralizes issues across `homekube`/`homekube-main`/`homekube-apps` because those three repos are really one system split for deployment reasons. herminator is a distinct app/product — Hermes Agent packaging — not cluster infra, so it doesn't share that trust/scope domain even though it deploys onto homekube. The `agent-safe` label itself is worth reusing regardless of tracker: it's a useful, already-proven signal for which issues an autonomous routine can pick up and PR without human design input first.

**Trade-offs accepted:** homekube also uses `area:*`/`criticality:*`/`repo:*` labels alongside `agent-safe`, driven by its three-repo split. herminator is single-repo, so only `agent-safe` is adopted for now; `area:*`/`criticality:*` can be added later if the issue volume justifies it. No nightly automated pick-up routine is being set up yet — that's a separate decision if/when it's wanted.

---

## 005 — Fresh Longhorn PVC; no migration of local `~/.hermes` data (2026-08-14)

**Decision:** The cluster deployment starts with an empty Longhorn-backed PVC. Nothing in the current `~/.hermes` (~370MB: sqlite state, sessions, workspace, logs) is copied over.

**Rationale:** User confirmed none of the local data is precious. Migrating it would add real complexity (getting ~370MB onto a Pi's Longhorn volume, reconciling sqlite files that may be mid-write) for no benefit.

**Trade-offs accepted:** any local session/kanban/history state from the Compose setup is lost. Acceptable per user.

---

## 004 — Exposure via Cilium LB-IPAM VIP, reachable over the existing Tailscale subnet route (2026-08-14)

**Decision:** hermes gets its own VIP (`192.168.86.246`) from homekube's existing Cilium LB-IPAM pool (`192.168.86.241–251`), the same mechanism Homepage/Grafana/Longhorn/Dex already use. No new component introduced.

**Rationale:** The pi nodes already advertise a Tailscale subnet route for `192.168.86.240/28`, so the whole VIP pool is reachable over Tailscale today with zero extra plumbing. User asked for "its own IP, reachable via Tailscale, like Homepage/Grafana/Longhorn" — that's exactly what a Cilium VIP already gives, no Tailscale Kubernetes operator or sidecar needed.

**Trade-offs accepted:** none — this is strictly reusing existing cluster capability.

---

## 003 — Helm chart as the manifest format, owned by this repo (2026-08-14)

**Decision:** hermes's k8s manifests are authored as a Helm chart living in this repo (`chart/`), not raw manifests or Kustomize. homekube-apps' ArgoCD `Application` references this repo as a git source — the same app-of-apps shape already used for the `dex` app (chart-based), as opposed to Homepage's vendored-raw-manifests approach.

**Rationale:** User's explicit choice. Also the more natural fit here: this repo's entire purpose is packaging hermes for k8s, so the chart *is* the deliverable, versioned and reviewable independently of the cluster's own GitOps repo.

**Trade-offs accepted:** slightly more boilerplate than raw manifests for a single-service app; judged worth it for the separation between "what hermes is" (this repo) and "that hermes is deployed" (homekube-apps).

---

## 002 — Dex client secret is a plain shared string, not sealed (2026-08-14)

**Decision:** The OIDC client secret shared between hermes and Dex is a literal string committed in both this repo's values and homekube-apps' `dex.yaml`, not a sealed-secret.

**Rationale:** Reuses homekube's own precedent (its DECISION-040): an internal, Tailscale-gated shared secret between two trusted in-cluster OIDC endpoints is low-value, not worth the sealed-secrets ceremony. Consistent with how ArgoCD's and Grafana's Dex client secrets are already handled.

**Trade-offs accepted:** the string is visible in both repos' git history. Trivial to rotate or upgrade to a sealed secret later if that judgment changes.

**Amended 2026-08-17 (moot, not wrong):** while building the chart, hermes's self-hosted OIDC docs turned out to describe a **public PKCE client — no client secret at all** (config surface is `issuer`/`client_id`/`scopes` only; the env var table has no `CLIENT_SECRET`). This decision's "if it exists, treat it as low-value" judgment isn't wrong, it's just inapplicable — there's nothing to seal or share. `chart/templates/secret.yaml` was removed; when the homekube-apps Dex change lands (Spec 001 rollout step 7), the `hermes` static client must be registered `public: true` with no `secret:` field, not with a shared string as the spec originally assumed.

---

## 001 — Dashboard auth: Dex-federated self-hosted OIDC, not basic auth (2026-08-14)

**Decision:** Drop HTTP basic auth entirely. hermes's dashboard authenticates via its built-in self-hosted OIDC support, federated to homekube's existing Dex instance — the same shape as ArgoCD/Grafana's Dex `staticClients`. Since homekube has no ingress controller and both ArgoCD/Grafana went HTTPS-only on joining Dex, hermes gets a small TLS-terminating nginx sidecar (cert from the existing `homekube-ca` ClusterIssuer) rather than serving the OIDC flow over plaintext.

**Rationale:** User explicitly rejected basic auth. hermes ships a generic self-hosted-OIDC mode built for exactly this (Authentik/Keycloak/Authelia/Dex-style providers) — no need for a bespoke oauth2-proxy/forward-auth layer, which homekube already considered and deliberately deferred for Homepage as "bespoke plumbing" not yet worth building.

**Trade-offs accepted:** adds a second container (nginx sidecar) to the pod purely for TLS termination, since hermes doesn't terminate TLS itself. Judged worth it to match the cluster's established HTTPS-for-OIDC-clients posture rather than inventing a plaintext exception.
