/* Deploys the foundational infrastructure for the project:

    AWS Acccount (existing)
     ├─ VPC for the project to be deployed into to segment it from other AWS account resources
     |   ├─ Internet Gateway for the lambda to use to get to AWS services, not using VPC endpoints because this is a toy project
     |   ├─ Subnet for the lambda to be deployed into
     |   ├─ Route Table routing everything to the internet that isn't part of the subnet
     |   └─ Security Group allowing egress and no ingress
     ├─ S3 bucket (private) for lambda layers because they're rather large
     |   └─ Lambda Layer for the custom PowerShell runtime
     └─ IAM role for lambda execution

*/

resource "aws_vpc" "pwshraytracer" {
  tags = {
    Name        = "PwshRaytracer VPC"
    Environment = var.environment_tag
  }
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "pwshraytracer_gw" {
  vpc_id = aws_vpc.pwshraytracer.id

  tags = {
    Name        = "PwshRaytracer Internet Gateway"
    Environment = var.environment_tag
  }
}

resource "aws_subnet" "pwshraytracer_main" {
  vpc_id     = aws_vpc.pwshraytracer.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name        = "PwshRaytracer Private Subnet"
    Environment = var.environment_tag
  }
}

resource "aws_default_route_table" "pwshraytracer_default_rtb" {
  default_route_table_id = aws_vpc.pwshraytracer.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.pwshraytracer_gw.id
  }

  tags = {
    Name        = "PwshRaytracer Default Route Table"
    Environment = var.environment_tag
  }
}

resource "aws_security_group" "pwshraytracer_sg" {
  name        = "PwshRaytracer Lambda Security Group"
  description = "No inbound"
  vpc_id      = aws_vpc.pwshraytracer.id

  ingress = []

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "PwshRaytracer Lambda Security Group"
    Environment = var.environment_tag
  }
}

resource "aws_s3_bucket" "pwshraytracer_lambda_layers" {
  bucket = "s3-pwshraytracer-layers"
  tags = {
    Name        = "PwshRaytracer Lambda Layers Bucket"
    Environment = var.environment_tag
  }
}

resource "aws_s3_bucket_acl" "pwshraytracer_lambda_layers_acl" {
  bucket = aws_s3_bucket.pwshraytracer_lambda_layers.id
  acl    = "private"
}

resource "aws_iam_role" "iam_for_pwshraytracer_lambda" {
  name = "role-lambda-pwshraytracer"
  tags = {
    Environment = var.environment_tag
  }
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

resource "aws_resourcegroups_group" "pwshraytracer_rg" {
  name = "rg-pwshraytracer"

  resource_query {
    query = <<JSON
{
  "ResourceTypeFilters": ["AWS::AllSupported"],
  "TagFilters": [
    {
      "Key": "Environment",
      "Values": ["${var.environment_tag}"]
    }
  ]
}
JSON
  }
  tags = {
    Name = "PwshRayTracer Resource Group"
    Environment = var.environment_tag
  }
}

resource "aws_sqs_queue" "pwshraytracer_notifications_queue" {
  name                      = "sqs-pwshraytracer-notifications"
  message_retention_seconds = 900
  receive_wait_time_seconds = 5

  tags = {
    Name = "PwshRaytracer SQS Notifications"
    Environment = var.environment_tag
  }
}