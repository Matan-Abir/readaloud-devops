variable "cluster_name" {
  description = "Minikube profile name"
  type        = string
  default     = "readaloud"
}

variable "driver" {
  description = "Minikube driver: docker (works with Docker Desktop on Windows/macOS/Linux) or hyperv"
  type        = string
  default     = "docker"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the cluster"
  type        = string
  default     = "v1.37.0"
}

variable "cpus" {
  description = "CPUs allocated to the Minikube node"
  type        = number
  default     = 4
}

variable "memory" {
  description = "Memory allocated to the Minikube node (e.g. 6144mb)"
  type        = string
  default     = "6144mb"
}

variable "addons" {
  description = "Minikube addons to enable"
  type        = list(string)
  default     = ["default-storageclass", "storage-provisioner", "ingress", "metrics-server"]
}
