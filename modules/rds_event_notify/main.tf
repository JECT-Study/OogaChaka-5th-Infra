resource "aws_sns_topic" "topic" {
  name = var.topic_name
}

# RDS 이벤트 구독이 이 토픽에 발행할 수 있도록 허용
data "aws_iam_policy_document" "topic" {
  statement {
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.topic.arn]

    principals {
      type        = "Service"
      identifiers = ["events.rds.amazonaws.com"]
    }
  }
}

resource "aws_sns_topic_policy" "topic" {
  arn    = aws_sns_topic.topic.arn
  policy = data.aws_iam_policy_document.topic.json
}

resource "aws_db_event_subscription" "rds" {
  name             = "${replace(var.topic_name, "_", "-")}-subscription"
  sns_topic        = aws_sns_topic.topic.arn
  source_type      = "db-instance"
  source_ids       = [var.db_identifier]
  event_categories = var.event_categories

  depends_on = [aws_sns_topic_policy.topic]
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.topic.arn
  protocol  = "lambda"
  endpoint  = var.lambda_arn
}

resource "aws_lambda_permission" "sns" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.topic.arn
}
