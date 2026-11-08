variable "namespace" {
  description = "Namespace for Prometheus, Alertmanager, Grafana, Loki and Promtail"
  type        = string
  default     = "monitoring"
}

variable "base_domain" {
  description = "UIs get <name>.<base_domain> through the Ingress (grafana, prometheus, alertmanager)"
  type        = string
  default     = "readaloud.local"
}

variable "grafana_admin_password" {
  description = "Grafana admin password (user admin)"
  type        = string
  sensitive   = true
}

variable "slack_webhook_url" {
  description = "Slack incoming webhook for ReadAloud alerts; empty = no Slack"
  type        = string
  default     = ""
  sensitive   = true
}

variable "slack_channel" {
  description = "Slack channel the webhook posts to"
  type        = string
  default     = "#readaloud-alerts"
}

variable "alert_email" {
  description = "Email settings for ReadAloud alerts; null = no email. For Gmail use smtp.gmail.com:587 and an app password."
  type = object({
    to            = string
    from          = string
    smarthost     = string
    auth_username = string
    auth_password = string
  })
  default   = null
  sensitive = true
}

variable "chart_versions" {
  description = "Pinned chart versions"
  type = object({
    kube_prometheus_stack = string
    loki                  = string
    promtail              = string
  })
  default = {
    kube_prometheus_stack = "93.1.0"
    loki                  = "7.5.0"
    promtail              = "6.17.1"
  }
}

variable "alert_receiver_image" {
  description = "In-cluster webhook that logs every alert it gets (visible in Loki), so alert delivery can be shown without Slack or email"
  type        = string
  default     = "mendhak/http-https-echo:43"
}
