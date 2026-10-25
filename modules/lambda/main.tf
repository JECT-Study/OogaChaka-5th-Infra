data "archive_file" "zip" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = "${path.module}/build/${var.function_name}.zip"
}

resource "aws_cloudwatch_log_group" "log" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "function" {
  function_name = var.function_name
  role          = var.role_arn
  runtime       = var.runtime
  handler       = var.handler
  architectures = [var.architecture]
  timeout       = var.timeout
  memory_size   = var.memory_size

  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256

  dynamic "environment" {
    for_each = length(var.environment) > 0 ? [1] : []

    content {
      variables = var.environment
    }
  }

  depends_on = [aws_cloudwatch_log_group.log]
}
