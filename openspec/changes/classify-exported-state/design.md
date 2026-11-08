# Design

## Context

See proposal.md for motivation. The requirements are in `specs/state-export/spec.md` and `specs/state-overview/spec.md`.

- `stateExport.paths` is a list of strings. The deployment joins it with newlines into `STATE_EXPORT_PATHS`, and `export.sh` copies each path. Nothing else reads it.
- `overview.py` already walks `/opt/data` read-only under `python3 -I` and writes the whole README: intro, then the Overview table. It finds the previous table by its exact header line.
- Live `/opt/data` on 2026-11-08 (Hermes image of that date): 79 top-level entries, including 21 dotfiles or `*.db*`/`*.lock` files. Three enabled cron jobs: `morning-briefing`, `nvim-tips`, `package-manifest-watchdog`. Each writes a directory of the same name.
- No values override of `stateExport` exists in homekube-apps.

## Goals / Non-Goals

**Goals:**
- `overview.py` stays the only place that computes anything for the README, and `export.sh` stays the only writer of `herminator-state`.
- Copying stays driven by the allowlist alone, so an unclassified entry can't be copied by construction.

**Non-Goals:**
- Classifying anything below the top level. For example, `cron/executions.db` sits inside the exported `cron/` entry and isn't surfaced.
- Any notification, metric or alert for unclassified entries.
- A history of classifications in the README. The README's git history covers that.

## Decisions

**Values shape.** Each `paths` entry becomes `{path, description}`. `ignore` is a list of `{reason, patterns}`, so one reason can cover several patterns and the Ignored table stays readable: about 15 rows instead of 40. The templates use `required` on `description`, `reason` and `patterns`, so a missing one fails rendering. *Alternative:* one `{pattern, reason}` per pattern, closer to the issue's wording. Rejected because most reasons repeat (runtime state, caches, credentials). *Alternative:* keep `paths` as strings and add descriptions in a separate map. Rejected because the two would drift.

**Transport to the sidecar.** `STATE_EXPORT_PATHS` keeps its newline-joined form, built from `.path`, so `export.sh`'s copy loop is unchanged. A new `STATE_EXPORT_CLASSIFICATION` env var carries `toJson` of `{paths, ignore}` for `overview.py`. An env var change rolls the pod, so new values take effect at once. *Alternative:* a ConfigMap key. Rejected because the pod has no checksum annotation and wouldn't restart.

**Classification in `overview.py`.** It lists the top-level names under the source with `os.listdir`, never following links. For each name:
- **export** if it equals the first component of any allowlist path;
- **ignore** if `fnmatch.fnmatchcase` matches any pattern, where `*` also matches a leading `.`;
- **unclassified** otherwise.

This keeps classification next to the other counts, in Python rather than bash glob handling. *Alternative:* classify in `export.sh` and pass the result in. Rejected because the README is the only consumer.

**README layout.** Intro, then `## Exported` (path, description), `## Ignored` (patterns, reason), `## Unclassified` (a bullet list, or "None."), then `## Overview` last. Paths and patterns are rendered in backticks, and `|` in descriptions is escaped. The previous Overview rows are still found by their header line, so the new sections before it don't affect parsing. The first export after rollout regenerates the README, the same way any intro change does.

**Initial classification.** Today's entries, so that Unclassified starts empty:

| Group | Entries | Reason / description |
|---|---|---|
| export (existing) | `config.yaml`, `SOUL.md`, `memories`, `cron/jobs.json`, `scripts`, `skills`, `morning-briefing`, `nvim-tips` | as today |
| export (new) | `package-manifest` | `package-manifest-watchdog` output: packages installed outside the image (4 files, 28K) |
| export (new) | `hooks`, `plugins`, `skins`, `plans` | user-authored extension points and plans, empty today; exporting them catches future content |
| ignore | `.env`, `auth.json`, `shared`, `pairing` | credentials and tokens |
| ignore | `.hermes_history` | CLI input history; may hold pasted secrets |
| ignore | `sessions`, `*.db`, `*.db-*` | conversation transcripts and runtime databases |
| ignore | `*.lock`, `*.pid`, `*.sock` | process coordination |
| ignore | `*cache*` | regenerable caches |
| ignore | `logs`, `*.log`, `kanban` | logs, including kanban task-run logs and workspaces |
| ignore | `home`, `.local`, `lazy-packages`, `bin`, `installs` | installed tools and packages; `package-manifest` documents them |
| ignore | `state`, `runtime`, `pending`, `pending_messages`, `telemetry`, `plugin-update-checks`, `gateway_state.json`, `channel_directory.json`, `spawn-ledger.json`, `telegram_update_receipts_*`, `install_id`, `tui-theme-boot.json`, `.scratch_tip_shown`, `.skills_prompt_snapshot.json` | runtime state |
| ignore | `backups`, `.curator_backups` | copies of exported files; git history covers them |
| ignore | `images` | generated binary images |
| ignore | `briefing`, `.hermes` | stale scratch from August 2026 (morning-briefing prototype, one plan file) |
| ignore | `desktop`, `platforms`, `sandboxes`, `workspace`, `lost+found` | empty or filesystem-managed |

Apply re-lists `/opt/data` and adjusts this table if entries have changed by then.

## Risks / Trade-offs

- [A broad pattern such as `*cache*` or `*.db*` hides a future meaningful entry] → Accepted. Those patterns match by naming convention, and the Ignored table shows each pattern, so a too-broad one is visible.
- [A newly exported entry like `package-manifest` holds something the secret scan flags, blocking all exports] → The same failure mode as for other content. `HermesStateExportStale` reports it within 12h.
- [Unclassified names are themselves data leaving the cluster] → Names only, and they pass the secret scan as part of the README. A secret in a file name is far-fetched.
- [Unclassified entries go unnoticed because nobody reads the README] → Accepted for now. This is the reconnaissance phase, and notification can be added on top of the same classification.

## Migration Plan

1. Merge. ArgoCD rolls the pod, and the next run commits `package-manifest/` and the regenerated README.
2. Rollback: revert the chart change. The next run that commits drops `package-manifest/` and the new README sections. The Overview rows are kept, because the old `overview.py` parses them by header.
