variable "cluster_name" {
  description = "Minikube profile name (also the kubectl context and the node's Docker network)"
  type        = string
  default     = "readaloud"
}

variable "driver" {
  description = "Minikube driver"
  type        = string
  default     = "docker"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.37.0"
}

variable "cpus" {
  description = "CPUs for the Minikube node"
  type        = number
  default     = 4
}

variable "memory" {
  description = "Memory for the Minikube node: app in dev + staging, Prometheus, Grafana, Loki"
  type        = string
  default     = "6144mb"
}

variable "base_domain" {
  description = "Hostnames: readaloud.local (dev), staging.readaloud.local, grafana.readaloud.local, ..."
  type        = string
  default     = "readaloud.local"
}

variable "monitoring_enabled" {
  description = "Install Prometheus, Alertmanager, Grafana, Loki and Promtail"
  type        = bool
  default     = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password (user admin)"
  type        = string
  default     = "ReadAloud-Grafana-2026!"
  sensitive   = true
}

variable "slack_webhook_url" {
  description = "Optional Slack incoming webhook for alerts (set in terraform.tfvars, never in git)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "slack_channel" {
  description = "Slack channel for alerts"
  type        = string
  default     = "#readaloud-alerts"
}

variable "alert_email" {
  description = "Optional email for alerts, e.g. Gmail with an app password (see terraform.tfvars.example)"
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
