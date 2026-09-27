# Advisory checks: they warn on every plan and apply but never block. Each
# describes a configuration that is valid yet usually unintended.

check "force_destroy_enabled" {
  assert {
    condition     = !var.force_destroy
    error_message = "force_destroy is true: terraform destroy will delete every object and object version in the bucket. Set it to false once the bucket holds data that matters."
  }
}

check "versioning_not_enabled" {
  assert {
    condition     = var.versioning == "Enabled"
    error_message = "Versioning is not Enabled: overwritten and deleted objects cannot be recovered, and Object Lock and noncurrent-version lifecycle rules have nothing to act on."
  }
}

check "ownership_not_enforced" {
  assert {
    condition     = var.object_ownership == "BucketOwnerEnforced"
    error_message = "object_ownership is not BucketOwnerEnforced: ACLs are enabled and object access can be granted outside the bucket policy. Prefer BucketOwnerEnforced unless a legacy client writes ACLs."
  }
}
