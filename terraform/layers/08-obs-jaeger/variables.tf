variable "aws_region" { type = string }
variable "project_name" { type = string }
variable "ecs_cluster_id" { type = string }
variable "cloudmap_namespace_id" { type = string }
variable "ecs_execution_role_arn" { type = string }
variable "ecs_task_role_arn" { type = string }
variable "log_group_name" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "ecs_sg_id" { type = string }
#variable "jaeger_tg_arn" { type = string }
variable "jaeger_ui_tg_arn" {
  type        = string
  description = "The ARN of the Application Load Balancer target group for the Jaeger Web UI"
}

variable "jaeger_grpc_tg_arn" {
  type        = string
  description = "The ARN of the Application Load Balancer target group for Jaeger OTLP gRPC traces"
}