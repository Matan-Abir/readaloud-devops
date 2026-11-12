# ADR 0008: Argo CD deploys prod on k3s (GitOps)

Date: 2026-11-12 · Status: accepted

## Context
Prod in AWS (ADR 0007) was updated by `helm upgrade`, first by hand, then by a
Jenkins stage. Jenkins runs on the home PC, so prod only got new versions while
that PC was on. Running deploys from GitHub Actions would mean opening the
Kubernetes API (6443, now limited to the home IP) to the internet and storing an
admin kubeconfig in GitHub.

## Decision
- **Argo CD in the cluster** (`terraform/cloud-platform/argocd.tf`, chart
  `argo-cd`). The Application `readaloud-prod` points at `helm/readaloud` on
  `master` of this repo with `values-prod.yaml` + `values-cloud.yaml`; automated
  sync with prune and self-heal. The cluster *pulls* its state from git: no
  credentials leave the cluster and 6443 stays closed. Git is the source of truth.
- **Argo CD Image Updater** for new images. It checks the digest of `:latest` on
  GHCR every 2 minutes and writes `latest@sha256:<digest>` into the
  Application's Helm parameters (write-back method `argocd`), which makes Argo CD
  roll out. The digest pins the exact build; rollback is in the Argo CD History.
  The alternative, an Actions job that commits the new SHA to this repo
  (write-back `git`), keeps every image change in git history but needs a
  token with write access to this repo stored in the app repo.
- **The Secret stays out of Argo CD.** Argo CD renders charts without cluster
  access, so the chart's `lookup()` (which keeps generated passwords) would see
  nothing and make new passwords on every sync. The Application sets
  `secrets.existingSecret=readaloud-secret`, a Secret made once with kubectl
  (docs/CLOUD.md part 6). The Gemini key is never in git or Terraform state.
- **Host from Terraform.** `ingress.host` depends on the Elastic IP, so
  Terraform passes it as a parameter instead of committing an IP to git.
- **Jenkins keeps Minikube** (dev, staging, optional prod there); its AWS stage
  was removed so two tools don't fight over the same objects.

## Consequences
- A merge to readaloud-app master reaches AWS in about 5-8 minutes with no
  computer of ours on. A merge to the chart reaches it within about a minute.
- `helm upgrade`/`helm history` no longer describe prod; the Argo CD UI does.
  Manual changes in prod are reverted (self-heal).
- About 0.5-1 GB more memory on the instance (Argo CD + Image Updater).
- The Argo CD UI is public over HTTP like Grafana, protected by the generated
  admin password.
