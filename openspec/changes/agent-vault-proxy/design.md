# Design

## Context

See proposal.md for motivation and `specs/credential-brokering/spec.md` for the requirements. Proxy behaviour and the choices around it (traffic policy, session TTL, bypass list) are in [homekube spec 010](https://github.com/jangroth/homekube/blob/main/docs/specs/010-agent-vault-hermes.md).

- `build-ca-bundle` writes `/ca-bundle/ca-bundle.crt` (system store + homekube-ca); `SSL_CERT_FILE` and `REQUESTS_CA_BUNDLE` point at it. `NODE_EXTRA_CA_CERTS` points at `homekube-ca.crt` alone.
- Real credentials already ship as SealedSecret ciphertext passed in as values (`sealedSecret.*` → `hermes-secrets`).
- The proxy URL is `http://x-agent-vault:<session-token>@agent-vault-proxy.agent-vault.svc:17323`; the session token is the password.
- httpx (Tavily plugin) and urllib honour `HTTPS_PROXY`/`NO_PROXY`. The Telegram gateway does too, through `gateway.trust_env` (default on). curl honours `HTTPS_PROXY` but takes its CAs from `CURL_CA_BUNDLE`, not `SSL_CERT_FILE`. Node's built-in `fetch` honours `HTTPS_PROXY` and `NO_PROXY` only with `NODE_USE_ENV_PROXY=1`.

## Goals / Non-Goals

**Goals:**
- Session rotation and CA changes are a homekube-apps values change only.

**Non-Goals:**
- `HTTP_PROXY`: no plain-HTTP API is brokered.
- Egress NetworkPolicy forcing traffic through the proxy.
- Brokering anything for the state-export sidecar.

## Decisions

**Purpose-built `agentVault` block, not generic `extraEnv`/`extraEnvFrom`/`extraCaCerts`.** The proxy URL, bypass list and CA only work together, and the restart-on-rotation annotation needs to know what they are. *Alternative:* generic extension values. Rejected: three loosely coupled settings, and the restart would be left to whoever sets them.

**Ciphertext as a value, rendered by the chart.** `agentVault.encryptedHttpsProxy` is the `encryptedData.HTTPS_PROXY` of a SealedSecret named `hermes-agent-vault` in namespace `hermes` (strict scope), and the chart renders that SealedSecret, like `hermes-secrets`. *Alternative:* the SealedSecret as a second ArgoCD source in homekube-apps. Rejected: adds a multi-source Application for one file. *Alternative:* a key in `hermes-secrets`. Rejected: its ciphertext lives in this repo's values, so a session rotation would need a herminator PR.

**`HTTPS_PROXY` via `secretKeyRef`, plus `NODE_USE_ENV_PROXY=1`, on the `hermes` container only.** The other containers run no agent code; state-export uses git over SSH.

**`noProxy` defaults in the chart.** `.svc`, `.cluster.local`, `.ts.net`, `10.0.0.0/8`, `100.64.0.0/10`, `192.168.86.0/24`, `localhost`, `127.0.0.1`, `api.telegram.org`, joined into `NO_PROXY`. Like `podCidr` and `vip`, they describe homekube; homekube-apps can override. `api.telegram.org` stays until Telegram is brokered (spec 010 step 9). httpx and urllib ignore the CIDR entries; the hostname suffixes cover Dex and Aperture.

**CA trust.** `caCert` becomes key `agent-vault-ca.crt` in `hermes-config`, mounted next to `homekube-ca.crt`. When set, `build-ca-bundle` appends it to `ca-bundle.crt` and also writes `node-extra.crt` (homekube-ca + proxy CA), which `NODE_EXTRA_CA_CERTS` then points at. `CURL_CA_BUNDLE` points at `ca-bundle.crt` whenever the block is on. With `caCert` unset, the init container's command is unchanged.

**Restart on change.** A pod-template annotation `checksum/agent-vault` holds the sha256 of `encryptedHttpsProxy` + `caCert`, rendered only when the block is on. The Deployment is `Recreate`, so a change replaces the pod once the RWO volume is released.

## Risks / Trade-offs

- [A wrong CA PEM breaks all proxied TLS] → homekube-apps fetches the CA through `kubectl port-forward` and checks its fingerprint against Infisical before setting it (spec 010 §4).
- [The proxy is down or the session revoked → Hermes loses web access, but Aperture and Dex keep working through `NO_PROXY`] → accepted; rollback is unsetting `agentVault`.
- [The session token is still a static secret in the pod's env] → scoped to one bundle, only usable at the in-cluster proxy, revocable in Infisical.

## Migration Plan

Merge here first: with the block unset nothing changes. Then the homekube-apps PR sets the values, and Hermes restarts on the proxy. Rollback: remove the values from homekube-apps.
