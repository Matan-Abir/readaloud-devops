output "cluster_name" {
  value = module.cluster.cluster_name
}

output "api_server" {
  value = module.cluster.host
}

output "next_steps" {
  value = <<-EOT
    kubectl config use-context ${module.cluster.cluster_name}
    ../scripts/deploy.sh                      # build image + helm upgrade --install
    kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
  EOT
}
