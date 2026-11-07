"""EventBridge 가 주기적으로 호출한다.

1. DynamoDB 에서 만료된 세션을 찾는다.
2. 활성 세션이 쓰지 않는 IP 의 보안그룹 규칙(설명이 RULE_DESCRIPTION 인 것만)을 삭제한다.
3. 만료된 세션 항목을 삭제한다.
4. 활성 세션이 없으면 실제로 켜져 있는 EC2(running) 와 RDS(available) 를 종료한다.
   "이번에 만료된 세션이 있는가" 가 아니라 현재 상태를 기준으로 하므로, 종료에 실패해도(pending, starting 등)
   다음 실행에서 다시 시도한다. 막 켜진 EC2 는 STOP_GRACE_MINUTES 동안 종료하지 않는다.
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
# 로그인 직후 켜진 EC2 를 바로 종료하지 않기 위한 보호 시간
STOP_GRACE_SECONDS = int(float(os.environ.get("STOP_GRACE_MINUTES", "15")) * 60)


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


def _stoppable_instance_ids(now):
    """running 이면서 켜진 지 STOP_GRACE_SECONDS 가 지난 EC2 만 종료 대상 (pending, stopping 등은 건너뜀)"""
    try:
        resp = ec2.describe_instances(InstanceIds=INSTANCE_IDS)
    except ClientError as e:
        print(f"describe_instances failed: {e}")
        return []

    ids = []
    for reservation in resp["Reservations"]:
        for instance in reservation["Instances"]:
            if instance["State"]["Name"] != "running":
                continue
            # LaunchTime 은 중지 후 다시 시작할 때마다 갱신된다
            if now - instance["LaunchTime"].timestamp() < STOP_GRACE_SECONDS:
                print(f"skip {instance['InstanceId']}: started recently")
                continue
            ids.append(instance["InstanceId"])
    return ids


def _stop_instances(instance_ids):
    if not instance_ids:
        return False
    try:
        ec2.stop_instances(InstanceIds=instance_ids)
    except ClientError as e:
        print(f"stop_instances failed: {e}")
        return False
    return True


def _stop_database():
    """RDS 중지. available 일 때만 시도하고, starting 등 전환 중이면 다음 실행에서 다시 시도한다."""
    if not DB_INSTANCE_ID:
        return False
    try:
        db = rds.describe_db_instances(DBInstanceIdentifier=DB_INSTANCE_ID)["DBInstances"][0]
        if db["DBInstanceStatus"] != "available":
            print(f"skip database: status={db['DBInstanceStatus']}")
            return False
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
    if not active:
        # 종료 직전에 다시 확인 (그 사이 새로 로그인한 세션이 있으면 종료하지 않는다)
        now = int(time.time())
        active = [s for s in _scan_sessions() if int(s["expires_at"]) > now]
    if not active:
        stopped = _stop_instances(_stoppable_instance_ids(now))
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
