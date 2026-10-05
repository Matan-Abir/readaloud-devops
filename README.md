# ReadAloud - DevOps repo

IaC, Kubernetes/Helm, CI/CD and monitoring for the ReadAloud app (see sibling `app` repo).

## Roadmap (mapped to the 10 course requirements)

| # | Phase | Requirement | Status |
|---|-------|-------------|--------|
| 1 | Backend MVP + Dockerfile + compose (app repo) | 1, 8 | done, verified on Postgres + Gemini |
| 2 | Flutter Android client (login, upload, list, listen, summarize, ask) | app | done, APK builds, needs on-device test |
| 3 | Minikube via Terraform module (`terraform/`) | 2 | written, `terraform validate` passes; needs a run on the laptop |
| 4 | Helm chart: backend, postgres, configmap, secret, ingress, probes, limits (`helm/readaloud`) | 3, 8 | written, lint + schema validation pass; needs a Minikube install |
| 5 | Jenkinsfile: lint, test, sonar, trivy, gitleaks, build, deploy, verify (+ GitHub Actions) | 4, 6 | todo |
| 6 | Prometheus + Alertmanager + Grafana dashboards (`monitoring/`, `compose/`) | 5 | verified in the Docker demo stack; K8s values written |
| 7 | Loki + Promtail (`logging/`, `compose/`) | 9 | verified in the Docker demo stack; K8s values written |
| 8 | ADRs, deployment steps, runbooks (`docs/`) | 10 | todo |

Requirement 7 (separate repos) is satisfied by the `app` / `devops` split.

## Resource plan (16 GB RAM machine)

- Minikube: ~6 GB / 4 CPUs (app, Postgres, ingress, Prometheus, Grafana, Loki)
- Jenkins + SonarQube: run outside the cluster in Docker Compose, started only when needed

## Demo: full stack on Docker (no Kubernetes needed)

Clone both repos side by side (`readaloud-app/` and `readaloud-devops/`), then:

```bash
cd readaloud-devops/compose
APP_DIR=../../readaloud-app docker compose up -d --build
../scripts/smoke_test.sh            # register, login, upload PDF, TTS chunks, metrics
```

The stack includes the Piper natural-voice container (`tts`); its first build
downloads the voice model (en_US-lessac-medium, ~60 MB). The Grafana dashboard
has a panel for its sentences/s and latency.

| What | URL |
|------|-----|
| API health / readiness | http://localhost:8000/healthz, http://localhost:8000/readyz |
| API metrics | http://localhost:8000/metrics |
| Grafana (admin / admin) - "ReadAloud - Service Overview" dashboard, incl. live logs | http://localhost:3000 |
| Prometheus (targets, alert rules) | http://localhost:9090/targets, http://localhost:9090/alerts |
| Alertmanager | http://localhost:9093 |

Try it live: run the smoke test a few times and watch the request-rate and upload
panels move; `docker compose stop backend` fires `ReadAloudBackendDown` after 1 minute.
Stop with `docker compose down` (add `-v` to wipe data).

The dashboard JSON and alert rules are shared with the Kubernetes path
(`helm/readaloud/dashboards`, `helm/readaloud/alerts`).

## Kubernetes path (Minikube)

```bash
cd terraform && cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply     # Minikube + kube-prometheus-stack + Loki/Promtail
minikube -p readaloud image build -t readaloud-backend:latest ../../readaloud-app/backend
minikube -p readaloud image build -t readaloud-tts:latest ../../readaloud-app/tts
helm upgrade --install readaloud ../helm/readaloud -n readaloud \
  --set-string secrets.geminiApiKey="$GEMINI_API_KEY"
```
