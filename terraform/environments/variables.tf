variable "kubeconfig_path" {
  description = "kubeconfig with the Minikube context"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubectl context of the cluster (the Minikube profile name)"
  type        = string
  default     = "readaloud"
}
