# Tasks

## 1. Export all skills

- [x] 1.1 Add `skills` to the default `stateExport.paths` and update its comment in `chart/values.yaml`. In `export.sh`, prune path components starting with `.` under `skills/`, and remove `copy_skills` and its diff against `/opt/hermes/skills`. Verify in the Hermes image with the fixture harness that the export contains:
  - identical, modified, new and installed skills
  - category `DESCRIPTION.md` files
  - no `.hub/`, `.archive/` or `.bundled_manifest`, and no dotfile inside a skill
  - unchanged results for the other directories, including that a dotfile under `scripts/` is still exported
- [x] 1.2 Pass `HERMES_IMAGE_TAG` from `.Values.image.tag` to the `state-export` container, and make the commit message `export <UTC timestamp> (hermes <tag>)`. Verify with `helm template` that the env var renders, and with the fixture that the commit message carries the tag.

## 2. Overview README

- [x] 2.1 Write `chart/files/state-export/overview.py`. It classifies skills (bundled, modified, installed, created), counts cron jobs (total and enabled), memory files and script files, and prints the README: the generated intro plus an Overview table. The previous rows are kept, and a new row goes on top only when a non-date value changes. Verify against fixtures for:
  - the 58/0/25/1 split
  - no previous README
  - an unchanged state (output identical to the input README)
  - a changed count (one new top row, old rows intact)
  - a tag-only change (new row)
  - a hand-edited or garbled table (starts a new table, exits 0)
- [x] 2.2 Call it from `export.sh` (`python3 -I`, previous README from `git show HEAD:README.md`) after mirroring and before symlink removal and staging, and add it to the `hermes-state-export` ConfigMap. Verify with the full fixture loop that:
  - the README is committed on the first run
  - a second unchanged run creates no commit
  - a fixture secret placed only in a counted file still blocks the commit
- [x] 2.3 Bump the chart version and add a `CHANGELOG.md` entry linking this change and issue #12. Verify `helm lint` passes and `openspec validate hermes-state-overview --strict` passes.

## 3. Rollout

- [ ] 3.1 After merge, verify ArgoCD is Synced/Healthy and `state-export` is ready.
- [ ] 3.2 Verify the first commit after rollout in `herminator-state`:
  - its message names the image tag
  - it adds the bundled skills and `DESCRIPTION.md` files and no dot-entries
  - the README's first row matches the counts taken from the live volume with `kubectl exec`
- [ ] 3.3 Verify a later hourly run without state changes creates no commit (`gh api repos/jangroth/herminator-state/commits`).

## Workflow follow-up

- Archive the change once verified. The archive PR closes issue #12.
