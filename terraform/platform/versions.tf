terraform {
  required_version = ">= 1.10"

  required_providers {
    minikube = {
      source  = "scott-the-programmer/minikube"
      version = "~> 0.8"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.5"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
  }

  # Remote state in the local Postgres from terraform/state (docker compose up -d).
  #   terraform init -backend-config=../state/pg.tfbackend
  backend "pg" {
    schema_name = "readaloud_platform"
  }
}

provider "minikube" {
  kubernetes_version = var.kubernetes_version
}

locals {
  cluster_auth = {
    host                   = module.cluster.host
    client_certificate     = module.cluster.client_certificate
    client_key             = module.cluster.client_key
    cluster_ca_certificate = module.cluster.cluster_ca_certificate
  }
}

provider "kubernetes" {
  host                   = local.cluster_auth.host
  client_certificate     = local.cluster_auth.client_certificate
  client_key             = local.cluster_auth.client_key
  cluster_ca_certificate = local.cluster_auth.cluster_ca_certificate
}

provider "helm" {
  kubernetes = local.cluster_auth
}
