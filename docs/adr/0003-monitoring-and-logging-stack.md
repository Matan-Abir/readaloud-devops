# ADR 0003: kube-prometheus-stack for metrics and alerts, Loki + Promtail for logs

Date: 2026-11-08 · Status: accepted

## Context
Requirements 5 and 9 ask for Prometheus + Grafana with custom metrics,
Alertmanager with Slack/email, dashboards, alert rules, and Loki + Promtail.

## Decision
- **kube-prometheus-stack** (Prometheus Operator) installed by Terraform. The app
  chart ships its own `ServiceMonitor` and `PrometheusRule`, so monitoring is
  versioned and deployed with the app, per environment. Prometheus selects them
  from every namespace.
- **Grafana** gets the ReadAloud dashboard from a ConfigMap (sidecar) and Loki
  as a second data source; dashboards are code, not clicks.
- **Loki** in single-binary mode on a PVC, 3-day retention, no object storage or
  caches, sized for a laptop. **Promtail** as a DaemonSet ships all container logs.
- **Alertmanager** routes ReadAloud alerts to Slack and/or email when their
  Terraform variables are set, and always to an in-cluster webhook
  (`alert-receiver`) that logs each notification, so delivery can be shown
  in Grafana with no external account.
- The backend's gunicorn uses Prometheus multiprocess mode so `/metrics` is
  the sum of all workers, not whichever worker answered the scrape.

## Consequences
- Promtail is deprecated upstream in favour of Grafana Alloy (chart 6.17.1 is
  the last). The course names Promtail, so it stays; moving to Alloy only
  changes the log shipper.
- Charts are pinned (kube-prometheus-stack 93.1.0, loki 7.5.0, promtail 6.17.1)
  and pulled from their OCI registries on ghcr.io.
