output "app_public_ip" { value = module.app.app_public_ip }
output "monitor_public_ip" { value = module.monitor.monitor_public_ip }
output "grafana_url" { value = "http://${module.monitor.monitor_public_ip}:3000  (user: admin, password in Secrets Manager)" }
output "grafana_secret_arn" { value = aws_secretsmanager_secret.grafana.arn }
