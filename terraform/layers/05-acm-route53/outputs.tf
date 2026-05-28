output "acm_certificate_arn" {
  value = var.create_ssl_cert ? aws_acm_certificate.new[0].arn : data.aws_acm_certificate.existing[0].arn
}