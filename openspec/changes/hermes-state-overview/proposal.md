# Proposal

Source issue: [#12](https://github.com/jangroth/herminator/issues/12)

## Why

The export only carries skills that differ from the image's bundled copies. That leaves out the part of Hermes' skill set that comes from upstream, so an upgrade's skill changes never appear in `herminator-state`. It also gives no quick answer to "how much state does Hermes have, and where did it come from". Of the 26 skills exported today, 25 were shipped by Hermes, not created by it.

## What Changes

- Export every skill under `skills/`, excluding its dot-directories (`.hub`, `.archive`, `.curator*` and the like). Bundled skills are no longer compared against `/opt/hermes/skills` to decide what to export. This change is **BREAKING** for readers of `herminator-state`: about 58 more skills appear in one commit.
- Each export commit message names the running Hermes image tag.
- The export maintains `README.md` at the root of `herminator-state`. It holds a generated intro and an **Overview** table, newest row first. A row is added only when a value other than the date changes. Columns:
  - date and Hermes version
  - skills: total, bundled, modified, installed, created
  - cron jobs (total and enabled), memory files, scripts
- Earlier rows are carried over from the last commit's README.

## Capabilities

### New Capabilities
- `state-overview`: the generated README in `herminator-state` that summarises Hermes' state as counts over time.

### Modified Capabilities
- `state-export`: all skills are exported, not only non-bundled or modified ones. The generated README is the one exported file not taken from `/opt/data`. Commit messages name the Hermes version.

## Impact

- `chart/files/state-export/export.sh`: skills handling, overview generation, commit message.
- `chart/templates/deployment.yaml`: the sidecar gets the image tag as an environment variable.
- `chart/values.yaml` comment, `chart/Chart.yaml` version, `CHANGELOG.md`.
- `jangroth/herminator-state`: one large commit adding the bundled skills and the README. After that, commits happen only on real changes, as before.
