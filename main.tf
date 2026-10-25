# t4g 인스턴스는 ARM64 이므로 arm64 AMI 사용
locals {
    ami_id = "ami-064b0e4b6529b20cf"
    db_identifier = "ooga-chaka-db"
}

# vpc
module "vpc" {
    source = "./modules/vpc"
    cidr_block = "172.16.160.0/22"
    vpc_name = "ooga_chaka"
}

module "igw" {
    source = "./modules/igw"
    vpc_id = module.vpc.vpc_id
    igw_name = "ooga_chaka_igw"
}

# 웹서버인 서버넷 (퍼블릭)
module "public_subnet_web" {
    source = "./modules/subnet"
    vpc_id = module.vpc.vpc_id
    cidr_block = "172.16.160.0/24"
    availability_zone = "ap-northeast-2a"
    subnet_name = "ooga_chaka_public_web"
}

# 애플리케이션 서버인 서브넷 (퍼블릭)
module "public_subnet_app" {
    source = "./modules/subnet"
    vpc_id = module.vpc.vpc_id
    cidr_block = "172.16.161.0/24"
    availability_zone = "ap-northeast-2a"
    subnet_name = "ooga_chaka_public_app"
}

# 애플리케이션 서버인 로깅 서브넷 (퍼블릭)
module "public_subnet_log" {
    source = "./modules/subnet"
    vpc_id = module.vpc.vpc_id
    cidr_block = "172.16.162.0/24"
    availability_zone = "ap-northeast-2a"
    subnet_name = "ooga_chaka_public_log"
}

# rds 서브넷 rds 는 기본 2개 필요 
module "private_subnet_a" {
    source = "./modules/subnet"
    vpc_id = module.vpc.vpc_id
    cidr_block = "172.16.163.0/25"
    availability_zone = "ap-northeast-2a"
    subnet_name = "ooga_chaka_private_a"
}

module "private_subnet_c" {
    source = "./modules/subnet"
    vpc_id = module.vpc.vpc_id
    cidr_block = "172.16.163.128/25"
    availability_zone = "ap-northeast-2c"
    subnet_name = "ooga_chaka_private_c"
}

# 라우트 테이블 (퍼블릭 iwg 연결)
module "route_table" {
    source = "./modules/route_table"
    vpc_id = module.vpc.vpc_id
    igw_id = module.igw.igw_id
    public_route_table_name = "ooga_chaka_public_rt"
    private_route_table_name = "ooga_chaka_private_rt"
}

# 라우트 테이블 (퍼블릭 web 서브넷 연결)
module "rt_assoc_public_web" {
    source = "./modules/route_table_association"
    subnet_id = module.public_subnet_web.subnet_id
    route_table_id = module.route_table.public_route_table_id
}


# 라우트 테이블 (퍼블릭 애플리캐이션 서브넷 연결)
module "rt_assoc_public_app" {
    source = "./modules/route_table_association"
    subnet_id = module.public_subnet_app.subnet_id
    route_table_id = module.route_table.public_route_table_id
}

# 라우트 테이블 (퍼블릭 로그 서브넷 연결)
module "rt_assoc_public_log" {
    source = "./modules/route_table_association"
    subnet_id = module.public_subnet_log.subnet_id
    route_table_id = module.route_table.public_route_table_id
}

# 라우트 테이블 (프라이빗 rds a 서브넷 연결)
module "rt_assoc_private_a" {
    source = "./modules/route_table_association"
    subnet_id = module.private_subnet_a.subnet_id
    route_table_id = module.route_table.private_route_table_id
}

# 라우트 테이블 (프라이빗 rds c 서브넷 연결)
module "rt_assoc_private_c" {
    source = "./modules/route_table_association"
    subnet_id = module.private_subnet_c.subnet_id
    route_table_id = module.route_table.private_route_table_id
}

# 보안그룹 (web ec2)
module "web_sg" {
    source = "./modules/sg"
    name = "ooga_chaka_web_sg"
    description = "Web server (nginx)"
    vpc_id = module.vpc.vpc_id
}


# 보안그룹 (app ec2)
module "app_sg" {
    source = "./modules/sg"
    name = "ooga_chaka_app_sg"
    description = "Application server"
    vpc_id = module.vpc.vpc_id
}

# 보안그룹 (log ec2)
module "log_sg" {
    source = "./modules/sg"
    name = "ooga_chaka_log_sg"
    description = "Log server (Grafana, Loki)"
    vpc_id = module.vpc.vpc_id
}

# 보안그룹 (rds ec2)
module "rds_sg" {
    source = "./modules/sg"
    name = "ooga_chaka_rds_sg"
    description = "RDS MySQL"
    vpc_id = module.vpc.vpc_id
}

# web ec2 보안그룹 80 443 22
module "web_in_http" {
    source = "./modules/sg_ingress_rule"
    security_group_id = module.web_sg.id
    description = "HTTP"
    from_port = 80
    to_port = 80
    cidr_ipv4 = "0.0.0.0/0"
}

module "web_in_https" {
    source = "./modules/sg_ingress_rule"
    security_group_id = module.web_sg.id
    description = "HTTPS"
    from_port = 443
    to_port = 443
    cidr_ipv4 = var.admin_cidr
}

module "web_in_ssh" {
    source = "./modules/sg_ingress_rule"
    security_group_id = module.web_sg.id
    description = "SSH"
    from_port = 22
    to_port = 22
    cidr_ipv4 = var.admin_cidr
}


# app ec2 보안그룹 8080  22
module "app_in_8080" {
    source = "./modules/sg_ingress_rule"
    security_group_id = module.app_sg.id
    description = "Spring Boot from web"
    from_port = 8080
    to_port = 8080
    referenced_security_group_id = module.web_sg.id
}

module "app_in_ssh" {
    source = "./modules/sg_ingress_rule"
    security_group_id = module.app_sg.id
    description = "SSH from web (bastion)"
    from_port = 22
    to_port = 22
    referenced_security_group_id = module.web_sg.id
}


# log ec2 보안그룹 3100  3000 22
module "log_in_loki" {
    source = "./modules/sg_ingress_rule"
    security_group_id = module.log_sg.id
    description = "Loki from app (Alloy)"
    from_port = 3100
    to_port = 3100
    referenced_security_group_id = module.app_sg.id
}

module "log_in_grafana" {
    source = "./modules/sg_ingress_rule"
    security_group_id = module.log_sg.id
    description = "Grafana"
    from_port = 3000
    to_port = 3000
    cidr_ipv4 = var.admin_cidr
}

module "log_in_ssh" {
    source = "./modules/sg_ingress_rule"
    security_group_id = module.log_sg.id
    description = "SSH from web (bastion)"
    from_port = 22
    to_port = 22
    referenced_security_group_id = module.web_sg.id
}

# rds 보안그룹 3306
# app 서버 생성 시 주석 해제
 module "rds_in_mysql" {
     source = "./modules/sg_ingress_rule"
     security_group_id = module.rds_sg.id
     description = "MySQL from app"
     from_port = 3306
     to_port = 3306
     referenced_security_group_id = module.app_sg.id
 }

# rds 보안그룹 3306 (web 서버 = 베스천, SSH 터널링용)
module "rds_in_mysql_bastion" {
    source = "./modules/sg_ingress_rule"
    security_group_id = module.rds_sg.id
    description = "MySQL from web (bastion tunnel)"
    from_port = 3306
    to_port = 3306
    referenced_security_group_id = module.web_sg.id
}

# outboud web 0.0.0.0
module "web_out_all" {
    source = "./modules/sg_egress_rule"
    security_group_id = module.web_sg.id
    description = "All outbound"
}


# outboud app 0.0.0.0
module "app_out_all" {
    source = "./modules/sg_egress_rule"
    security_group_id = module.app_sg.id
    description = "All outbound"
}

# outboud log 0.0.0.0
module "log_out_all" {
    source = "./modules/sg_egress_rule"
    security_group_id = module.log_sg.id
    description = "All outbound"
}

# web EC2
module "web_ec2" {
    source = "./modules/ec2"
    ami_id = local.ami_id
    instance_type = "t4g.micro"    # t4g.nano 는 프리티어 불가. 다음 단계에서 t4g.small 로 변경 예정
    subnet_id = module.public_subnet_web.subnet_id
    security_group_ids = [module.web_sg.id]
    key_name = var.key_name
    associate_public_ip = true
    instance_name = "ooga_chaka_web"
}


# app EC2
module "app_ec2" {
    source = "./modules/ec2"
    ami_id = local.ami_id
    instance_type = "t4g.small"
    subnet_id = module.public_subnet_app.subnet_id
    security_group_ids = [module.app_sg.id]
    key_name = var.key_name
    associate_public_ip = true    # NAT 없이 IGW 로 outbound 하기 위해 필요
    instance_name = "ooga_chaka_app"
}

# log EC2
module "log_ec2" {
    source = "./modules/ec2"
    ami_id = local.ami_id
    instance_type = "t4g.small"
    subnet_id = module.public_subnet_log.subnet_id
    security_group_ids = [module.log_sg.id]
    key_name = var.key_name
    associate_public_ip = true
    instance_name = "ooga_chaka_log"
}


# web 로드벨런서와 eip 연결
module "web_eip" {
    source = "./modules/eip"
    name = "ooga_chaka_web_eip"
    instance_id = module.web_ec2.instance_id
}

# rds
module "rds" {
    source = "./modules/rds"
    db_subnet_group_name = "ooga-chaka-rds-subnet-group"
    private_subnet_ids = [module.private_subnet_a.subnet_id, module.private_subnet_c.subnet_id]
    db_identifier = local.db_identifier
    instance_class = "db.t4g.micro"
    db_name = var.db_name
    db_username = var.db_username
    db_password = var.db_password
    security_group_ids = [module.rds_sg.id]
}

# ==============================================================================
# 개발자 접속 허용 시스템
# Developer -> CloudFront/S3 로그인 페이지 -> Cognito -> API Gateway -> Lambda -> EC2/보안그룹
# EventBridge(5분마다) -> Lambda -> 만료된 접속 정리, EC2 종료
# ==============================================================================
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
    account_id = data.aws_caller_identity.current.account_id
    region = data.aws_region.current.name

    # 시작 / 종료 대상 EC2 (web, app, log 전부)
    access_instance_ids = [module.web_ec2.instance_id, module.app_ec2.instance_id, module.log_ec2.instance_id]
    access_instance_arns = [for id in local.access_instance_ids : "arn:aws:ec2:${local.region}:${local.account_id}:instance/${id}"]

    # 시작 / 종료 대상 RDS
    db_arn = "arn:aws:rds:${local.region}:${local.account_id}:db:${local.db_identifier}"

    # Lambda 가 22, 443 을 열고 닫을 보안그룹
    web_sg_arn = "arn:aws:ec2:${local.region}:${local.account_id}:security-group/${module.web_sg.id}"

    login_page_url = "https://${module.cloudfront.domain_name}"
    cognito_domain_url = "https://${var.cognito_domain_prefix}.auth.${local.region}.amazoncognito.com"

    access_lambda_env = {
        TABLE_NAME = module.access_table.table_name
        SECURITY_GROUP_ID = module.web_sg.id
        INSTANCE_IDS = join(",", local.access_instance_ids)
        DB_INSTANCE_ID = local.db_identifier
        PORTS = "22,443"
        DEFAULT_HOURS = "2"
        MAX_HOURS = "2"
        RULE_DESCRIPTION = "ooga-access"
    }
}

# 로그인 페이지 (S3 + CloudFront HTTPS)
module "login_page_bucket" {
    source = "./modules/s3"
    bucket_name = "ooga-chaka-login-${local.account_id}"
    objects = {
        "index.html" = {
            content = file("${path.module}/web/index.html")
            content_type = "text/html; charset=utf-8"
        }
        "app.js" = {
            content = file("${path.module}/web/app.js")
            content_type = "application/javascript; charset=utf-8"
        }
        "config.js" = {
            content = templatefile("${path.module}/web/config.js.tftpl", {
                cognito_domain = local.cognito_domain_url
                client_id = module.cognito.client_id
                api_endpoint = module.api.api_endpoint
            })
            content_type = "application/javascript; charset=utf-8"
        }
    }
}

module "cloudfront" {
    source = "./modules/cloudfront"
    name = "ooga_chaka_login_page"
    bucket_id = module.login_page_bucket.bucket_id
    bucket_arn = module.login_page_bucket.bucket_arn
    bucket_regional_domain_name = module.login_page_bucket.bucket_regional_domain_name
}

# 인증 (관리자가 만든 사용자만 로그인 가능 -> 아무나 가입해서 22 포트를 여는 것을 방지)
module "cognito" {
    source = "./modules/cognito"
    user_pool_name = "ooga_chaka_users"
    client_name = "ooga_chaka_login_page"
    domain_prefix = var.cognito_domain_prefix
    callback_urls = ["${local.login_page_url}/"]
    logout_urls = ["${local.login_page_url}/"]
    allow_admin_create_user_only = true
}

# 세션(사용자, IP, 만료시간) 저장
module "access_table" {
    source = "./modules/dynamodb"
    table_name = "ooga_chaka_access"
    hash_key = "user_sub"
    range_key = "ip"
}

# 시작 Lambda : EC2 시작 + 접속 IP 허용
module "start_ec2_iam" {
    source = "./modules/lambda_iam"
    role_name = "ooga_chaka_start_ec2"
    statements = [
        {
            sid = "StartInstances"
            actions = ["ec2:StartInstances"]
            resources = local.access_instance_arns
        },
        {
            sid = "StartDatabase"
            actions = ["rds:StartDBInstance", "rds:DescribeDBInstances"]
            resources = [local.db_arn]
        },
        {
            sid = "OpenSecurityGroup"
            actions = ["ec2:AuthorizeSecurityGroupIngress"]
            resources = [local.web_sg_arn]
        },
        {
            sid = "WriteSession"
            actions = ["dynamodb:PutItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:DeleteItem"]
            resources = [module.access_table.table_arn]
        },
        {
            sid = "DescribeRules"
            actions = ["ec2:DescribeSecurityGroupRules"]
            resources = ["*"]
        },
        {
            sid = "CloseOldSecurityGroupRules"
            actions = ["ec2:RevokeSecurityGroupIngress"]
            resources = [local.web_sg_arn]
        },
    ]
}

module "start_ec2_lambda" {
    source = "./modules/lambda"
    function_name = "ooga_chaka_start_ec2"
    source_dir = "${path.module}/lambda/start_ec2"
    role_arn = module.start_ec2_iam.role_arn
    environment = local.access_lambda_env
}

# 종료 Lambda : 만료된 접속 정리 + EC2 종료
module "stop_ec2_iam" {
    source = "./modules/lambda_iam"
    role_name = "ooga_chaka_stop_ec2"
    statements = [
        {
            sid = "StopInstances"
            actions = ["ec2:StopInstances"]
            resources = local.access_instance_arns
        },
        {
            sid = "StopDatabase"
            actions = ["rds:StopDBInstance", "rds:DescribeDBInstances"]
            resources = [local.db_arn]
        },
        {
            sid = "DescribeRules"
            actions = ["ec2:DescribeSecurityGroupRules"]
            resources = ["*"]
        },
        {
            sid = "CloseSecurityGroup"
            actions = ["ec2:RevokeSecurityGroupIngress"]
            resources = [local.web_sg_arn]
        },
        {
            sid = "ManageSessions"
            actions = ["dynamodb:Scan", "dynamodb:DeleteItem"]
            resources = [module.access_table.table_arn]
        },
    ]
}

module "stop_ec2_lambda" {
    source = "./modules/lambda"
    function_name = "ooga_chaka_stop_ec2"
    source_dir = "${path.module}/lambda/stop_ec2"
    role_arn = module.stop_ec2_iam.role_arn
    environment = local.access_lambda_env
}

# API Gateway : Cognito 로그인한 사용자만 POST /access 호출 가능
module "api" {
    source = "./modules/api_gateway"
    api_name = "ooga_chaka_access_api"
    lambda_invoke_arn = module.start_ec2_lambda.invoke_arn
    lambda_function_name = module.start_ec2_lambda.function_name
    jwt_issuer = module.cognito.issuer_url
    jwt_audience = [module.cognito.client_id]
    cors_allow_origins = [local.login_page_url]
}

# EventBridge : 30분마다 종료 Lambda 실행
module "stop_schedule" {
    source = "./modules/eventbridge"
    rule_name = "ooga_chaka_stop_ec2_schedule"
    schedule_expression = "rate(30 minutes)"
    lambda_arn = module.stop_ec2_lambda.function_arn
    lambda_function_name = module.stop_ec2_lambda.function_name
}
