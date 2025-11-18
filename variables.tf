variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "allowed_cidr" {
  type    = string
  default = "0.0.0.0/0"
}

variable "public_key_path" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
}

variable "instance_type_app" {
  type    = string
  default = "t3.micro"
}

variable "instance_type_monitor" {
  type    = string
  default = "t3.small"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}
