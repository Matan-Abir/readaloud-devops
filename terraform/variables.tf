variable "cluster_name" {
  description = "Minikube profile name (also the kubectl context name)"
  type        = string
  default     = "readaloud"
}

variable "driver" {
  description = "Minikube driver"
  type        = string
  default     = "docker"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "v1.37.0"
}

variable "cpus" {
  description = "CPUs for the Minikube node"
  type        = number
  default     = 4
}

variable "memory" {
  description = "Memory for the Minikube node"
  type        = string
  default     = "6144mb"
}

variable "namespaces" {
  description = "One namespace per environment the Helm chart is deployed to"
  type        = list(string)
  default     = ["dev", "staging"]
}
