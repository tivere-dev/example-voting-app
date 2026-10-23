# Useful values printed after `terraform apply`. None of these are secrets.

output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "HTTPS address of the Kubernetes API server."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the control plane."
  value       = aws_eks_cluster.this.version
}

output "vpc_id" {
  description = "ID of the default VPC the cluster uses."
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "Default-VPC subnets used by the cluster and nodes."
  value       = local.cluster_subnet_ids
}

output "node_group_name" {
  description = "Name of the managed node group."
  value       = aws_eks_node_group.default.node_group_name
}

output "configure_kubectl" {
  description = "Command that adds this cluster to your kubeconfig."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.this.name}"
}
