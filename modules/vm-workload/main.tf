locals {
  name      = "${var.prefix_name}-vm-workload"
  disk_size = 8
  ssh_port  = 22
  # Ztunnel HBONE mTLS tunnel port (Istio ambient default)
  hbone_port = 15008
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  name_regex  = "^amzn2-ami-hvm.*-ebs"

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "tls_private_key" "vm_workload" {
  count = var.enable ? 1 : 0

  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "vm_workload" {
  count = var.enable ? 1 : 0

  key_name   = "${local.name}-key"
  public_key = tls_private_key.vm_workload[0].public_key_openssh

  tags = var.tags
}

resource "local_sensitive_file" "vm_workload_private_key" {
  count = var.enable ? 1 : 0

  content         = tls_private_key.vm_workload[0].private_key_pem
  filename        = "${path.module}/output/${local.name}-key.pem"
  file_permission = "0600"
}

resource "aws_security_group" "vm_workload" {
  count = var.enable ? 1 : 0

  description = "VM workload security group for ambient mesh multi-workload identity"
  name        = "${local.name}-sg"
  vpc_id      = var.vpc_id

  tags = var.tags
}

resource "aws_security_group_rule" "ingress_ssh" {
  count = var.enable ? 1 : 0

  description       = "SSH access to the VM workload"
  type              = "ingress"
  from_port         = local.ssh_port
  to_port           = local.ssh_port
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.vm_workload[0].id
}

resource "aws_security_group_rule" "ingress_hbone" {
  count = var.enable ? 1 : 0

  description              = "Ztunnel HBONE tunnel port from cluster worker nodes"
  type                     = "ingress"
  from_port                = local.hbone_port
  to_port                  = local.hbone_port
  protocol                 = "tcp"
  source_security_group_id = var.cluster_worker_security_group_id
  security_group_id        = aws_security_group.vm_workload[0].id
}

resource "aws_security_group_rule" "egress_vm_workload" {
  count = var.enable ? 1 : 0

  description       = "Outgoing traffic from the VM workload"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.vm_workload[0].id
}

resource "aws_instance" "vm_workload" {
  count = var.enable ? 1 : 0

  ami                         = data.aws_ami.amazon_linux_2.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.vm_workload[0].id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.vm_workload[0].key_name

  root_block_device {
    volume_size           = local.disk_size
    volume_type           = "gp2"
    delete_on_termination = true
  }

  tags = merge(var.tags, {
    Name = local.name
  })

  lifecycle {
    create_before_destroy = true
  }
}
