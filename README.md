# OogaChaka Nginx 배포

이 브랜치는 Web EC2의 Nginx와 HTTPS 설정을 관리합니다.

## 요청 전달

| 경로 | 전달 대상 |
| --- | --- |
| `/healthz` | Nginx 자체 상태 확인 |
| `/grafana` | `/grafana/`로 이동 (쿼리 유지) |
| `/grafana/…` (HTTPS) | Log EC2의 Grafana, 3000 포트 |
| 나머지 경로 | 기존 App EC2의 8080 포트 |

HTTP 요청은 기존 설정대로 HTTPS로 이동합니다. Grafana는 HTTPS 설정에만 연결합니다.
Nginx가 `/grafana/` 접두사를 제거해서 전달하며 Grafana Live의 WebSocket 헤더도 전달합니다.

## 배포 전 준비

1. `dev/test`의 보안 그룹 변경을 적용해 Web EC2에서 Log EC2의 TCP 3000에 접근하도록 허용합니다.
2. `log` 브랜치의 Loki·Grafana 배포를 완료합니다.
3. Log EC2 배포 폴더의 `.env`에 `OOGA_GRAFANA_BIND_IP=0.0.0.0`을 설정하고 재배포합니다.
   포트 접근은 Web 보안 그룹으로 제한해야 합니다.
4. Grafana 실행 설정에 아래 값을 지정하고 재배포합니다.

```dotenv
GF_SERVER_ROOT_URL=https://test.oogachaka.co.kr/grafana/
GF_SERVER_SERVE_FROM_SUB_PATH=false
GF_SECURITY_COOKIE_SECURE=true
```

관리자 비밀번호 등 비밀값은 Parameter Store 또는 서버 설정 파일에서 관리합니다.
`GF_SERVER_SERVE_FROM_SUB_PATH=false`는 Nginx에서 접두사를 제거하는 위 설정과 함께 사용합니다.

Web EC2의 `/etc/ooga/env`에는 아래 항목이 필요합니다.
Terraform의 Web EC2 `env_vars`에서 주소를 관리합니다.

- `APP_PRIVATE_IP`: App EC2 Private IP
- `LOG_PRIVATE_IP`: Log EC2 Private IP
- `DOMAIN`, `CERT_EMAIL`: 기존 HTTPS 인증서 발급 설정

`deploy.sh`는 필수 주소를 확인하고 Nginx 설정 검사를 통과한 뒤 서비스를 재시작합니다.
`nginx` 브랜치 병합 시 기존 GitHub Actions로 Web EC2에 배포합니다.

## 배포 후 확인

맥 터미널에서 실행합니다.

```bash
curl -I https://test.oogachaka.co.kr/grafana
curl -fsS https://test.oogachaka.co.kr/grafana/api/health
curl -fsS https://test.oogachaka.co.kr/health
```

첫 요청은 `/grafana/`로 이동하고 Grafana 상태 응답의 `database`는 `ok`여야 합니다.
브라우저에서 `https://test.oogachaka.co.kr/grafana/`를 열어 로그인 화면과 로그 조회도 확인합니다.
백엔드 `/health` 응답도 확인합니다. Nginx 자체 `/healthz` 성공만으로 Grafana 연결을 판단하지 않습니다.

502가 나오면 Grafana 실행 상태, Log EC2의 바인딩 주소, Web → Log 3000 보안 그룹을 확인합니다.
리다이렉트가 반복되거나 정적 파일이 열리지 않으면 Grafana의 ROOT_URL과 SUB_PATH 설정을 확인합니다.

참고: https://grafana.com/tutorials/run-grafana-behind-a-proxy/
