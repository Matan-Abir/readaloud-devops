# The platform on the k3s cluster in AWS, built from the SAME modules as on
# Minikube (terraform/platform + terraform/environments):
#   monitoring       Prometheus, Alertmanager, Grafana, Loki, Promtail, dashboard
#   app-environment  the prod namespace with its quota and default limits
# Differences from Minikube: Traefik (k3s's Ingress controller) instead of
# ingress-nginx, nip.io hostnames, and no public Prometheus/Alertmanager UI.
# The app itself is deployed by Argo CD (argocd.tf), from helm/readaloud in git.

# Outputs of terraform/cloud (public IP, nip.io domain) from its remote state.
data "terraform_remote_state" "cloud" {
  backend = "pg"
  config = {
    conn_str    = var.state_conn_str
    schema_name = "readaloud_cloud"
  }
}

locals {
  base_domain = data.terraform_remote_state.cloud.outputs.base_domain
  argocd_host = "argocd.${local.base_domain}"
}

module "monitoring" {
  source = "../modules/monitoring"

  base_domain            = local.base_domain
  ingress_class_name     = "traefik"
  expose_admin_uis       = false
  grafana_admin_password = var.grafana_admin_password
}

module "environment" {
  source = "../modules/app-environment"

  name = var.environment
  quota = {
    requests_cpu    = "2"
    requests_memory = "3Gi"
    limits_cpu      = "6"
    limits_memory   = "6Gi"
    pods            = 12
    pvcs            = 4
    storage         = "10Gi"
  }
}
