# Spec Delta

## Purpose

Publishes the human-readable part of Hermes' runtime state to a private git repository, so changes to its config, skills, schedules and memories have a reviewable history, without exposing secrets or giving Hermes the push credential.

## ADDED Requirements

### Requirement: Only allowlisted state is exported
The export SHALL publish only paths on the configured allowlist: `config.yaml`, `SOUL.md`, `memories/`, `cron/jobs.json`, `scripts/`, the configured job output directories, and non-bundled or modified skills. Lock files SHALL NOT be exported. Symbolic links under `/opt/data` SHALL NOT be followed or exported.

#### Scenario: Symlink planted on the PVC
- **WHEN** an allowlisted path is, or contains, a symbolic link, including one pointing outside `/opt/data`
- **THEN** neither the link nor its target's content appears in the `herminator-state` repository

#### Scenario: Secret files stay out
- **WHEN** `/opt/data` contains `.env`, `auth.json`, `sessions/` or SQLite databases
- **THEN** none of them appear in the `herminator-state` repository

#### Scenario: Unchanged bundled skill
- **WHEN** a skill on the PVC is identical to the bundled copy shipped in the Hermes image
- **THEN** it is not exported

#### Scenario: Skill created or modified by Hermes
- **WHEN** a skill on the PVC is absent from the image's bundled skills or differs from its bundled copy
- **THEN** it is exported

#### Scenario: Path removed from the allowlist
- **WHEN** a path is removed from the allowlist
- **THEN** the next export removes it from the repository

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
