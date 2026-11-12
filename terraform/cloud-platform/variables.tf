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

variable "argocd_chart_versions" {
  description = "Pinned chart versions from https://argoproj.github.io/argo-helm"
  type = object({
    argo_cd       = string
    image_updater = string
  })
  default = {
    argo_cd       = "10.11.6" # Argo CD v3.5.6
    image_updater = "1.3.2"   # Argo CD Image Updater v1.3.1
  }
}

variable "gitops_repo_url" {
  description = "Repo Argo CD reads the Helm chart from (public, so no credentials)"
  type        = string
  default     = "https://github.com/Matan-Abir/readaloud-devops.git"
}

variable "gitops_branch" {
  description = "Branch Argo CD follows"
  type        = string
  default     = "master"
}

variable "app_secret_name" {
  description = "Secret in the prod namespace with GEMINI_API_KEY, JWT_SECRET_KEY and POSTGRES_PASSWORD. Made once by hand (docs/CLOUD.md part 6), never in git"
  type        = string
  default     = "readaloud-secret"
}
