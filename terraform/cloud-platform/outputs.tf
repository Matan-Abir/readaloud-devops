output "grafana_url" {
  value = module.monitoring.urls["grafana"]
}

output "namespace" {
  value = module.environment.namespace
}

output "helm_command" {
  description = "PowerShell, from the readaloud-devops folder, with $gk holding the Gemini key (see the guide)"
  value = join(" ", [
    "helm upgrade --install readaloud helm/readaloud",
    "-n ${module.environment.namespace}",
    "-f helm/readaloud/values-prod.yaml -f helm/readaloud/values-cloud.yaml",
    "--set-string ingress.host=app.${local.base_domain}",
    "--set-string secrets.geminiApiKey=$gk",
    "--wait --timeout 10m",
  ])
}
