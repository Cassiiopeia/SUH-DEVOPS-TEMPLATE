# Synology NAS 배포 가이드

Synology NAS에 애플리케이션을 자동 배포하는 워크플로우 사용 가이드입니다.

---

## 개요

SUH-DEVOPS-TEMPLATE은 Synology NAS 배포를 위한 5종의 워크플로우를 제공합니다.

| 워크플로우 | 프로젝트 타입 | 용도 |
|-----------|-------------|------|
| `PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD` | Flutter | APK 빌드 후 SMB로 NAS 업로드 |
| `PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD` | Spring Boot | Docker 이미지 빌드 및 배포 (기본, 단일 컨테이너) |
| `PROJECT-SPRING-SYNOLOGY-NONSTOP-TRAEFIK-CICD` | Spring Boot | 무중단 배포 (Traefik Blue-Green, opt-in) |
| `PROJECT-SPRING-SYNOLOGY-NONSTOP-NGINX-CICD` | Spring Boot | 무중단 배포 (Nginx Blue-Green, opt-in) |
| `PROJECT-SPRING-SYNOLOGY-PR-PREVIEW` | Spring Boot | PR별 Preview 환경 자동 생성 |

> **참고**: Synology 워크플로우는 template_integrator 실행 시 `--synology` 옵션으로 포함할 수 있습니다.
> **무중단 배포 옵션**은 기본 `SIMPLE-CICD` 와 함께 배포되며, 사용자가 명시적으로 전환할 때만 활성화됩니다 (트리거 주석 처리 상태).

---

## 멀티 프로젝트 타입 배포 시

단일 레포에 여러 타입(예: Spring 백엔드 + Python AI)이 공존해 여러 SYNOLOGY-CICD 워크플로우가 함께 설치된 경우, 같은 NAS에 배포하므로 리소스 충돌을 막기 위해 각 워크플로우의 env를 **서로 다른 값**으로 설정해야 합니다.

- 각 워크플로우의 `PROJECT_NAME`, `CONTAINER_NAME`, `DEPLOY_PORT`(또는 `PROJECT_DEPLOY_PORT`)를 타입별로 분리합니다.
- 동일 NAS에 같은 포트로 두 컨테이너를 배포할 수 없습니다 (`port is already allocated`).
- 예: Spring 백엔드 `8096`, Python AI `8092` 등으로 포트를 분리한 뒤 사용합니다.

| 항목 | Spring 백엔드 | Python AI |
|------|--------------|-----------|
| `PROJECT_NAME` | `myapp-back` | `myapp-ai` |
| `DEPLOY_PORT` | `8096` | `8092` |

> CI 워크플로우(`*-CI.yaml`)가 멀티타입에서 동시에 발화하는 문제는 [TEMPLATE-INTEGRATOR.md](TEMPLATE-INTEGRATOR.md#멀티-프로젝트-타입)의 CI 트리거 주의를 참고하세요.

---

## 사전 준비

### 1. Synology NAS 설정

#### Docker 패키지 설치 (Spring Boot 배포용)
1. DSM > 패키지 센터 > Docker 설치
2. Docker 컨테이너 관리 권한 확인

#### SSH 활성화
1. DSM > 제어판 > 터미널 및 SNMP > SSH 서비스 활성화
2. 포트: 기본 22 또는 커스텀 (워크플로우 기본값: 2022)
3. 관리자 계정 SSH 접속 허용

#### SMB 공유 폴더 설정 (Flutter APK 업로드용)
1. DSM > 제어판 > 공유 폴더 > 새 공유 폴더 생성
2. SMB 서비스 활성화 (제어판 > 파일 서비스 > SMB)
3. 포트: 기본 445 또는 커스텀 (예: 44445)

### 2. GitHub Secrets 공통 설정

모든 Synology 워크플로우에서 공통으로 사용하는 Secrets:

| Secret | 설명 | 예시 |
|--------|------|------|
| `SERVER_HOST` | Synology NAS IP 또는 도메인 | `192.168.1.100` 또는 `nas.example.com` |
| `SERVER_USER` | SSH/SMB 접속 사용자명 | `admin` |
| `SERVER_PASSWORD` | SSH/SMB 접속 비밀번호 | `{PASSWORD}` |

---

## Flutter Android 배포 (SMB)

### 워크플로우

**파일**: `PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD.yaml`

**트리거**:
- `deploy` 브랜치 푸시
- CHANGELOG 워크플로우 완료 후 자동 실행
- 수동 실행 (workflow_dispatch)

### 필수 GitHub Secrets

| Secret | 설명 |
|--------|------|
| `SERVER_HOST` | Synology NAS 호스트 |
| `SERVER_USER` | SMB 접속 사용자명 |
| `SERVER_PASSWORD` | SMB 접속 비밀번호 |
| `DEBUG_KEYSTORE` | Android Debug Keystore (Base64 인코딩) |
| `ENV_FILE` | Flutter .env 파일 내용 |
| `GOOGLE_SERVICES_JSON` | Firebase google-services.json 내용 |

### 환경변수 설정 (워크플로우 파일 내 수정)

```yaml
env:
  PROJECT_NAME: "your-project"      # 프로젝트명 (APK 파일명에 사용)
  FLUTTER_VERSION: "3.35.5"         # Flutter 버전
  JAVA_VERSION: "17"                # Java 버전
  SMB_PORT: "44445"                 # SMB 포트 (기본 445)
  SMB_SHARE: "web"                  # SMB 공유 폴더명
  SMB_PATH_ANDROID: "/android/download"  # APK 저장 경로
```

### 배포 프로세스

```
1. Flutter APK 빌드 (Fastlane)
2. APK 파일명 변경: {PROJECT_NAME}-v{VERSION}-{COMMIT_HASH}.apk
3. SMB로 Synology NAS에 업로드
4. 빌드 히스토리 JSON 업데이트
```

### 배포 결과

APK 파일 경로: `//{SERVER_HOST}/{SMB_SHARE}/{PROJECT_NAME}/android/download/`

히스토리 파일: `{PROJECT_NAME}-android-cicd-history.json`

---

## Spring Boot 단순 배포 (Docker)

### 워크플로우

**파일**: `PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD.yaml`

**트리거**:
- `deploy` 브랜치 푸시 (운영 환경)
- `test` 브랜치 푸시 (테스트 환경)
- 수동 실행 (workflow_dispatch)

### 필수 GitHub Secrets

| Secret | 설명 |
|--------|------|
| `APPLICATION_PROD_YML` | Spring Boot 운영 설정 파일 내용 |
| `DOCKERHUB_USERNAME` | DockerHub 사용자명 |
| `DOCKERHUB_TOKEN` | DockerHub 액세스 토큰 |
| `SERVER_HOST` | Synology NAS 호스트 |
| `SERVER_USER` | SSH 접속 사용자명 |
| `SERVER_PASSWORD` | SSH 접속 비밀번호 |

### 선택적 Secrets (포트 커스터마이징)

| Secret | 기본값 | 설명 |
|--------|-------|------|
| `PROJECT_DEPLOY_PORT` | 8080 | deploy 브랜치 배포 포트 |
| `PROJECT_TEST_PORT` | 8081 | test 브랜치 배포 포트 |

### 환경변수 설정 (워크플로우 파일 내 수정)

```yaml
env:
  PROJECT_NAME: "project"           # 프로젝트명
  DOCKER_IMAGE_PREFIX: "back-container"
  SPRING_PROFILE: "prod"
  JAVA_VERSION: "17"
```

### 브랜치별 배포

| 브랜치 | 포트 | 컨테이너명 |
|--------|-----|-----------|
| deploy | 8080 (기본) | `{PROJECT_NAME}-back-deploy` |
| test | 8081 (기본) | `{PROJECT_NAME}-back-test` |

### 배포 프로세스

```
1. Gradle 빌드 (테스트 제외)
2. Docker 이미지 빌드 및 DockerHub 푸시
3. SSH로 Synology NAS 접속
4. Docker 이미지 Pull
5. 기존 컨테이너 제거 후 새 컨테이너 실행
```

---

## Spring Boot 무중단 배포 (Traefik Blue-Green)

> 기본 `SIMPLE-CICD` 와 동일한 Secrets 를 사용하며, Traefik 라벨 기반 Blue-Green 토글로 다운타임 없는 배포를 제공합니다.

### 워크플로우

**파일**: `PROJECT-SPRING-SYNOLOGY-NONSTOP-TRAEFIK-CICD.yaml`

**트리거** (기본 비활성):
- `workflow_dispatch` (수동 실행)
- `# push: deploy` 주석 처리됨 — 전환 시 주석 해제 + `SIMPLE-CICD` 의 push 트리거 주석 처리

### 사전 요구사항

#### 1. Traefik 리버스 프록시 설치

```bash
docker network create traefik-network

docker run -d \
  --name traefik \
  --network traefik-network \
  -p 80:80 -p 8079:8079 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  traefik:v2.10 \
  --providers.docker=true \
  --entrypoints.web.address=:8079
```

#### 2. DSM 역방향 프록시 매핑

```
${PRODUCTION_DOMAIN}:443 → localhost:${TRAEFIK_INTERNAL_PORT}  (기본 8079)
```

### 필수 GitHub Secrets

`SIMPLE-CICD` 와 동일.

| Secret | 설명 |
|--------|------|
| `APPLICATION_PROD_YML` | application-prod.yml 내용 |
| `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` | DockerHub 인증 |
| `SERVER_HOST` / `SERVER_USER` / `SERVER_PASSWORD` | SSH 접속 |

### 주요 env 설정

```yaml
env:
  PROJECT_NAME: "mapsy-back"
  PRODUCTION_DOMAIN: "example.com"
  TRAEFIK_NETWORK: "traefik-network"
  TRAEFIK_ENTRYPOINT: "web"
  TRAEFIK_INTERNAL_PORT: "8079"
  EXTRA_NETWORKS: ""                 # 예: "selenium-chrome-network"
  HEALTHCHECK_PATH: "/"
  HEALTHCHECK_ACCEPT_CODES: "200|301|302|308"
  HEALTHCHECK_MAX_RETRIES: "36"
  HEALTHCHECK_RETRY_INTERVAL: "5"
  IN_FLIGHT_WAIT: "10"
```

### 배포 프로세스

```
1. Gradle 빌드 + Docker 이미지 빌드 & DockerHub Push
2. SSH 로 Synology 접속 → Traefik 라벨 부착 컨테이너 검색 → active 색 판별
3. 반대 색(blue/green) 으로 신규 컨테이너 기동 (Traefik 라벨 자동 등록)
4. EXTRA_NETWORKS 가 있으면 추가 docker network connect
5. Traefik 통한 GET 호출로 헬스체크 (HEALTHCHECK_ACCEPT_CODES 매칭 시 통과)
   실패 시 신규 컨테이너 유지 + old 그대로 → 사실상 자동 롤백
6. IN_FLIGHT_WAIT 초 후 old 컨테이너 제거 + dangling 이미지 정리
```

### 리소스 네이밍

| 항목 | 형식 |
|------|------|
| 컨테이너 | `{PROJECT_NAME}-blue` / `{PROJECT_NAME}-green` |
| 이미지 | `{DOCKERHUB_USERNAME}/{PROJECT_NAME}:{ref_name}` |
| Traefik router/service | `{PROJECT_NAME}` |

---

## Spring Boot 무중단 배포 (Nginx Blue-Green)

> 기본 `SIMPLE-CICD` 와 동일한 Secrets 를 사용하며, nginx config 의 `proxy_pass` 포트 토글로 Blue-Green 무중단 배포를 제공합니다. Traefik 미설치 환경에서 사용합니다.

### 워크플로우

**파일**: `PROJECT-SPRING-SYNOLOGY-NONSTOP-NGINX-CICD.yaml`

**트리거** (기본 비활성):
- `workflow_dispatch` (수동 실행)
- `# push: deploy` 주석 처리됨 — 전환 시 주석 해제 + `SIMPLE-CICD` 의 push 트리거 주석 처리

### 사전 요구사항

#### 1. nginx 설치 + sites-enabled config 존재

config 의 server 블록에 다음 라인이 존재해야 합니다:

```nginx
server {
    listen 443 ssl;
    server_name example.com;

    location / {
        proxy_pass http://127.0.0.1:8080;   # BLUE_PORT (또는 GREEN_PORT)
        # ...
    }
}
```

#### 2. SSH 사용자 권한

- `sudo nginx -t`, `sudo systemctl reload nginx`, `sudo docker ...` 실행 가능
- nginx config 파일 및 백업 디렉토리 쓰기 권한

### 필수 GitHub Secrets

`SIMPLE-CICD` 와 동일.

### 주요 env 설정

```yaml
env:
  PROJECT_NAME: "mapsy-back"
  DOMAIN_NAME: "example.com"                                  # nginx server_name 과 일치
  BLUE_PORT: "8080"
  GREEN_PORT: "8081"
  NGINX_RP_CONF: "/etc/nginx/sites-enabled/example.conf"
  NGINX_BACKUP_DIR: "/volume1/project/nginx/backups"
  NGINX_BACKUP_KEEP: "10"
  HEALTHCHECK_PATH: "/actuator/health"
  HEALTHCHECK_MAX_RETRIES: "120"
  HEALTHCHECK_RETRY_INTERVAL: "1"
  DOMAIN_CHECK_RETRIES: "10"
  DOMAIN_CHECK_INTERVAL: "2"
  IN_FLIGHT_WAIT: "5"
```

### 배포 프로세스

```
1. Gradle 빌드 + Docker 이미지 빌드 & DockerHub Push
2. SSH 접속 → nginx config 파일 백업 (NGINX_BACKUP_DIR)
3. nginx config 의 proxy_pass 포트 awk 파싱 → 현재 active 포트 판별
4. 비활성 포트로 신규 컨테이너 기동
5. 컨테이너 헬스체크 (HEALTHCHECK_PATH HTTP 호출)
6. nginx config 의 proxy_pass 포트를 신규 포트로 awk 토글
7. `nginx -t` 검증 후 reload (실패 시 백업 복구 + 신규 컨테이너 제거 → 자동 롤백)
8. 도메인 접근 검증 (DOMAIN_CHECK_RETRIES 회 https://${DOMAIN_NAME} 호출)
9. IN_FLIGHT_WAIT 초 후 old 컨테이너 제거 + dangling 이미지 정리
10. nginx 백업 파일 최신 NGINX_BACKUP_KEEP 개 보존
```

### 리소스 네이밍

| 항목 | 형식 |
|------|------|
| 컨테이너 | `{PROJECT_NAME}-blue` / `{PROJECT_NAME}-green` |
| 이미지 | `{DOCKERHUB_USERNAME}/{PROJECT_NAME}:{ref_name}` |
| nginx 백업 파일 | `${NGINX_BACKUP_DIR}/server.ReverseProxy.conf.{TIMESTAMP}.bak` |

### 자동 롤백 시나리오

| 실패 단계 | 동작 |
|----------|------|
| 컨테이너 헬스체크 실패 | 신규 컨테이너 제거 — old 그대로 유지 |
| `nginx -t` 검증 실패 | 백업 파일로 nginx config 복구 + 신규 컨테이너 제거 |
| `systemctl reload/restart nginx` 실패 | 백업 복구 후 restart 재시도, 실패 시 신규 컨테이너 제거 |
| 도메인 접근 검증 실패 | 경고만 — 배포는 진행 (DNS 전파 지연 가능성) |

---

## Spring Boot PR Preview (Traefik)

### 워크플로우

**파일**: `PROJECT-SPRING-SYNOLOGY-PR-PREVIEW.yaml`

**트리거**:
- PR 코멘트에 `@suh-lab pr build/destroy/status` 입력
- PR 종료 시 자동 삭제

### 사전 요구사항

#### 1. Traefik 리버스 프록시 설치

```bash
# Docker 네트워크 생성
docker network create traefik-network

# Traefik 컨테이너 실행
docker run -d \
  --name traefik \
  --network traefik-network \
  -p 80:80 -p 8079:8079 -p 8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  traefik:v2.10 \
  --api.dashboard=true \
  --providers.docker=true \
  --entrypoints.web.address=:8079
```

#### 2. 와일드카드 DNS 설정

```
*.pr.suhsaechan.kr → Synology NAS IP
```

### 필수 GitHub Secrets

| Secret | 설명 |
|--------|------|
| `APPLICATION_PROD_YML` | Spring Boot 운영 설정 파일 |
| `DOCKERHUB_USERNAME` | DockerHub 사용자명 |
| `DOCKERHUB_TOKEN` | DockerHub 액세스 토큰 |
| `SERVER_HOST` | Synology NAS 호스트 |
| `SERVER_USER` | SSH 접속 사용자명 |
| `SERVER_PASSWORD` | SSH 접속 비밀번호 |

### 환경변수 설정 (워크플로우 파일 내 수정)

```yaml
env:
  PROJECT_NAME: "suh-project-utility"
  JAVA_VERSION: '17'
  GRADLE_BUILD_CMD: './gradlew clean build -x test -Dspring.profiles.active=prod'
  JAR_PATH: 'Suh-Web/build/libs/*.jar'
  APPLICATION_YML_PATH: 'Suh-Web/src/main/resources/application-prod.yml'
  DOCKERFILE_PATH: './Dockerfile'
  INTERNAL_PORT: '8080'
  TRAEFIK_NETWORK: 'traefik-network'
  PREVIEW_DOMAIN_SUFFIX: 'pr.suhsaechan.kr'
  PREVIEW_PORT: '8079'
```

### 사용법

PR 코멘트에 다음 명령어 입력:

| 명령어 | 설명 |
|--------|------|
| `@suh-lab pr build` | PR Preview 빌드 및 배포 |
| `@suh-lab pr destroy` | Preview 환경 삭제 |
| `@suh-lab pr status` | 현재 상태 확인 |

### 리소스 네이밍 규칙

| 항목 | 형식 | 예시 |
|------|------|------|
| 컨테이너명 | `{PROJECT_NAME}-pr-{PR번호}` | `suh-project-utility-pr-123` |
| 이미지 태그 | `{DOCKERHUB_USERNAME}/{PROJECT_NAME}:pr-{PR번호}` | `user/suh-project-utility:pr-123` |
| Preview URL | `http://{PROJECT_NAME}-pr-{PR번호}.{DOMAIN}:{PORT}` | `http://suh-project-utility-pr-123.pr.suhsaechan.kr:8079` |

### 진행 상황 알림

빌드 중 PR에 실시간 댓글 업데이트:
- 프로젝트 빌드 상태
- Docker 이미지 생성 상태
- 서버 배포 및 Health Check 상태
- 소요 시간 표시

---

## 트러블슈팅

### 공통 문제

#### SSH 연결 실패
```
Error: ssh: connect to host xxx port 2022: Connection refused
```
**해결**:
1. Synology DSM > 제어판 > 터미널 및 SNMP > SSH 서비스 활성화 확인
2. 포트 번호 확인 (워크플로우 기본값: 2022)
3. 방화벽에서 SSH 포트 허용

#### Docker 권한 문제
```
Error: permission denied while trying to connect to Docker daemon
```
**해결**:
1. SSH 사용자가 docker 그룹에 포함되어 있는지 확인
2. 워크플로우에서 `sudo` 사용 확인

#### 포트 충돌
```
Error: port is already allocated
```
**해결**:
1. 해당 포트를 사용 중인 컨테이너 확인: `docker ps`
2. 포트 변경 또는 기존 컨테이너 중지

### Flutter 특화

#### SMB 연결 실패
```
Error: session setup failed: NT_STATUS_LOGON_FAILURE
```
**해결**:
1. SMB 사용자명/비밀번호 확인
2. SMB 서비스 활성화 확인 (DSM > 제어판 > 파일 서비스 > SMB)
3. 공유 폴더 접근 권한 확인

#### SMB 경로 오류
```
Error: tree connect failed: NT_STATUS_BAD_NETWORK_NAME
```
**해결**:
1. `SMB_SHARE` 환경변수가 공유 폴더명과 일치하는지 확인
2. `SMB_PATH` 경로가 존재하는지 확인

### Spring Boot 특화

#### 헬스체크 실패
```
Error: Health check timeout after 60 seconds
```
**해결**:
1. 애플리케이션 기동 시간 확인 (60초 이상 필요 시 MAX_RETRIES 증가)
2. 헬스체크 엔드포인트 확인 (`/actuator/health` 또는 `/`)
3. 컨테이너 로그 확인: `docker logs {container_name}`

#### Traefik 라우팅 실패 (PR Preview)
```
Error: 404 page not found
```
**해결**:
1. Traefik 컨테이너 실행 중인지 확인
2. Docker 네트워크 연결 확인: `docker network inspect traefik-network`
3. Traefik 대시보드에서 라우터/서비스 상태 확인

### 무중단 배포 특화

#### Traefik Blue-Green: 새 컨테이너 헬스체크 일시적 404
- Traefik 라우터 재등록 race condition. 헬스체크 재시도(`HEALTHCHECK_MAX_RETRIES`)가 충분히 크면 다음 시도에서 통과합니다.
- 워크플로우 로그의 `🔍 Traefik 라벨 확인:` 출력에서 `Host(\`${PRODUCTION_DOMAIN}\`)` 라벨이 정상 escape 되었는지 확인.

#### Nginx Blue-Green: 활성 포트 탐지 실패
```
⚠️ 활성 포트를 찾지 못함 → 기본값(BLUE=8080)을 활성으로 간주
```
**해결**:
1. `NGINX_RP_CONF` 경로가 정확한지 확인
2. config 의 `server_name` 라인이 `${DOMAIN_NAME}` 과 정확히 일치하는지 확인
3. config 의 `proxy_pass http://127.0.0.1:{PORT};` 형식 유지 (포트 번호 2~5자리)

#### Nginx Blue-Green: `nginx -t` 실패 → 백업 복구
- 워크플로우가 자동으로 백업 파일로 복구하고 신규 컨테이너를 제거합니다.
- 백업 파일은 `${NGINX_BACKUP_DIR}/server.ReverseProxy.conf.{TIMESTAMP}.bak` 에 보존됩니다.

---

## template_integrator 연동

### Synology 워크플로우 포함하기

```bash
# Linux/macOS
bash <(curl -fsSL https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh) --synology

# Windows PowerShell
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;& ([scriptblock]::Create($wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1"))) -Synology
```

### 대화형 모드

`--synology` 옵션 없이 실행하면, 해당 프로젝트 타입에 Synology 워크플로우가 있을 경우 질문이 표시됩니다:

```
Synology 워크플로우가 발견되었습니다. (10개 파일)
Synology NAS에 배포하는 워크플로우를 포함하시겠습니까? (y/N)
```

### 설정 저장

선택한 Synology 옵션은 `version.yml`에 저장됩니다:

```yaml
metadata:
  template:
    options:
      synology: true  # 또는 false
```

재통합 시 이전 설정이 자동으로 감지되어 적용됩니다.

---

## 관련 문서

- [TEMPLATE-INTEGRATOR.md](TEMPLATE-INTEGRATOR.md) - 템플릿 통합 스크립트 가이드
- [FLUTTER-CICD-OVERVIEW.md](FLUTTER-CICD-OVERVIEW.md) - Flutter CI/CD 전체 가이드
