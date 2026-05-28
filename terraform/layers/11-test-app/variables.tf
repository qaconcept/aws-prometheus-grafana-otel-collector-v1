# Required by providers.tf
variable "aws_region" {
  type        = string
  description = "The target AWS region passed from central.tfvars"
}

# Required by main.tf
variable "project_name" {
  type        = string
}

variable "ecs_cluster_id" {
  type        = string
}

variable "ecs_execution_role_arn" {
  type        = string
}

variable "ecs_task_role_arn" {
  type        = string
}

variable "log_group_name" {
  type        = string
}

variable "public_subnet_ids" {
  type        = list(string)
}

variable "ecs_sg_id" {
  type        = string
}

variable "dockerhub_username" {
  type        = string
  description = "The public Docker Hub registry organization or username"
}