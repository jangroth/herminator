# Tasks

## 1. Chart

- [x] 1.1 Add the `agentVault` values (`encryptedHttpsProxy: ""`, `caCert: ""`, `noProxy` defaults) and `templates/agent-vault-sealedsecret.yaml`, rendered only when `encryptedHttpsProxy` is set. Verify with `helm template` that it renders with the value set and not without.
- [x] 1.2 In `deployment.yaml`, add `HTTPS_PROXY` (secretKeyRef), `NO_PROXY` and `CURL_CA_BUNDLE` to the `hermes` container and the `checksum/agent-vault` annotation, all only when the block is on. Verify with `helm template` that no other container gets them.
- [x] 1.3 Add `agent-vault-ca.crt` to `hermes-config` when `caCert` is set; have `build-ca-bundle` append it to `ca-bundle.crt` and write `node-extra.crt`, and point `NODE_EXTRA_CA_CERTS` at it. Verify by running the rendered init command in the Hermes image against a test CA, and that the command is unchanged without `caCert`.
- [x] 1.4 Add `chart/tests/agent-vault-render.sh`: compares a render without `agentVault` with one from `origin/main`, and checks a render with the block set (SealedSecret name and namespace, env only on `hermes`, annotation changes when either value changes). Verify it passes, and fails when an env var is moved to another container.
- [x] 1.5 Bump the chart version, add a `CHANGELOG.md` entry linking this change and issue #20, and describe the block in `README.md`. Verify `helm lint` and `openspec validate agent-vault-proxy --strict` pass.
- [x] 1.6 Add `NODE_USE_ENV_PROXY=1` to the `hermes` container when the block is on, since Node's built-in `fetch` ignores `HTTPS_PROXY` without it, and to the render test's hermes-only check. Bump the chart version. Verify the render test passes and, in the pod, `node -e 'fetch(...)'` gets a certificate issued by the proxy CA.
- [ ] 1.7 Drop `api.telegram.org` from the default `noProxy` once the bundle's `telegram` service substitutes the bot token in the path, and bump the chart version. `TELEGRAM_BOT_TOKEN` becomes a placeholder in the same restart. Verify Telegram reconnects, its requests are logged as `brokered` with the placeholder path only, and a photo sent to Hermes downloads.

## 2. Rollout

- [ ] 2.1 After merge, verify ArgoCD shows `hermes` Synced/Healthy with no pod restart (block unset).
- [ ] 2.2 After the homekube-apps values PR merges, verify the pod restarted, `HTTPS_PROXY` is set only in `hermes`, `curl -v` from the `hermes` container to an external HTTPS host succeeds with issuer `CN=Infisical Agent Vault Proxy`, and Dex and Aperture still work.

## Workflow follow-up

- homekube-apps PR setting `agentVault.encryptedHttpsProxy` and `agentVault.caCert` (homekube spec 010 step 4), after this merges.
- Archive the change once verified. The archive PR closes issue #20.
