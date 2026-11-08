# Deploying ReadAloud from zero (Windows, PowerShell)

Everything runs on one PC: Docker Desktop, a Minikube cluster, and Jenkins +
SonarQube in Docker. Both repos sit side by side:

```
D:\Final Project\V1\readaloud-app
D:\Final Project\V1\readaloud-devops
```

Times are for the first run; later runs reuse images and are much faster.

## 0. Tools and memory (once)

```powershell
winget install -e --id Docker.DockerDesktop
winget install -e --id Kubernetes.minikube
winget install -e --id Kubernetes.kubectl
winget install -e --id Helm.Helm
winget install -e --id Hashicorp.Terraform
winget install -e --id Git.Git
```

Close and reopen PowerShell, then check each one answers:
`docker version`, `minikube version`, `kubectl version --client`, `helm version`, `terraform version`.

**Memory.** Minikube takes 6 GB, Jenkins + SonarQube about 3 GB more while a
build runs. Docker Desktop on WSL gets half your RAM by default (8 GB on a
16 GB PC), which is too little. Create `C:\Users\<you>\.wslconfig` with:

```ini
[wsl2]
memory=12GB
```

then `wsl --shutdown` and start Docker Desktop again.

## 1. Remote Terraform state (~1 min)

```powershell
cd "D:\Final Project\V1\readaloud-devops\terraform\state"
docker compose up -d
```

A Postgres on `127.0.0.1:5433` that keeps Terraform's state and locks.
It must be running for every `terraform` command.

## 2. Platform: cluster + monitoring (~15 min)

```powershell
cd "D:\Final Project\V1\readaloud-devops\terraform\platform"
copy terraform.tfvars.example terraform.tfvars    # optional: Slack / email, Grafana password
terraform init -backend-config=..\state\pg.tfbackend
terraform apply                                   # type yes
minikube -p readaloud update-context
kubectl get nodes                                 # readaloud   Ready
kubectl get pods -n monitoring                    # all Running after a few minutes
```

Creates the Minikube cluster (ingress, metrics-server, storage) and the
`monitoring` namespace with Prometheus, Alertmanager, Grafana (with the
ReadAloud dashboard), Loki, Promtail and the alert-receiver.

## 3. Environments: one Terraform workspace each (~1 min)

```powershell
cd ..\environments
terraform init -backend-config=..\state\pg.tfbackend
terraform workspace select -or-create dev;     terraform apply
terraform workspace select -or-create staging; terraform apply
# optional, needs more memory:  terraform workspace select -or-create prod; terraform apply
terraform workspace list
kubectl get resourcequota -A
```

## 4. Hostnames and tunnel

Once, in PowerShell **as Administrator**:

```powershell
Add-Content C:\Windows\System32\drivers\etc\hosts "127.0.0.1 readaloud.local staging.readaloud.local prod.readaloud.local grafana.readaloud.local prometheus.readaloud.local alertmanager.readaloud.local"
```

Then in its own window, left open the whole time:

```powershell
minikube -p readaloud tunnel
```

## 5. Jenkins: build, deploy, verify, monitor (~20 min the first time)

```powershell
cd "D:\Final Project\V1\readaloud-devops\jenkins"
copy .env.example .env
notepad .env        # GEMINI_API_KEY=<your key> for Summary/Ask; leave none to skip
docker compose up -d --build
docker compose logs -f sonar-init     # wait for "Token for Jenkins written.", then Ctrl+C
```

Open http://localhost:8081 (admin / admin) > **readaloud** > **Build with
Parameters** (the very first time it says **Build Now**: run it once, it
learns the parameters) > **Build**.

Defaults: DEPLOY on, PROMOTE_TO_STAGING on, PROMOTE_TO_PROD off. The run goes
Checkout, 1 Lint, 2 Test, 3 SAST, 4 Security, 5 Build + push, Cluster access,
6 Deploy: dev, 7 Verify: dev, 6 Deploy: staging, 7 Verify: staging, 8 Monitor.
The build page shows test, coverage and Newman reports.

## 6. Open it

| What | URL | Login |
|---|---|---|
| App (dev) | http://readaloud.local | register a user |
| App (staging) | http://staging.readaloud.local | separate database |
| Grafana | http://grafana.readaloud.local | admin / `ReadAloud-Grafana-2026!` (or your tfvars value) |
| Prometheus | http://prometheus.readaloud.local | - |
| Alertmanager | http://alertmanager.readaloud.local | - |
| Jenkins | http://localhost:8081 | admin / admin |
| SonarQube | http://localhost:9000 | admin / `ReadAloud-Sonar-2026!` |

## Deploying without Jenkins

Build the images in the app repo, load them, and run Helm yourself:

```powershell
cd "D:\Final Project\V1\readaloud-app"
docker compose build
minikube -p readaloud image load readaloud-backend:local
minikube -p readaloud image load readaloud-web:local
cd "D:\Final Project\V1\readaloud-devops"
helm upgrade --install readaloud .\helm\readaloud -n dev -f .\helm\readaloud\values-dev.yaml --set-string secrets.geminiApiKey=$env:GEMINI_API_KEY --wait --timeout 10m
```

API tests by hand (tunnel running): `npx newman run tests\api\readaloud.postman_collection.json --working-dir tests\api --env-var baseUrl=http://readaloud.local`

## Tear down

```powershell
minikube -p readaloud stop                         # pause; keeps everything
cd terraform\environments; terraform workspace select staging; terraform destroy; terraform workspace select dev; terraform destroy
cd ..\platform; terraform destroy                  # deletes the cluster
docker compose -f ..\..\jenkins\docker-compose.yml down
# the state Postgres keeps the (now empty) states; `docker compose down -v` in terraform\state removes them
```
