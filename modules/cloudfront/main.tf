resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = var.name
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  comment             = var.name
  default_root_object = var.default_root_object
  price_class         = var.price_class

  origin {
    domain_name              = var.bucket_regional_domain_name
    origin_id                = "s3"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "s3"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # 로그인 페이지는 파일이 작고 자주 바뀌므로 캐시하지 않음 (수정 후 무효화 불필요)
    cache_policy_id            = var.cache_policy_id
    response_headers_policy_id = var.response_headers_policy_id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # 기본 도메인(*.cloudfront.net) 인증서 사용 -> 추가 비용 없음
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# 이 배포(distribution)에서 오는 요청만 S3 객체 읽기 허용
data "aws_iam_policy_document" "bucket" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${var.bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "bucket" {
  bucket = var.bucket_id
  policy = data.aws_iam_policy_document.bucket.json
}
