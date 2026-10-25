resource "aws_dynamodb_table" "table" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = var.hash_key
  range_key = var.range_key

  attribute {
    name = var.hash_key
    type = "S"
  }

  dynamic "attribute" {
    for_each = var.range_key != null ? [var.range_key] : []

    content {
      name = attribute.value
      type = "S"
    }
  }

  # 만료 후 남은 항목을 자동 정리 (실제 접근 차단은 스케줄러 Lambda 가 담당)
  ttl {
    attribute_name = var.ttl_attribute
    enabled        = true
  }

  tags = {
    Name = var.table_name
  }
}
