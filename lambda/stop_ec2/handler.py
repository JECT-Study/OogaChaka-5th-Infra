"""EventBridge 가 주기적으로 호출한다.

1. DynamoDB 에서 만료된 세션을 찾는다.
2. 활성 세션이 쓰지 않는 IP 의 보안그룹 규칙(설명이 RULE_DESCRIPTION 인 것만)을 삭제한다.
3. 만료된 세션 항목을 삭제한다.
4. 이번에 만료된 세션이 있고 남은 활성 세션이 없으면 EC2 와 RDS 를 종료한다.
"""
import os
import time

import boto3
from botocore.exceptions import ClientError

ec2 = boto3.client("ec2")
rds = boto3.client("rds")
table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])

SECURITY_GROUP_ID = os.environ["SECURITY_GROUP_ID"]
INSTANCE_IDS = [i.strip() for i in os.environ["INSTANCE_IDS"].split(",") if i.strip()]
RULE_DESCRIPTION = os.environ.get("RULE_DESCRIPTION", "ooga-access")
DB_INSTANCE_ID = os.environ.get("DB_INSTANCE_ID", "")


def _scan_sessions():
    items = []
    kwargs = {}
    while True:
        resp = table.scan(**kwargs)
        items.extend(resp["Items"])
        if "LastEvaluatedKey" not in resp:
            return items
        kwargs["ExclusiveStartKey"] = resp["LastEvaluatedKey"]


def _owned_rules():
    """이 시스템이 만든 인바운드 규칙만 조회"""
    rules = []
    paginator = ec2.get_paginator("describe_security_group_rules")
    pages = paginator.paginate(Filters=[{"Name": "group-id", "Values": [SECURITY_GROUP_ID]}])
    for page in pages:
        for rule in page["SecurityGroupRules"]:
            if (
                not rule["IsEgress"]
                and rule.get("Description") == RULE_DESCRIPTION
                and rule.get("CidrIpv4")
            ):
                rules.append(rule)
    return rules


def _revoke_stale_rules(active_cidrs):
    stale_ids = [
        r["SecurityGroupRuleId"] for r in _owned_rules() if r["CidrIpv4"] not in active_cidrs
    ]
    for i in range(0, len(stale_ids), 20):
        ec2.revoke_security_group_ingress(
            GroupId=SECURITY_GROUP_ID, SecurityGroupRuleIds=stale_ids[i : i + 20]
        )
    return len(stale_ids)


def _stop_instances():
    try:
        ec2.stop_instances(InstanceIds=INSTANCE_IDS)
    except ClientError as e:
        print(f"stop_instances failed: {e}")
        return False
    return True


def _stop_database():
    """RDS 중지. 이미 중지됐거나 상태 전환 중이면 다음 실행에서 다시 시도한다."""
    if not DB_INSTANCE_ID:
        return False
    try:
        rds.stop_db_instance(DBInstanceIdentifier=DB_INSTANCE_ID)
    except ClientError as e:
        print(f"stop_db_instance failed: {e}")
        return False
    return True


def lambda_handler(event, context):
    now = int(time.time())

    sessions = _scan_sessions()
    expired = [s for s in sessions if int(s["expires_at"]) <= now]
    active = [s for s in sessions if int(s["expires_at"]) > now]

    # 활성 세션이 쓰는 IP 의 규칙은 유지 (같은 공유기/회사 IP 를 여러 명이 쓰는 경우 대비)
    active_cidrs = {f"{s['ip']}/32" for s in active}
    revoked = _revoke_stale_rules(active_cidrs)

    for s in expired:
        table.delete_item(Key={"user_sub": s["user_sub"], "ip": s["ip"]})

    stopped = False
    db_stopped = False
    if expired and not active:
        stopped = _stop_instances()
        db_stopped = _stop_database()

    result = {
        "expired_sessions": len(expired),
        "active_sessions": len(active),
        "revoked_rules": revoked,
        "instances_stopped": stopped,
        "database_stopped": db_stopped,
    }
    print(result)
    return result
