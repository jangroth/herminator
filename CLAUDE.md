# herminator

Packaging and deploying [Hermes Agent](https://hermes-agent.nousresearch.com/) (Nous Research) onto the homekube Raspberry Pi k8s cluster.

## Working Approach

- **Spec-driven ([OpenSpec](https://github.com/Fission-AI/OpenSpec))**: propose an OpenSpec change (`/opsx:propose`) before any significant implementation, apply it (`/opsx:apply`), and archive it once verified (`/opsx:archive`). Changes live in `openspec/changes/`; `openspec/specs/` is the current truth, updated only by archiving. Run `openspec validate <change> --strict` before opening a PR. A change's `proposal.md` links the issue it came from, and the archive PR closes it. `docs/specs/` is legacy (Spec 001), not to be extended.
- **Decision log**: record decisions that live outside a single OpenSpec change (no-change decisions, decisions spanning changes, amendments) in `DECISIONS.md`, newest decision first. Decisions capture **why**. Decisions made within a change stay in its `design.md`.
- **Change log**: append every material change to `CHANGELOG.md` (top-level, reverse-chronological, [Keep a Changelog](https://keepachangelog.com) format). Captures **what was done** — distinct from `DECISIONS.md`.
- **Todo**: open tasks tracked as GitHub Issues on this repo (not homekube's shared tracker — see DECISIONS.md #006), always labelled `todo` + `agent-safe`. `agent-safe` marks issues that are unambiguous, reversible, PR-only fixes with no open design decision or physical/external-account step — safe for autonomous implementation.
- **Trust**: propose, human approves for destructive/irreversible operations.
- **Cross-repo boundary**: this repo owns the Hermes Helm chart (`chart/`). The separate `homekube-apps` repo owns the thin ArgoCD `Application` and Dex `staticClients` wiring that references this repo. A material change on the homekube-apps side gets an entry in *both* repos' logs (this repo's, and homekube's own `DECISIONS.md`/`CHANGELOG.md`).

## Key Files

- `DECISIONS.md` — decision log (why)
- `CHANGELOG.md` — change log (what was done)
- `openspec/specs/` — current-truth capability specs
- `openspec/changes/` — in-flight changes; `archive/` holds completed ones
- `docs/specs/` — legacy pre-OpenSpec specs
- `chart/` — the Helm chart for hermes-agent

## Related

- Cluster: `/Users/jan/Projects/kube/homekube` — ArgoCD app-of-apps GitOps; ArgoCD watches its `homekube-apps` repo.
