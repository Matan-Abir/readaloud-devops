output "grafana_url" {
  value = module.monitoring.urls["grafana"]
}

output "namespace" {
  value = module.environment.namespace
}

output "app_url" {
  value = "http://app.${local.base_domain}"
}

output "argocd_url" {
  description = "Argo CD UI, user admin"
  value       = "http://${local.argocd_host}"
}

output "argocd_password_command" {
  description = "PowerShell: prints the generated Argo CD admin password"
  value       = "[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String((kubectl get secret -n argocd argocd-initial-admin-secret -o jsonpath='{.data.password}')))"
}
