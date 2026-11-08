# ReadAloud in AWS for the class demo: one EC2 instance running k3s (single-node
# Kubernetes) with a fixed public IP. The same Helm chart and monitoring module
# as on Minikube are installed on it afterwards (terraform/cloud-platform, then
# helm). Public URLs use nip.io, so no domain or DNS setup is needed:
#   app.<ip>.nip.io  grafana.<ip>.nip.io
#
# Cost: about 0.10 USD an hour while it exists. `terraform destroy` removes
# everything this file creates.

locals {
  # 22 and 6443 are open only to this address (default: the PC's public IP).
  admin_cidr  = var.admin_cidr != "" ? var.admin_cidr : "${chomp(data.http.my_ip.response_body)}/32"
  base_domain = "${aws_eip.this.public_ip}.nip.io"
}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"
}

# Ubuntu 24.04 LTS from Canonical's own AWS account, newest build.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# The account's default VPC, in an availability zone that offers the instance
# type (not every zone has every type).
data "aws_vpc" "default" {
  default = true
}

data "aws_ec2_instance_type_offerings" "here" {
  location_type = "availability-zone"
  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
  filter {
    name   = "availability-zone"
    values = data.aws_ec2_instance_type_offerings.here.locations
  }
}

resource "aws_key_pair" "this" {
  key_name   = var.name
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# Firewall: the web (80/443) is open to everyone; SSH and the Kubernetes API only
# to the admin address. Grafana is reached through 80; Prometheus and
# Alertmanager are not published (kubectl port-forward).
resource "aws_security_group" "this" {
  name        = var.name
  description = "ReadAloud k3s node"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "web" {
  for_each = { http = 80, https = 443 }

  security_group_id = aws_security_group.this.id
  description       = each.key
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = each.value
  to_port           = each.value
}

resource "aws_vpc_security_group_ingress_rule" "admin" {
  for_each = { ssh = 22, kubernetes-api = 6443 }

  security_group_id = aws_security_group.this.id
  description       = each.key
  cidr_ipv4         = local.admin_cidr
  ip_protocol       = "tcp"
  from_port         = each.value
  to_port           = each.value
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.this.id
  description       = "image pulls, Gemini API, OS updates"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Allocated before the instance so its address can go into the k3s API
# certificate and the kubeconfig; stays the same across stop/start.
resource "aws_eip" "this" {
  domain = "vpc"
  tags   = { Name = var.name }
}

resource "aws_instance" "this" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids = [aws_security_group.this.id]
  key_name               = aws_key_pair.this.key_name

  user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    name        = var.name
    public_ip   = aws_eip.this.public_ip
    k3s_channel = var.k3s_channel
  })
  # A changed script means a new machine (user data runs only on first boot).
  user_data_replace_on_change = true

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_gb
    encrypted   = true
  }

  # IMDSv2 only: pods can't read the instance's metadata with a plain GET.
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tags = { Name = var.name }

  lifecycle {
    ignore_changes = [ami] # a newer Ubuntu image must not replace a running demo
  }
}

resource "aws_eip_association" "this" {
  allocation_id = aws_eip.this.id
  instance_id   = aws_instance.this.id
}
