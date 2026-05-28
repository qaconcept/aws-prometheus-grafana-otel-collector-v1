output "ecs_cluster_id" { value = aws_ecs_cluster.main.id }
output "cloudmap_namespace_id" { value = aws_service_discovery_private_dns_namespace.internal.id }
output "alb_sg_id" { value = aws_security_group.alb_sg.id }
output "ecs_sg_id" { value = aws_security_group.ecs_tasks.id }