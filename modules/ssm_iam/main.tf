data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

# SSM agent 가 SSM 에 등록되고 Run Command 를 받을 수 있게 한다
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 배포 파일 버킷 읽기 전용
data "aws_iam_policy_document" "deploy_bucket" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${var.deploy_bucket_arn}/*"]
  }

  statement {
    actions   = ["s3:ListBucket"]
    resources = [var.deploy_bucket_arn]
  }
}

resource "aws_iam_role_policy" "deploy_bucket" {
  name   = "${var.name}-deploy-bucket"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.deploy_bucket.json
}

resource "aws_iam_instance_profile" "ec2" {
  name = var.name
  role = aws_iam_role.ec2.name
}

# ECR 이미지 pull 전용 (지정한 저장소만, push 불가)
data "aws_iam_policy_document" "ecr_pull" {
  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPull"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
    ]
    resources = var.ecr_pull_repository_arns
  }
}

resource "aws_iam_role_policy" "ecr_pull" {
  count = length(var.ecr_pull_repository_arns) > 0 ? 1 : 0

  name   = "${var.name}-ecr-pull"
  role   = aws_iam_role.ec2.id
  policy = data.aws_iam_policy_document.ecr_pull.json
}
