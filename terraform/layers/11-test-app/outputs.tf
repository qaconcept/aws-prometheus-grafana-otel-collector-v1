output "test_app_service_name" {
  description = "The name of the containerized Python generator service"
  value       = aws_ecs_service.test_app.name
}