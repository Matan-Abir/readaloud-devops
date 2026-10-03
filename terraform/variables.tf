variable "cluster_name" {
  type    = string
  default = "readaloud"
}

variable "driver" {
  type    = string
  default = "docker"
}

variable "kubernetes_version" {
  type    = string
  default = "v1.31.0"
}

variable "cpus" {
  type    = number
  default = 4
}

variable "memory" {
  type    = string
  default = "6144mb"
}

variable "app_namespace" {
  description = "Namespace the ReadAloud Helm chart is deployed into (by Jenkins / deploy.sh)"
  type        = string
  default     = "readaloud"
}

variable "install_monitoring" {
  description = "Install kube-prometheus-stack (Prometheus, Alertmanager, Grafana)"
  type        = bool
  default     = true
}

variable "install_logging" {
  description = "Install Loki + Promtail"
  type        = bool
  default     = true
}

variable "grafana_admin_password" {
  description = "Grafana admin password (pass via TF_VAR_grafana_admin_password, never commit)"
  type        = string
  sensitive   = true
  default     = "admin"
}
