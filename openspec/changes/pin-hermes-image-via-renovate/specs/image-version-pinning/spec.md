# Spec Delta

## Purpose

Ensures every container image in the Hermes deployment runs at an explicit, recorded version, and that version changes arrive only as reviewed pull requests.

## ADDED Requirements

### Requirement: Images are pinned to explicit versions
The deployed Hermes and Tailscale images SHALL be referenced by an explicit version tag (and digest where supported), never by `latest` or another moving alias.

#### Scenario: Running version is readable from git
- **WHEN** an operator inspects the `homekube-apps` Hermes `Application`
- **THEN** the Hermes image version in use is stated there as a concrete tag

#### Scenario: Chart rendered without an override
- **WHEN** the chart is rendered without an image version supplied
- **THEN** rendering or deployment fails visibly instead of defaulting to `latest`

### Requirement: Version changes arrive as reviewed PRs
Renovate SHALL propose each new stable Hermes release as a pull request against `homekube-apps`, and no version change SHALL deploy without that PR being merged.

#### Scenario: New stable release published
- **WHEN** Hermes publishes a new plain `vX.Y.Z` tag
- **THEN** Renovate opens a PR bumping the pinned version and does not automerge it

#### Scenario: Pre-release and variant tags
- **WHEN** the registry contains `rc.*`, `-amd64`, `-arm64` or `-desktop` tags
- **THEN** Renovate does not propose them as updates

### Requirement: Version changes are revertible
Reverting the version-bump commit in `homekube-apps` SHALL restore the previously pinned image on the next ArgoCD sync.

#### Scenario: Bad upgrade rolled back
- **WHEN** the bump commit is reverted and ArgoCD syncs
- **THEN** the pod runs the previous pinned image version
