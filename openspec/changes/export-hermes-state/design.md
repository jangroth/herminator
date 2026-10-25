# Design

## Context

See proposal.md for motivation and specs/state-export/spec.md for requirements.

- `/opt/data` is the `hermes-data` PVC (Longhorn, ReadWriteOnce), owned by uid 1000. `config.yaml` is mode `0640`, so a reader must run as uid 1000.
- The Hermes image (pinned in `homekube-apps`, Decision 012) ships `git`, `ssh`, `bash` and Python, and the bundled skills at `/opt/hermes/skills`. It has no `rsync` and no secret scanner.
- Outbound SSH to `github.com:22` works from the pod (checked 2026-10-24).
- The `hermes` service account can only get, update and patch the Tailscale state Secret (Decision 007). `kubectl auth can-i get secret/hermes-secrets` returns `no`.
- `jangroth/herminator-state` is private and empty, with no deploy keys.

## Goals / Non-Goals

**Goals:**
- One more container in the existing pod, using images already pinned and tracked by Renovate where possible.
- The export logic is a script in this chart, reviewable in PRs.

**Non-Goals:**
- Exporting conversation history (`state.db` etc.), or any restore path from the export.
- Alerting on export failures beyond container logs.
- Automatically exporting new job output directories Hermes creates. They are added to the allowlist by hand.

## Decisions

**Sidecar, not a CronJob.** The PVC is ReadWriteOnce, so a separate pod could be scheduled on another node and fail to mount it. A container in the hermes pod shares the mount. Alternative: a Hermes cron script. Rejected because Hermes would hold the key and could edit its own export.

**Reuse the Hermes image for the sidecar.** It already has git, ssh, bash and Python, and it is pinned and Renovate-tracked. It also contains `/opt/hermes/skills`, the reference for "unchanged bundled skill". The command is overridden to run the export script. Alternative: `alpine/git` plus tools installed at start. Rejected because that would mean an unpinned install and a second image to track.

**Nothing Hermes writes can steer the sidecar's tools.** Overriding the command skips the image's entrypoint, which is what remaps the `hermes` user (uid 10000, home `/opt/data`) to uid 1000. Without a passwd entry ssh refuses to run, and with home on the PVC it would read a Hermes-planted `~/.ssh/config`. An init container writes a passwd file that maps uid 1000 to `/work/home`, mounted over `/etc/passwd` in the sidecar only, and ssh runs with `-F /dev/null`. The image's `PATH` includes `/opt/data/.local/bin`, so the sidecar sets `PATH=/usr/local/bin:/usr/bin:/bin`. Otherwise a planted `git` or `ssh` would run with the key. The deploy key's secret volume is root-owned (`fsGroup` would chown the whole PVC), so it is mounted `0444`, and `run.sh` copies it to a memory-backed `emptyDir` as `0600`.

**Bundled-skill detection by directory diff against `/opt/hermes/skills`.** A PVC skill directory is exported when no directory exists at the same relative path in the image, or when `diff -r` reports a difference. Alternative: reproduce the hashes in `skills/.bundled_manifest`. Rejected because the hash algorithm is internal to Hermes and undocumented.

**Betterleaks as the scanner.** Betterleaks is maintained by the gitleaks authors, who now focus their work there. Gitleaks' last release is v8.30.1 from March 2026, while betterleaks v1.9.0 is from September 2026. Betterleaks also detects generic secrets better, which suits the free-form text being exported (memories, job outputs, scripts). Alternative: gitleaks. Rejected because it's on the less active line, with weaker generic detection. The pin stays on v1 because v2 is at release candidate stage with CLI and config changes. Renovate will propose v2 as a separate major bump.

**Validation stays disabled.** Betterleaks can check found secrets against provider APIs (`--validation`, opt-in). Here that would send a leaked secret from the pod to a third party, so the flag is never passed and the scan makes no network requests. v1 has no revocation feature.

**Betterleaks from its own pinned image via an init container.** The init container copies the `betterleaks` binary into an `emptyDir` that the sidecar mounts. The image is `ghcr.io/betterleaks/betterleaks`, with an initial pin of `v1.9.0` (multi-arch, including arm64; entrypoint `betterleaks`). Its tag is pinned in the `homekube-apps` Application under `helm.valuesObject`, with a `# renovate:` marker so the existing custom manager tracks it, and the chart `required`s it like the other tags. Alternative: downloading a release at start. Rejected because it is unpinned unless checksum-verified, and it needs egress on every start.

**Symlinks are never followed.** Hermes writes `/opt/data` and could plant a link to the sidecar's key file, which the sidecar would resolve in its own filesystem. The copy skips symbolic links at every level, including allowlisted top-level files, and logs each skipped path. The bundled-skill comparison skips them too (`diff -r --no-dereference`). Alternative: rely on the secret scan to catch a copied key. Rejected because the scan is the second line of defence, not the first.

**Scan the staged tree, not history.** Each run builds the export into a work tree, stages it, and runs betterleaks over the staged changes before committing. Any finding aborts the run before the commit. Findings are logged with redaction, so file and rule are shown but not the value.

**Deploy key in the existing `hermes-secrets` SealedSecret.** A new key, `STATE_EXPORT_SSH_KEY`, is mounted as a file only into the sidecar through a secret volume with a single `items` entry. The Hermes container keeps using per-key `secretKeyRef`s, so it never sees the new key, and RBAC already denies API access. `shareProcessNamespace` stays unset (false). Otherwise Hermes could read the sidecar's filesystem through `/proc`.

**Pinned GitHub host keys.** `known_hosts` comes from a ConfigMap containing GitHub's published SSH host keys, with `StrictHostKeyChecking=yes`.

**Run loop that never exits on failure.** `while true; bash /scripts/export.sh || log; sleep $INTERVAL`. The export runs as a separate process with `set -euo pipefail`. Run as a shell function on the left of `||`, it would have `set -e` suppressed, and a failing scan would fall through to commit and push. The script also checks the scanner's exit status explicitly and treats anything other than "no findings" as a failure. A non-zero export is logged and retried at the next interval, and the container never crashloops. This matters because a crashlooping container would make the pod NotReady and take the dashboard Service endpoints with it. The work tree is an `emptyDir` and is re-cloned when the container restarts.

**Allowlist and interval in `values.yaml`.** The defaults follow the proposal, and the interval defaults to 3600 seconds. Commits are authored as `hermes-state-export`, with the message `export <UTC timestamp>`.

## Risks / Trade-offs

- [`USER.md` and `MEMORY.md` hold personal details, and GitHub stores them, even in a private repo] → Accepted by the user. Memories can be dropped from the allowlist later.
- [The sidecar can read secret files on the PVC, because it runs as uid 1000] → It copies only allowlisted paths, and the secret scan is a second line of defence.
- [The scanner may miss a custom secret format] → Accepted. The allowlist is the primary control.
- [Betterleaks is younger than gitleaks, and v2 will change its CLI] → Pinned to v1. The v2 bump is reviewed as its own PR, and the export script's scan command may need updating then.
- [A persistent scan finding blocks all exports until the file is fixed] → This is intended. It is visible in the sidecar logs.
- [The deploy key never expires] → Revoke it by deleting it from the repo. It only grants write access to `herminator-state`.

## Migration Plan

1. Generate the key pair, seal the private key, and add the public key to `herminator-state` with write access.
2. Merge the `homekube-apps` betterleaks pin first, because the chart will `required` the tag.
3. Merge the chart change. The pod restarts with the new sidecar.
4. Rollback: revert the chart change. The repo and the deploy key can stay, or the key can be deleted.
