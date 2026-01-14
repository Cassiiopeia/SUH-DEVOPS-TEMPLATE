# PR Preview 시스템

Issue나 PR에서 댓글 한 줄로 임시 서버를 배포하고, 닫으면 자동으로 정리됩니다.

---

## 개요

PR Preview는 개발 중인 코드를 실제 서버 환경에서 테스트할 수 있게 해주는 시스템입니다.

| 기능 | 설명 |
|------|------|
| **Issue/PR 지원** | Issue 또는 PR 댓글에서 모두 사용 가능 |
| **자동 정리** | Issue/PR 닫힘 시 컨테이너 자동 삭제 |
| **Traefik 연동** | 자동 SSL 및 도메인 라우팅 |
| **Health Check** | HTTP + 로그 패턴 하이브리드 방식 |

---

## 지원 프로젝트

| 타입 | 워크플로우 |
|------|-----------|
| **Spring** | `PROJECT-SPRING-SYNOLOGY-PR-PREVIEW.yaml` |
| **Python** | `PROJECT-PYTHON-SYNOLOGY-PR-PREVIEW.yaml` |

> 두 워크플로우는 동일한 명령어와 기능을 제공합니다.

---

## 사용법

### 명령어

Issue나 PR에 댓글로 다음 명령어를 입력합니다.

| 명령어 | 기능 |
|--------|------|
| `@suh-lab server build` | Preview 서버 빌드 및 배포 |
| `@suh-lab server destroy` | Preview 서버 삭제 |
| `@suh-lab server status` | 현재 상태 확인 |

### 사용 시나리오

#### PR에서 사용
```
1. PR 생성
2. 댓글: @suh-lab server build
3. → 빌드 및 배포 진행
4. → Preview URL 댓글로 안내
5. PR 닫힘 시 자동 삭제
```

#### Issue에서 사용
```
1. Issue 생성
2. Issue Helper가 브랜치명 자동 제안 (댓글)
3. 해당 브랜치로 코드 푸시
4. 댓글: @suh-lab server build
5. → 브랜치 자동 감지 후 빌드
6. Issue 닫힘 시 자동 삭제
```

---

## 배포 결과

배포 완료 시 다음과 같은 댓글이 자동으로 작성됩니다.

```markdown
### Preview 환경
| 항목 | 값 |
|------|-----|
| **Preview URL** | http://project-pr-123.pr.domain.com:8079 |
| **API Docs** | http://project-pr-123.pr.domain.com:8079/docs/swagger |
| **컨테이너** | `project-pr-123` |
| **브랜치** | `feature/new-feature` |
| **커밋** | `abc1234` |
```

---

## 환경변수 설정

워크플로우 파일의 `[영역 1]` 섹션에서 프로젝트에 맞게 설정합니다.

### 필수 설정

```yaml
env:
  PROJECT_NAME: my-project           # 프로젝트 이름
  INTERNAL_PORT: '8080'              # 컨테이너 내부 포트
  EXTERNAL_PORT: '8079'              # 외부 노출 포트
  SUH_LAB_BASE_DOMAIN: 'domain.com'  # 베이스 도메인
```

### 선택 설정

```yaml
env:
  # Health Check
  HEALTH_CHECK_PATH: '/actuator/health'              # HTTP 체크 경로 (빈값: 스킵)
  HEALTH_CHECK_LOG_PATTERN: 'Started .* in [0-9.]+ seconds'  # 로그 패턴

  # API 문서
  API_DOCS_PATH: '/docs/swagger'                     # Swagger 경로 (빈값: 미표시)

  # 볼륨 마운트
  PROJECT_TARGET_DIR: '/volume1/data'                # 호스트 디렉토리
  PROJECT_MNT_DIR: '/mnt/data'                       # 컨테이너 마운트 경로

  # Issue Helper
  ISSUE_HELPER_MARKER: 'Guide by SUH-LAB'            # 브랜치 추출 마커
```

---

## Health Check

서버 시작 완료를 확인하는 두 가지 방식을 지원합니다.

### 1. HTTP Health Check (우선)

`HEALTH_CHECK_PATH`가 설정되면 HTTP 요청으로 확인합니다.

```bash
# Spring Actuator 예시
GET http://localhost:8080/actuator/health
→ {"status":"UP"} 확인
```

### 2. 로그 패턴 (폴백)

HTTP 실패 시 컨테이너 로그에서 패턴을 검색합니다.

```yaml
# Spring 기본 패턴
HEALTH_CHECK_LOG_PATTERN: 'Started .* in [0-9.]+ seconds'

# Python/FastAPI 패턴
HEALTH_CHECK_LOG_PATTERN: 'Uvicorn running on'
```

### 타임아웃

- 기본: 120초
- 5초 간격으로 체크
- 실패 시 로그 출력 및 알림

---

## 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                    GitHub Actions                        │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   │
│  │ check-cmd   │──▶│ build-pr    │   │ build-issue │   │
│  │             │   │ (PR 댓글)    │   │ (Issue 댓글) │   │
│  └─────────────┘   └─────────────┘   └─────────────┘   │
│         │                                               │
│         ▼                                               │
│  ┌─────────────┐   ┌─────────────┐                     │
│  │destroy-prev │   │ check-status│                     │
│  └─────────────┘   └─────────────┘                     │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                   Synology NAS                          │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   │
│  │   Docker    │◀──│   Traefik   │──▶│  Container  │   │
│  │  Registry   │   │  (Router)   │   │  project-   │   │
│  └─────────────┘   └─────────────┘   │  pr-123     │   │
│                                       └─────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## 트러블슈팅

### 빌드 실패

**증상**: `@suh-lab server build` 후 에러 발생

**확인 사항**:
1. GitHub Actions 로그 확인
2. Dockerfile 경로 확인 (`./Dockerfile` 기본)
3. Secrets 설정 확인 (SYNOLOGY_HOST, DOCKER_* 등)

### Health Check 실패

**증상**: 배포 완료되었으나 "Health check failed" 에러

**해결**:
1. `HEALTH_CHECK_PATH` 경로가 올바른지 확인
2. Spring: Actuator 의존성 추가 여부 확인
3. `HEALTH_CHECK_LOG_PATTERN`으로 폴백 설정

### Issue에서 브랜치 못 찾음

**증상**: "브랜치를 찾을 수 없습니다" 에러

**확인 사항**:
1. Issue Helper 댓글이 있는지 확인
2. 해당 브랜치가 실제로 푸시되었는지 확인
3. `ISSUE_HELPER_MARKER` 값이 올바른지 확인

### 컨테이너 삭제 안됨

**증상**: Issue/PR 닫아도 컨테이너 남아있음

**해결**:
```bash
# 수동 삭제 (Synology SSH)
docker stop project-pr-123
docker rm project-pr-123
docker rmi registry/project-pr-123:latest
```

---

## 필수 Secrets

| Secret | 설명 |
|--------|------|
| `SYNOLOGY_HOST` | Synology NAS 주소 |
| `SYNOLOGY_USERNAME` | SSH 사용자명 |
| `SYNOLOGY_PASSWORD` | SSH 비밀번호 |
| `DOCKER_REGISTRY_URL` | Docker Registry URL |
| `DOCKER_USERNAME` | Registry 사용자명 |
| `DOCKER_PASSWORD` | Registry 비밀번호 |

---

## 관련 문서

- [Synology 배포 가이드](SYNOLOGY-DEPLOYMENT-GUIDE.md)
- [트러블슈팅](TROUBLESHOOTING.md)
