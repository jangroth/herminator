# state-export Specification

## Purpose
Publishes the human-readable part of Hermes' runtime state to a private git repository, so changes to its config, skills, schedules and memories have a reviewable history, without exposing secrets or giving Hermes the push credential.

## Requirements

### Requirement: Only allowlisted state is exported
The export SHALL publish only paths on the configured allowlist: `config.yaml`, `SOUL.md`, `memories/`, `cron/jobs.json`, `scripts/`, the configured job output directories, and the `skills/` tree except entries whose names start with `.`. Each allowlist entry SHALL carry a description. The generated overview README is the only other file in the repository. Lock files SHALL NOT be exported. Symbolic links under `/opt/data` SHALL NOT be followed or exported.

#### Scenario: Symlink planted on the PVC
- **WHEN** an allowlisted path is, or contains, a symbolic link, including one pointing outside `/opt/data`
- **THEN** neither the link nor its target's content appears in the `herminator-state` repository

#### Scenario: Secret files stay out
- **WHEN** `/opt/data` contains `.env`, `auth.json`, `sessions/` or SQLite databases
- **THEN** none of them appear in the `herminator-state` repository

#### Scenario: Unchanged bundled skill
- **WHEN** a skill on the PVC is identical to the bundled copy shipped in the Hermes image
- **THEN** it is exported

#### Scenario: Skill created or modified by Hermes
- **WHEN** a skill on the PVC is absent from the image's bundled skills or differs from its bundled copy
- **THEN** it is exported

#### Scenario: Skill metadata stays out
- **WHEN** `skills/` contains entries whose names start with `.`, at any depth, such as `.hub/`, `.archive/` or `.bundled_manifest`
- **THEN** none of them appear in the `herminator-state` repository

#### Scenario: Path removed from the allowlist
- **WHEN** a path is removed from the allowlist
- **THEN** the next export removes it from the repository

#### Scenario: Allowlist entry without a description
- **WHEN** an allowlist entry has no description
- **THEN** the chart fails to render

### Requirement: Every top-level entry is classified
Each run SHALL classify every top-level entry under `/opt/data` as exactly one of: export, when it is the first path component of an allowlist entry; ignore, when it matches a configured ignore pattern; unclassified, otherwise. Export takes precedence over ignore. Ignore patterns SHALL be globs over top-level names, grouped into entries that each carry a reason. Classification SHALL use entry names only and SHALL NOT follow symbolic links.

#### Scenario: New directory appears
- **WHEN** Hermes creates a top-level directory that is neither allowlisted nor matched by an ignore pattern
- **THEN** the run classifies it as unclassified

#### Scenario: Ignored entry
- **WHEN** a top-level entry such as `state.db-wal` matches the ignore pattern `*.db*`
- **THEN** the run classifies it as ignored

#### Scenario: Allowlisted and matched by an ignore pattern
- **WHEN** a top-level entry is the first component of an allowlist entry and also matches an ignore pattern
- **THEN** it is classified as export and exported

#### Scenario: Ignore entry without a reason
- **WHEN** an ignore entry has no reason
- **THEN** the chart fails to render

### Requirement: Unclassified entries are not exported
The export SHALL NOT copy any content of an unclassified entry. Its name SHALL appear in the repository only in the generated README.

#### Scenario: Unclassified directory with content
- **WHEN** an unclassified directory holds files
- **THEN** none of its files appear in the `herminator-state` repository, and the README names the directory

### Requirement: A secret scan gates every push
Each export SHALL run a secret scan over the content to be committed, and SHALL NOT push when the scan reports any finding.

#### Scenario: Secret found in an allowlisted file
- **WHEN** an allowlisted file contains a credential the scanner detects
- **THEN** nothing is committed or pushed for that run, and the sidecar logs the finding's file and rule without the secret value

#### Scenario: Scanner fails to run
- **WHEN** the scanner exits with an error or cannot be executed
- **THEN** nothing is committed or pushed for that run

### Requirement: Hermes cannot access the push credential
The deploy key SHALL be readable only by the export sidecar. The Hermes container SHALL have no file, environment variable or Kubernetes API access to it.

#### Scenario: Hermes looks for the key
- **WHEN** the Hermes container searches its filesystem and environment, or requests the `hermes-secrets` Secret through the Kubernetes API with its service account
- **THEN** the key is not found and the API request is forbidden

### Requirement: The export cannot change Hermes' data
The sidecar SHALL access `/opt/data` read-only.

#### Scenario: Write attempt
- **WHEN** the sidecar attempts to write under `/opt/data`
- **THEN** the write fails

### Requirement: Exports run periodically and only commit changes
The export SHALL run at a configured interval, defaulting to hourly, and SHALL create a commit only when the exported content differs from the repository's latest commit.

#### Scenario: State changed
- **WHEN** Hermes changes an allowlisted file
- **THEN** a commit containing that change is pushed within one interval

#### Scenario: Nothing changed
- **WHEN** no allowlisted content changed since the last export
- **THEN** no commit is created

### Requirement: Export failures do not affect Hermes
A failed export SHALL NOT stop, restart or degrade Hermes or the pod's readiness.

#### Scenario: GitHub unreachable
- **WHEN** a push fails because GitHub is unreachable or rejects the key
- **THEN** the sidecar logs the error and retries at the next interval, and the Hermes dashboard stays available

### Requirement: Export commits name the Hermes version
Each export commit message SHALL include the tag of the Hermes image running in the pod.

#### Scenario: Commit after an upgrade
- **WHEN** the Hermes image is upgraded and the next export commits
- **THEN** that commit's message names the new image tag

### Requirement: A stale export raises an alert
An alert SHALL fire through the cluster's Alertmanager when no export run has succeeded for 12 hours. A run succeeds when it pushed, or when it found nothing to push. Missing export metrics SHALL count as no success.

#### Scenario: Secret scan keeps blocking
- **WHEN** every export run for 12 hours is blocked by a secret-scan finding
- **THEN** an alert fires that names the failure as a scan finding

#### Scenario: Push keeps failing
- **WHEN** every export run for 12 hours fails to push, for example because the deploy key was revoked
- **THEN** an alert fires

#### Scenario: Metrics disappear
- **WHEN** Prometheus has had no export metrics from the sidecar for 12 hours
- **THEN** an alert fires

#### Scenario: Exports recover
- **WHEN** a run succeeds after the alert fired
- **THEN** the alert resolves

#### Scenario: Healthy export with nothing to push
- **WHEN** runs keep succeeding without changes for more than 12 hours
- **THEN** no alert fires

### Requirement: Failure logs carry the real exit code
When an export run fails, the sidecar's log line SHALL report that run's exit code.

#### Scenario: Run fails
- **WHEN** an export run exits with a non-zero code
- **THEN** the log line names that code
