output "cluster_name" {
  value = module.cluster.cluster_name
}

output "api_server" {
  value = module.cluster.host
}

output "namespaces" {
  value = [for ns in kubernetes_namespace_v1.env : ns.metadata[0].name]
}
