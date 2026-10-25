# Spec Delta

## Purpose

Gives a high-level, chronological view of how much state Hermes holds and where its skills come from, as a README in the `herminator-state` repository that the export maintains.

## ADDED Requirements

### Requirement: The export maintains an overview README
The export SHALL write `README.md` at the root of `herminator-state`. It contains a short intro, saying that the file is generated and that manual edits are overwritten, and an Overview table. The README SHALL pass the same secret scan as all other exported content.

#### Scenario: First export with the overview
- **WHEN** the export runs and the repository has no overview README yet
- **THEN** the pushed commit contains a README with the intro and one Overview row

#### Scenario: Manual edit
- **WHEN** someone edits the README's intro in `herminator-state` directly
- **THEN** the next export that commits replaces the intro with the generated text

### Requirement: Overview rows record state counts
Each Overview row SHALL record the date and time (UTC), the Hermes image tag, the skill counts, the number of cron jobs and how many are enabled, the number of memory files, and the number of script files.

#### Scenario: Row contents
- **WHEN** a row is added
- **THEN** it shows the UTC time, the image tag, the skill total with its four-way split, cron jobs as total and enabled, memory files and script files

### Requirement: Skills are classified by origin
A skill SHALL be a directory under `skills/` that contains `SKILL.md`, outside entries whose names start with `.`. Each skill SHALL be counted as exactly one of the following:
- bundled: identical to the image's copy
- modified: differs from the image's copy
- installed: listed in `skills/.bundled_manifest` but absent from the image
- created: none of the above

#### Scenario: Counts match the volume
- **WHEN** `/opt/data` holds 84 skills, of which 58 are identical to the image, 0 differ, 25 are listed in the manifest only and 1 is in neither
- **THEN** the newest row shows 84 skills: 58 bundled, 0 modified, 25 installed, 1 created

### Requirement: Rows are added only on change, newest first
The export SHALL add a row at the top of the Overview table only when any value other than the date differs from the newest existing row. Earlier rows SHALL be kept unchanged.

#### Scenario: Nothing counted changed
- **WHEN** an export runs and every value except the date matches the newest row
- **THEN** the README is unchanged

#### Scenario: A count changed
- **WHEN** Hermes creates a new skill
- **THEN** the next export adds a row at the top showing the new totals, and all earlier rows remain

#### Scenario: Hermes upgraded without count changes
- **WHEN** the Hermes image tag changes but no count does
- **THEN** a new row is added showing the new tag
