# create_before_destroy, hardcoded: a certificate replacement (e.g. adding a
# SAN) provisions the new cert before the old one is torn down, so whatever
# references certificate_arn is never left pointing at a destroyed cert.
#
# Issues the certificate only. AWS doesn't assign a DNS validation record's
# name/value until the certificate is actually created, so a module that
# both creates the certificate and its validation records in the same apply
# forces every caller into a two-phase apply on first create (a well-known
# rough edge of self-validating ACM modules). Leaving that composition to the
# caller — using this module's domain_validation_options output alongside
# modules/aws/route53 or a plain aws_route53_record/aws_acm_certificate_validation
# — keeps that inherent AWS ordering constraint visible instead of papering
# over it, and matches this repo's "what's shared is the pattern, not the
# resource code" convention.
resource "aws_acm_certificate" "this" {
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = var.validation_method
  tags                      = var.tags

  lifecycle {
    create_before_destroy = true
  }
}
