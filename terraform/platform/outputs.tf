output "cluster_name" {
  value = module.cluster.cluster_name
}

output "api_server" {
  value = module.cluster.host
}

output "monitoring_urls" {
  description = "Open these while `minikube -p readaloud tunnel` runs"
  value       = var.monitoring_enabled ? module.monitoring[0].urls : {}
}
