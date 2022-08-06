resource "aws_sns_topic" "raytracing_jobs_topic" {
  name = "raytracingjobs"
  tags = {
    Environment = var.environment_tag
  }
}

resource "aws_sns_topic_subscription" "raytracing_jobs_subscription" {
  topic_arn = aws_sns_topic.raytracing_jobs_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.pwshraytracer_lambda.arn
}

resource "aws_lambda_permission" "allow_sns_to_call_lambda" {
    statement_id = "AllowExecutionFromSNS"
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.pwshraytracer_lambda.function_name
    principal = "sns.amazonaws.com"
    source_arn = aws_sns_topic.raytracing_jobs_topic.arn
}

resource "aws_s3_object" "pwsh_custom_runtime_layer" {
  bucket = aws_s3_bucket.pwshraytracer_lambda_layers.id
  key    = "pwsh_lambda_layer_payload.zip"
  source = "../artifacts/pwsh_lambda_layer_payload.zip"
  etag   = filemd5("../artifacts/pwsh_lambda_layer_payload.zip")
  tags = {
    Environment = var.environment_tag
  }
  lifecycle {
    ignore_changes = [etag]
  }
}

resource "aws_lambda_layer_version" "pwsh_lambda_layer" {
  s3_bucket                = aws_s3_object.pwsh_custom_runtime_layer.bucket
  s3_key                   = aws_s3_object.pwsh_custom_runtime_layer.key
  layer_name               = "PowerShell-Runtime"
  compatible_architectures = ["x86_64"]
  compatible_runtimes      = ["provided.al2"]
  description              = var.environment_tag
}

resource "aws_lambda_function" "pwshraytracer_lambda" {
  layers        = [aws_lambda_layer_version.pwsh_lambda_layer.arn]
  filename      = "../artifacts/pwsh_lambda_function_payload.zip"
  handler       = "HelloWorld.ps1::Invoke-Handler"
  function_name = "PwshRayTracer"
  memory_size   = 250
  timeout       = 15
  role          = aws_iam_role.iam_for_pwshraytracer_lambda.arn
  source_code_hash = filebase64sha256("../artifacts/pwsh_lambda_function_payload.zip")
  runtime = "provided.al2"

  tags = {
    Name        = "Pwsh Raytracer Lambda Function"
    Environment = var.environment_tag
  }
}

resource "aws_cloudwatch_log_group" "pwshraytracer_lambda_loggroup" {
  name              = "/aws/lambda/${aws_lambda_function.pwshraytracer_lambda.function_name}"
  retention_in_days = 14
}

resource "aws_iam_policy" "pwshraytracer_lambda_logging" {
  name        = "PwshRayTracerLambdaLogging"
  path        = "/"
  description = "IAM policy for logging from the lambda"

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
      "Resource": "${aws_cloudwatch_log_group.pwshraytracer_lambda_loggroup.arn}",
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