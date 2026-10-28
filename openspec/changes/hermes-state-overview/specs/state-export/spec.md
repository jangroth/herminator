# Spec Delta

## MODIFIED Requirements

### Requirement: Only allowlisted state is exported
The export SHALL publish only paths on the configured allowlist: `config.yaml`, `SOUL.md`, `memories/`, `cron/jobs.json`, `scripts/`, the configured job output directories, and the `skills/` tree except entries whose names start with `.`. The generated overview README is the only other file in the repository. Lock files SHALL NOT be exported. Symbolic links under `/opt/data` SHALL NOT be followed or exported.

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

## ADDED Requirements

### Requirement: Export commits name the Hermes version
Each export commit message SHALL include the tag of the Hermes image running in the pod.

#### Scenario: Commit after an upgrade
- **WHEN** the Hermes image is upgraded and the next export commits
- **THEN** that commit's message names the new image tag
