# 구현 보고서: Spring PR-Preview 워크플로우 업그레이드

**이슈**: [#145](https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/145)
**작업일**: 2026-01-12
**작업자**: Claude Code

---

## 📌 작업 개요

Spring PR-Preview 워크플로우를 Python 버전과 동일하게 **Issue와 PR 모두 지원**하도록 업그레이드. Health Check 개선 및 다양한 기능 추가.

---

## 🎯 구현 목표

| 목표 | 설명 |
|------|------|
| Issue 지원 | PR뿐만 아니라 Issue 댓글에서도 Preview 빌드 가능 |
| Issue 닫힘 시 자동 삭제 | Issue가 닫히면 Preview 컨테이너 자동 정리 |
| 브랜치 자동 추출 | Issue Helper 댓글에서 브랜치명 자동 파싱 |
| Health Check 개선 | HTTP + 로그 패턴 하이브리드 방식 |
| API Docs 링크 | 배포 완료 코멘트에 API 문서 링크 표시 |
| 볼륨 마운트 | 프로젝트별 데이터 디렉토리 마운트 지원 |
| 명령어 통일 | `@suh-lab pr` → `@suh-lab server`로 변경 |

---

## ✅ 구현 내용

### 1. 트리거 확장

**파일**: `PROJECT-SPRING-SYNOLOGY-PR-PREVIEW.yaml`

**변경 전**:
```yaml
on:
  issue_comment:
    types: [created]
  pull_request:
    types: [closed]
```

**변경 후**:
```yaml
on:
  issue_comment:
    types: [created]      # PR 댓글 + Issue 댓글
  issues:
    types: [closed]       # Issue 닫힘 시 자동 삭제
  pull_request:
    types: [closed]       # PR 닫힘 시 자동 삭제
```

### 2. 새로운 환경변수 추가

| 환경변수 | 용도 | 기본값 |
|----------|------|--------|
| `ISSUE_HELPER_MARKER` | Issue Helper 댓글 마커 | `Guide by SUH-LAB` |
| `HEALTH_CHECK_PATH` | HTTP Health Check 경로 | `/actuator/health` |
| `HEALTH_CHECK_LOG_PATTERN` | 로그 패턴 매칭 | `Started .* in [0-9.]+ seconds` |
| `API_DOCS_PATH` | API 문서 경로 | `/docs/swagger` |
| `PROJECT_TARGET_DIR` | 서버 데이터 디렉토리 | (빈값) |
| `PROJECT_MNT_DIR` | 컨테이너 마운트 경로 | (빈값) |

### 3. 새로운 Job 구조

| Job | 역할 |
|-----|------|
| `check-command` | 명령어 파싱 + PR/Issue 구분 |
| `build-preview-pr` | PR 댓글에서 빌드 (기존 로직) |
| `get-branch-from-issue` | Issue Helper 댓글에서 브랜치 추출 |
| `build-preview-issue` | Issue 댓글에서 빌드 (새로 추가) |
| `destroy-preview` | PR/Issue 닫힘 + destroy 명령 처리 |
| `check-status` | 상태 확인 |

### 4. Issue에서 브랜치 자동 추출

Issue Helper가 생성한 댓글에서 브랜치명을 자동으로 파싱:

```markdown
## Guide by SUH-LAB
### 브랜치
```
20260111_#145_이슈와_PR_모두_지원하는_PR_Preview_로_업그레이드_필요
```
```

정규식으로 마커를 찾고 브랜치명을 추출하여 빌드 진행.

### 5. Health Check 하이브리드 방식

1. **HTTP 체크 우선**: `HEALTH_CHECK_PATH`로 HTTP 요청
2. **로그 패턴 폴백**: HTTP 실패 시 `HEALTH_CHECK_LOG_PATTERN`으로 로그 매칭

```bash
# 1. HTTP Health Check
HEALTH=$(docker exec $CONTAINER wget -qO- "http://localhost:8080/actuator/health")
if echo "$HEALTH" | grep -q '"status":"UP"'; then
  # 성공
fi

# 2. 로그 패턴 폴백
STARTED=$(docker logs $CONTAINER | grep -E "Started .* in [0-9.]+ seconds")
if [ -n "$STARTED" ]; then
  # 성공
fi
```

### 6. 배포 완료 코멘트 개선

**Before**:
```
| **Preview URL** | http://xxx-pr-123.pr.suhsaechan.kr:8079 |
| **컨테이너** | `xxx-pr-123` |
| **브랜치** | `feature/xxx` |
```

**After**:
```
| **Preview URL** | http://xxx-pr-123.pr.suhsaechan.kr:8079 |
| **API Docs** | http://xxx-pr-123.pr.suhsaechan.kr:8079/docs/swagger |
| **컨테이너** | `xxx-pr-123` |
| **브랜치** | `feature/xxx` |
| **커밋** | `abc1234` |
```

### 7. 명령어 키워드 통일

| Before | After |
|--------|-------|
| `@suh-lab pr build` | `@suh-lab server build` |
| `@suh-lab pr destroy` | `@suh-lab server destroy` |
| `@suh-lab pr status` | `@suh-lab server status` |

Python 버전과 동일한 명령어로 통일.

---

## 🔧 수정된 파일

| 파일 | 변경 내용 |
|------|----------|
| `.github/workflows/project-types/spring/synology/PROJECT-SPRING-SYNOLOGY-PR-PREVIEW.yaml` | Issue 지원, Health Check 개선, 볼륨 마운트, API Docs 링크 추가 |
| `.github/workflows/project-types/python/synology/PROJECT-PYTHON-SYNOLOGY-PR-PREVIEW.yaml` | Issue 배포 코멘트에 커밋 SHA 추가 (일관성) |

---

## 📊 변경사항 요약

### Spring PR-Preview (주요 변경)

- **+** `issues: [closed]` 트리거 추가
- **+** `get-branch-from-issue` Job 추가
- **+** `build-preview-issue` Job 추가
- **+** 6개 새 환경변수 추가
- **~** `check-command` Job에 `is_pr` 출력 추가
- **~** `destroy-preview` Job에 Issue 닫힘 처리 추가
- **~** Health Check 하이브리드 방식으로 개선
- **~** 명령어 `@suh-lab pr` → `@suh-lab server` 변경

### Python PR-Preview (마이너 변경)

- **+** Issue 배포 코멘트에 커밋 SHA 표시 추가

---

## 🧪 테스트 및 검증

### Issue에서 빌드 테스트
1. Issue 생성
2. Issue Helper 댓글 확인 (브랜치명 포함)
3. `@suh-lab server build` 댓글 작성
4. 빌드 및 배포 확인
5. 배포 코멘트에 브랜치, 커밋 SHA 표시 확인

### PR에서 빌드 테스트
1. PR 생성
2. `@suh-lab server build` 댓글 작성
3. 기존과 동일하게 동작 확인

### 자동 삭제 테스트
1. Issue 닫기 → 컨테이너 자동 삭제 확인
2. PR 닫기 → 컨테이너 자동 삭제 확인

### Health Check 테스트
1. Actuator 있는 프로젝트: HTTP 체크 확인
2. Actuator 없는 프로젝트: 로그 패턴 폴백 확인

---

## 📌 참고사항

### 하위 호환성
- 기존 PR 빌드 로직은 그대로 유지
- 새 명령어 `@suh-lab server`만 추가 (기존 `@suh-lab pr`은 더 이상 동작 안 함)

### 프로젝트별 설정
`[영역 1]` 환경변수 섹션에서 프로젝트에 맞게 설정 필요:
- `API_DOCS_PATH`: Swagger UI 경로 (없으면 빈값)
- `PROJECT_TARGET_DIR`, `PROJECT_MNT_DIR`: 볼륨 마운트 (없으면 빈값)

---

**보고서 파일**: `.report/20260112_#145_Spring_PR_Preview_Issue_지원_업그레이드.md`
