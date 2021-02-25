provider "aws" {
  region = var.region
}

# Variables
variable "region"{
    type = string
}

variable "vpc_name"{
    type = string
}

variable "cidr_block_vpc" {
  type = string
}

variable "cidr_block1_subnet" {
  type = string
}

variable "cidr_block2_subnet" {
  type = string
}

variable "cidr_block3_subnet" {
  type = string
}

# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_block_vpc
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_classiclink_dns_support = true
  assign_generated_ipv6_cidr_block = false
  tags = {
    Name = format("%s-%s",var.vpc_name,"vpc_${timestamp()}")
  }
}

# Subnets
resource "aws_subnet" "subnet1" {
  cidr_block              = var.cidr_block1_subnet
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = format("%s%s",var.region,"a")
  map_public_ip_on_launch = true
  tags = {
    Name = format("%s-%s",var.vpc_name,"subnet1_${timestamp()}")
  }
}

resource "aws_subnet" "subnet2" {
  cidr_block        = var.cidr_block2_subnet
  vpc_id            = aws_vpc.vpc.id
  availability_zone = format("%s%s",var.region,"b")
  tags = {
    Name = format("%s-%s",var.vpc_name,"subnet2_${timestamp()}")
  }
}

resource "aws_subnet" "subnet3" {
  cidr_block        = var.cidr_block3_subnet
  vpc_id            = aws_vpc.vpc.id
  availability_zone = format("%s%s",var.region,"c")
  tags = {
    Name = format("%s-%s",var.vpc_name,"subnet3_${timestamp()}")
  }
}

# Internet Gateway
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = format("%s-%s",var.vpc_name,"ig_${timestamp()}")
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
    Name = format("%s-%s",var.vpc_name,"rt__${timestamp()}")
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
