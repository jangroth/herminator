# Proposal

Source issue: [#25](https://github.com/jangroth/herminator/issues/25)

## Why

The export copies an allowlist, so a new top-level entry under `/opt/data` is silently left out. `package-manifest/`, written by the new `package-manifest-watchdog` cron job, is the current example: nothing shows it isn't exported. `/opt/data` holds about 80 top-level entries, and the full set of exported paths isn't documented anywhere. The spec only says "the configured job output directories".

## What Changes

- Every top-level entry under `/opt/data` is classified as one of:
  - **export**: on the allowlist, as today.
  - **ignore**: matches an ignore pattern that has a reason.
  - **unclassified**: neither.
- Each `stateExport.paths` entry gains a description. **BREAKING** for value overrides: entries become `{path, description}` objects instead of strings. No override exists today.
- New `stateExport.ignore` list of `{pattern, reason}` entries, where a pattern is a glob over top-level names.
- The generated `herminator-state` README gains three sections:
  - an **Exported** table (path, description)
  - an **Ignored** table (pattern, reason)
  - an **Unclassified** list of names
- Unclassified entries are never copied. Only their names reach the repository, in the README, which passes the same secret scan as everything else.
- Initial classification of today's entries. `package-manifest` is added to the allowlist; the rest are sorted into export or ignore so the Unclassified list starts empty.
- Out of scope: any notification about unclassified entries, whether a Hermes cron job or an Alertmanager rule. Checking is manual via the README until there is data on how often new entries appear.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `state-export`: the allowlist carries descriptions, and every top-level entry under `/opt/data` is classified against the allowlist and a new ignore list. Unclassified entries are not exported.
- `state-overview`: the README documents the export and ignore lists and names unclassified entries.

## Impact

- `chart/values.yaml`: `stateExport.paths` format, new `stateExport.ignore`, initial classification.
- `chart/templates/deployment.yaml`: how paths and ignore patterns reach the sidecar.
- `chart/files/state-export/export.sh` and `overview.py`: classification and the new README sections.
- `chart/Chart.yaml` version, `CHANGELOG.md`, `README.md` (link to the generated list).
- `jangroth/herminator-state`: one commit adding `package-manifest/` and the new README sections.
