# The platform, shared by every environment: the Minikube cluster plus the
# monitoring and logging stack. Environments (namespaces with quotas) are a
# separate root, terraform/environments, one Terraform workspace each. The app
# itself is released with Helm by Jenkins, so app releases need no Terraform run.

module "cluster" {
  source = "../modules/minikube-cluster"

  cluster_name       = var.cluster_name
  driver             = var.driver
  kubernetes_version = var.kubernetes_version
  cpus               = var.cpus
  memory             = var.memory
}

module "monitoring" {
  source = "../modules/monitoring"
  count  = var.monitoring_enabled ? 1 : 0

  base_domain            = var.base_domain
  grafana_admin_password = var.grafana_admin_password
  slack_webhook_url      = var.slack_webhook_url
  slack_channel          = var.slack_channel
  alert_email            = var.alert_email

  depends_on = [module.cluster]
}
