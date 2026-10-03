# HANDOFF - read this first (for a new AI agent / collaborator)

Last updated: 2026-10-03

## 1. What this project is
**ReadAloud**: a mobile app where a user uploads a PDF and listens to it like an
audiobook (device text-to-speech), can get an LLM summary, and ask questions about
the document (Google Gemini).

This is **DevOps course final-project work**. The grade is about the DevOps
practices around the app (IaC, Kubernetes/Helm, CI/CD, security scanning,
monitoring, logging, docs), NOT about app features. Keep the app small; put effort
into the pipeline/infrastructure. Do not gold-plate app features.

## 2. Repository layout (two repos - course requirement 7)
Both live side by side locally in `D:\DevOpsPro\Final Project\`:

| Repo | Contents |
|------|----------|
| `app/` | Flask backend (`backend/`), Flutter Android client (`mobile/`), `docker-compose.yml`, backend Dockerfile |
| `devops/` | Infra/ops: Terraform, Helm, Jenkinsfile, monitoring, logging, docs (this file). Currently only README + docs |

Root folder `Final Project/` is NOT a git repo; each subfolder is its own repo.

## 3. What has been done
- **Backend (done, verified on Postgres + Gemini)**: Flask API. Endpoints under
  `/api/auth` (register/login, JWT) and `/api/documents` (upload PDF, list, text
  chunks for TTS, summary, Q&A). `app/metrics.py` exposes Prometheus metrics
  (prometheus-flask-exporter). Alembic migrations in `backend/migrations`
  (run automatically on compose start via `flask db upgrade`). Gemini retry logic
  in `app/llm.py`. Tests: pytest (SQLite in-memory `TestConfig`), flake8 config.
- **Dockerfile + docker-compose** (Postgres 15 + backend on :8000, gunicorn).
- **Flutter Android client (done, APK builds, NOT yet tested on a real device)**:
  login, document library, TTS reader, summary, Q&A. API URL set at build time via
  `--dart-define=API_BASE_URL=...`. Tests: `flutter analyze && flutter test`.
- Roadmap README in `devops/` mapping phases to course requirements.

## 4. What is NOT done (current scope = remaining work, in order)
See the roadmap table in `devops/README.md`. Status: phases 1-2 done, 3-8 todo.
3. Minikube via Terraform module (`devops/terraform/`) - req 2
4. Helm chart `devops/helm/readaloud`: backend, postgres, configmap, secret, ingress,
   probes, resource limits - req 3, 8
5. `Jenkinsfile`: lint, test, SonarQube, Trivy, gitleaks, build image, deploy,
   verify (+ optionally GitHub Actions) - req 4, 6
6. Prometheus + Alertmanager + Grafana dashboards (`devops/monitoring/`) - req 5
7. Loki + Promtail (`devops/logging/`) - req 9
8. ADRs, deployment steps, runbooks (`devops/docs/`) - req 10

**Caveat:** the full text of the course's 10 requirements is not stored in the repo;
only the numbers referenced above. Ask the user for the official requirement list
and add it to `docs/REQUIREMENTS.md` before finalizing anything.

## 5. Constraints and decisions
- Dev machine: Windows 10, 16 GB RAM. Minikube budget ~6 GB / 4 CPUs.
- Jenkins + SonarQube run **outside** the cluster in Docker Compose, started only
  when needed (RAM).
- Git workflow so far: feature branches merged into `master` with merge commits.
- LLM is Gemini (`GEMINI_API_KEY`); default model `gemini-flash-latest`.
- TTS happens on the phone, not the server (server only returns text chunks).

## 6. Secrets - important
- `app/.env` holds real secrets and is **gitignored**. Never commit it. Only
  `.env.example` is tracked. Run gitleaks before pushing.
- In Kubernetes, secrets must come from a Secret object, not values in git.

## 7. How to run / test
See `app/README.md`. Short version:
```bash
cd app && cp .env.example .env   # fill secrets
docker compose up --build        # API on :8000
cd backend && pip install -r requirements-dev.txt && flake8 . && pytest
cd mobile && flutter analyze && flutter test
```

## 8. Suggested next step
Phase 3: write the Terraform module that provisions Minikube (docker/hyperv driver
on Windows), then Phase 4 Helm chart. Verify each phase actually runs before
marking it done in `devops/README.md`, and update this file's section 3/4 each time.
