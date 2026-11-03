output "vpc_id" {
    value =module.vpc.vpc_id
}

output "web_public_ip" {
    value = module.web_eip.public_ip
}

output "app_private_ip" {
    value = module.app_ec2.private_ip
}

output "app_public_ip" {
    value = module.app_ec2.public_ip
}

output "log_public_ip" {
    value = module.log_ec2.public_ip
}

output "rds_endpoint" {
    value = module.rds.db_endpoint
}

output "login_page_url" {
    value = local.login_page_url
}

output "access_api_endpoint" {
    value = module.api.api_endpoint
}

output "cognito_user_pool_id" {
    value = module.cognito.user_pool_id
}

output "deploy_bucket_name" {
    value = module.deploy_bucket.bucket_id
}


output "web_github_deploy_role_arn" {
    value = module.web_github_deploy.role_arn
}
