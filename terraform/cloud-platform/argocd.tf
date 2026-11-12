# GitOps on the AWS cluster (ADR 0008). Three Helm releases in the argocd namespace:
#   argocd          Argo CD: keeps the prod namespace equal to the Helm chart in git
#   image-updater   Argo CD Image Updater: watches GHCR, tells Argo CD about new images
#   gitops          our own small chart (./gitops): the Application and ImageUpdater
#                   objects that connect the two to ReadAloud
# The last one is separate because its objects use the CRDs that the first two
# install, and Helm can't create a CRD and its objects in one release.

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_versions.argo_cd
  timeout    = 600

  values = [yamlencode({
    configs = {
      # TLS ends at Traefik's port 80 like the other demo UIs, so the server speaks plain HTTP.
      params = { "server.insecure" = true }
      # How often Argo CD re-reads git (default 3 min).
      cm = { "timeout.reconciliation" = "60s" }
    }
    # Not needed for one admin user: no SSO (Dex), no Slack/email notifications.
    dex           = { enabled = false }
    notifications = { enabled = false }
    server = {
      ingress = {
        enabled          = true
        ingressClassName = "traefik"
        hostname         = local.argocd_host
      }
    }
  })]
}

resource "helm_release" "image_updater" {
  name       = "argocd-image-updater"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-image-updater"
  version    = var.argocd_chart_versions.image_updater
  timeout    = 300

  # Checks the registry every 2 minutes (the default interval).
  values = [yamlencode({
    config = { "argocd.namespace" = "argocd" }
  })]

  depends_on = [helm_release.argocd]
}

resource "helm_release" "gitops" {
  name      = "readaloud-gitops"
  namespace = kubernetes_namespace_v1.argocd.metadata[0].name
  chart     = "${path.module}/gitops"

  values = [yamlencode({
    repoURL        = var.gitops_repo_url
    targetRevision = var.gitops_branch
    namespace      = module.environment.namespace
    ingressHost    = "app.${local.base_domain}"
    existingSecret = var.app_secret_name
  })]

  depends_on = [helm_release.argocd, helm_release.image_updater]
}
