output "cluster_name" {
  value = minikube_cluster.this.cluster_name
}

output "host" {
  value = minikube_cluster.this.host
}

output "client_certificate" {
  value     = minikube_cluster.this.client_certificate
  sensitive = true
}

output "client_key" {
  value     = minikube_cluster.this.client_key
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = minikube_cluster.this.cluster_ca_certificate
  sensitive = true
}
