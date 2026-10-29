"""RDS 시작 / 종료 이벤트(SNS)를 Discord 웹훅으로 전달한다."""
import json
import os
import urllib.request

WEBHOOK_URL = os.environ["DISCORD_WEBHOOK_URL"]

# RDS 이벤트 ID -> (상태, embed 색상)
EVENTS = {
    "RDS-EVENT-0088": (" 시작 완료", 0x2ECC71),
    "RDS-EVENT-0087": (" 종료 완료", 0xE74C3C),
}


def _send(message):
    # RDS 가 SNS 로 보내는 본문: "Event ID" 는 URL 이고 '#' 뒤가 RDS-EVENT-xxxx
    event_id = message.get("Event ID", "").split("#")[-1]
    if event_id not in EVENTS:
        return
    status, color = EVENTS[event_id]

    payload = {
        "embeds": [
            {
                "title": f"서버 {status}",
                "color": color,
            }
        ]
    }

    req = urllib.request.Request(
        WEBHOOK_URL,
        data=json.dumps(payload).encode("utf-8"),
        # Discord 는 기본 Python User-Agent 를 403 으로 차단한다
        headers={"Content-Type": "application/json", "User-Agent": "ooga-chaka-notify/1.0"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=10):
        pass


def lambda_handler(event, context):
    for record in event["Records"]:
        _send(json.loads(record["Sns"]["Message"]))
