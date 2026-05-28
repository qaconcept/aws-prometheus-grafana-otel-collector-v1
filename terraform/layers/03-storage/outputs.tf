output "log_group_name" { value = aws_cloudwatch_log_group.observability.name }
output "efs_file_system_id" { value = aws_efs_file_system.main.id }
output "prometheus_ap_id" { value = aws_efs_access_point.prometheus.id }
output "grafana_ap_id" { value = aws_efs_access_point.grafana.id }