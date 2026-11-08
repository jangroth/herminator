# Spec Delta

## MODIFIED Requirements

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

## ADDED Requirements

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
