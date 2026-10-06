# Fixture for the contract tests: a KMS key and the bucket encrypted under it,
# declared in one configuration the way a caller does when the key and the
# bucket belong to the same root. The key ARN is a computed attribute, so it
# is unknown while the plan is built, and every value derived from it,
# including a rendered bucket policy that names the key, is known only after
# apply. The module must still plan: its resource counts may depend on inputs
# alone, never on a rendered document. terraform test plans this root under
# mock_provider and discards it; nothing is created.

resource "aws_kms_key" "this" {
  description             = "Fixture key for ${var.bucket}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

module "bucket" {
  source = "../../.."

  bucket = var.bucket

  kms_key_arn                     = aws_kms_key.this.arn
  deny_insecure_transport         = var.deny_insecure_transport
  deny_unencrypted_object_uploads = var.deny_unencrypted_object_uploads
  deny_incorrect_encryption_key   = var.deny_incorrect_encryption_key
}
