#!/usr/bin/env bash
# log EC2 에서 Redis 컨테이너를 (재)배포한다. GitHub Actions 가 SSM Run Command 로 root 권한으로 호출한다.
# SSM 은 sh 로 실행하므로 bash 가 아니면 bash 로 다시 실행한다
[ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"
set -euo pipefail

cd "$(dirname "$0")"

# Terraform(terraform.tfvars 의 redis_password)이 EC2 부팅 때마다 이 파일에 기록한다
ENV_FILE=/etc/ooga/env

if ! grep -q '^REDIS_PASSWORD=.\{12,\}' "$ENV_FILE" 2>/dev/null; then
    echo "[deploy] $ENV_FILE 에 REDIS_PASSWORD(12자 이상)가 없습니다 (Terraform apply 후 EC2 재부팅 필요)" >&2
    exit 1
fi
REDIS_PASSWORD=$(grep -m1 '^REDIS_PASSWORD=' "$ENV_FILE" | cut -d= -f2- | tr -d '"\r')

# docker 가 없으면 설치 (Ubuntu 24.04)
if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
    echo "[deploy] docker 설치"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y docker.io docker-compose-v2 curl
fi
systemctl enable --now docker

# Redis 권장 설정: 메모리 부족 시에도 백그라운드 저장(fork)이 실패하지 않도록 한다
if [ "$(sysctl -n vm.overcommit_memory)" != "1" ]; then
    echo "vm.overcommit_memory = 1" > /etc/sysctl.d/99-ooga-redis.conf
    sysctl -p /etc/sysctl.d/99-ooga-redis.conf >/dev/null
fi

docker compose pull

# 설정 오류로 기존 서비스를 내리지 않도록 먼저 compose 파일 검사
echo "[deploy] compose 설정 검사"
docker compose config -q

# EC2 가 중지/시작될 때마다 compose 가 다시 올라오도록 systemd 에 등록 (이미 같은 내용이면 건드리지 않음)
# - 부팅: docker 가 뜬 뒤 compose up
# - 종료: compose stop (down 이 아니라 stop. 데이터 볼륨은 어느 쪽이든 유지된다)
UNIT_NAME=ooga-redis.service
UNIT_PATH=/etc/systemd/system/$UNIT_NAME
UNIT_TMP=$(mktemp)
cat > "$UNIT_TMP" <<EOF
[Unit]
Description=Ooga Redis (docker compose)
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$(pwd)
ExecStart=$(command -v docker) compose up -d --remove-orphans
ExecStop=$(command -v docker) compose stop
TimeoutStartSec=300
TimeoutStopSec=60

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

# 설정/이미지가 바뀐 경우에만 컨테이너가 다시 만들어진다 (같으면 Redis 를 재시작하지 않음)
echo "[deploy] 컨테이너 시작"
systemctl start "$UNIT_NAME"
docker compose up -d --remove-orphans

healthy=0
for _ in $(seq 1 30); do
    if docker exec -e REDISCLI_AUTH="$REDIS_PASSWORD" ooga-redis redis-cli ping 2>/dev/null | grep -q PONG; then
        healthy=1
        break
    fi
    sleep 2
done

if [ "$healthy" = 1 ]; then
    echo "[deploy] OK (redis PONG, $(systemctl is-enabled "$UNIT_NAME"))"
    docker image prune -f >/dev/null
    exit 0
fi

echo "[deploy] 상태 확인 실패" >&2
systemctl status "$UNIT_NAME" --no-pager >&2 || true
docker compose ps >&2
docker compose logs --tail 50 redis >&2
exit 1
