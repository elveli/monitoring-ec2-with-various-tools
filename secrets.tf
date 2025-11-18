resource "random_password" "grafana_admin" {
  length           = 16
  special          = true
  override_special = "!@#-"
}


resource "aws_secretsmanager_secret" "grafana" { name = "grafana-admin-credentials" }

resource "aws_secretsmanager_secret_version" "grafana" {
  secret_id     = aws_secretsmanager_secret.grafana.id
  secret_string = jsonencode({ username = "admin", password = random_password.grafana_admin.result })
}
