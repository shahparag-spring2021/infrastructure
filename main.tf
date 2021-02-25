provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_classiclink_dns_support = true
  assign_generated_ipv6_cidr_block = false
  tags = {
    Name = "vpc-tf"
  }
}

# Subnets
resource "aws_subnet" "subnet1" {
  cidr_block              = "10.0.1.0/24"
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "subnet1-tf"
  }
}

resource "aws_subnet" "subnet2" {
  cidr_block        = "10.0.2.0/24"
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "us-east-1b"
  tags = {
    Name = "subnet2-tf"
  }
}

resource "aws_subnet" "subnet3" {
  cidr_block        = "10.0.3.0/24"
  vpc_id            = aws_vpc.vpc.id
  availability_zone = "us-east-1c"
  tags = {
    Name = "subnet3-tf"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "internet-gateway-tf"
  }
}

# Route table and Public route
resource "aws_route_table" "route-table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }
  tags = {
    Name = "route-table-tf"
  }
}

# Association - Attach subnets
resource "aws_route_table_association" "rt-subnet1" {
  route_table_id = aws_route_table.route-table.id
  subnet_id      = aws_subnet.subnet1.id
}

resource "aws_route_table_association" "rt-subnet2" {
  route_table_id = aws_route_table.route-table.id
  subnet_id      = aws_subnet.subnet2.id
}

resource "aws_route_table_association" "rt-subnet3" {
  route_table_id = aws_route_table.route-table.id
  subnet_id      = aws_subnet.subnet3.id
}
