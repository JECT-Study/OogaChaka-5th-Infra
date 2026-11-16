# OogaChaka-5th-Infra
OogaChaka-5th-Infra 5팀 인프라

## Log EC2

GitHub Actions는 `log` 브랜치의 설정을 Log EC2의 `/opt/ooga/log`에 배포한다.
Redis, Loki, Grafana는 한 Compose 프로젝트에서 실행하며 각각의 데이터를 Docker 볼륨에 저장한다.
Loki는 로그를 7일 동안 보관하고, Grafana에서는 Loki를 기본 데이터 소스로 사용한다.

첫 배포 전에 Log EC2의 `/etc/ooga/grafana.env`에 `GF_SECURITY_ADMIN_PASSWORD`를 설정하고 파일 권한을 600으로 제한한다.
Grafana는 기본값으로 Log EC2의 `127.0.0.1:3000`에서 확인한다. Web EC2에서 연결하는 절차는 아래에 있다.
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

## App EC2의 로그 수집

Alloy는 App EC2에서 `oogachaka-app` 컨테이너의 Docker 로그를 읽고 Log EC2의 Loki로 보낸다.
App EC2에서 Log EC2 내부 주소의 `3100`번 포트에 접근할 수 있어야 한다.
Docker 소켓은 호스트의 Docker API에 대한 접근 권한을 주므로 Alloy 관리 화면의 포트는 공개하지 않는다.

`log` 브랜치 자동 배포가 만든 S3 배포 묶음에서 `alloy/`를 가져와 App EC2의 `/opt/ooga/alloy`에 둔다.
같은 디렉터리의 `.env`에 `LOKI_PUSH_URL=http://<Log EC2 내부 주소>:3100/loki/api/v1/push`를 설정한다.
App EC2에서 아래 순서대로 구성 검증과 실행을 진행한다.

```bash
cd /opt/ooga/alloy
sudo docker compose run --rm alloy validate /etc/alloy/config.alloy
sudo docker compose up -d
sudo docker compose logs --tail 30 alloy
```

Grafana의 **Explore**에서 `{service="oogachaka-app"}`을 조회해 백엔드 로그를 확인한다.

## Web EC2의 Nginx에서 Grafana 연결

팀은 기존 HTTPS 도메인의 `/grafana/`에서 Grafana에 접속한다. Nginx는 기존 `LOG_PRIVATE_IP`를 사용해 Log EC2의 `3000`번 포트로 전달한다.
이 저장소의 `log`, `dev/test`, `nginx` 브랜치는 배포 대상이 다르다. 아래 패치 두 개는 로깅 PR에 함께 포함하되 각각 해당 브랜치에서 적용한다.

1. `dev/test`에서 `integrations/grafana-security-group.patch`를 적용한다. Terraform 적용 후 Web EC2 보안 그룹에서 Log EC2의 Grafana 포트로 접근할 수 있는지 확인한다.
2. Log EC2의 `/opt/ooga/log/.env`에 `OOGA_GRAFANA_BIND_IP=0.0.0.0`을 추가한다.
   `/etc/ooga/grafana.env`에는 기존 관리자 비밀번호와 함께 아래 설정을 추가한다. 도메인 값은 Web EC2의 HTTPS 도메인에 맞춘다.

   ```dotenv
   GF_SERVER_ROOT_URL=https://test.oogachaka.co.kr/grafana/
   GF_SERVER_SERVE_FROM_SUB_PATH=false
   GF_SECURITY_COOKIE_SECURE=true
   ```

   `/opt/ooga/log`에서 `sudo docker compose up -d grafana`로 반영한다.
3. `nginx` 브랜치에서 `integrations/grafana-nginx.patch`를 적용하고 기존 Nginx 배포로 반영한다.
   Web EC2의 `/etc/ooga/env`에 `LOG_PRIVATE_IP`가 있는지 확인한다.
4. 브라우저에서 `https://test.oogachaka.co.kr/grafana/`로 로그인하고, **Explore**에서 앱 로그를 조회한다.

패치는 대상 브랜치의 작업 폴더에서 `git apply --check <패치 파일 경로>`로 확인한 뒤 `git apply <패치 파일 경로>`로 적용한다.
