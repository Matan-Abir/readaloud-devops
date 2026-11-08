terraform {
  required_version = ">= 1.10"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.5"
    }
  }

  # Same Postgres as terraform/platform, its own schema; one state per workspace.
  #   terraform init -backend-config=../state/pg.tfbackend
  backend "pg" {
    schema_name = "readaloud_environments"
  }
}

# Uses the kubectl context Minikube writes (`minikube -p readaloud update-context`),
# so this root doesn't depend on the platform state.
provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}
