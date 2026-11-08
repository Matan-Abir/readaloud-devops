# Course requirements, and where each one is met

Source: [REQUIREMENTS.md](REQUIREMENTS.md) (Project 12). "Shown by" is what to
open or run in the demo.

## The 10 mandatory requirements

| # | Requirement | Where | Shown by |
|---|---|---|---|
| 1 | Docker, multi-stage builds for all components | app repo: `backend/Dockerfile` (builder, voice download, slim non-root runtime), `mobile/Dockerfile` (Flutter build, nginx-unprivileged); pinned base images; Hadolint in CI | `docker compose up --build`, Jenkins stage 1 Hadolint |
| 2 | Terraform modules (Minikube) | `terraform/modules/{minikube-cluster,monitoring,app-environment}`, roots `platform` and `environments` | `terraform apply`, `terraform workspace list` |
| 3 | Helm, ConfigMaps, Secrets, Ingress | `helm/readaloud`: ConfigMap, Secret (generated once, kept on upgrade), NGINX Ingress for `/` and `/api`, values per environment | `kubectl get all,ingress,cm,secret -n dev` |
| 4 | Jenkins declarative pipeline (+ GitHub Actions) | `Jenkinsfile` (8 stages), Jenkins as code in `jenkins/`; GitHub Actions in both repos | a green Jenkins run, the Actions tab |
| 5 | Prometheus + Grafana, custom app metrics | `terraform/modules/monitoring`, ServiceMonitor in the chart, `readaloud_*` metrics in the app, ReadAloud dashboard | Grafana dashboard moves while you use the app |
| 6 | Trivy, GitLeaks, SonarQube | Jenkins stages 3 and 4 (+5 for images); Trivy and GitLeaks also in GitHub Actions | SonarQube project page, Trivy output in Jenkins |
| 7 | Separate app and DevOps repos | `readaloud-app`, `readaloud-devops` | - |
| 8 | Liveness / readiness probes on all services | backend: startup + liveness `/healthz`, readiness `/readyz` (checks the DB); web: liveness + readiness; Postgres: `pg_isready` | `kubectl describe deploy readaloud-backend -n dev` |
| 9 | Log aggregation (Loki + Promtail) | `terraform/modules/monitoring` (Loki single binary, Promtail DaemonSet), logs panel on the dashboard | Grafana Explore: `{namespace="dev", container="backend"}` |
| 10 | Architecture decisions, deployment steps, runbooks | `docs/ARCHITECTURE.md`, `docs/adr/`, `docs/DEPLOYMENT.md`, `docs/RUNBOOK.md`; app ADR in the app repo | these files |

## Pipeline stages

| Stage | Course asks for | Jenkinsfile |
|---|---|---|
| 1 Lint | Flake8, Hadolint | `1 Lint` (parallel flake8 + Hadolint) |
| 2 Test | pytest + coverage | `2 Test` (JUnit + Cobertura reports on the build page) |
| 3 SAST | SonarQube quality gate | `3 SAST (SonarQube)` with `qualitygate.wait` |
| 4 Security | Trivy, GitLeaks | `4 Security` (GitLeaks on history, Trivy on dependencies) |
| 5 Build + push | images to a registry | `5 Build + push` (Trivy image scan; push to GHCR with `PUSH_IMAGES`) |
| 6 Deploy | Helm upgrade, dev / staging / prod | `6 Deploy: dev`, `6 Deploy: staging`, `6 Deploy: prod` (manual approval) |
| 7 Verify | Newman API tests + health checks | `7 Verify: <env>`: rollout status, `/healthz` + `/readyz`, Newman collection with JUnit report |
| 8 Monitor | Prometheus + Grafana deployed | `8 Monitor`: new pods scraped, Grafana and Loki healthy, logs arriving, no ReadAloud alert firing |

## Stack details

| Detail | Status |
|---|---|
| Flask-Migrate, Flask-SQLAlchemy, PostgreSQL 15 | yes |
| Flask-RESTful | kept plain Flask blueprints, see app repo `docs/adr/0001` |
| Pinned base images | yes (`python:3.12.16-slim-trixie`, `postgres:15.19-alpine`, ...) |
| Terraform remote state | `pg` backend in a local Postgres (`terraform/state`); S3 example included ([ADR 0005](adr/0005-terraform-remote-state-and-workspaces.md)) |
| Terraform workspaces dev / staging / prod | `terraform/environments` |
| Variables, outputs, modules | all roots and modules |
| ClusterIP Services, NGINX Ingress | yes |
| Requests + limits | every container; LimitRange defaults for the rest; ResourceQuota per environment |
| PersistentVolumes for uploads | `readaloud-uploads` PVC, Postgres volumeClaimTemplate |
| Registry | GHCR (GitHub Actions on master, Jenkins with `PUSH_IMAGES`) |
| Alertmanager with Slack / email | receivers wired from Terraform variables; an in-cluster webhook shows delivery without credentials |
| Pre-configured dashboards + alert rules | ReadAloud dashboard (ConfigMap), 6 rules per environment, tested with promtool |
| Metrics via prometheus-flask-exporter | yes, plus `readaloud_*` custom metrics |

## API endpoints (Project 12)

All implemented and covered by the Newman collection: upload (PDF or `.txt`),
list, get, delete, ask, history, summarize, analytics (`most_asked`,
`avg_summary_chars`), plus auth, read-aloud chunks, progress and the voice.
