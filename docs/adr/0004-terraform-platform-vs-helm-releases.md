# ADR 0004: Terraform owns the platform and environments, Helm (via Jenkins) owns app releases

Date: 2026-11-08 · Status: accepted

## Context
Both Terraform (helm provider) and Jenkins could install the app chart.
App releases happen on every commit; the cluster and the monitoring stack
change rarely.

## Decision
- `terraform/platform`: the cluster and the shared monitoring/logging stack.
- `terraform/environments`: one workspace per environment, each a namespace with
  a ResourceQuota and LimitRange (module `app-environment`).
- Jenkins runs `helm upgrade --install --wait --rollback-on-failure` into those
  namespaces. The deploy script refuses to create a namespace itself, so
  environments only come from Terraform.

## Consequences
- An app release never needs a Terraform run or state lock.
- Helm history (`helm history readaloud -n dev`) is the release log, and a bad
  release rolls back on its own.
- Terraform doesn't drift when Jenkins deploys, because it doesn't manage the release.
