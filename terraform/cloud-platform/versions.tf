terraform {
  required_version = ">= 1.10"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.5"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
  }

  #   terraform init -backend-config=../state/pg.tfbackend
  backend "pg" {
    schema_name = "readaloud_cloud_platform"
  }
}

# The k3s cluster in AWS, through the kubeconfig copied from the instance
# (terraform -chdir=../cloud output kubeconfig_command).
provider "kubernetes" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = var.kube_context
}

provider "helm" {
  kubernetes = {
    config_path    = pathexpand(var.kubeconfig_path)
    config_context = var.kube_context
  }
}
