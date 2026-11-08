variable "name" {
  description = "Environment name; also the namespace the Helm chart is installed into"
  type        = string
}

variable "quota" {
  description = "Upper bound for everything running in the environment (requests and limits summed over all pods)"
  type = object({
    requests_cpu    = string
    requests_memory = string
    limits_cpu      = string
    limits_memory   = string
    pods            = number
    pvcs            = number
    storage         = string
  })
}

variable "default_container_limits" {
  description = "Applied to containers that set none (e.g. init containers), so the quota can be enforced"
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "500m"
    memory = "384Mi"
  }
}
