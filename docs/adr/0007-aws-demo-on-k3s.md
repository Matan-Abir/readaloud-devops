# ADR 0007: prod in AWS is k3s on one EC2 instance, built by Terraform

Date: 2026-11-08 · Status: accepted

## Context
The class demo has to work from any browser, without a laptop. Minikube runs on
the home PC behind a home router. The AWS account is new (Free plan credits),
the IAM user for Terraform has only AmazonEC2FullAccess, and the budget is a
few dollars.

## Decision
- **One EC2 instance with k3s** (`terraform/cloud`), not EKS. EKS costs about
  0.10 USD/h for the control plane alone plus nodes, NAT and load balancers, and
  needs IAM permissions the user doesn't have. k3s is CNCF-certified Kubernetes,
  so the same chart and modules run unchanged.
- **m7i-flex.large** (2 vCPU, 8 GB): fits k3s, two backend pods, Postgres and the
  monitoring stack, and is allowed on the AWS Free plan.
- **Elastic IP + nip.io**: a fixed address that survives stop/start, and
  hostnames (`app.<ip>.nip.io`, `grafana.<ip>.nip.io`) without buying a domain.
- **Security group**: 80/443 open to all; SSH and the Kubernetes API (6443)
  only from the admin's current public IP. Prometheus and Alertmanager have no
  login, so they get no public Ingress (`expose_admin_uis = false`); use
  `kubectl port-forward`. SSM Session Manager would avoid opening 22, but needs
  an IAM role and instance profile, which the Terraform user can't create.
- **Same modules, second root** (`terraform/cloud-platform`): `monitoring` and
  `app-environment` from the Minikube setup, pointed at the k3s kubeconfig. It
  reads the IP from `terraform/cloud`'s state with `terraform_remote_state`.
  Two roots because the Kubernetes providers can't be configured until the
  instance exists.
- **State** stays in the local Postgres (`../state/pg.tfbackend`), schemas
  `readaloud_cloud` and `readaloud_cloud_platform`. Terraform runs on the PC, so
  AWS never needs to reach it, and every root keeps its state the same way.
- **Images** come from GHCR (public packages, pushed by GitHub Actions in the app
  repo), so the cluster needs no pull secret and no registry of its own.
- **Gemini key** goes from the local `.env` into the chart's Secret with
  `--set-string` at install time; it is never in git or in Terraform state.

## Consequences
- The whole cloud setup is two `terraform apply`s and one `helm upgrade`, and
  goes away with two `terraform destroy`s.
- Single node, no backups, plain HTTP: right for a demo, not for real users.
  Next steps would be cert-manager + Let's Encrypt for HTTPS, EBS snapshots for
  Postgres, and an S3 state backend with locking.
- The home IP changes from time to time; `terraform apply` in `terraform/cloud`
  re-detects it and updates the security group.
