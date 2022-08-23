resource "aws_lambda_function" "pwshraytracer_lambda" {
  layers           = [aws_lambda_layer_version.pwsh_lambda_layer.arn]
  filename         = "../artifacts/pwsh_lambda_function_payload.zip"
  handler          = "Handler.ps1::Invoke-Handler"
  function_name    = "lambda-pwshraytracer"
  memory_size      = 128 # 5400 if you want 4 CPU cores
  timeout          = 600
  role             = aws_iam_role.iam_for_pwshraytracer_lambda.arn
  source_code_hash = filebase64sha256("../artifacts/pwsh_lambda_function_payload.zip")
  runtime          = "provided.al2"

  tags = {
    Name        = "PwshRaytracer Lambda Function"
    Environment = var.environment_tag
  }
}

resource "aws_lambda_function_event_invoke_config" "pwshraytracer_lambda_notifications" {
  function_name = aws_lambda_function.pwshraytracer_lambda.function_name
  maximum_retry_attempts = 1
  destination_config {
    on_failure {
      destination = aws_sqs_queue.pwshraytracer_notifications_queue.arn
    }

    on_success {
      destination = aws_sqs_queue.pwshraytracer_notifications_queue.arn
    }
  }
}

resource "aws_sns_topic_subscription" "raytracing_jobs_subscription" {
  topic_arn = aws_sns_topic.raytracing_jobs_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.pwshraytracer_lambda.arn
}