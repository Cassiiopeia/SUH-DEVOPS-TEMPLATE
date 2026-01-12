# 체인지로그 자동화

deploy 브랜치로 PR이 생성되면 CodeRabbit AI 리뷰를 기반으로 체인지로그가 자동 생성됩니다.

---

## 개요

| 기능 | 설명 |
|------|------|
| **AI 분석** | CodeRabbit이 변경사항 자동 분석 |
| **카테고리 분류** | Features, Bug Fixes 등 자동 분류 |
| **이중 형식** | JSON (데이터) + Markdown (가독성) |
| **PR 제목 자동화** | `Deploy YYYYMMDD-vX.X.X` 형식으로 변경 |

---

## 자동화 흐름

```
main 푸시
    │
    ▼
버전 증가 (VERSION-CONTROL)
    │
    ▼
deploy PR 자동 생성
    │
    ▼
CodeRabbit AI 리뷰
    │
    ▼
CHANGELOG-CONTROL 워크플로우
    │
    ├─ Summary 파싱
    ├─ CHANGELOG.json 업데이트
    ├─ CHANGELOG.md 생성
    └─ PR 자동 머지
```

---

## 출력 파일

### CHANGELOG.json

구조화된 데이터 형식으로, 프로그래밍적 접근이 가능합니다.

```json
{
  "versions": [
    {
      "version": "1.2.3",
      "date": "2026-01-12",
      "categories": {
        "Features": [
          "새로운 로그인 기능 추가"
        ],
        "Bug Fixes": [
          "회원가입 오류 수정"
        ]
      }
    }
  ]
}
```

### CHANGELOG.md

사람이 읽기 좋은 마크다운 형식입니다.

```markdown
# Changelog

## [1.2.3] - 2026-01-12

### Features
- 새로운 로그인 기능 추가

### Bug Fixes
- 회원가입 오류 수정
```

---

## changelog_manager.py 사용법

### 기본 명령어

```bash
# CodeRabbit Summary로 업데이트
python3 .github/scripts/changelog_manager.py update-from-summary

# Markdown 재생성
python3 .github/scripts/changelog_manager.py generate-md

# 특정 버전 릴리즈 노트 추출
python3 .github/scripts/changelog_manager.py export --version 1.2.3 --output release_notes.txt

# 유효성 검증
python3 .github/scripts/changelog_manager.py validate
```

---

## 카테고리 분류

CodeRabbit이 변경사항을 자동으로 분류합니다.

| 카테고리 | 설명 | 예시 키워드 |
|----------|------|------------|
| **Features** | 새로운 기능 | feat, add, new |
| **Bug Fixes** | 버그 수정 | fix, bug, resolve |
| **Documentation** | 문서 변경 | docs, readme |
| **Performance** | 성능 개선 | perf, optimize |
| **Refactoring** | 코드 리팩토링 | refactor, clean |
| **Tests** | 테스트 추가/수정 | test, spec |
| **Chores** | 기타 작업 | chore, build |

---

## PR 제목 자동 포맷팅

CodeRabbit이 deploy PR 제목을 자동으로 변경합니다.

**Before**:
```
main에서 deploy로 병합
```

**After**:
```
Deploy 20260112-v1.2.3 : 새로운 로그인 기능 추가
```

---

## 워크플로우

### PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml

```yaml
on:
  pull_request:
    types: [opened, synchronize]
    branches: [deploy]
```

**트리거 조건**:
- deploy 브랜치로 PR 생성/업데이트

**실행 내용**:
1. CodeRabbit Summary 대기
2. Summary 파싱
3. CHANGELOG.json 업데이트
4. CHANGELOG.md 생성
5. 변경사항 커밋
6. PR 자동 머지

---

## CodeRabbit 연동

### 필수 조건

1. 저장소에 CodeRabbit 앱 설치
2. `.coderabbit.yaml` 설정 (선택)

### Summary 형식

CodeRabbit이 PR에 남기는 Summary 형식:

```markdown
## Summary by CodeRabbit

### Changes
- Added new login feature
- Fixed signup validation bug

### Files Changed
- src/auth/login.ts
- src/auth/signup.ts
```

---

## 이중 파싱 전략

레거시 및 최신 CodeRabbit 형식 모두 지원합니다.

### 최신 형식
```markdown
## Summary by CodeRabbit
<details>
  <summary>Changes</summary>
  ...
</details>
```

### 레거시 형식
```markdown
**Summary**
- Change 1
- Change 2
```

---

## 트러블슈팅

### 체인지로그 생성 안됨

**증상**: PR 머지 후에도 CHANGELOG가 업데이트 안됨

**확인 사항**:
1. CodeRabbit이 Summary를 남겼는지 확인
2. `_GITHUB_PAT_TOKEN` Secret 설정 확인
3. Actions 로그에서 에러 확인

### Summary 파싱 실패

**증상**: "Could not parse CodeRabbit summary" 에러

**해결**:
1. PR 댓글에서 CodeRabbit Summary 형식 확인
2. HTML 태그가 깨지지 않았는지 확인

### PR 자동 머지 실패

**증상**: 체인지로그는 생성되었으나 PR이 머지 안됨

**확인 사항**:
1. Branch protection rule 확인
2. PAT 토큰 권한 확인 (repo, workflow)
3. Repository Settings → Actions 권한 확인

---

## 수동 업데이트

자동화가 실패한 경우 수동으로 업데이트할 수 있습니다.

```bash
# 1. CHANGELOG.json 직접 수정
# 2. Markdown 재생성
python3 .github/scripts/changelog_manager.py generate-md

# 3. 커밋 & 푸시
git add CHANGELOG.json CHANGELOG.md
git commit -m "docs: update changelog"
git push
```

---

## 관련 문서

- [버전 관리](VERSION-CONTROL.md)
- [트러블슈팅](TROUBLESHOOTING.md)
