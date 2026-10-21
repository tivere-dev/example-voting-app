variable "region" {
  description = "AWS region for the cluster."
  type        = string
  default     = "eu-west-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster. Also used as a prefix for related resources."
  type        = string
  default     = "voting-app"
}

variable "kubernetes_version" {
  description = "Kubernetes minor version. Must be in EKS standard support (1.36 is supported until 2 Aug 2027)."
  type        = string
  default     = "1.36"
}

variable "api_allowed_cidrs" {
  description = "IP ranges allowed to reach the cluster's public API endpoint, for example [\"203.0.113.10/32\"]. No default, so the API is never left open to the whole internet by accident."
  type        = list(string)

  validation {
    condition     = length(var.api_allowed_cidrs) > 0 && !contains(var.api_allowed_cidrs, "0.0.0.0/0")
    error_message = "Set at least one CIDR, and do not use 0.0.0.0/0 (the whole internet)."
  }
}

variable "excluded_az_ids" {
  description = "Availability Zone IDs where EKS cannot run its control plane. In us-east-1 this is [\"use1-az3\"]; eu-west-1 has none."
  type        = list(string)
  default     = []
}

variable "node_instance_types" {
  description = "EC2 instance types for the worker nodes."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Number of worker nodes to run normally."
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Smallest number of worker nodes."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Largest number of worker nodes."
  type        = number
  default     = 3
}

variable "node_disk_size_gib" {
  description = "Root disk size for each worker node, in GiB."
  type        = number
  default     = 20
}
