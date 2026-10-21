# Which Terraform and provider versions this code is written for.
# `terraform init` records the exact provider version it picks in
# .terraform.lock.hcl, which should be committed once it exists.
terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }

  # State is kept in a local file (terraform.tfstate), which is ignored by Git.
  # A remote S3 backend is an optional stretch goal and is not configured here.
}
