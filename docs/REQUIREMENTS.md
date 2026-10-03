# Course requirements (source: Technion DevOps Course 2026, "Final Project Catalog")

Chosen project: **Project 12 - AI Document Summarizer & Q&A** (ReadAloud is a
variant: same core, plus a Flutter Android client with text-to-speech in place of
the optional React UI).

## Mandatory for all projects (the "10 requirements")
1. Containerize all components with Docker, **multi-stage builds**
2. Terraform modules for infra provisioning (EKS, GKE, or **Minikube**)
3. Deploy to Kubernetes with Helm charts, ConfigMaps, Secrets, Ingress
4. Full CI/CD in **Jenkins** (declarative) with lint, test, scan, build, deploy stages (+ GitHub Actions)
5. Prometheus + Grafana monitoring with **custom application metrics**
6. Security scanning: Trivy (containers), GitLeaks (secrets), SonarQube (SAST)
7. Separate Git repos: App repo (code + Dockerfiles) and DevOps repo (IaC + K8s + CI/CD)
8. Liveness/readiness probes on all deployed services
9. Log aggregation with ELK or Loki (+ Promtail)
10. Document architecture decisions, deployment steps, runbooks

## Grading
App functionality (REST API completeness, error handling, validation) 25% |
Containerization 15% | Kubernetes (manifests, Helm, probes, limits) 20% |
CI/CD (completeness, security gates, tests) 20% | Monitoring (metrics, dashboards,
alerting) 10% | IaC (modules, state mgmt, reusability) 10%

## Stack details to honor
- Flask with Flask-RESTful, Flask-Migrate, Flask-SQLAlchemy; PostgreSQL 15+; pin base image versions
- Terraform: modules, **remote state backend**, **workspaces** dev/staging/prod, variables/outputs/data sources
- K8s: ConfigMaps, Secrets, Deployments, Services (ClusterIP/NodePort), NGINX Ingress, probes, resource requests+limits, PersistentVolumes for uploaded files
- Registry: Docker Hub / ECR / GHCR
- Monitoring: Alertmanager with Slack/email, pre-configured Grafana dashboards + alert rules
- Metrics via prometheus_flask_instrumentator/exporter

## Pipeline stages required
1 Lint (Flake8, ESLint if React, **Hadolint**) | 2 Test (pytest + coverage) |
3 SAST (SonarQube quality gate) | 4 Security (Trivy, GitLeaks) | 5 Build + push |
6 Deploy (Helm upgrade, dev/staging/prod) | 7 Verify (**Newman** API tests + health checks) |
8 Monitor (verify Prometheus + Grafana deployment)

## Project 12 API endpoints (from the catalog)
- POST /api/documents (upload PDF or .txt); GET /api/documents; GET /api/documents/<id> (details + summary); DELETE /api/documents/<id>
- POST /api/documents/<id>/ask; GET /api/documents/<id>/history
- GET /api/analytics (most queried docs, avg summary length)

### Status vs. the app today
Implemented: upload, list, get, delete, ask, history, summarize, chunks, progress, auth.
**Gaps to close:** `GET /api/analytics` is missing; confirm `.txt` upload is accepted;
catalog names Flask-RESTful (app uses plain Flask blueprints - decide/document in an ADR).
Pipeline items not yet in any repo: Hadolint, Newman collection, Terraform remote state/workspaces.
