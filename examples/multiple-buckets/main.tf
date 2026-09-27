provider "aws" {
  region = var.region
}

# One module call is one bucket. A fleet is a for_each over the module block,
# so each bucket keeps its own plan, its own validation errors, and its own
# lifecycle while sharing the naming scheme and tags.
module "bucket" {
  source   = "../../"
  for_each = var.buckets

  bucket      = "${var.name_prefix}-${each.key}"
  versioning  = each.value.versioning
  kms_key_arn = each.value.kms_key_arn
  tags        = merge(var.tags, { Dataset = each.key })

  lifecycle_rules = {
    for id in(each.value.expire_after_days == null ? [] : ["expire-objects"]) : id => {
      expiration                             = { days = each.value.expire_after_days }
      noncurrent_version_expiration          = { noncurrent_days = 30 }
      abort_incomplete_multipart_upload_days = 7
    }
  }
}
