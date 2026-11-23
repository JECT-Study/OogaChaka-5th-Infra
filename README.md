# OogaChaka-5th-Infra
OogaChaka-5th-Infra 5팀 인프라

## Log EC2

GitHub Actions는 `log` 브랜치의 설정을 Log EC2의 `/opt/ooga/log`에 배포한다.
Redis, Loki, Grafana는 한 Compose 프로젝트에서 실행하며 각각의 데이터를 Docker 볼륨에 저장한다.
Loki는 로그를 7일 동안 보관하고, Grafana에서는 Loki를 기본 데이터 소스로 사용한다.

Grafana 설정은 기존 `/etc/ooga/grafana.env` 파일 또는 Parameter Store의 SecureString으로 관리한다.
Parameter Store를 사용할 경우 환경변수 파일 전체를 저장하고, Infra 저장소의 Actions Variables에 `GRAFANA_ENV_PARAMETER`를 해당 경로로 등록한다.
배포할 때 Log EC2가 값을 조회하고 관리자 비밀번호 항목을 확인한 뒤 파일을 600 권한으로 교체한다.
파라미터 경로만 GitHub 변수에 등록하고 실제 비밀값은 Parameter Store에 보관한다.
Log EC2 역할에는 해당 경로의 `ssm:GetParameter` 권한과 암호화 키 사용 권한이 필요하다.
GitHub 변수나 Parameter Store 값만 변경하면 워크플로가 자동 시작되지는 않으므로, 값을 바꾼 뒤 `log` 브랜치의 배포를 수동 실행한다.

SecureString 값의 형식은 다음과 같다. 관리자 비밀번호는 실제 값으로 등록한다.

```dotenv
GF_SECURITY_ADMIN_PASSWORD=<관리자 비밀번호>
GF_SERVER_ROOT_URL=https://test.oogachaka.co.kr/grafana/
GF_SERVER_SERVE_FROM_SUB_PATH=false
GF_SECURITY_COOKIE_SECURE=true
```

Grafana 관리자 비밀번호 설정은 새 Grafana DB를 초기화할 때 적용된다.
기존 Grafana 사용자의 비밀번호를 변경하려면 Grafana UI 또는 관리 API로 변경해야 한다.
Parameter Store 설정을 서버에 반영하는 것만으로 기존 계정의 비밀번호가 변경되지는 않는다.
로컬 HTTP 테스트에는 위 HTTPS 설정을 사용하지 않고 아래 로컬 테스트 설정을 사용한다.
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
App EC2에서 아래 순서대로 구성 검증과 실행을 진행한다. `deploy.sh`는 설정 검사 후 systemd에 등록해 EC2 중지·시작 후에도 Alloy를 다시 실행한다.
이 단계는 App EC2에서 실행한다. `log` 브랜치 워크플로는 Log EC2만 배포한다.

배포 파일은 다음과 같이 App EC2에서 다운로드할 수 있다. `<log 배포 커밋 SHA>`는 성공한 log 배포 실행의 SHA로 바꾼다.

```bash
alloy_package_dir=$(mktemp -d)
aws s3 cp s3://ooga-chaka-deploy-727660953850/log/<log 배포 커밋 SHA>.tar.gz "$alloy_package_dir/log.tar.gz" --region ap-northeast-2
tar -xzf "$alloy_package_dir/log.tar.gz" -C "$alloy_package_dir"
sudo install -d -m 750 /opt/ooga/alloy
sudo install -m 644 "$alloy_package_dir"/alloy/{compose.yml,config.alloy,deploy.sh} /opt/ooga/alloy/
```

`/opt/ooga/alloy/.env`를 준비하고 아래 스크립트를 실행한다.

```bash
cd /opt/ooga/alloy
sudo bash deploy.sh
sudo docker compose logs --tail 30 alloy
```

Grafana의 **Explore**에서 `{service="oogachaka-app"}`을 조회해 백엔드 로그를 확인한다.

## 브랜치별 설정 관리

- `log`에서는 Redis, Loki, Grafana, Alloy 설정과 배포 스크립트를 관리한다.
- `dev/test`에서는 Web EC2 보안 그룹에서 Log EC2의 TCP 3000 포트로 접근하도록 Terraform을 수정하고 적용한다.
- `nginx`에서는 실제 HTTPS 서버 설정에 `/grafana/` 경로를 추가한다. Nginx가 이 접두사를 제거해서 Grafana로 전달하도록 하고 WebSocket 헤더도 전달한다.

Grafana를 외부 Nginx에서 사용하려면 보안 그룹 적용 후 Log EC2의 `/opt/ooga/log/.env`에 `OOGA_GRAFANA_BIND_IP=0.0.0.0`을 추가한다.
`/etc/ooga/grafana.env` 또는 SecureString에는 위 Grafana HTTPS 설정을 넣고 log 배포를 실행한다.
Web EC2의 `/etc/ooga/env`에 있는 `LOG_PRIVATE_IP`를 Nginx의 목적지 주소로 사용한다.
브라우저에서 `https://test.oogachaka.co.kr/grafana/`로 로그인하고 **Explore**에서 앱 로그를 확인한다.
