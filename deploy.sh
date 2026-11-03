#!/usr/bin/env bash
# web EC2 에서 nginx 컨테이너를 (재)배포한다. GitHub Actions 가 SSM Run Command 로 root 권한으로 호출한다.
set -euo pipefail

cd "$(dirname "$0")"

# nginx 설정에 쓰는 web EC2 환경변수 (Terraform 이 /etc/ooga/env 에 기록)
if ! grep -q '^APP_PRIVATE_IP=.\+' /etc/ooga/env 2>/dev/null; then
    echo "[deploy] /etc/ooga/env 에 APP_PRIVATE_IP 가 없습니다 (Terraform env_vars 확인)" >&2
    exit 1
fi

# docker 가 없으면 설치 (Ubuntu 24.04)
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
    echo "[deploy] docker 설치"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y docker.io docker-compose-v2 curl
fi
systemctl enable --now docker

docker compose pull

# 설정 오류로 기존 서비스를 내리지 않도록 먼저 문법 검사
echo "[deploy] nginx 설정 검사"
docker compose run --rm --no-deps nginx nginx -t

# EC2 가 중지/시작될 때마다 compose 가 다시 올라오도록 systemd 에 등록 (이미 같은 내용이면 건드리지 않음)
# - 부팅: docker 가 뜬 뒤 compose up (컨테이너를 새로 만들어 /etc/ooga/env 의 최신 값을 반영)
# - 종료: compose down
UNIT_NAME=ooga-nginx.service
UNIT_PATH=/etc/systemd/system/$UNIT_NAME
UNIT_TMP=$(mktemp)
cat > "$UNIT_TMP" <<EOF
[Unit]
Description=Ooga nginx (docker compose)
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$(pwd)
ExecStart=$(command -v docker) compose up -d --force-recreate --remove-orphans
ExecStop=$(command -v docker) compose down
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

if ! cmp -s "$UNIT_TMP" "$UNIT_PATH"; then
    echo "[deploy] systemd 유닛 등록: $UNIT_NAME"
    install -m 644 "$UNIT_TMP" "$UNIT_PATH"
    systemctl daemon-reload
fi
rm -f "$UNIT_TMP"
systemctl enable "$UNIT_NAME"

# 템플릿의 ${APP_PRIVATE_IP} 는 컨테이너 시작 때만 치환되므로 매번 새로 만든다 (restart = down 후 up)
echo "[deploy] 컨테이너 시작"
systemctl restart "$UNIT_NAME"

for _ in $(seq 1 30); do
    if curl -fsS http://127.0.0.1/healthz >/dev/null 2>&1; then
        echo "[deploy] OK ($(systemctl is-enabled "$UNIT_NAME"))"
        docker image prune -f >/dev/null
        exit 0
    fi
    sleep 2
done

echo "[deploy] 상태 확인 실패" >&2
systemctl status "$UNIT_NAME" --no-pager >&2 || true
docker compose ps >&2
docker compose logs --tail 50 nginx >&2
exit 1
