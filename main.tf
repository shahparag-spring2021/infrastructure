provider "aws" {
  region = var.region
}

# Variables
variable "region"{
    type = string
}

variable "secret_key"{
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

variable "codedeploy_application_name"{
    type = string
}

variable "codedeploy_group_name"{
    type = string
}

variable "codedeploy_bucket"{
    type = string
}

variable "account_id"{
    type = string
}

variable "domain"{
    type = string
}

variable "zone_id"{
    type = string
}

variable "serverless_bucket"{
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

resource "aws_security_group" "loadbalancer_sg" {
  name = "loadbalancer_sg"
  description = "Loadbalancer security group"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "loadbalancer_sg"
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

# # EC2 role for S3 bucket without specifying credentials
# resource "aws_iam_role" "ec2_csye6225" {
#   name = "ec2_csye6225"

#   assume_role_policy = <<EOF
# {
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Action": "sts:AssumeRole",
#             "Principal": {
#                "Service": "ec2.amazonaws.com"
#             },
#             "Effect": "Allow",
#             "Sid": ""
#         }
#     ]
# }
# EOF
# }

# WebappS3 EC2 policy attachment
resource "aws_iam_policy_attachment" "ec2_s3_attachment" {
  name       = "ec2_s3_attachment"
  roles      = [aws_iam_role.CodeDeployEC2ServiceRole.name]
  policy_arn = aws_iam_policy.WebAppS3.arn
}

# IAM User for CI/CD
data "aws_iam_user" "ghactions_user" {
  user_name = "ghactions"
}

# CodeDeploy code

# IAM Instance Profile
resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "iam_instance_profile"
  role = aws_iam_role.CodeDeployEC2ServiceRole.name
}

# CodeDeploy Role
resource "aws_iam_role" "CodeDeployEC2ServiceRole" {
  name = "CodeDeployEC2ServiceRole"

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

# Policy attachment
resource "aws_iam_policy_attachment" "codedeploy_ec2_s3_policy_attachment" {
  name       = "codedeploy_ec2_s3_attachment"
  roles      = [aws_iam_role.CodeDeployEC2ServiceRole.name]
  policy_arn = aws_iam_policy.CodeDeploy-EC2-S3.arn
}

# CodeDeploy-EC2-S3 IAM Policy
resource "aws_iam_policy" "CodeDeploy-EC2-S3" {
  name        = "CodeDeploy-EC2-S3"
  path        = "/"
  description = "CodeDeploy-EC2-S3 policy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:Get*",
                "s3:GetObject",
                "s3:List*",
                "s3:Put*",
                "s3:PutObject"
            ],
            "Effect": "Allow",
            "Resource": [
              "arn:aws:s3:::${var.codedeploy_bucket}",
              "arn:aws:s3:::${var.codedeploy_bucket}/*"
              ]
        }
    ]
}
EOF
}

# Policy attachment
resource "aws_iam_user_policy_attachment" "ghactions_attach_gh_upload_to_s3_policy" {
  user       = data.aws_iam_user.ghactions_user.user_name
  policy_arn = aws_iam_policy.GH-Upload-To-S3.arn
}

# GH-Upload-To-S3 IAM Policy
resource "aws_iam_policy" "GH-Upload-To-S3" {
  name        = "GH-Upload-To-S3"
  path        = "/"
  description = "GH-Upload-To-S3 policy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:PutObjectAcl",
                "s3:Put*",
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [
              "arn:aws:s3:::${var.codedeploy_bucket}",
              "arn:aws:s3:::${var.codedeploy_bucket}/*"
            ]
        }
    ]
}
EOF
}

# CodeDeployServiceRole for CodeDeploy service
resource "aws_iam_role" "CodeDeployServiceRole" {
  name = "CodeDeployServiceRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Policy attachment
resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.CodeDeployServiceRole.name
}

# Codedeploy app
resource "aws_codedeploy_app" "csye6225-webapp" {
  compute_platform = "Server"
  name             = "csye6225-webapp"
}

# Codedeploy group
resource "aws_codedeploy_deployment_group" "csye6225-webapp-deployment" {
  app_name              = aws_codedeploy_app.csye6225-webapp.name
  deployment_group_name = "csye6225-webapp-deployment"
  service_role_arn      = aws_iam_role.CodeDeployServiceRole.arn
  deployment_config_name = "CodeDeployDefault.OneAtATime"
  autoscaling_groups = [aws_autoscaling_group.autoscaling_group_webapp.name]
  load_balancer_info {
    target_group_info {
      name = aws_lb_target_group.lb-target-group.name
    }
  }
  
  deployment_style {
    deployment_type   = "IN_PLACE"
  }

  ec2_tag_set {
    ec2_tag_filter {
      key   = "Name"
      type  = "KEY_AND_VALUE"
      value = "ec2_instance"
    }
  }
}

# GH Code Deploy Policy
resource "aws_iam_policy" "GH-Code-Deploy" {
  name        = "GH-Code-Deploy"
  description = "GH-Code-Deploy policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:RegisterApplicationRevision",
        "codedeploy:GetApplicationRevision"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${var.account_id}:application:${var.codedeploy_application_name}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:CreateDeployment",
        "codedeploy:GetDeployment"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${var.account_id}:deploymentgroup:${var.codedeploy_application_name}/${var.codedeploy_group_name}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:GetDeploymentConfig"
      ],
      "Resource": [
        "arn:aws:codedeploy:${var.region}:${var.account_id}:deploymentconfig:CodeDeployDefault.OneAtATime",
        "arn:aws:codedeploy:${var.region}:${var.account_id}:deploymentconfig:CodeDeployDefault.HalfAtATime",
        "arn:aws:codedeploy:${var.region}:${var.account_id}:deploymentconfig:CodeDeployDefault.AllAtOnce"
      ]
    }
  ]
}
EOF
}

# Policy attachment
resource "aws_iam_user_policy_attachment" "ghactions_attach_ghcodedeploy_policy" {
  user       = data.aws_iam_user.ghactions_user.user_name
  policy_arn = aws_iam_policy.GH-Code-Deploy.arn
}

# Route 53 Hosted Zone
data "aws_route53_zone" "fetched_zone" {
  name         = var.domain
  private_zone = false
}

# Route 53 record with alias
resource "aws_route53_record" "route53_record" {
  zone_id  = var.zone_id
  name     = var.domain
  type     = "A"
  
  alias {
    name                   = aws_lb.load-balancer.dns_name
    zone_id                = aws_lb.load-balancer.zone_id
    evaluate_target_health = true
  }

}

# Policy attachment
resource "aws_iam_role_policy_attachment" "CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.CodeDeployEC2ServiceRole.name
}


# EC2 instance
# resource "aws_instance" "ec2_instance" {
#   ami = data.aws_ami.custom_ami.id
#   instance_type = "t2.micro"
#   key_name = var.cred["key_name"]
#   vpc_security_group_ids = [aws_security_group.webapp_sg.id]
#   subnet_id = aws_subnet.subnet1.id
#   iam_instance_profile = aws_iam_instance_profile.iam_instance_profile.name
#   associate_public_ip_address = true
#   disable_api_termination = false

#   user_data = <<-EOF
#                 #!/bin/bash
#                 sudo touch .env\n
#                 sudo echo "export RDS_DB_HOSTNAME=${aws_db_instance.db_instance.address}" >> /etc/environment
#                 sudo echo "export RDS_DB_ENDPOINT=${aws_db_instance.db_instance.endpoint}" >> /etc/environment
#                 sudo echo "export RDS_DB_NAME=${aws_db_instance.db_instance.name}" >> /etc/environment
#                 sudo echo "export RDS_DB_USERNAME=${var.cred["username"]}" >> /etc/environment
#                 sudo echo "export RDS_DB_PASSWORD=${var.cred["password"]}" >> /etc/environment
#                 sudo echo "export S3_BUCKET_NAME=${aws_s3_bucket.webapp_bucket.bucket}" >> /etc/environment
#                 sudo echo "export SECRET_KEY=${var.secret_key}" >> /etc/environment
#   EOF


#   root_block_device {
#       volume_type = "gp2"
#       volume_size =  20
#       delete_on_termination = true
#   }

#   tags = {
#     Name = "ec2_instance"
#   }
# }

# AMI Details
data "aws_ami" "custom_ami" {
  owners = ["508886276467"]
  most_recent = true

}

# Auto-scale Launch configuration for EC2
resource "aws_launch_configuration" "asg_launch_config" {
  name_prefix   = "asg_launch_config"
  image_id      = data.aws_ami.custom_ami.id
  instance_type = "t2.micro"
  key_name = var.cred["key_name"]
  security_groups = [aws_security_group.webapp_sg.id]
  associate_public_ip_address = true
  iam_instance_profile = aws_iam_instance_profile.iam_instance_profile.name


  user_data = <<-EOF
                #!/bin/bash
                sudo touch .env\n
                sudo echo "export RDS_DB_HOSTNAME=${aws_db_instance.db_instance.address}" >> /etc/environment
                sudo echo "export RDS_DB_ENDPOINT=${aws_db_instance.db_instance.endpoint}" >> /etc/environment
                sudo echo "export RDS_DB_NAME=${aws_db_instance.db_instance.name}" >> /etc/environment
                sudo echo "export RDS_DB_USERNAME=${var.cred["username"]}" >> /etc/environment
                sudo echo "export RDS_DB_PASSWORD=${var.cred["password"]}" >> /etc/environment
                sudo echo "export S3_BUCKET_NAME=${aws_s3_bucket.webapp_bucket.bucket}" >> /etc/environment
                sudo echo "export SECRET_KEY=${var.secret_key}" >> /etc/environment
                sudo echo "export SNS_TOPIC=${aws_sns_topic.sns_topic.arn}" >> /etc/environment
  EOF

  lifecycle {
    create_before_destroy = true
  }

}

# Auto-scaling group
resource "aws_autoscaling_group" "autoscaling_group_webapp" {
  name                 = "autoscaling_group_webapp"
  launch_configuration = aws_launch_configuration.asg_launch_config.name
  min_size             = 3
  max_size             = 5
  desired_capacity     = 3
  default_cooldown     = 60
  health_check_grace_period = 1200
  target_group_arns = [aws_lb_target_group.lb-target-group.arn]
  vpc_zone_identifier  = [aws_subnet.subnet1.id, aws_subnet.subnet2.id,aws_subnet.subnet3.id]

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "ec2_instance"
    propagate_at_launch = true
  }
}

# Scale-Up Policy
resource "aws_autoscaling_policy" "WebServerScaleUpPolicy" {
  name                   = "WebServerScaleUpPolicy"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group_webapp.name
}

# Scale-Down Policy
resource "aws_autoscaling_policy" "WebServerScaleDownPolicy" {
  name                   = "WebServerScaleDownPolicy"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 60
  autoscaling_group_name = aws_autoscaling_group.autoscaling_group_webapp.name
}

# Alarm for CPU High
resource "aws_cloudwatch_metric_alarm" "CPUAlarmHigh" {
  alarm_name          = "CPUAlarmHigh"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "5"
  alarm_description   = "Scale-up if CPU > 5% for 300 seconds"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling_group_webapp.name
  }

  alarm_actions     = [aws_autoscaling_policy.WebServerScaleUpPolicy.arn]
}

# Alarm for CPU Low
resource "aws_cloudwatch_metric_alarm" "CPUAlarmLow" {
  alarm_name          = "CPUAlarmLow"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "3"
  alarm_description   = "Scale-down if CPU < 3% for 300 seconds"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.autoscaling_group_webapp.name
  }
 
  alarm_actions     = [aws_autoscaling_policy.WebServerScaleDownPolicy.arn]
}

# Load Balancer
resource "aws_lb" "load-balancer" {
  name               = "load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.loadbalancer_sg.id]
  subnets            = [aws_subnet.subnet1.id, aws_subnet.subnet2.id,aws_subnet.subnet3.id]

  enable_deletion_protection = false

  tags = {
    Name = "ec2_instance"
  }

}

# Load Balancer Listener
resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = aws_lb.load-balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb-target-group.arn
  }
}

resource "aws_lb_target_group" "lb-target-group" {
  name     = "lb-target-group"
  port     = 5000
  protocol = "HTTP"

  health_check {
    port                = 5000
    matcher             = 200
    path                = "/health"
    healthy_threshold   = 5
    unhealthy_threshold = 3

  }
  
  vpc_id   = aws_vpc.vpc.id
}

resource "aws_sns_topic" "sns_topic" {
  name = "sns_topic"
}

resource "aws_iam_role_policy_attachment" "SNSPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
  role       = aws_iam_role.CodeDeployEC2ServiceRole.name
}

resource "aws_iam_role" "iam_lambda" {
  name = "iam_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_iam_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.iam_lambda.name
}


resource "aws_lambda_function" "assignment_lambda" {
  filename      = "csye6225-lambda.zip"
  function_name = "csye6225"
  role          = aws_iam_role.iam_lambda.arn
  handler       = "index.handler"
  memory_size   = 256
  timeout       = 180



  runtime = "nodejs12.x"

  environment {
    variables = {
      Name = "Lambda Function"
    }
  }
}

resource "aws_s3_bucket" "lambdabucket" {
  bucket = var.serverless_bucket
  acl    = "private"
  force_destroy = true


  server_side_encryption_configuration {    
    rule {     
       apply_server_side_encryption_by_default { sse_algorithm = "AES256"}
       }
  }

  lifecycle_rule {
    id      = "log"
    enabled = true
    transition {
      days          = 30
      storage_class = "STANDARD_IA" # or "ONEZONE_IA"
    }
  }

  tags = {
    Name = "lambdabucket"
  }
}

resource "aws_s3_bucket_public_access_block" "serverlessBucketRemovePublicAccess" {
bucket = aws_s3_bucket.lambdabucket.id
block_public_acls = true
block_public_policy = true
restrict_public_buckets = true
ignore_public_acls = true
}

//adding lambda full access to gh actions user
resource "aws_iam_user_policy_attachment" "ghactions_attach_gh_serverless_upload_to_s3_policy" {
  user       = data.aws_iam_user.ghactions_user.user_name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}

resource "aws_sns_topic_subscription" "user_updates_sns_target" {
  topic_arn = aws_sns_topic.sns_topic.arn
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.assignment_lambda.arn}"
}

resource "aws_lambda_permission" "lambda_sns_permission" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.assignment_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.sns_topic.arn
}

resource "aws_iam_policy" "lambdapolicy" {
  name        = "lambdapolicy"
  path        = "/"
  description = "lambdapolicy"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ses:SendEmail",
                "ses:SendRawEmail"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_execution_policy_attachment" {
  policy_arn = aws_iam_policy.lambdapolicy.arn
  role       = aws_iam_role.iam_lambda.name
}

resource "aws_iam_role_policy_attachment" "lambda_ses_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
  role       = aws_iam_role.iam_lambda.name
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  role       = aws_iam_role.iam_lambda.name
}

resource "aws_db_parameter_group" "db-param-group-performance-schema" {
  name   = "db-param-group-performance-schema"
  family = "mysql8.0"

  parameter {
    name         = "performance_schema"
    value        = "1"
    apply_method = "pending-reboot"
  }

}

resource "aws_dynamodb_table" "dynamodb" {
  name           = "csye6225"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "dynamodb"
  }
}