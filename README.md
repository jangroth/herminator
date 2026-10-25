# herminator

Packaging and deploying [Hermes Agent](https://hermes-agent.nousresearch.com/) (Nous Research) onto the homekube Raspberry Pi k8s cluster.

## Status

Deployed to homekube via ArgoCD. Image versions are pinned in `homekube-apps` and bumped by Renovate ([DECISIONS.md #012](DECISIONS.md)). Hermes' readable runtime state (config, memories, cron jobs, scripts, and skills not identical to their bundled copies) is exported hourly to the private repo [`jangroth/herminator-state`](https://github.com/jangroth/herminator-state).

## Layout

- `chart/` — Helm chart for hermes-agent (this repo's deliverable)
- `openspec/` — [OpenSpec](https://github.com/Fission-AI/OpenSpec) capability specs (`specs/`) and in-flight changes (`changes/`)
- `docs/specs/` — legacy pre-OpenSpec specs
- `local/` — local trial setup (Docker Compose), superseded by the Helm chart
- `DECISIONS.md` — decision log (why)
- `CHANGELOG.md` — change log (what was done)

## Related

- Cluster: [`homekube`](https://github.com/jangroth/homekube) (`/Users/jan/Projects/kube/homekube`) — ArgoCD app-of-apps GitOps cluster this chart deploys onto. The `hermes` Application and its image pins live in [`homekube-apps`](https://github.com/jangroth/homekube-apps).

See [`CLAUDE.md`](CLAUDE.md) for the working approach.
