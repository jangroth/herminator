# herminator

Packaging and deploying [Hermes Agent](https://hermes-agent.nousresearch.com/) (Nous Research) onto the homekube Raspberry Pi k8s cluster.

## Working Approach

- **Spec-driven**: write a spec in `docs/specs/NNN-title.md` before any significant implementation. Specs define the problem, acceptance criteria, and approach.
- **Decision log**: record key decisions in `DECISIONS.md`, newest decision first. Decisions capture **why**.
- **Change log**: append every material change to `CHANGELOG.md` (top-level, reverse-chronological, [Keep a Changelog](https://keepachangelog.com) format). Captures **what was done** — distinct from `DECISIONS.md`.
- **Todo**: open tasks tracked as GitHub Issues on this repo (not homekube's shared tracker — see DECISIONS.md #006). Label `agent-safe` marks issues that are unambiguous, reversible, PR-only fixes with no open design decision or physical/external-account step — safe for autonomous implementation.
- **Trust**: propose, human approves for destructive/irreversible operations.
- **Cross-repo boundary**: this repo owns the Hermes Helm chart (`chart/`). The separate `homekube-apps` repo owns the thin ArgoCD `Application` and Dex `staticClients` wiring that references this repo. A material change on the homekube-apps side gets an entry in *both* repos' logs (this repo's, and homekube's own `DECISIONS.md`/`CHANGELOG.md`).

## Key Files

- `DECISIONS.md` — decision log (why)
- `CHANGELOG.md` — change log (what was done)
- `docs/specs/` — specs for significant work items
- `chart/` — the Helm chart for hermes-agent (once built)

## Related

- Cluster: `/Users/jan/Projects/kube/homekube` — ArgoCD app-of-apps GitOps; ArgoCD watches its `homekube-apps` repo.
