data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "role" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume.json

  tags = {
    Name = var.role_name
  }
}

# CloudWatch Logs 쓰기 권한
resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "inline" {
  dynamic "statement" {
    for_each = var.statements

    content {
      sid       = statement.value.sid
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "inline" {
  count = length(var.statements) > 0 ? 1 : 0

  name   = "${var.role_name}-policy"
  role   = aws_iam_role.role.id
  policy = data.aws_iam_policy_document.inline.json
}
