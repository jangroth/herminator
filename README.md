# herminator

Packaging and deploying [Hermes Agent](https://hermes-agent.nousresearch.com/) (Nous Research) onto the homekube Raspberry Pi k8s cluster.

## Status

MVP not yet built. Deployment approach is defined in [`docs/specs/001-deploy-hermes-to-homekube.md`](docs/specs/001-deploy-hermes-to-homekube.md).

## Layout

- `chart/` — Helm chart for hermes-agent (this repo's deliverable; not yet built)
- `docs/specs/` — specs for significant work items
- `local/` — local trial setup (Docker Compose), superseded by the Helm chart
- `DECISIONS.md` — decision log (why)
- `CHANGELOG.md` — change log (what was done)

## Related

- Cluster: `homekube` (`/Users/jan/Projects/kube/homekube`) — ArgoCD app-of-apps GitOps cluster this chart deploys onto.

See [`CLAUDE.md`](CLAUDE.md) for the working approach.
