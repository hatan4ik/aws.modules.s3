locals {
  # Derived from partition and name so the policy is known at plan time and the
  # module never reads from the account.
  bucket_arn = "arn:${var.partition}:s3:::${var.bucket}"

  # A caller-supplied document replaces the composed one; the precondition on
  # aws_s3_bucket_policy.this makes the takeover explicit.
  policy_json = var.policy_json_override != null ? var.policy_json_override : module.bucket_policy.json

  # Rules with the filter normalised so the resource can count its criteria.
  lifecycle_rules = {
    for id, rule in var.lifecycle_rules : id => merge(rule, {
      filter = rule.filter == null ? {
        prefix                   = null
        tags                     = {}
        object_size_greater_than = null
        object_size_less_than    = null
      } : rule.filter
    })
  }

  # The S3 API takes a single criterion directly (prefix, one tag, or one
  # size bound) and requires an And element for two or more criteria, which
  # includes any filter with more than one tag. Zero criteria is an empty
  # filter that matches every object.
  lifecycle_filter_criteria = {
    for id, rule in local.lifecycle_rules : id => (
      (rule.filter.prefix == null ? 0 : 1) +
      min(length(rule.filter.tags), 2) +
      (rule.filter.object_size_greater_than == null ? 0 : 1) +
      (rule.filter.object_size_less_than == null ? 0 : 1)
    )
  }
}
