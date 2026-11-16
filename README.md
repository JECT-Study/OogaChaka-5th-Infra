# OogaChaka-5th-Infra
OogaChaka-5th-Infra 5팀 인프라

## Log EC2

GitHub Actions는 `log` 브랜치의 설정을 Log EC2의 `/opt/ooga/log`에 배포한다.
Redis, Loki, Grafana는 한 Compose 프로젝트에서 실행하며 각각의 데이터를 Docker 볼륨에 저장한다.
Loki는 로그를 7일 동안 보관하고, Grafana에서는 Loki를 기본 데이터 소스로 사용한다.

첫 배포 전에 Log EC2의 `/etc/ooga/grafana.env`에 `GF_SECURITY_ADMIN_PASSWORD`를 설정하고 파일 권한을 600으로 제한한다.
Grafana는 Log EC2의 `127.0.0.1:3000`에서 확인한다. Nginx에서 연결할 때 Grafana 바인딩과 보안 그룹을 함께 조정한다.
Loki의 `3100`번 포트는 App EC2에서 접근하므로 배포 전에 Log EC2 보안 그룹에서 허용 범위를 확인한다.

### 맥에서 확인

로깅 작업 폴더의 터미널에서 로컬 테스트에만 쓰는 값을 준비한다.

```bash
logging_env_dir=$(mktemp -d)
printf 'REDIS_PASSWORD=local-test-redis\n' > "$logging_env_dir/redis.env"
printf 'GF_SECURITY_ADMIN_PASSWORD=local-test-grafana\n' > "$logging_env_dir/grafana.env"
export OOGA_REDIS_ENV_FILE="$logging_env_dir/redis.env"
export OOGA_GRAFANA_ENV_FILE="$logging_env_dir/grafana.env"
export OOGA_LOKI_BIND_IP=127.0.0.1
docker compose -p ooga-logging-local up -d --wait loki grafana
```

`curl -fsS http://127.0.0.1:3100/ready`가 `ready`를 반환하면 테스트 로그를 전송한다.

```bash
printf '{"streams":[{"stream":{"service":"logging-smoke"},"values":[["%s000000000","hello from local logging test"]]}]}' "$(date +%s)" |
  curl -fsS -H 'Content-Type: application/json' --data-binary @- http://127.0.0.1:3100/loki/api/v1/push
```

브라우저에서 `http://127.0.0.1:3000`을 열고 `admin` / `local-test-grafana`로 접속한다.
**Explore**에서 Loki를 선택하고 `{service="logging-smoke"}`를 조회해 테스트 로그가 보이는지 확인한다.
확인이 끝나면 `docker compose -p ooga-logging-local down`으로 종료한다.
