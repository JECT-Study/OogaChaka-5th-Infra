"""로그인한 개발자의 IP 를 보안그룹에 열고, EC2 를 시작한 뒤 만료 시간을 DynamoDB 에 기록한다.

API Gateway(HTTP API, JWT authorizer) 뒤에서 호출된다.
  POST /access   body(선택): {"hours": 2}

계정(user_sub)당 세션은 1개만 유지한다. 다른 IP 로 다시 로그인하면 이전 IP 세션은 삭제하고,
다른 활성 세션이 쓰지 않는 이전 IP 의 보안그룹 규칙도 즉시 닫는다.
"""
import ipaddress
import json
import os
import time

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

ec2 = boto3.client("ec2")
rds = boto3.client("rds")
table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])

SECURITY_GROUP_ID = os.environ["SECURITY_GROUP_ID"]
INSTANCE_IDS = [i.strip() for i in os.environ["INSTANCE_IDS"].split(",") if i.strip()]
PORTS = [int(p) for p in os.environ.get("PORTS", "22,443").split(",")]
DEFAULT_HOURS = float(os.environ.get("DEFAULT_HOURS", "2"))
MAX_HOURS = float(os.environ.get("MAX_HOURS", "8"))
# 이 설명이 붙은 규칙만 stop Lambda 가 삭제한다 (Terraform 이 만든 고정 규칙은 건드리지 않음)
RULE_DESCRIPTION = os.environ.get("RULE_DESCRIPTION", "ooga-access")
DB_INSTANCE_ID = os.environ.get("DB_INSTANCE_ID", "")


def _response(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def _open_ports(ip):
    for port in PORTS:
        try:
            ec2.authorize_security_group_ingress(
                GroupId=SECURITY_GROUP_ID,
                IpPermissions=[
                    {
                        "IpProtocol": "tcp",
                        "FromPort": port,
                        "ToPort": port,
                        "IpRanges": [{"CidrIp": f"{ip}/32", "Description": RULE_DESCRIPTION}],
                    }
                ],
            )
        except ClientError as e:
            # 같은 IP 규칙이 이미 있으면(다른 세션 또는 고정 규칙) 그대로 사용
            if e.response["Error"]["Code"] != "InvalidPermission.Duplicate":
                raise


def _revoke_ip(ip):
    """RULE_DESCRIPTION 이 붙은 규칙 중 해당 IP 의 규칙만 삭제"""
    rule_ids = []
    paginator = ec2.get_paginator("describe_security_group_rules")
    pages = paginator.paginate(Filters=[{"Name": "group-id", "Values": [SECURITY_GROUP_ID]}])
    for page in pages:
        for rule in page["SecurityGroupRules"]:
            if (
                not rule["IsEgress"]
                and rule.get("Description") == RULE_DESCRIPTION
                and rule.get("CidrIpv4") == f"{ip}/32"
            ):
                rule_ids.append(rule["SecurityGroupRuleId"])
    if rule_ids:
        ec2.revoke_security_group_ingress(GroupId=SECURITY_GROUP_ID, SecurityGroupRuleIds=rule_ids)


def _drop_previous_sessions(user_sub, current_ip, now):
    """같은 계정의 다른 IP 세션을 삭제하고, 더 이상 쓰는 세션이 없는 IP 의 규칙을 닫는다."""
    previous = table.query(KeyConditionExpression=Key("user_sub").eq(user_sub))["Items"]
    old_ips = {item["ip"] for item in previous if item["ip"] != current_ip}
    if not old_ips:
        return

    for ip in old_ips:
        table.delete_item(Key={"user_sub": user_sub, "ip": ip})

    # 같은 공유기/회사 IP 를 쓰는 다른 사용자의 활성 세션이 있으면 규칙은 유지
    in_use = set()
    kwargs = {}
    while True:
        resp = table.scan(**kwargs)
        in_use.update(i["ip"] for i in resp["Items"] if int(i["expires_at"]) > now)
        if "LastEvaluatedKey" not in resp:
            break
        kwargs["ExclusiveStartKey"] = resp["LastEvaluatedKey"]

    for ip in old_ips - in_use:
        _revoke_ip(ip)


def _start_instances():
    """시작 요청. 이미 켜져 있으면 문제 없고, 종료 중 같은 상태면 경고 메시지를 돌려준다."""
    try:
        ec2.start_instances(InstanceIds=INSTANCE_IDS)
    except ClientError as e:
        return e.response["Error"]["Message"]
    return None


def _start_database():
    """RDS 시작 요청. 이미 켜져 있거나 시작/중지 중이면 경고 메시지를 돌려준다."""
    if not DB_INSTANCE_ID:
        return None
    try:
        rds.start_db_instance(DBInstanceIdentifier=DB_INSTANCE_ID)
    except ClientError as e:
        if e.response["Error"]["Code"] == "InvalidDBInstanceState":
            return None  # 이미 available / starting
        return e.response["Error"]["Message"]
    return None


def lambda_handler(event, context):
    claims = event["requestContext"]["authorizer"]["jwt"]["claims"]
    user_sub = claims["sub"]
    email = claims.get("email", "")

    # 본문이 아니라 API Gateway 가 기록한 접속 IP 를 사용 (IP 위조 방지)
    ip = event["requestContext"]["http"]["sourceIp"]
    try:
        if ipaddress.ip_address(ip).version != 4:
            return _response(400, {"message": "IPv4 접속만 지원합니다"})
    except ValueError:
        return _response(400, {"message": "invalid source ip"})

    try:
        body = json.loads(event.get("body") or "{}")
        hours = float(body.get("hours", DEFAULT_HOURS))
    except (ValueError, TypeError, AttributeError):
        return _response(400, {"message": "invalid request body"})
    if hours <= 0:
        return _response(400, {"message": "hours must be positive"})
    hours = min(hours, MAX_HOURS)

    now = int(time.time())
    expires_at = now + int(hours * 3600)

    _open_ports(ip)

    # user_sub + ip 가 키: 같은 사용자가 같은 IP 로 다시 호출하면 만료 시간이 연장된다
    table.put_item(
        Item={
            "user_sub": user_sub,
            "ip": ip,
            "email": email,
            "started_at": now,
            "expires_at": expires_at,
            "ttl": expires_at + 86400,
        }
    )

    # 새 세션을 먼저 기록한 뒤 이전 세션을 정리 (정리 도중 실패해도 새 접속은 유효)
    _drop_previous_sessions(user_sub, ip, now)

    warning = _start_instances() or _start_database()

    result = {
        "ip": ip,
        "ports": PORTS,
        "expires_at": expires_at,
        "hours": hours,
        "instances": INSTANCE_IDS,
        "database": DB_INSTANCE_ID,
    }
    if warning:
        result["warning"] = warning
    return _response(200, result)
