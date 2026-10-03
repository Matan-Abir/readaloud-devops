# Provisions the whole platform: Minikube cluster + namespaces + monitoring + logging.
# The application itself is deployed by the Helm chart (helm/readaloud) from the
# CI/CD pipeline, so app releases don't require a Terraform run.

module "cluster" {
  source = "./modules/minikube-cluster"

  cluster_name       = var.cluster_name
  driver             = var.driver
  kubernetes_version = var.kubernetes_version
  cpus               = var.cpus
  memory             = var.memory
}

resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
  }
}

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "kube_prometheus_stack" {
  count      = var.install_monitoring ? 1 : 0
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "65.1.1"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 900

  values = [file("${path.module}/../monitoring/kube-prometheus-stack-values.yaml")]

  set_sensitive {
    name  = "grafana.adminPassword"
    value = var.grafana_admin_password
  }
}

resource "helm_release" "loki_stack" {
  count      = var.install_logging ? 1 : 0
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki-stack"
  version    = "2.10.2"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600

  values = [file("${path.module}/../logging/loki-stack-values.yaml")]
}
