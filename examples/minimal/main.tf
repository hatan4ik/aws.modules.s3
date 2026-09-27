provider "aws" {
  region = var.region
}

# The smallest call: a name and tags. Everything else is the module's secure
# default: public access blocked, ACLs disabled, versioning on, SSE-KMS with
# the AWS managed key and an S3 Bucket Key, and a policy that denies
# unencrypted transport.
module "bucket" {
  source = "../../"

  bucket = var.bucket
  tags   = var.tags
}
