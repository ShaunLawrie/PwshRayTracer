resource "aws_sns_topic" "raytracing_jobs_topic" {
  name = "RayTracing-Jobs"
  tags = {
    Environment = "PwshRayTracer"
  }
}

resource "aws_sns_topic_subscription" "raytracing_jobs_subscription" {
  topic_arn = aws_sns_topic.raytracing_jobs_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.pwshraytracer_lambda.arn
}

resource "aws_s3_object" "pwsh_custom_runtime_layer" {
  bucket = aws_s3_bucket.pwshraytracer_lambda_layers.id
  key    = "pwsh_lambda_layer_payload.zip"
  source = "artifacts/pwsh_lambda_layer_payload.zip"
  etag   = filemd5("artifacts/pwsh_lambda_layer_payload.zip")
  tags = {
    Environment = "PwshRayTracer"
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
  description              = "PwshRayTracer"
}

resource "aws_lambda_function" "pwshraytracer_lambda" {
  layers        = [aws_lambda_layer_version.pwsh_lambda_layer.arn]
  filename      = "artifacts/pwsh_lambda_function_payload.zip"
  handler       = "HelloWorld.ps1::Invoke-Handler"
  function_name = "PwshRayTracer"
  memory_size   = 250
  timeout       = 15
  role          = aws_iam_role.iam_for_pwshraytracer_lambda.arn
  source_code_hash = filebase64sha256("artifacts/pwsh_lambda_function_payload.zip")
  runtime = "provided.al2"

  tags = {
    Name        = "Pwsh Raytracer Lambda Function"
    Environment = "PwshRayTracer"
  }
}