# herminator

Packaging and deploying [Hermes Agent](https://hermes-agent.nousresearch.com/) (Nous Research) onto the homekube Raspberry Pi k8s cluster. The Helm chart is in `chart/`.

## Change workflow

Significant work goes through an [OpenSpec](https://github.com/Fission-AI/OpenSpec) change. `openspec/specs/` is the current truth, updated only by archiving; `docs/specs/` is legacy (Spec 001) and stays frozen.

1. **Propose** (`/opsx:propose`): the change folder exists in `openspec/changes/`, and its `proposal.md` links the issue it came from.
2. **Open the draft PR**: the change's branch is pushed and a draft PR (`Refs #<issue>`) holds only the artifacts.
3. **Track**: the issue has a `## Tracking` section linking the change folder, branch and draft PR, noting that the archive PR closes the issue.
4. **Apply** (`/opsx:apply`): the implementation is on the same branch, and `openspec validate <change> --strict` passes.
5. **Archive** (`/opsx:archive`) once verified: the archive PR closes the issue.

## Records

- **Decision log**: record decisions that live outside a single OpenSpec change (no-change decisions, decisions spanning changes, amendments) in `DECISIONS.md`, newest decision first. Decisions capture **why**. Decisions made within a change stay in its `design.md`.
- **Change log**: append every material change to `CHANGELOG.md` (top-level, reverse-chronological, [Keep a Changelog](https://keepachangelog.com) format). Captures **what was done** — distinct from `DECISIONS.md`.
- **Todo**: open tasks tracked as GitHub Issues on this repo, not homekube's shared tracker (DECISIONS.md #006).
- **Cross-repo boundary**: `homekube-apps` owns the thin ArgoCD `Application` and Dex `staticClients` wiring that references this repo. A material change on the homekube-apps side gets an entry in *both* repos' logs (this repo's, and homekube's own `DECISIONS.md`/`CHANGELOG.md`).
