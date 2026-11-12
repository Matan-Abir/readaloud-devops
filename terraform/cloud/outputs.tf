output "public_ip" {
  description = "Elastic IP of the k3s node (stays the same across stop/start)"
  value       = aws_eip.this.public_ip
}

output "base_domain" {
  description = "nip.io resolves <anything>.<ip>.nip.io to <ip>, so no DNS setup is needed"
  value       = local.base_domain
}

output "app_url" {
  value = "http://app.${local.base_domain}"
}

output "grafana_url" {
  value = "http://grafana.${local.base_domain}"
}

output "instance_id" {
  value = aws_instance.this.id
}

output "admin_cidr" {
  description = "The only address allowed to SSH and to the Kubernetes API"
  value       = local.admin_cidr
}

output "ssh_command" {
  value = "ssh -i \"$HOME\\.ssh\\readaloud-aws\" ubuntu@${aws_eip.this.public_ip}"
}

output "kubeconfig_command" {
  description = "PowerShell: copy the cluster's kubeconfig to the PC"
  value       = "scp -i \"$HOME\\.ssh\\readaloud-aws\" ubuntu@${aws_eip.this.public_ip}:kubeconfig \"$HOME\\.kube\\readaloud-aws.yaml\""
}

output "stop_command" {
  description = "Pause between sessions: no instance charge while stopped (disk and IP still cost a few cents a day)"
  value       = "aws ec2 stop-instances --region ${var.region} --instance-ids ${aws_instance.this.id}"
}

output "start_command" {
  value = "aws ec2 start-instances --region ${var.region} --instance-ids ${aws_instance.this.id}"
}
