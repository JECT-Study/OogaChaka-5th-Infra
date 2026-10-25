# public access block 이 끝난 뒤에 버킷 정책이 붙도록 pab 를 참조
output "bucket_id" {
  value = aws_s3_bucket_public_access_block.pab.bucket
}

output "bucket_arn" {
  value = aws_s3_bucket.bucket.arn
}

output "bucket_regional_domain_name" {
  value = aws_s3_bucket.bucket.bucket_regional_domain_name
}
