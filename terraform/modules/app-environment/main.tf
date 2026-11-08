# Reusable module: one application environment (dev, staging, prod) on the
# shared cluster. A namespace, a ResourceQuota so one environment can't starve
# the others, and a LimitRange with defaults for containers that set no limits.

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = var.name
    labels = {
      "app.kubernetes.io/part-of" = "readaloud"
      environment                 = var.name
    }
  }
}

resource "kubernetes_resource_quota_v1" "this" {
  metadata {
    name      = "${var.name}-quota"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"         = var.quota.requests_cpu
      "requests.memory"      = var.quota.requests_memory
      "limits.cpu"           = var.quota.limits_cpu
      "limits.memory"        = var.quota.limits_memory
      pods                   = var.quota.pods
      persistentvolumeclaims = var.quota.pvcs
      "requests.storage"     = var.quota.storage
    }
  }
}

resource "kubernetes_limit_range_v1" "this" {
  metadata {
    name      = "${var.name}-defaults"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec {
    limit {
      type = "Container"
      default = {
        cpu    = var.default_container_limits.cpu
        memory = var.default_container_limits.memory
      }
      default_request = {
        cpu    = "50m"
        memory = "64Mi"
      }
    }
  }
}
