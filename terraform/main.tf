# The platform: a Minikube cluster plus one namespace per environment.
# The application itself is deployed with the Helm chart (helm/readaloud), by
# hand now and by Jenkins later, so app releases don't need a Terraform run.
# Monitoring and logging get added here in a later step.

module "cluster" {
  source = "./modules/minikube-cluster"

  cluster_name       = var.cluster_name
  driver             = var.driver
  kubernetes_version = var.kubernetes_version
  cpus               = var.cpus
  memory             = var.memory
}

resource "kubernetes_namespace_v1" "env" {
  for_each = toset(var.namespaces)

  metadata {
    name = each.key
    labels = {
      "app.kubernetes.io/part-of" = "readaloud"
      environment                 = each.key
    }
  }
}
