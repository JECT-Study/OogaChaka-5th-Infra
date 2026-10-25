resource "aws_s3_bucket" "bucket" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = {
    Name = var.bucket_name
  }
}

# 버킷은 비공개. CloudFront(OAC)를 통해서만 읽을 수 있음
resource "aws_s3_bucket_public_access_block" "pab" {
  bucket = aws_s3_bucket.bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "objects" {
  for_each = var.objects

  bucket       = aws_s3_bucket.bucket.id
  key          = each.key
  content      = each.value.content
  content_type = each.value.content_type
  etag         = md5(each.value.content)
}
