data "aws_ami" "amzn2" {
  most_recent = true
  owners      = ["amazon"]
  filter { name = "name", values = ["amzn2-ami-hvm-*-x86_64-gp2"] }
}

locals { public_key = chomp(file(var.public_key_path)) }

module "app" {
  source = "./modules/app"
  ami    = data.aws_ami.amzn2.id
  instance_type = var.instance_type_app
  subnet_id = aws_subnet.this.id
  security_group_ids = [aws_security_group.app_monitor.id]
  instance_profile_arn = aws_iam_instance_profile.instance_profile.name
  public_key = local.public_key
}

module "monitor" {
  source = "./modules/monitor"
  ami    = data.aws_ami.amzn2.id
  instance_type = var.instance_type_monitor
  subnet_id = aws_subnet.this.id
  security_group_ids = [aws_security_group.app_monitor.id]
  instance_profile_arn = aws_iam_instance_profile.instance_profile.name
  prometheus_volume_size_gb = 20
  loki_volume_size_gb = 30
  grafana_secret_arn = aws_secretsmanager_secret.grafana.arn
  app_private_ip = module.app.app_private_ip
  public_key = local.public_key
}
