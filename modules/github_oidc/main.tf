data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  repo_owner = split("/", var.github_repo)[0]
  repo_name  = split("/", var.github_repo)[1]

  # 숫자 ID 가 지정되면 repo:조직@ID/저장소@ID 형식, 아니면 기본 repo:조직/저장소 형식
  repo_subject = (
    var.github_owner_id != null && var.github_repo_id != null
    ? "${local.repo_owner}@${var.github_owner_id}/${local.repo_name}@${var.github_repo_id}"
    : var.github_repo
  )
}

# 지정한 저장소 / 브랜치의 워크플로만 이 역할을 맡을 수 있다
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.repo_subject}:ref:refs/heads/${var.branch}"]
    }
  }
}

resource "aws_iam_role" "github" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid       = "UploadArtifact"
    actions   = ["s3:PutObject"]
    resources = ["${var.deploy_bucket_arn}/*"]
  }

  # Name 태그가 일치하는 EC2 에만 명령 전송
  statement {
    sid       = "SendCommandToTaggedInstance"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ec2:${local.region}:${local.account_id}:instance/*"]

    condition {
      test     = "StringEquals"
      variable = "ssm:resourceTag/Name"
      values   = [var.target_name_tag]
    }
  }

  statement {
    sid       = "UseRunShellScriptDocument"
    actions   = ["ssm:SendCommand"]
    resources = ["arn:aws:ssm:${local.region}::document/AWS-RunShellScript"]
  }

  statement {
    sid       = "ReadCommandResult"
    actions   = ["ssm:GetCommandInvocation", "ssm:ListCommandInvocations", "ssm:ListCommands"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "${var.role_name}-policy"
  role   = aws_iam_role.github.id
  policy = data.aws_iam_policy_document.deploy.json
}
