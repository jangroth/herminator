# credential-brokering Specification

## Purpose
Hermes reaches external HTTPS APIs through the Agent Vault proxy, which attaches real credentials, so the Hermes pod never holds them.

## Requirements

### Requirement: Off unless configured
The chart SHALL render exactly as without this capability when no proxy URL ciphertext is set.

#### Scenario: Block unset
- **WHEN** the chart is rendered without `agentVault.encryptedHttpsProxy`
- **THEN** the rendered objects are identical to those of the previous chart version

### Requirement: Hermes's HTTPS goes through the proxy
When a proxy URL ciphertext is set, the `hermes` container SHALL send HTTPS requests through the proxy it names, except to destinations in the bypass list. The proxy URL SHALL reach the pod only as a sealed secret.

#### Scenario: External API call
- **WHEN** Hermes calls an external HTTPS API not in the bypass list
- **THEN** the request goes through the proxy

#### Scenario: Cluster and tailnet destinations
- **WHEN** Hermes calls a destination in the bypass list, such as Dex or Aperture
- **THEN** the request goes direct

#### Scenario: No plaintext token in git
- **WHEN** the chart and its values are read
- **THEN** the session token appears only as SealedSecret ciphertext

### Requirement: Hermes trusts the proxy CA
When a proxy CA is set, Hermes's Python, Node and curl clients SHALL trust it in addition to the system store and homekube's CA.

#### Scenario: Proxied TLS
- **WHEN** Hermes makes an HTTPS request through the proxy, which presents a certificate issued by its CA
- **THEN** the TLS handshake succeeds

#### Scenario: Existing trust kept
- **WHEN** Hermes calls a public HTTPS site or Dex
- **THEN** the TLS handshake still succeeds

### Requirement: Rotation restarts Hermes
The Hermes pod SHALL restart when the proxy URL ciphertext or the proxy CA changes.

#### Scenario: Session resealed
- **WHEN** a new ciphertext for the proxy URL is deployed
- **THEN** the pod is replaced and the new session is in use

### Requirement: Only the agent is proxied
The proxy settings SHALL be given only to the `hermes` container.

#### Scenario: State export
- **WHEN** the state-export sidecar runs
- **THEN** it has no proxy settings
