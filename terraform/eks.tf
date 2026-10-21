# --- The Kubernetes control plane (managed by AWS) ---

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = local.cluster_subnet_ids
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = var.api_allowed_cidrs
  }

  # Who may use kubectl: access entries (the "API" mode). The identity that
  # runs `terraform apply` is made a cluster admin so it can deploy afterwards.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  # Cost guard: when 1.36 leaves standard support, upgrade automatically
  # instead of moving to paid extended support (an extra $0.50 per hour).
  upgrade_policy {
    support_type = "STANDARD"
  }

  # Control plane logs to CloudWatch are off to avoid log storage charges.
  enabled_cluster_log_types = []

  # The role's policy must be attached before the cluster is created, and must
  # stay attached until the cluster has been deleted.
  depends_on = [aws_iam_role_policy_attachment.cluster]
}

# --- Settings for the worker node EC2 instances ---

resource "aws_launch_template" "node" {
  name_prefix = "${var.cluster_name}-node-"

  # Cost guard: "standard" CPU credits mean a t3 instance slows down when it
  # runs out of burst credits instead of billing extra for "unlimited" mode.
  credit_specification {
    cpu_credits = "standard"
  }

  # Require IMDSv2 tokens for the instance metadata service (blocks a common
  # credential-theft technique). A hop limit of 2 matches the EKS default.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.node_disk_size_gib
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Tag the EC2 instances and disks too (default_tags does not reach them).
  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.cluster_name}-node" }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "${var.cluster_name}-node" }
  }
}

# --- The worker nodes (managed node group) ---

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-default"
  node_role_arn   = aws_iam_role.node.arn

  # Default-VPC subnets are public and give each node a public IP, so nodes can
  # reach the internet without a NAT gateway (which would cost extra).
  subnet_ids = local.cluster_subnet_ids

  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  instance_types = var.node_instance_types

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  # Node policies must exist before nodes join, and must outlive them on destroy.
  depends_on = [aws_iam_role_policy_attachment.node]
}
