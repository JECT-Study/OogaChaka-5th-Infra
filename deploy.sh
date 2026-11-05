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

# --- SSL 설정 ---------------------------------------------------------------
# /etc/ooga/env 에 DOMAIN, CERT_EMAIL 이 둘 다 있으면 Let's Encrypt 인증서를 받아 HTTPS 를 켠다.
# 없으면 80 포트 nginx 만 띄운다. (인증서 발급에 실패해도 HTTP 로 계속 배포한다)
env_val() { grep -m1 "^$1=" /etc/ooga/env 2>/dev/null | cut -d= -f2- | tr -d '"\r' || true; }
DOMAIN=$(env_val DOMAIN)
CERT_EMAIL=$(env_val CERT_EMAIL)
CERT_DIR=/etc/letsencrypt/live/$DOMAIN

mkdir -p /etc/letsencrypt /var/www/certbot

# 인증서가 이미 있으면 https 모드, 아니면 http 모드로 .env 를 쓴다 (compose 와 systemd 유닛이 읽는다)
set_mode() {
    if [ "$1" = "https" ]; then
        printf 'HTTPS_ENABLED=1\nSSL_TEMPLATE=ssl.conf.template\n' > .env
    else
        printf 'HTTPS_ENABLED=0\nSSL_TEMPLATE=ssl.off.template\n' > .env
    fi
}

if [ -n "$DOMAIN" ] && [ -n "$CERT_EMAIL" ] && [ -f "$CERT_DIR/fullchain.pem" ]; then
    set_mode https
else
    set_mode http
fi

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

healthy=0
for _ in $(seq 1 30); do
    if curl -fsS http://127.0.0.1/healthz >/dev/null 2>&1; then
        healthy=1
        break
    fi
    sleep 2
done

if [ "$healthy" = 1 ]; then
    if [ -n "$DOMAIN" ] && [ -n "$CERT_EMAIL" ]; then
        # 처음 배포라 인증서가 없으면 발급 (80 포트 nginx 가 /.well-known/acme-challenge 를 서빙 중)
        if [ ! -f "$CERT_DIR/fullchain.pem" ]; then
            echo "[deploy] 인증서 발급: $DOMAIN"
            if docker compose run --rm certbot certonly --webroot -w /var/www/certbot \
                -d "$DOMAIN" --email "$CERT_EMAIL" --agree-tos --no-eff-email --non-interactive; then
                set_mode https
                docker compose run --rm --no-deps nginx nginx -t
                systemctl restart "$UNIT_NAME"
            else
                echo "[deploy] 인증서 발급 실패 - DNS(A 레코드)/80 포트 확인 필요. HTTP 로 계속 운영합니다." >&2
            fi
        fi

        # 인증서 자동 갱신: 매일 새벽 certbot renew 후 nginx reload
        cat > /etc/cron.d/ooga-certbot <<CRON
17 3 * * * root cd $(pwd) && $(command -v docker) compose run --rm certbot renew --quiet && $(command -v docker) exec ooga-nginx nginx -s reload
CRON
        chmod 644 /etc/cron.d/ooga-certbot
    else
        rm -f /etc/cron.d/ooga-certbot
        echo "[deploy] DOMAIN/CERT_EMAIL 없음 - HTTPS 없이 nginx 만 실행"
    fi

    echo "[deploy] OK ($(systemctl is-enabled "$UNIT_NAME"), $(grep -q '^HTTPS_ENABLED=1' .env && echo https || echo http))"
    docker image prune -f >/dev/null
    exit 0
fi

echo "[deploy] 상태 확인 실패" >&2
systemctl status "$UNIT_NAME" --no-pager >&2 || true
docker compose ps >&2
docker compose logs --tail 50 nginx >&2
exit 1
