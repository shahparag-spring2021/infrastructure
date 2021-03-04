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

variable "s3_bucketname" {
  type = string
}

variable "cred" {
  type = map(string)
}


# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.cidr_block_vpc
  enable_dns_hostnames = true
  enable_dns_support   = true
  enable_classiclink_dns_support = true
  assign_generated_ipv6_cidr_block = false
  tags = {
    Name = format("%s-%s",var.vpc_name,"vpc_${terraform.workspace}")
  }
}

# Subnets
resource "aws_subnet" "subnet1" {
  cidr_block              = var.cidr_block1_subnet
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = format("%s%s",var.region,"a")
  map_public_ip_on_launch = true
  tags = {
    Name = format("%s-%s",var.vpc_name,"subnet1_${terraform.workspace}")
  }
}

resource "aws_subnet" "subnet2" {
  cidr_block        = var.cidr_block2_subnet
  vpc_id            = aws_vpc.vpc.id
  availability_zone = format("%s%s",var.region,"b")
  tags = {
    Name = format("%s-%s",var.vpc_name,"subnet2_${terraform.workspace}")
  }
}

resource "aws_subnet" "subnet3" {
  cidr_block        = var.cidr_block3_subnet
  vpc_id            = aws_vpc.vpc.id
  availability_zone = format("%s%s",var.region,"c")
  tags = {
    Name = format("%s-%s",var.vpc_name,"subnet3_${terraform.workspace}")
  }
}

# Internet Gateway
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = format("%s-%s",var.vpc_name,"ig_${terraform.workspace}")
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
    Name = format("%s-%s",var.vpc_name,"rt_${terraform.workspace}")
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


# Application Security Group
resource "aws_security_group" "webapp_sg" {
  name = "webapp_sg"
  description = "Application security group"
  vpc_id = aws_vpc.vpc.id
  
  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 5000
    to_port = 5000
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 3128
    to_port = 3128
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "webapp_sg_${terraform.workspace}"
  }
}

# Database Security Group
resource "aws_security_group" "database_sg" {
  name = "database_sg"
  description = "Database security group"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port = 80
    to_port = 5432
    protocol = "tcp"
    security_groups = [aws_security_group.webapp_sg.id]
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "database_sg_${terraform.workspace}"
  }
}

# S3 Bucket
resource "aws_s3_bucket" "webapp_bucket" {
  bucket = var.s3_bucketname
  force_destroy = true
  acl = "private"
  
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle {
    prevent_destroy = false
  }

  lifecycle_rule {
    enabled = true

    transition {
      days = 30
      storage_class = "STANDARD_IA"
    }
  }

  tags = {
    Name = "webapp_bucket_${terraform.workspace}"
  }
}

resource "aws_s3_bucket_public_access_block" "s3_public_access_block" {
  bucket = aws_s3_bucket.webapp_bucket.id
  block_public_acls = true
  block_public_policy = true
  restrict_public_buckets = true
  ignore_public_acls = true
}

# DB Subnet Group
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db_subnet_group"
  subnet_ids = [aws_subnet.subnet1.id, aws_subnet.subnet2.id,aws_subnet.subnet3.id]

  tags = {
    Name = "db_subnet_group_${terraform.workspace}"
  }
}

# DB Instance - Postgres
resource "aws_db_instance" "db_instance" {
  allocated_storage = 8
  storage_type = "gp2"
  engine = "postgres"
  engine_version    = "13.1"
  instance_class = "db.t3.micro"
  name = var.cred["name"]
  username = var.cred["username"]
  password = var.cred["password"]
  port     = "5432"
  multi_az = false
  publicly_accessible = false
  identifier = var.cred["identifier"]
  skip_final_snapshot = true
  vpc_security_group_ids = [aws_security_group.database_sg.id]
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  storage_encrypted = true
  ca_cert_identifier = data.aws_rds_certificate.rds_certificate.id
#   parameter_group_name = aws_db_parameter_group.db-param-group-performance-schema.name
  tags = {
    Name = "db_instance_${terraform.workspace}"
  }
}

data "aws_rds_certificate" "rds_certificate" {
  latest_valid_till = true
}


# IAM Policy
resource "aws_iam_policy" "WebAppS3" {
  name        = "WebAppS3"
  path        = "/"
  description = "WebAppS3 policy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListObjectsInBucket",
            "Effect": "Allow",
            "Action": ["s3:ListBucket"],
            "Resource": ["arn:aws:s3:::${var.s3_bucketname}"]
        },
        {
            "Sid": "AllObjectActions",
            "Effect": "Allow",
            "Action": "s3:*Object",
            "Resource": ["arn:aws:s3:::${var.s3_bucketname}/*"]
        }
    ]
}
EOF
}

// EC2 role for S3 bucket without specifying credentials
resource "aws_iam_role" "ec2_csye6225" {
  name = "ec2_csye6225"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_policy_attachment" "ec2_s3_attachment" {
  name       = "ec2_s3_attachment"
  roles      = [aws_iam_role.ec2_csye6225.name]
  policy_arn = aws_iam_policy.WebAppS3.arn
}


resource "aws_iam_instance_profile" "instance_profile_dev1" {
  name = "instance_profile_dev1"
  role = aws_iam_role.ec2_csye6225.name
}


# IAM User
data "aws_iam_user" "dev_user" {
  user_name = "dev"
}

# AMI Details
data "aws_ami" "custom_ami" {
  owners = ["508886276467"]
  most_recent = true

}

# EC2 instance
resource "aws_instance" "ec2_instance" {
  ami = data.aws_ami.custom_ami.id
  instance_type = "t2.micro"
  key_name = var.cred["key_name"]
  vpc_security_group_ids = [aws_security_group.webapp_sg.id]
  subnet_id = aws_subnet.subnet1.id
  iam_instance_profile = aws_iam_instance_profile.instance_profile_dev1.name
  associate_public_ip_address = true
  disable_api_termination = false

  user_data = <<-EOF
                #!/bin/bash
                sudo touch .env\n
                sudo echo "export RDS_DB_HOSTNAME=${aws_db_instance.db_instance.address}" >> /etc/environment
                sudo echo "export RDS_DB_ENDPOINT=${aws_db_instance.db_instance.endpoint}" >> /etc/environment
                sudo echo "export RDS_DB_NAME=${aws_db_instance.db_instance.name}" >> /etc/environment
                sudo echo "export RDS_DB_USERNAME=${var.cred["username"]}" >> /etc/environment
                sudo echo "export RDS_DB_PASSWORD=${var.cred["password"]}" >> /etc/environment
                sudo echo "export S3_BUCKET_NAME=${aws_s3_bucket.webapp_bucket.bucket}" >> /etc/environment
  EOF


  root_block_device {
      volume_type = "gp2"
      volume_size =  20
      delete_on_termination = true
  }

  tags = {
    Name = "ec2_instance_${terraform.workspace}"
  }
}
