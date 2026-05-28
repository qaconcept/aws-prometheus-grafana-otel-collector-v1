output "alb_dns_name" { value = aws_lb.main.dns_name }
output "grafana_tg_arn" { value = aws_lb_target_group.grafana.arn }
#output "jaeger_tg_arn" { value = aws_lb_target_group.jaeger.arn }
# REPLACE THE OLD JAEGER OUTPUT WITH THESE TWO:
output "jaeger_grpc_tg_arn" {
  value = aws_lb_target_group.jaeger_grpc.arn
}

output "jaeger_ui_tg_arn" {
  value = aws_lb_target_group.jaeger_ui.arn
}