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
    Name        = "PwshRayTracer"
    Environment = var.environment_tag
  }
  cidr_block = "10.0.0.0/16"

}

resource "aws_internet_gateway" "pwshraytracer_gw" {
  vpc_id = aws_vpc.pwshraytracer.id

  tags = {
    Name        = "Pwsh Raytracer IGW"
    Environment = var.environment_tag
  }
}

resource "aws_subnet" "pwshraytracer_main" {
  vpc_id     = aws_vpc.pwshraytracer.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name        = "Pwsh Raytracer Subnet"
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
    Name        = "Pwsh Raytracer Default RTB"
    Environment = var.environment_tag
  }
}

resource "aws_security_group" "pwshraytracer_sg" {
  name        = "Pwsh Raytracer Lambda SG"
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
    Name        = "Pwsh Raytracer Lambda SG"
    Environment = var.environment_tag
  }
}

resource "aws_s3_bucket" "pwshraytracer_lambda_layers" {
  bucket = "pwsh-raytracer-layers"
  tags = {
    Name        = "Pwsh Raytracer Lambda Layers"
    Environment = var.environment_tag
  }
}

resource "aws_s3_bucket_acl" "pwshraytracer_lambda_layers_acl" {
  bucket = aws_s3_bucket.pwshraytracer_lambda_layers.id
  acl    = "private"
}

resource "aws_iam_role" "iam_for_pwshraytracer_lambda" {
  name = "iam_for_pwshraytracer_lambda"
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
