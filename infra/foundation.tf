/* Deploys the foundational infrastructure for the project:

    AWS Account (existing account)
     ├─ S3 bucket (private) for lambda layers because they're rather large
     |   └─ Lambda Layer for the custom PowerShell runtime
     ├─ IAM role for lambda execution
     |    ├─ Lambda logging policy
     |    └─ Lambda send to SQS policy
     ├─ Lambda permission to allow SNS to trigger executions
     ├─ SNS topic for distributing processed pixel payloads to lambda
     ├─ SQS queue for recieving processed pixel payloads
     ├─ Log group for cloudwatch lambda execution logging
     └─ Resource group for viewing the resouces created by this project

*/

# S3 bucket (private) for lambda layers because they're rather large
resource "aws_s3_bucket" "pwshraytracer_lambda_layers" {
  # Bucket names need to be globally unique
  bucket = "s3-pwshraytracer-layers-${random_id.id.hex}"
  tags = {
    Name        = "PwshRaytracer Lambda Layers Bucket"
    Environment = var.environment_tag
  }
}

resource "aws_s3_bucket_acl" "pwshraytracer_lambda_layers_acl" {
  bucket = aws_s3_bucket.pwshraytracer_lambda_layers.id
  acl    = "private"
}

# Lambda Layer for the custom PowerShell runtime
resource "aws_s3_object" "pwsh_custom_runtime_layer" {
  bucket = aws_s3_bucket.pwshraytracer_lambda_layers.id
  key    = "pwsh_lambda_layer_payload.zip"
  source = "../artifacts/pwsh_lambda_layer_payload.zip"
  etag   = filemd5("../artifacts/pwsh_lambda_layer_payload.zip")
  tags = {
    Name        = "PwshRaytracer Lambda Layer for Powershell Runtime"
    Environment = var.environment_tag
  }
  lifecycle {
    ignore_changes = [etag]
  }
}

resource "aws_lambda_layer_version" "pwsh_lambda_layer" {
  s3_bucket                = aws_s3_object.pwsh_custom_runtime_layer.bucket
  s3_key                   = aws_s3_object.pwsh_custom_runtime_layer.key
  layer_name               = "runtime-pwsh"
  compatible_architectures = ["x86_64"]
  compatible_runtimes      = ["provided.al2"]
  description              = var.environment_tag
}

# IAM role for lambda execution
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

# Lambda logging policy
resource "aws_iam_policy" "pwshraytracer_lambda_logging" {
  name        = "policy-pwshraytracer-lambda-logging"
  path        = "/"
  description = "IAM policy for logging from the lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "${aws_cloudwatch_log_group.pwshraytracer_lambda_loggroup.arn}:*",
      "Effect": "Allow"
    }
  ]
}
EOF
  tags = {
    Environment = var.environment_tag
  }
}
resource "aws_iam_role_policy_attachment" "pwshraytracer_lambda_logs" {
  role       = aws_iam_role.iam_for_pwshraytracer_lambda.name
  policy_arn = aws_iam_policy.pwshraytracer_lambda_logging.arn
}

# Lambda send to SQS policy
resource "aws_iam_policy" "pwshraytracer_lambda_send_to_sqs" {
  name        = "policy-pwshraytracer-lambda-to-sqs"
  path        = "/"
  description = "IAM policy for sending to SQS from the lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "sqs:SendMessage"
      ],
      "Resource": "${aws_sqs_queue.pwshraytracer_notifications_queue.arn}",
      "Effect": "Allow"
    }
  ]
}
EOF
  tags = {
    Environment = var.environment_tag
  }
}

resource "aws_iam_role_policy_attachment" "pwshraytracer_lambda_sqs" {
  role       = aws_iam_role.iam_for_pwshraytracer_lambda.name
  policy_arn = aws_iam_policy.pwshraytracer_lambda_send_to_sqs.arn
}

# Lambda permission to allow SNS to trigger executions
resource "aws_lambda_permission" "allow_sns_to_call_lambda" {
  statement_id  = "permission-pwshraytracer-sns-to-lambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pwshraytracer_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.raytracing_jobs_topic.arn
}

# SNS topic for distributing processed pixel payloads to lambda
resource "aws_sns_topic" "raytracing_jobs_topic" {
  name = "topic-raytracingjobs"
  tags = {
    Name        = "PwshRaytracer SNS Topic for Jobs"
    Environment = var.environment_tag
  }
}

# SQS queue for recieving processed pixel payloads
resource "aws_sqs_queue" "pwshraytracer_notifications_queue" {
  name                      = "sqs-pwshraytracer-notifications"
  message_retention_seconds = 900
  receive_wait_time_seconds = 5

  tags = {
    Name        = "PwshRaytracer SQS Notifications"
    Environment = var.environment_tag
  }
}

# Log group for cloudwatch lambda execution logging
resource "aws_cloudwatch_log_group" "pwshraytracer_lambda_loggroup" {
  name              = "/aws/lambda/${aws_lambda_function.pwshraytracer_lambda.function_name}"
  retention_in_days = 14
}

# Resource group for viewing the resouces created by this project
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
    Name        = "PwshRayTracer Resource Group"
    Environment = var.environment_tag
  }
}