# Synology NAS 배포 가이드

Synology NAS에 애플리케이션을 자동 배포하는 워크플로우 사용 가이드입니다.

---

## 개요

SUH-DEVOPS-TEMPLATE은 Synology NAS 배포를 위한 3종의 워크플로우를 제공합니다.

| 워크플로우 | 프로젝트 타입 | 용도 |
|-----------|-------------|------|
| `PROJECT-FLUTTER-ANDROID-SYNOLOGY-CICD` | Flutter | APK 빌드 후 SMB로 NAS 업로드 |
| `PROJECT-SPRING-SYNOLOGY-SIMPLE-CICD` | Spring Boot | Docker 이미지 빌드 및 배포 |
| `PROJECT-SPRING-SYNOLOGY-PR-PREVIEW` | Spring Boot | PR별 Preview 환경 자동 생성 |

> **참고**: Synology 워크플로우는 template_integrator 실행 시 `--synology` 옵션으로 포함할 수 있습니다.

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

---

## template_integrator 연동

### Synology 워크플로우 포함하기

```bash
# Linux/macOS
bash <(curl -fsSL https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh) --synology

# Windows PowerShell
irm https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1 | iex -Synology
```

### 대화형 모드

`--synology` 옵션 없이 실행하면, 해당 프로젝트 타입에 Synology 워크플로우가 있을 경우 질문이 표시됩니다:

```
Synology 워크플로우가 발견되었습니다. (4개 파일)
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
