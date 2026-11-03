# 계정당 하나만 만들 수 있는 GitHub OIDC 공급자
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}
