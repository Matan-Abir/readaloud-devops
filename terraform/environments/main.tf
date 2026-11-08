# One Terraform workspace per environment:
#   terraform workspace select -or-create dev      (then staging, prod)
#   terraform apply
# The workspace name picks the settings below and becomes the namespace name.

locals {
  environments = {
    # One backend pod; room for a rolling update (maxSurge 1).
    dev = {
      requests_cpu    = "1500m"
      requests_memory = "2Gi"
      limits_cpu      = "4"
      limits_memory   = "4Gi"
      pods            = 10
      pvcs            = 4
      storage         = "10Gi"
    }
    # Production-like: two backend pods.
    staging = {
      requests_cpu    = "2"
      requests_memory = "3Gi"
      limits_cpu      = "6"
      limits_memory   = "6Gi"
      pods            = 12
      pvcs            = 4
      storage         = "10Gi"
    }
    prod = {
      requests_cpu    = "2"
      requests_memory = "3Gi"
      limits_cpu      = "6"
      limits_memory   = "6Gi"
      pods            = 12
      pvcs            = 4
      storage         = "10Gi"
    }
  }
}

check "known_workspace" {
  assert {
    condition     = contains(keys(local.environments), terraform.workspace)
    error_message = "Select an environment workspace first: terraform workspace select -or-create dev (or staging, prod)."
  }
}

module "environment" {
  source = "../modules/app-environment"
  count  = contains(keys(local.environments), terraform.workspace) ? 1 : 0

  name  = terraform.workspace
  quota = lookup(local.environments, terraform.workspace, local.environments.dev)
}
