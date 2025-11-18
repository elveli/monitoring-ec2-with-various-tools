resource "aws_key_pair" "deployer" {
  key_name   = "tf-deployer-key-app"
  public_key = var.public_key
  lifecycle { create_before_destroy = true }
}

resource "aws_instance" "app" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = var.instance_profile_arn
  key_name               = aws_key_pair.deployer.key_name

  tags = { Name = "nodejs-app" }

  user_data = file("${path.module}/../../scripts/user_data_app_grafana_cloud.sh")
}
