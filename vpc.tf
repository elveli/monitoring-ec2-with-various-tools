resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr
  tags = { Name = "tf-monitoring-vpc" }
}

resource "aws_subnet" "this" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  tags = { Name = "tf-monitoring-subnet" }
}

resource "aws_internet_gateway" "igw" { vpc_id = aws_vpc.this.id }

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.this.id
  route { cidr_block = "0.0.0.0/0", gateway_id = aws_internet_gateway.igw.id }
}

resource "aws_route_table_association" "rta" {
  subnet_id = aws_subnet.this.id
  route_table_id = aws_route_table.rt.id
}
