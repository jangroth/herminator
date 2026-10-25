# Design

## Context

See proposal.md for motivation. The requirements are in `specs/state-export/spec.md` (modified) and `specs/state-overview/spec.md` (new).

- `export.sh` rebuilds the work tree from `/opt/data` on every run, keeping only `.git`, then stages, scans and commits only on a diff. Today `copy_skills` diffs every skill directory against `/opt/hermes/skills`.
- The live volume holds 84 skills (directories containing `SKILL.md`), 16 category-level `DESCRIPTION.md` files, and metadata in dot-entries: `.hub/`, `.archive/`, `.curator_*`, `.locks/`, `.bundled_manifest`. No skill is nested inside another.
- `skills/.bundled_manifest` lists one `name:hash` per line, keyed by the skill's directory name. The hash algorithm is undocumented.
- `cron/jobs.json` is `{"jobs": {...}, "updated_at": ...}`, and each job has an `enabled` field.
- The sidecar's `PATH` is `/usr/local/bin:/usr/bin:/bin`. `/usr/bin/python3` (Debian's 3.13) is on it, and `jq` is not.
- Today's `herminator-state` has no README.

## Goals / Non-Goals

**Goals:**
- Keep `export.sh` the single writer of `herminator-state`, so the README goes through the same scan and commit gate.
- No new image, tool or credential.

**Non-Goals:**
- Rebuilding Overview rows for exports that happened before this change.
- Counting anything that is not exported, such as sessions or `state.db`.
- Any formatting of the README beyond a Markdown table.

## Decisions

**`skills/` becomes an ordinary allowlist entry with dot-entries pruned.** The default `stateExport.paths` gains `skills`. Copying a directory prunes every path component that starts with `.` when the path is under `skills/`. Other allowlisted directories keep today's behaviour, which prunes only `.git` and `__pycache__`. `copy_skills` and its diff against `/opt/hermes/skills` are removed. *Alternative:* keep copying per skill directory. Rejected because it drops the category `DESCRIPTION.md` files for no benefit. *Alternative:* prune dot-entries everywhere. Rejected because it would silently change what `scripts/` exports.

**Classification lives only in the overview.** A skill counts as **bundled** if `diff -rq --no-dereference` (with `*.lock` and `__pycache__` excluded) finds no difference against `/opt/hermes/<same relative path>`. It is **modified** if that path exists but differs, **installed** if its directory name appears in `.bundled_manifest` and not in the image, and **created** otherwise. Only manifest names are used, never its hashes. *Alternative:* use the hub's `lock.json` for "installed". Rejected because the manifest already lists all 25 skills that are on the volume but not in the image, and it has a simple one-line-per-skill format.

**Counts and README rendering in a small Python helper.** A new `chart/files/state-export/overview.py` runs as `python3 -I`, isolated from the environment and from the script's directory, against the read-only source. It prints the README to stdout. Its inputs are the source path, the bundled-skills path, the image tag, the time, and the previous README read with `git show HEAD:README.md`. Classification and JSON parsing are awkward in bash, and without `jq` Python is the image's only JSON parser. Like the shell scripts, the helper reaches the pod through the ConfigMap.

**Overview row rule.** The helper parses the previous README's table and compares the new row with the newest one, ignoring the date column. It prepends the new row only if they differ. The intro is always regenerated. A missing or unparseable previous table starts a new one, so a hand-edited table can never block an export.

**Pipeline order.** Mirror paths → write `README.md` → remove symlinks → stage → scan → commit. The README is therefore part of the commit-only-on-diff check and the secret scan.

**Version label.** The chart passes `.Values.image.tag` to the sidecar as `HERMES_IMAGE_TAG`. The commit message becomes `export <UTC timestamp> (hermes <tag>)`, and the overview uses the same tag.

## Risks / Trade-offs

- [The first export after rollout commits about 58 skills plus 16 descriptions in one go] → Expected and one-off. betterleaks found 0 findings over the bundled skills in v0.22.2.
- [A future bundled skill contains a string betterleaks flags, blocking all exports] → The same failure mode already accepted for other content. The alerting change (#13) makes it visible.
- [Upgrade commits mix upstream skill changes with Hermes' own edits] → The commit message and the overview row name the image tag. Edits Hermes makes between upgrades show up as separate commits.
- [Dotfiles inside a skill directory are no longer exported] → Accepted. None exist today, and skills are Markdown plus scripts.
- [Manifest names could collide across categories] → None do today. A collision would at worst misclassify a skill in the counts, never change what is exported.

## Migration Plan

1. Merge. ArgoCD rolls the pod, and the next run pushes the large skills commit with the first README.
2. Rollback: revert the chart change. The next run that commits deletes the README and the unchanged bundled skills from the repo, because the old script mirrors only its own paths. Git history keeps the Overview rows.
