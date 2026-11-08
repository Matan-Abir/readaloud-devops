# Reusable module: the monitoring and logging stack for a ReadAloud cluster.
#   kube-prometheus-stack  Prometheus, Alertmanager, Grafana, kube-state-metrics,
#                          node-exporter, and the Prometheus Operator CRDs that the
#                          app chart's ServiceMonitor and PrometheusRule use
#   loki                   log store (single binary, filesystem storage)
#   promtail               DaemonSet that ships every container's logs to Loki
#   alert-receiver         webhook that logs each alert Alertmanager sends
#   ReadAloud dashboard    ConfigMap picked up by Grafana's dashboard sidecar

locals {
  hosts = {
    grafana      = "grafana.${var.base_domain}"
    prometheus   = "prometheus.${var.base_domain}"
    alertmanager = "alertmanager.${var.base_domain}"
  }

  # Alertmanager routing: ReadAloud alerts go to the team receiver (Slack and/or
  # email when configured) and always to the in-cluster webhook.
  team_receiver = merge(
    { name = "readaloud-team" },
    var.slack_webhook_url == "" ? {} : {
      slack_configs = [{
        api_url       = var.slack_webhook_url
        channel       = var.slack_channel
        send_resolved = true
        title         = "{{ .Status | toUpper }}: {{ .CommonLabels.alertname }} ({{ .CommonLabels.namespace }})"
        text          = "{{ range .Alerts }}{{ .Annotations.summary }}\n{{ .Annotations.runbook_url }}\n{{ end }}"
      }]
    },
    var.alert_email == null ? {} : {
      email_configs = [{
        to            = var.alert_email.to
        from          = var.alert_email.from
        smarthost     = var.alert_email.smarthost
        auth_username = var.alert_email.auth_username
        auth_password = var.alert_email.auth_password
        send_resolved = true
      }]
    },
  )

  alertmanager_config = {
    global = { resolve_timeout = "5m" }
    route = {
      receiver        = "null"
      group_by        = ["alertname", "namespace"]
      group_wait      = "30s"
      group_interval  = "5m"
      repeat_interval = "4h"
      routes = [
        { receiver = "null", matchers = ["alertname = Watchdog"] },
        { receiver = "alert-log", matchers = ["alertname =~ ReadAloud.*"], continue = true },
        { receiver = "readaloud-team", matchers = ["alertname =~ ReadAloud.*"] },
      ]
    }
    receivers = [
      { name = "null" },
      {
        name = "alert-log"
        webhook_configs = [{
          url           = "http://alert-receiver.${var.namespace}.svc:8080/alerts"
          send_resolved = true
        }]
      },
      local.team_receiver,
    ]
  }
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/part-of" = "readaloud"
    }
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = "kps"
  namespace  = kubernetes_namespace_v1.this.metadata[0].name
  repository = "oci://ghcr.io/prometheus-community/charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_versions.kube_prometheus_stack
  timeout    = 900

  values = [
    templatefile("${path.module}/values/kube-prometheus-stack.yaml", merge(local.hosts, {
      ingress_class    = var.ingress_class_name
      expose_admin_uis = var.expose_admin_uis
    })),
    yamlencode({ alertmanager = { config = local.alertmanager_config } }),
  ]

  set_sensitive = [
    { name = "grafana.adminPassword", value = var.grafana_admin_password },
  ]
}

resource "helm_release" "loki" {
  name       = "loki"
  namespace  = kubernetes_namespace_v1.this.metadata[0].name
  repository = "oci://ghcr.io/grafana/helm-charts"
  chart      = "loki"
  version    = var.chart_versions.loki
  timeout    = 600

  values = [file("${path.module}/values/loki.yaml")]
}

resource "helm_release" "promtail" {
  name       = "promtail"
  namespace  = kubernetes_namespace_v1.this.metadata[0].name
  repository = "oci://ghcr.io/grafana/helm-charts"
  chart      = "promtail"
  version    = var.chart_versions.promtail
  timeout    = 300

  values = [templatefile("${path.module}/values/promtail.yaml", { namespace = var.namespace })]

  depends_on = [helm_release.loki]
}

# Grafana's sidecar loads every ConfigMap labelled grafana_dashboard=1.
resource "kubernetes_config_map_v1" "readaloud_dashboard" {
  metadata {
    name      = "readaloud-dashboard"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      grafana_dashboard = "1"
    }
  }
  data = {
    "readaloud.json" = file("${path.module}/dashboards/readaloud.json")
  }
}

# Logs every alert notification as one JSON line, so `{container="alert-receiver"}`
# in Grafana Explore shows what Alertmanager sent and when.
resource "kubernetes_deployment_v1" "alert_receiver" {
  metadata {
    name      = "alert-receiver"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels    = { app = "alert-receiver" }
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "alert-receiver" }
    }
    template {
      metadata {
        labels = { app = "alert-receiver" }
      }
      spec {
        container {
          name  = "alert-receiver"
          image = var.alert_receiver_image
          env {
            name  = "HTTP_PORT"
            value = "8080"
          }
          env {
            name  = "LOG_IGNORE_PATH"
            value = "/healthz"
          }
          port {
            container_port = 8080
          }
          readiness_probe {
            http_get {
              path = "/healthz"
              port = 8080
            }
          }
          resources {
            requests = { cpu = "10m", memory = "32Mi" }
            limits   = { cpu = "100m", memory = "96Mi" }
          }
        }
      }
    }
  }
}

resource "kubernetes_service_v1" "alert_receiver" {
  metadata {
    name      = "alert-receiver"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec {
    selector = { app = "alert-receiver" }
    port {
      port        = 8080
      target_port = 8080
    }
  }
}
