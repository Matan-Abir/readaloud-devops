# ADR 0005: Remote state in a local Postgres, environments as Terraform workspaces

Date: 2026-11-08 · Status: accepted

## Context
The course asks for a remote state backend and dev/staging/prod workspaces.
The project runs on Minikube; there is no cloud account by default.

## Decision
- **Backend:** Terraform's `pg` backend against a small Postgres in Docker
  Compose (`terraform/state`), bound to 127.0.0.1. It stores one state per
  workspace and takes a lock during plan/apply, which is what remote state is
  for. It lives outside the cluster, so `terraform destroy` can't delete its own state.
- Each root has its own schema (`readaloud_platform`, `readaloud_environments`);
  the shared connection string is in `state/pg.tfbackend` (partial backend config).
- **Workspaces:** `terraform/environments` uses `terraform.workspace` as the
  environment name and picks its quota from a map; a `check` block warns in the
  `default` workspace. The platform root is shared, so it stays in `default`.

## Alternatives
- **S3 + native lock file** (`use_lockfile`): the usual choice on AWS.
  `state/s3.tfbackend.example` shows the switch; `terraform init -migrate-state` moves existing state.
- **Kubernetes Secret backend**: state would live inside the cluster it creates.
- **Local state**: no locking, nothing to show for the requirement.

## Consequences
- No cloud account or credentials needed.
- The state Postgres must be running before any `terraform` command (`docker compose up -d` in `terraform/state`).
