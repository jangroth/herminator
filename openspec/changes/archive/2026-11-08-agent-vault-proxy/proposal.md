# Proposal

Source issue: [#20](https://github.com/jangroth/herminator/issues/20)

## Why

Hermes keeps its outbound API keys in plaintext in `/opt/data/.env`, where anything it runs, logs or exports can leak them. homekube now runs an Infisical Agent Vault proxy in-cluster ([homekube spec 010](https://github.com/jangroth/homekube/blob/main/docs/specs/010-agent-vault-hermes.md)) that attaches the real credentials to outbound requests, so Hermes only has to hold a revocable session token that works nowhere but at that proxy.

## What Changes

- New optional `agentVault` chart values, off by default: `encryptedHttpsProxy` (SealedSecret ciphertext of the proxy URL with the session token), `caCert` (the proxy's CA) and `noProxy` (destinations that bypass the proxy).
- When `encryptedHttpsProxy` is set, the chart renders SealedSecret `hermes-agent-vault` and gives the `hermes` container `HTTPS_PROXY` from it, plus `NO_PROXY`.
- The proxy CA is added to the trust Hermes's Python, Node and curl clients use. `CURL_CA_BUNDLE` points at the combined bundle.
- The pod restarts when the ciphertext or the CA changes.
- With `agentVault` unset, the rendered chart is unchanged.

## Capabilities

### New Capabilities
- `credential-brokering`: Hermes's outbound HTTPS goes through the Agent Vault proxy, which holds the real credentials; the pod holds only the session token.

### Modified Capabilities

## Impact

- `chart/values.yaml`, `chart/templates/deployment.yaml`, `chart/templates/configmap.yaml`, new `chart/templates/agent-vault-sealedsecret.yaml`.
- `chart/tests/`: render tests for the block off and on. `chart/Chart.yaml` version, `CHANGELOG.md`, `README.md`.
- homekube-apps sets `agentVault.encryptedHttpsProxy` and `agentVault.caCert` in `wave-03-apps/hermes.yaml`. The state-export sidecar is not proxied.
