variable "kubeconfig_path" {
  description = "kubeconfig of the k3s cluster in AWS"
  type        = string
  default     = "~/.kube/readaloud-aws.yaml"
}

variable "kube_context" {
  description = "Context name inside that kubeconfig (set by the instance's first-boot script)"
  type        = string
  default     = "readaloud-aws"
}

variable "state_conn_str" {
  description = "Where terraform/cloud keeps its state (same Postgres as ../state/pg.tfbackend), to read its outputs"
  type        = string
  default     = "postgres://tfstate:tfstate@127.0.0.1:5433/tfstate?sslmode=disable"
}

variable "grafana_admin_password" {
  description = "Grafana admin password. Grafana is on the internet here, so there is no default: put it in terraform.tfvars (gitignored)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.grafana_admin_password) >= 12
    error_message = "Use at least 12 characters: this Grafana is reachable from the whole internet."
  }
}

variable "environment" {
  description = "Namespace the app is released into (Helm -n). The AWS cluster plays prod; dev and staging stay on Minikube"
  type        = string
  default     = "prod"
}
