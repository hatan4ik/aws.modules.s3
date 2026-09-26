# Disposable prerequisites for the integration suites: a globally unique bucket
# name and identifying tags. The module under test needs nothing else from the
# account, so this fixture creates no AWS resource; the random suffix keeps
# concurrent runs from colliding on the bucket namespace.

resource "random_id" "suffix" {
  byte_length = 4
}

locals {
  bucket_name = "${var.name_prefix}-${random_id.suffix.hex}"

  tags = merge(var.tags, {
    IntegrationTest = "aws.modules.s3"
    Disposable      = "true"
  })
}
