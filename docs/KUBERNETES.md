# Running ReadAloud on Minikube (Windows, PowerShell)

Assumes Docker Desktop is running, and `minikube`, `kubectl`, `helm` and
`terraform` are installed (`winget install Kubernetes.minikube Kubernetes.kubectl Helm.Helm Hashicorp.Terraform`).
Both repos sit next to each other in `D:\Final Project\V1`.

## 1. Cluster (Terraform)

```powershell
cd "D:\Final Project\V1\readaloud-devops\terraform"
terraform init
terraform apply          # type yes; creates Minikube "readaloud" + namespaces dev, staging
minikube -p readaloud update-context   # points kubectl at the new cluster
kubectl get nodes        # one node, Ready
```

The cluster gets 4 CPUs and 6 GB (change in `terraform.tfvars`, see the example
file). Addons: ingress, metrics-server, storage.

## 2. Images into the cluster

The chart uses the images you already built with `docker compose up --build`
in the app repo (`readaloud-backend:local`, `readaloud-web:local`):

```powershell
minikube -p readaloud image load readaloud-backend:local
minikube -p readaloud image load readaloud-web:local
```

## 3. App (Helm)

```powershell
cd "D:\Final Project\V1\readaloud-devops"
helm upgrade --install readaloud .\helm\readaloud -n dev -f .\helm\readaloud\values-dev.yaml `
  --set-string secrets.geminiApiKey=$env:GEMINI_API_KEY
kubectl get pods -n dev -w      # Ctrl+C once all are Running and READY 1/1
```

What gets created: backend Deployment (Piper voice inside, startup/liveness/
readiness probes, CPU and memory requests and limits, PVC for uploads),
Postgres 15 StatefulSet with its own volume, web Deployment (nginx), Services,
ConfigMap, Secret (JWT and Postgres passwords generated once and kept on
upgrades), and an Ingress.

## 4. Open it through the Ingress

Once, as Administrator, add the hostname to the hosts file:

```powershell
Add-Content C:\Windows\System32\drivers\etc\hosts "127.0.0.1 readaloud.local"
```

Then keep a tunnel running in its own window (it may ask for permission):

```powershell
minikube -p readaloud tunnel
```

Open http://readaloud.local . `/api/...` goes to the backend, everything else
to the web app.

## Checks worth showing in class

```powershell
kubectl describe deploy readaloud-backend -n dev | Select-String -Pattern "Liveness|Readiness|Startup|Limits|Requests" -Context 0,2
kubectl delete pod -n dev -l app.kubernetes.io/name=readaloud-backend   # a new pod replaces it
kubectl get ingress -n dev
```

## Clean up

```powershell
helm uninstall readaloud -n dev
terraform destroy        # deletes the Minikube cluster
```
