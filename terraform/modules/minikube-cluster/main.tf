# Reusable module: a single-node Minikube cluster sized for a 16 GB laptop.
resource "minikube_cluster" "this" {
  cluster_name       = var.cluster_name
  driver             = var.driver
  kubernetes_version = var.kubernetes_version
  cpus               = var.cpus
  memory             = var.memory
  addons             = var.addons
}
