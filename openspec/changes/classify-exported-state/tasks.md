# Tasks

## 1. Values and transport

- [x] 1.1 Convert `stateExport.paths` in `chart/values.yaml` to `{path, description}` entries and add `stateExport.ignore` as `{reason, patterns}` entries, using the initial classification in design.md. First re-list `/opt/data` with `kubectl exec` and adjust the table to any entries that changed. Update the comments. Verify that `helm template` renders and that a missing `description`, `reason` or `patterns` fails rendering.
- [x] 1.2 In `chart/templates/deployment.yaml`, build `STATE_EXPORT_PATHS` from `.path`, and add `STATE_EXPORT_CLASSIFICATION` as `toJson` of `{paths, ignore}`. Verify with `helm template` that `STATE_EXPORT_PATHS` is byte-identical to today's apart from the new `package-manifest`, `hooks`, `plugins`, `skins` and `plans` lines, and that the JSON parses.

## 2. Classification and README

- [x] 2.1 In `overview.py`, classify the top-level entries of the source as export, ignore or unclassified, as in design.md. Verify against a fixture tree for:
  - an allowlisted nested path (`cron/jobs.json`) making `cron` export
  - a name matching both lists being export
  - a dot-name matched by `*cache*`
  - a top-level symlink classified by its name and not followed
  - an unmatched directory being unclassified
- [x] 2.2 Render `## Exported`, `## Ignored` and `## Unclassified` between the intro and `## Overview`, with backticked paths and patterns and escaped `|`. Unclassified is "None." when empty. Verify with fixtures that:
  - previous Overview rows are carried over unchanged
  - an unchanged state yields an identical README
  - a new unclassified directory changes only the Unclassified section
- [x] 2.3 Verify with the full fixture loop in the Hermes image (`export.sh` against a fixture `/opt/data`) that:
  - an unclassified directory's files are not in the commit, and its name is in the README
  - a second unchanged run creates no commit
- [x] 2.4 Update `README.md` to link the generated Exported section in `herminator-state` instead of its own parenthetical list. Bump the chart version and add a `CHANGELOG.md` entry linking this change and issue #25. Verify that `helm lint` and `openspec validate classify-exported-state --strict` pass.

## 3. Rollout

- [ ] 3.1 After merge, verify ArgoCD is Synced/Healthy and `state-export` is ready.
- [ ] 3.2 Verify the first commit after rollout in `herminator-state`:
  - it adds `package-manifest/`
  - its README shows the Exported and Ignored tables
  - Unclassified is "None.", or lists only entries created since apply
  - the Overview rows are intact

## Workflow follow-up

- Archive the change once verified. The archive PR closes issue #25.
