terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.5"
    }
  }

  # Same remote state as the other roots: the Postgres from terraform/state on
  # the PC that runs Terraform (AWS never talks to it), in its own schema.
  #   terraform init -backend-config=../state/pg.tfbackend
  backend "pg" {
    schema_name = "readaloud_cloud"
  }
}

# Credentials come from `aws configure` (the default profile), never from files in git.
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "readaloud"
      ManagedBy = "terraform"
      Root      = "terraform/cloud"
    }
  }
}
