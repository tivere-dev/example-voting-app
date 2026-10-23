# The brief asks for the cluster to live in the DEFAULT VPC. Terraform does
# not create or change the VPC; it only looks it up ("data" = read-only).

data "aws_vpc" "default" {
  default = true
}

# The default VPC has one public "default" subnet per Availability Zone.
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Read each subnet so we know which Availability Zone it is in.
data "aws_subnet" "default" {
  for_each = toset(data.aws_subnets.default.ids)
  id       = each.value
}

locals {
  # Drop subnets in zones that EKS does not support, and sort the IDs so the
  # list (and therefore the plan) does not change order between runs.
  cluster_subnet_ids = sort([
    for subnet in data.aws_subnet.default : subnet.id
    if !contains(var.excluded_az_ids, subnet.availability_zone_id)
  ])
}
