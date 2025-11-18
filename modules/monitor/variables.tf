variable "ami" {}
variable "instance_type" {}
variable "subnet_id" {}
variable "security_group_ids" { type = list(string) }
variable "instance_profile_arn" {}
variable "prometheus_volume_size_gb" { type = number, default = 20 }
variable "loki_volume_size_gb" { type = number, default = 30 }
variable "grafana_secret_arn" {}
variable "app_private_ip" {}
variable "public_key" {}
