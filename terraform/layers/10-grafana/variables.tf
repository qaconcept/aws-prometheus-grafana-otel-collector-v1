variable "aws_region" { type = string }
variable "project_name" { type = string }
variable "ecs_cluster_id" { type = string }
variable "cloudmap_namespace_id" { type = string }
variable "ecs_execution_role_arn" { type = string }
variable "ecs_task_role_arn" { type = string }
variable "log_group_name" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "ecs_sg_id" { type = string }
variable "grafana_tg_arn" { type = string }
variable "efs_file_system_id" { type = string }
variable "grafana_ap_id" { type = string }
variable "domain_name" {
  type        = string
  description = "The root domain name passed dynamically from central.tfvars"
}