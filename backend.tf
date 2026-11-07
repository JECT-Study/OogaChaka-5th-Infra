terraform {
  backend "s3" {
    bucket         = "ooga-chaka-tfstate-727660953850"
    key            = "ooga-chaka/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "ooga-chaka-tfstate-lock"
    encrypt        = true
  }
}
