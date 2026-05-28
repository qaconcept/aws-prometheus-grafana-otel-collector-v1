data "aws_acm_certificate" "existing" {
  count       = var.create_ssl_cert ? 0 : 1
  domain      = var.domain_name
  most_recent = true
  statuses    = ["ISSUED"]
}

data "aws_route53_zone" "primary" {
  count        = var.create_ssl_cert ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

resource "aws_acm_certificate" "new" {
  count             = var.create_ssl_cert ? 1 : 0
  domain_name       = var.domain_name
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}