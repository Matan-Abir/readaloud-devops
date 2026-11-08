# ADR 0001: Jenkins and SonarQube run in Docker next to Minikube, not inside it

Date: 2026-11-08 · Status: accepted

## Context
The course requires a declarative Jenkins pipeline with SonarQube. Everything
runs on one 16 GB Windows laptop. Jenkins inside Minikube would compete with
the app, Prometheus and Loki for the node's 6 GB, and building images from a
pod needs Docker-in-Docker or Kaniko.

## Decision
Jenkins and SonarQube run in Docker Compose (`jenkins/`), started only when
needed. Jenkins is configured entirely as code (JCasC + Job DSL: admin user,
credentials, the `readaloud` job). Every pipeline tool runs in its own pinned
container (`agent { docker { ... } }`). For stages 6-8 the tool containers join
Minikube's Docker network so they reach the API server and the Ingress.

## Consequences
- No clicking to set up Jenkins; `docker compose down -v` and up again gives the same Jenkins.
- The cluster's memory goes to the app and monitoring only.
- Jenkins holds the host's Docker socket (root-equivalent). Fine for a local CI
  box that is never exposed; a shared Jenkins would use agents instead.
