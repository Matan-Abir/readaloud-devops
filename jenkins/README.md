# Jenkins + SonarQube (local CI)

Runs on your PC in Docker, only when you need it. Everything is configured as
code: the admin user, the SonarQube token, the credentials and the `readaloud`
pipeline job exist as soon as Jenkins starts.

| Service   | URL                    | Login                                   |
|-----------|------------------------|-----------------------------------------|
| Jenkins   | http://localhost:8081  | `admin` / `JENKINS_ADMIN_PASSWORD` (default `admin`) |
| SonarQube | http://localhost:9000  | `admin` / `SONAR_ADMIN_PASSWORD`        |

```powershell
cd jenkins
copy .env.example .env          # optional: change the passwords
docker compose up -d --build    # first start: ~5 min (plugins + SonarQube)
```

Then open Jenkins, click **readaloud**, **Build with Parameters**, **Build**.
Stages 6-8 need the cluster from `terraform/platform` and the namespaces from
`terraform/environments` (see `docs/DEPLOYMENT.md`); untick **DEPLOY** to run
stages 1-5 only. Put your Gemini key in `.env` (`GEMINI_API_KEY`) so the deployed
app can summarize.

## The pipeline (`../Jenkinsfile`)

| Stage | What runs | Fails the build when |
|-------|-----------|----------------------|
| 1 Lint | flake8 (backend), Hadolint (both Dockerfiles) | any lint finding |
| 2 Test | pytest with coverage; JUnit + coverage reports in the build | a test fails |
| 3 SAST | SonarQube scan, waits for the quality gate | quality gate fails |
| 4 Security | GitLeaks (git history), Trivy on dependency files | a secret, or a fixable HIGH/CRITICAL CVE |
| 5 Build + push | builds backend + web images, Trivy scans them, pushes to GHCR if `PUSH_IMAGES` | fixable HIGH/CRITICAL CVE in an image |
| Cluster access | finds the Minikube node, writes a kubeconfig, loads the new images into the node | the cluster isn't running |
| 6 Deploy | `helm upgrade --install --wait --rollback-on-failure` to dev, then staging, then prod (with approval, off by default) | pods never get Ready (Helm rolls back) |
| 7 Verify | rollout status, `/healthz` + `/readyz`, Newman API collection per environment (JUnit report) | a health check or API test fails |
| 8 Monitor | Prometheus scrapes the new pods, Grafana and Loki healthy, backend logs in Loki, no ReadAloud alert firing | monitoring is down; a firing alert makes the build unstable |

Each tool runs in its own pinned container (`agent { docker { ... } }`), so the
Jenkins image only needs the Docker CLI.

## How the pieces connect

- Jenkins uses your Docker Desktop through the mounted Docker socket.
- `sonar-init` waits for SonarQube, changes the default `admin/admin` password,
  creates a token and stores it in a volume; Jenkins reads it as the
  `sonar-token` credential (`casc.yaml`).
- All services share the Docker network `ci`, which the SonarQube scanner
  stage joins to reach `http://sonarqube:9000`.

## Troubleshooting

- `sonar-init` keeps waiting: `docker compose logs sonarqube`. If it mentions
  `disk watermark`, free disk space in Docker Desktop (Settings > Resources).
- Changed `casc.yaml` or `plugins.txt`: `docker compose up -d --build jenkins`.
- Start over completely: `docker compose down -v` (deletes Jenkins and Sonar data).
