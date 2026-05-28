variable "aws_region" { type = string }
variable "project_name" { type = string }
variable "domain_name" { type = string }
variable "vpc_id" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "alb_sg_id" { type = string }
variable "acm_certificate_arn" { type = string }