# ReadAloud in AWS (class demo): set up, demo, tear down

Windows PowerShell, one step at a time. Each step says what you should see.
Why it is built this way: [ADR 0007](adr/0007-aws-demo-on-k3s.md) (k3s on EC2) and
[ADR 0008](adr/0008-gitops-with-argo-cd.md) (Argo CD).

```
your PC (Terraform, kubectl)                       AWS us-east-1
  terraform/cloud ─────────────── creates ──────▶  EC2 m7i-flex.large, Ubuntu 24.04
  terraform/cloud-platform ─ kubeconfig :6443 ──▶   └ k3s (Kubernetes)
                                                       ├ monitoring: Prometheus, Grafana, Loki, ...
                                                       ├ argocd: Argo CD + Image Updater
                                                       └ prod: ReadAloud backend x2, web, Postgres
GitHub readaloud-devops (Helm chart) ◀── Argo CD reads it every minute
GHCR (public images, pushed by GitHub Actions) ◀── Image Updater checks every 2 min
any browser ── http://app.<ip>.nip.io ── :80 ──▶  Traefik Ingress
```

After setup your PC can be off: a merge to readaloud-app master reaches AWS
through GitHub Actions, GHCR and Argo CD alone (Part 8).

Cost: about **0.10 USD per hour** while the instance exists (about 2.40 USD a
day). Stopped: a few cents a day. Destroyed: nothing.

---

## Part 0. Once, in the browser (~5 min)

**0.1 Both images on GHCR must be public.** The cluster pulls them without a
password. `readaloud-backend` already is. `readaloud-web` was created outside this
workflow (an earlier push), so GitHub Actions isn't allowed to write to it: that is why
the last master run of readaloud-app failed at "Push to GHCR" with `denied`, and
the package has no image in it. Open
https://github.com/users/Matan-Abir/packages/container/readaloud-web/settings and:

1. **Manage Actions access** > **Add Repository** > `readaloud-app` > role **Write**
2. **Danger Zone** > **Change visibility** > **Public**

**0.2 Push the web image again:** open the last master run of readaloud-app
(https://github.com/Matan-Abir/readaloud-app/actions, the top "Merge pull request
#2" run) > **Re-run jobs** > **Re-run failed jobs**. **Expect:** green after
~3 min, and the readaloud-web package page shows a `latest` tag.

**0.3 Budget alarm (recommended):** sign in to AWS as the root user >
**Billing and Cost Management** > **Budgets** > **Create budget** > template
**Monthly cost budget**, 10 USD, your email. You get a mail before anything
expensive happens.

## Part 1. Tools and code (~3 min)

```powershell
winget install -e --id Amazon.AWSCLI      # skip if `aws --version` already works
aws sts get-caller-identity
```

**Expect:** JSON with `"Arn": "arn:aws:iam::...:user/terraform-demo"`.

```powershell
cd "D:\Final Project\V1\readaloud-devops"
git fetch origin; git switch master; git pull
cd terraform\state
docker compose up -d
```

**Expect:** `readaloud-tfstate` Running (the same state database as the Minikube roots).

## Part 2. An SSH key (once, ~1 min)

```powershell
New-Item -ItemType Directory -Force "$HOME\.ssh", "$HOME\.kube" | Out-Null
ssh-keygen -t ed25519 -f "$HOME\.ssh\readaloud-aws"
```

Press Enter twice (no passphrase). **Expect:** `readaloud-aws` and
`readaloud-aws.pub` in `$HOME\.ssh`. Only the `.pub` half goes to AWS.

## Part 3. The server: terraform/cloud (~3 min)

```powershell
cd "D:\Final Project\V1\readaloud-devops\terraform\cloud"
terraform init "-backend-config=..\state\pg.tfbackend"
terraform plan
```

**Expect:** `Plan: 10 to add, 0 to change, 0 to destroy.` (key pair, security
group + 5 rules, Elastic IP, instance, IP association).

```powershell
terraform apply
```

Type `yes`. **Expect:** `Apply complete! Resources: 10 added` and outputs
including `public_ip`, `app_url`, `grafana_url`, `kubeconfig_command`.

## Part 4. Wait for k3s and get the kubeconfig (~3 min)

The instance installs k3s on first boot. Copy the `ssh_command` output and add
the wait at the end, or:

```powershell
$ip = terraform output -raw public_ip
ssh -i "$HOME\.ssh\readaloud-aws" ubuntu@$ip "cloud-init status --wait"
```

The first time it asks `Are you sure you want to continue connecting`: type
`yes`. **Expect** (after 1-3 min of dots): `status: done`.

```powershell
scp -i "$HOME\.ssh\readaloud-aws" ubuntu@${ip}:kubeconfig "$HOME\.kube\readaloud-aws.yaml"
$env:KUBECONFIG = "$HOME\.kube\readaloud-aws.yaml"
kubectl get nodes
```

**Expect:** one node `readaloud`, `Ready`. From now on, **every new PowerShell
window** that talks to AWS needs the `$env:KUBECONFIG = ...` line first
(otherwise kubectl talks to Minikube).

## Part 5. Monitoring and the prod namespace: terraform/cloud-platform (~8 min)

Pick a Grafana password (12+ characters; this Grafana is on the internet) and
put it in a gitignored file:

```powershell
cd ..\cloud-platform
Set-Content terraform.tfvars 'grafana_admin_password = "CHANGE-ME-to-something-long"'
notepad terraform.tfvars      # change it, save
terraform init "-backend-config=..\state\pg.tfbackend"
terraform apply
```

Type `yes`. **Expect** (5-10 min): `Apply complete! Resources: 14 added`, outputs
`grafana_url`, `argocd_url`, `app_url` and `argocd_password_command`.

```powershell
kubectl get pods -n monitoring
kubectl get pods -n argocd
```

**Expect:** grafana, kps-prometheus, kps-alertmanager, kps-operator,
kube-state-metrics, node-exporter, loki, promtail, alert-receiver: all `Running`.
In argocd: argocd-server, argocd-repo-server, argocd-application-controller,
argocd-redis, argocd-applicationset-controller, argocd-image-updater: all `Running`.

Argo CD starts deploying the app straight away. Until Part 6 the backend pods
wait with `CreateContainerConfigError` (no Secret yet); that is expected.

## Part 6. The app's Secret (once, ~3 min)

Argo CD deploys everything in the Helm chart except the Secret: the Gemini key
must not be in git, and Argo CD can't keep generated passwords stable (ADR 0008).
So the Secret is made once by hand. From the devops folder; the first line reads
your Gemini key from the app's `.env` without printing it:

```powershell
cd "D:\Final Project\V1\readaloud-devops"
$gk = ((Get-Content "D:\Final Project\V1\readaloud-app\.env" | Select-String '^GEMINI_API_KEY=').Line -split '=', 2)[1].Trim()
"Gemini key length: $($gk.Length)"
function New-Password { -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object { [char]$_ }) }
kubectl create secret generic readaloud-secret -n prod `
  --from-literal=GEMINI_API_KEY=$gk `
  --from-literal=JWT_SECRET_KEY=$(New-Password) `
  --from-literal=POSTGRES_PASSWORD=$(New-Password)
```

**Expect:** a length of about 39, then `secret/readaloud-secret created`.
**Already had the app from the old `helm upgrade` instructions?** Skip this part:
that release made the same Secret, and Argo CD adopts the running app as it is.

```powershell
kubectl get pods,ingress -n prod
terraform -chdir=terraform/cloud-platform output app_url
```

**Expect** (2-4 min, the backend image is big): 2 backend, 1 web, 1 postgres
pod `Running`; the ingress host `app.<ip>.nip.io`. Open the `app_url` in a
browser (try your phone on mobile data too): register, upload a PDF, play, Summary.

Don't run `helm upgrade` or `helm uninstall` on prod any more: Argo CD owns it
and undoes manual changes within a few minutes.

## Part 7. Grafana (~2 min)

`terraform -chdir=terraform/cloud output grafana_url`, log in as **admin** with
your password. **Expect:** Dashboards > **ReadAloud** with Environment = `prod`
showing requests after you used the app; Explore > Loki > `{namespace="prod"}`
shows the app's logs.

Prometheus (no public URL on purpose):

```powershell
kubectl port-forward -n monitoring svc/kps-prometheus 9090
```

then http://localhost:9090 > Alerts. Ctrl+C to stop.

## Part 8. Automatic deploys with Argo CD (GitOps)

Nothing to set up: Part 5 installed it. The chain, with your PC off:

```
merge to readaloud-app master
  └▶ GitHub Actions: tests, Trivy, build, push ghcr.io/matan-abir/readaloud-*:latest
       └▶ Image Updater (in k3s, every 2 min): the digest of :latest changed
            └▶ writes backend.image.tag / web.image.tag = latest@sha256:<digest>
               into the Argo CD Application readaloud-prod
                 └▶ Argo CD: rolling update of prod; old pods serve until the new are Ready

merge to readaloud-devops master (chart, values-prod.yaml, values-cloud.yaml)
  └▶ Argo CD (every minute) renders the chart again and applies the difference
```

Jenkins still runs the full pipeline on Minikube (dev, staging) on your PC; AWS
prod no longer depends on it.

**The Argo CD UI:** `terraform -chdir=terraform/cloud-platform output argocd_url`,
user **admin**, password:

```powershell
$env:KUBECONFIG = "$HOME\.kube\readaloud-aws.yaml"
terraform -chdir=terraform/cloud-platform output -raw argocd_password_command | Invoke-Expression
```

**Expect:** the `readaloud-prod` app, **Synced** and **Healthy**, with its tree
of Deployments, Pods, Services and the Ingress. **History and rollback** shows
each deploy; **Rollback** on an older entry goes back to that image (automatic
sync pauses until you press **Sync** again).

**Try it:** change something small in readaloud-app on github.com and commit to
master. **Expect** (about 5-8 min): the Actions run goes green, within 2 min
the Image Updater log shows the new digest, and Argo CD shows the app
**Progressing** then **Healthy** again with new pods:

```powershell
kubectl logs -n argocd deploy/argocd-image-updater --tail 20
kubectl get imageupdater -n argocd
kubectl get pods -n prod -w
```

**Self-healing of config:** `kubectl scale deploy readaloud-backend -n prod --replicas 1`;
within a few seconds Argo CD sets it back to 2, because git says 2.

---

## Saving money: stop, start, destroy

**Between sessions (keeps everything, the IP stays):**

```powershell
cd "D:\Final Project\V1\readaloud-devops\terraform\cloud"
terraform output -raw stop_command | Invoke-Expression
```

Start again: `terraform output -raw start_command | Invoke-Expression`, wait 2
min, `kubectl get pods -A` (with `$env:KUBECONFIG` set). k3s starts by itself
and the pods come back with their data.

**After the presentation (removes everything, nothing left to pay):**

```powershell
cd "D:\Final Project\V1\readaloud-devops\terraform\cloud-platform"
$env:KUBECONFIG = "$HOME\.kube\readaloud-aws.yaml"
terraform destroy
cd ..\cloud
terraform destroy
```

Type `yes` each time. **Expect:** `Destroy complete! Resources: 10 destroyed.`
at the end. Check in the AWS console (EC2 > Instances, and EC2 > Elastic IPs,
region N. Virginia) that nothing is left.

If the instance is already gone and the first destroy can't reach the cluster,
forget that root's state instead: `terraform state list` then
`terraform state rm <each line>`, and carry on with `..\cloud`.

**Your home IP changed** (SSH or kubectl time out): `terraform apply` in
`terraform\cloud` again: it re-detects the IP and only updates the two rules.

---

## Demo script for class (about 10 minutes)

In class you have only a browser. Everything live runs in AWS; the terminal
parts are shown from a recording made at home.

**At home, the evening before:**

- [ ] Instance running, `kubectl get pods -A` all Running, app and Grafana open from your phone on mobile data
- [ ] Record the terminal part (below) as a video, plus the Jenkins run on Minikube
- [ ] Upload the video(s) to Google Drive or YouTube (unlisted) **and** copy to a USB stick
- [ ] Bookmarks / a note with: app URL, Grafana URL + password, GitHub repos, video link
- [ ] A short PDF reachable from the class PC (e.g. in your Google Drive)

**What to record at home** (OBS Studio, `winget install -e --id OBSProject.OBSStudio`,
records the whole screen; Win+G only records one window):

1. `cd terraform\cloud; terraform plan`: "No changes", the infrastructure matches the code.
2. Open `terraform/cloud/main.tf` and the security group rules; `terraform output`.
3. `kubectl get nodes,pods -A`; `kubectl get ingress -n prod`.
4. Self-healing: `kubectl delete pod -n prod -l app.kubernetes.io/name=readaloud-backend`
   then `kubectl get pods -n prod -w` until a new pod is Ready, and the app still works.
5. Rolling update: commit a change to readaloud-app master, then `kubectl get pods -n prod -w` while Argo CD replaces the pods one by one.
6. The Jenkins pipeline on Minikube, all stages green (or screenshots of Pipeline Overview).
7. Optional: `terraform destroy` + `apply` timed, to show the whole server is code.

**Live in class (from the browser):**

1. **The app, 2 min:** `http://app.<ip>.nip.io`, log in, upload the PDF, play
   (Natural voice), Summary, Ask.
2. **It runs in the cloud, 1 min:** the architecture picture above; "this is an
   EC2 instance made by Terraform, running Kubernetes (k3s), the same Helm chart as on Minikube".
3. **The code, 2 min:** GitHub `readaloud-devops`: `terraform/cloud/main.tf`,
   `terraform/cloud-platform/main.tf` (same modules as Minikube),
   `terraform/cloud-platform/argocd.tf`, `helm/readaloud/values-cloud.yaml`, ADR 0007 and 0008.
4. **CI/CD, 2 min:** GitHub Actions in readaloud-app (tests, Trivy, push to GHCR)
   and the public packages: the images the cluster runs. Then the Argo CD UI
   (`argocd_url`): `readaloud-prod` Synced and Healthy, its resource tree, History.
5. **Monitoring, 2 min:** Grafana > ReadAloud dashboard (Environment = prod):
   the requests you just made. Dashboards > Kubernetes / Compute Resources /
   Namespace (Pods), namespace `prod`: the pods live, with CPU and memory.
   Explore > Loki > `{namespace="prod"}`: the app's logs.
6. **The recording, 3 min:** Terraform, kubectl, self-healing, Jenkins.

**If something fails in class:** play the full recording. If the class network
blocks nip.io (rare), try from your phone's hotspot.
