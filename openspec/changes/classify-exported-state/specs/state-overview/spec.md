# Spec Delta

## MODIFIED Requirements

### Requirement: The export maintains an overview README
The export SHALL write `README.md` at the root of `herminator-state`. It contains a short intro, saying that the file is generated and that manual edits are overwritten, the Exported, Ignored and Unclassified sections, and an Overview table. The README SHALL pass the same secret scan as all other exported content.

#### Scenario: First export with the overview
- **WHEN** the export runs and the repository has no overview README yet
- **THEN** the pushed commit contains a README with the intro and one Overview row

#### Scenario: Manual edit
- **WHEN** someone edits the README's intro in `herminator-state` directly
- **THEN** the next export that commits replaces the intro with the generated text

## ADDED Requirements

### Requirement: The README documents the classification
The README SHALL contain an Exported table listing each allowlist entry with its description, in allowlist order, an Ignored table listing each ignore entry's patterns with its reason, in configured order, and an Unclassified section naming every unclassified top-level entry, sorted by name, or stating that there are none. These sections SHALL reflect the current run only.

#### Scenario: Configured lists
- **WHEN** the allowlist holds `memories` described as "agent memories" and the ignore list holds `*.db*` with reason "runtime databases"
- **THEN** the Exported table has a row for `memories` with "agent memories", and the Ignored table a row for `*.db*` with "runtime databases"

#### Scenario: Several patterns share a reason
- **WHEN** one ignore entry lists the patterns `*.lock`, `*.pid` and `*.sock` with reason "process coordination"
- **THEN** the Ignored table shows them in one row with that reason

#### Scenario: Nothing unclassified
- **WHEN** every top-level entry is exported or ignored
- **THEN** the Unclassified section states that there are none

#### Scenario: New unclassified entry
- **WHEN** a new unclassified directory appears under `/opt/data`
- **THEN** the next export commits a README whose Unclassified section names it

#### Scenario: Entry classified
- **WHEN** a previously unclassified entry is added to the allowlist or the ignore list
- **THEN** the next export's README no longer names it under Unclassified, and lists it in the matching table
