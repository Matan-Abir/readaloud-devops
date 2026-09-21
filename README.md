# ReadAloud - DevOps repo

IaC, Kubernetes/Helm, CI/CD and monitoring for the ReadAloud app (see sibling `app` repo).

## Roadmap (mapped to the 10 course requirements)

| # | Phase | Requirement | Status |
|---|-------|-------------|--------|
| 1 | Backend MVP + Dockerfile + compose (app repo) | 1, 8 | done, verified on Postgres + Gemini |
| 2 | Flutter Android client (login, upload, list, listen, summarize, ask) | app | done, APK builds, needs on-device test |
| 3 | Minikube via Terraform module (`terraform/`) | 2 | todo |
| 4 | Helm chart: backend, postgres, configmap, secret, ingress, probes, limits (`helm/readaloud`) | 3, 8 | todo |
| 5 | Jenkinsfile: lint, test, sonar, trivy, gitleaks, build, deploy, verify (+ GitHub Actions) | 4, 6 | todo |
| 6 | Prometheus + Alertmanager + Grafana dashboards (`monitoring/`) | 5 | todo |
| 7 | Loki + Promtail (`logging/`) | 9 | todo |
| 8 | ADRs, deployment steps, runbooks (`docs/`) | 10 | todo |

Requirement 7 (separate repos) is satisfied by the `app` / `devops` split.

## Resource plan (16 GB RAM machine)

- Minikube: ~6 GB / 4 CPUs (app, Postgres, ingress, Prometheus, Grafana, Loki)
- Jenkins + SonarQube: run outside the cluster in Docker Compose, started only when needed
