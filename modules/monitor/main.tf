resource "aws_key_pair" "deployer" {
  key_name   = "tf-deployer-key-monitor"
  public_key = var.public_key
  lifecycle { create_before_destroy = true }
}

data "aws_subnet" "selected" { id = var.subnet_id }

resource "aws_ebs_volume" "prometheus" {
  availability_zone = data.aws_subnet.selected.availability_zone
  size              = var.prometheus_volume_size_gb
  tags = { Name = "prometheus-data" }
}

resource "aws_ebs_volume" "loki" {
  availability_zone = data.aws_subnet.selected.availability_zone
  size              = var.loki_volume_size_gb
  tags = { Name = "loki-data" }
}

resource "aws_instance" "monitor" {
  ami                    = var.ami
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids = var.security_group_ids
  iam_instance_profile   = var.instance_profile_arn
  key_name               = aws_key_pair.deployer.key_name
  tags = { Name = "monitoring" }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = file("${path.module}/../../scripts/user_data_monitor_local_stack.sh")
}

resource "aws_volume_attachment" "prometheus_attach" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.prometheus.id
  instance_id = aws_instance.monitor.id
  force_detach = true
}

resource "aws_volume_attachment" "loki_attach" {
  device_name = "/dev/xvdg"
  volume_id   = aws_ebs_volume.loki.id
  instance_id = aws_instance.monitor.id
  force_detach = true
}
