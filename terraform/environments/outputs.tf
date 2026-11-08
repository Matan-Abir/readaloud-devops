output "namespace" {
  value = one(module.environment[*].namespace)
}

output "next_step" {
  value = "Deploy into it: run the Jenkins job, or DEPLOY_ENV=${terraform.workspace} ./scripts/deploy.sh"
}
