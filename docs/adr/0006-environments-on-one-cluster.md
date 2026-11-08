# ADR 0006: dev, staging and prod are namespaces on one Minikube cluster

Date: 2026-11-08 · Status: accepted

## Context
Three clusters don't fit on a laptop. Environments still need to be separate
enough that a test in dev can't break staging.

## Decision
One namespace per environment, each with its own Helm release, Secret,
Postgres, PVCs, hostname and ResourceQuota. Promotion is the same image tag
going dev -> staging -> prod in one pipeline run; prod needs a human approval
(`input` step) and is off by default (`PROMOTE_TO_PROD`). Staging runs two
backend replicas like prod; dev runs one.

## Consequences
- Promotion is real (same artifact, separate data), and the quota stops one environment from eating the node.
- A node failure takes all environments down; acceptable for a course demo, not for production.
