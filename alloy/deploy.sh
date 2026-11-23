#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ "$EUID" -ne 0 ]; then
    echo "[alloy] sudo bash deploy.sh로 실행하세요." >&2
    exit 1
fi

command -v docker >/dev/null
docker compose version >/dev/null
systemctl enable --now docker
docker compose config -q
docker compose pull
docker compose run --rm --no-deps alloy validate /etc/alloy/config.alloy

unit_tmp=$(mktemp)
trap 'rm -f "$unit_tmp"' EXIT
cat > "$unit_tmp" <<EOF
[Unit]
Description=Ooga app log collector
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$(pwd)
ExecStart=$(command -v docker) compose up -d
ExecStop=$(command -v docker) compose stop
TimeoutStartSec=300
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
EOF

if ! cmp -s "$unit_tmp" /etc/systemd/system/ooga-alloy.service; then
    install -m 644 "$unit_tmp" /etc/systemd/system/ooga-alloy.service
    systemctl daemon-reload
fi
systemctl enable --now ooga-alloy.service
docker compose up -d
docker compose ps
