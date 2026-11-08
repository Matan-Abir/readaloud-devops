output "namespace" {
  value = kubernetes_namespace_v1.this.metadata[0].name
}

output "urls" {
  description = "Monitoring UIs (need the hosts-file line and `minikube tunnel`)"
  value       = { for k, h in local.hosts : k => "http://${h}" }
}
