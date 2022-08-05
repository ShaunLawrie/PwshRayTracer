resource "aws_vpc" "pwshraytracer" {
  tags = {
    Name        = "PwshRayTracer"
    Environment = "PwshRayTracer"
  }
  cidr_block = "10.0.0.0/16"

}

resource "aws_internet_gateway" "pwshraytracer_gw" {
  vpc_id = aws_vpc.pwshraytracer.id

  tags = {
    Name        = "Pwsh Raytracer IGW"
    Environment = "PwshRayTracer"
  }
}

resource "aws_subnet" "pwshraytracer_main" {
  vpc_id     = aws_vpc.pwshraytracer.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name        = "Pwsh Raytracer Subnet"
    Environment = "PwshRayTracer"
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
    Environment = "PwshRayTracer"
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
    Environment = "PwshRayTracer"
  }
}

resource "aws_s3_bucket" "pwshraytracer_lambda_layers" {
  bucket = "pwsh-raytracer-layers"
  tags = {
    Name        = "Pwsh Raytracer Lambda Layers"
    Environment = "PwshRayTracer"
  }
}

resource "aws_s3_bucket_acl" "pwshraytracer_lambda_layers_acl" {
  bucket = aws_s3_bucket.pwshraytracer_lambda_layers.id
  acl    = "private"
}

resource "aws_iam_role" "iam_for_pwshraytracer_lambda" {
  name = "iam_for_pwshraytracer_lambda"
  tags = {
    Environment = "PwshRayTracer"
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

/*
resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 14
}

# See also the following AWS managed policy: AWSLambdaBasicExecutionRole
resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda_logging"
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}
*/