# The AWS provider talks to the AWS APIs. Credentials are NOT set here: they
# come from the environment (for example `aws login`), so none are in Git.
provider "aws" {
  region = var.region

  # Every resource that supports tags gets these, so project resources are
  # easy to find and are never confused with anything else in the account.
  default_tags {
    tags = {
      Project   = "devops-capstone-voting-app"
      Owner     = "tivere-madagwa"
      ManagedBy = "terraform"
    }
  }
}
