variable "name" {
  description = "Name for the instance, key pair, security group and k3s node"
  type        = string
  default     = "readaloud"
}

variable "region" {
  description = "AWS region (us-east-1 is the cheapest; latency doesn't matter for a demo)"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "2 vCPU / 8 GB fits k3s, the app and the monitoring stack. m7i-flex.large is allowed on the AWS Free plan (paid from the sign-up credits); t3.large is the same size on a paid plan"
  type        = string
  default     = "m7i-flex.large"
}

variable "root_volume_gb" {
  description = "Root disk (gp3): OS, k3s, container images, Postgres, uploads, Loki"
  type        = number
  default     = 30
}

variable "ssh_public_key_path" {
  description = "Public half of the key made with ssh-keygen (the private half never leaves the PC)"
  type        = string
  default     = "~/.ssh/readaloud-aws.pub"
}

variable "admin_cidr" {
  description = "Who may use SSH (22) and the Kubernetes API (6443). Empty = this PC's current public IP, looked up at plan time"
  type        = string
  default     = ""
}

variable "k3s_channel" {
  description = "k3s release channel (stable = the current recommended Kubernetes minor)"
  type        = string
  default     = "stable"
}
