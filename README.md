# ReadAloud - DevOps repo

IaC, Kubernetes/Helm, CI/CD and monitoring for the ReadAloud app (see sibling `app` repo).

## What's here

| Path | What |
|------|------|
| `Jenkinsfile`, `jenkins/`, `scripts/` | Jenkins as code and the 8-stage pipeline (lint, test, SAST, security, build, deploy, verify, monitor) |
| `helm/readaloud` | the app chart: backend, web, Postgres, Ingress, probes, limits, ServiceMonitor, alert rules |
| `terraform/` | remote state, the platform (Minikube + monitoring/logging), environments as workspaces, and `cloud` + `cloud-platform` for the AWS demo (EC2 + k3s) |
| `tests/api` | Newman API tests (stage 7) |
| `tests/alerts` | promtool tests for the alert rules |
| `docs/` | [architecture](docs/ARCHITECTURE.md), [requirements map](docs/REQUIREMENTS_MAP.md), [ADRs](docs/adr), [deployment](docs/DEPLOYMENT.md), [runbook](docs/RUNBOOK.md), [demo script](docs/DEMO.md), [AWS demo](docs/CLOUD.md) |

Start with [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md).

## Status (10 course requirements)

| # | Requirement | Where |
|---|-------------|-------|
| 1 | Docker multi-stage builds | app repo Dockerfiles |
| 2 | Terraform modules | `terraform/modules/*`, roots `platform`, `environments`, `cloud` (AWS), `cloud-platform` |
| 3 | Helm, ConfigMaps, Secrets, Ingress | `helm/readaloud` |
| 4 | Jenkins declarative pipeline + GitHub Actions | `Jenkinsfile`, `.github/workflows` here and in the app repo |
| 5 | Prometheus + Grafana, custom metrics | `terraform/modules/monitoring`, chart ServiceMonitor, `readaloud_*` metrics |
| 6 | Trivy, GitLeaks, SonarQube | Jenkins stages 3-5 |
| 7 | Separate repos | `readaloud-app` / `readaloud-devops` |
| 8 | Probes on all services | chart templates |
| 9 | Loki + Promtail | `terraform/modules/monitoring` |
| 10 | Decisions, deployment, runbooks | `docs/` |

Details: [docs/REQUIREMENTS_MAP.md](docs/REQUIREMENTS_MAP.md).

## Resource plan (16 GB RAM machine)

- Minikube: ~6 GB / 4 CPUs (app in dev + staging, Postgres, ingress, Prometheus, Grafana, Loki)
- Jenkins + SonarQube: run outside the cluster in Docker Compose, started only when needed
