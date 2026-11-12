# ReadAloud in AWS (class demo): set up, demo, tear down

Windows PowerShell, one step at a time. Each step says what you should see.
Why it is built this way: [ADR 0007](adr/0007-aws-demo-on-k3s.md).

```
your PC (Terraform, kubectl, helm)                 AWS us-east-1
  terraform/cloud ─────────────── creates ──────▶  EC2 m7i-flex.large, Ubuntu 24.04
  terraform/cloud-platform ─ kubeconfig :6443 ──▶   └ k3s (Kubernetes)
  helm upgrade ──────────────── kubeconfig ─────▶      ├ monitoring: Prometheus, Grafana, Loki, ...
                                                       └ prod: ReadAloud backend x2, web, Postgres
any browser ── http://app.<ip>.nip.io ── :80 ──▶  Traefik Ingress
GHCR (public images, pushed by GitHub Actions) ──▶ pulled by k3s
```

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

Type `yes`. **Expect** (5-10 min): `Apply complete! Resources: 10 added`, outputs
`grafana_url` and `helm_command`.

```powershell
kubectl get pods -n monitoring
```

**Expect:** grafana, kps-prometheus, kps-alertmanager, kps-operator,
kube-state-metrics, node-exporter, loki, promtail, alert-receiver: all `Running`.

## Part 6. The app: Helm (~4 min)

From the devops folder. The first line reads your Gemini key from the app's
`.env` without printing it:

```powershell
cd "D:\Final Project\V1\readaloud-devops"
$gk = ((Get-Content "D:\Final Project\V1\readaloud-app\.env" | Select-String '^GEMINI_API_KEY=').Line -split '=', 2)[1].Trim()
"Gemini key length: $($gk.Length)"
$domain = terraform -chdir=terraform/cloud output -raw base_domain
helm upgrade --install readaloud helm/readaloud -n prod `
  -f helm/readaloud/values-prod.yaml -f helm/readaloud/values-cloud.yaml `
  --set-string ingress.host=app.$domain `
  --set-string secrets.geminiApiKey=$gk `
  --wait --timeout 10m
```

**Expect:** a length of about 39, then (2-4 min, the backend image is big)
`STATUS: deployed`.

```powershell
kubectl get pods,ingress -n prod
terraform -chdir=terraform/cloud output app_url
```

**Expect:** 2 backend, 1 web, 1 postgres pod `Running`; the ingress host
`app.<ip>.nip.io`. Open the `app_url` in a browser (try your phone on mobile
data too): register, upload a PDF, play, Summary.

Later upgrades: the same `helm upgrade` line. Without `--set-string
secrets.geminiApiKey=...` the key already in the cluster is kept.

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

## Part 8. Automatic deploys from Jenkins (once, ~3 min)

The whole chain, with no manual step after a `git push` to readaloud-app master:

```
git push ─▶ GitHub Actions: tests, build, push ghcr.io/...:<commit SHA> and :latest
        └─▶ Jenkins polls every 2 min (pollSCM) ─▶ stages 1-8 on Minikube
                 └─▶ "6 Deploy: AWS": waits for the <commit SHA> images on GHCR,
                     helm upgrade --reuse-values with both image tags = that SHA,
                     rolling update, rollback if the new pods never get Ready
```

Each AWS release is pinned to a commit SHA, so `helm history readaloud -n prod`
shows which commit runs and `helm rollback readaloud <revision> -n prod` goes
back to a known image. The script is `scripts/deploy-aws.sh`.

Part 6 must have been done once (it sets the ingress host and the Gemini key,
which the automatic deploys keep). Then give Jenkins the kubeconfig:

1. http://localhost:8081 > **Manage Jenkins** > **Credentials** > **System** >
   **Global credentials** > **Add Credentials**
2. Kind **Secret file**, File: `$HOME\.kube\readaloud-aws.yaml`, ID
   **`aws-kubeconfig`** > **Create**

Jenkins runs on your PC, so it reaches the k3s API (port 6443) from the home IP
the security group allows. Without the credential the stage just logs
"skipping", so the Minikube-only pipeline still works. To turn it off for one
run, untick **DEPLOY_AWS**. It only deploys builds of `master`.

**Try it:** push a small change to readaloud-app master. **Expect** (about
10-15 min): a Jenkins build starts on its own within 2 min, `6 Deploy: AWS`
prints `Deploying ghcr.io/matan-abir/readaloud-*:<sha>`, and

```powershell
$env:KUBECONFIG = "$HOME\.kube\readaloud-aws.yaml"
helm history readaloud -n prod
```

shows a new revision "Jenkins build N, image <sha>".

By hand (same thing, from Git Bash in the devops folder):
`AWS_KUBECONFIG=~/.kube/readaloud-aws.yaml IMAGE_TAG=<full sha> sh scripts/deploy-aws.sh`

If you rebuild the server (`terraform destroy` + `apply`), the kubeconfig
changes: redo Part 4, then update the `aws-kubeconfig` credential's file.

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
5. Rolling update: the `helm upgrade` command, then `helm history readaloud -n prod`.
6. The Jenkins pipeline on Minikube, all stages green (or screenshots of Pipeline Overview).
7. Optional: `terraform destroy` + `apply` timed, to show the whole server is code.

**Live in class (from the browser):**

1. **The app, 2 min:** `http://app.<ip>.nip.io`, log in, upload the PDF, play
   (Natural voice), Summary, Ask.
2. **It runs in the cloud, 1 min:** the architecture picture above; "this is an
   EC2 instance made by Terraform, running Kubernetes (k3s), the same Helm chart as on Minikube".
3. **The code, 2 min:** GitHub `readaloud-devops`: `terraform/cloud/main.tf`,
   `terraform/cloud-platform/main.tf` (same modules as Minikube),
   `helm/readaloud/values-cloud.yaml`, ADR 0007.
4. **CI, 1 min:** GitHub Actions in readaloud-app (tests, Trivy, push to GHCR)
   and the public packages: the images the cluster runs.
5. **Monitoring, 2 min:** Grafana > ReadAloud dashboard (Environment = prod):
   the requests you just made. Dashboards > Kubernetes / Compute Resources /
   Namespace (Pods), namespace `prod`: the pods live, with CPU and memory.
   Explore > Loki > `{namespace="prod"}`: the app's logs.
6. **The recording, 3 min:** Terraform, kubectl, self-healing, Jenkins.

**If something fails in class:** play the full recording. If the class network
blocks nip.io (rare), try from your phone's hotspot.
