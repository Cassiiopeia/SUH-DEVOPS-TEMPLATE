# 체인지로그 자동화

main 브랜치로 PR이 생성되면 CodeRabbit AI 리뷰를 기반으로 체인지로그가 자동 생성됩니다.

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
develop 푸시
    │
    ▼
버전 증가 (VERSION-CONTROL)
    │
    ▼
develop → main PR 자동 생성
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

CodeRabbit이 develop → main PR 제목을 자동으로 변경합니다.

**Before**:
```
develop에서 main으로 병합
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
    branches: [main]
```

**트리거 조건**:
- main 브랜치로 PR 생성/업데이트

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

## 릴리스 버전 확정 커밋과 후속 워크플로우 트리거

`AUTO-CHANGELOG-CONTROL`이 develop→main 릴리스 PR을 automerge하며 만드는 **버전 확정 커밋**은
`[skip ci]`를 **포함하지 않는다**. 이 커밋이 main HEAD가 되므로, main push 트리거 워크플로우
(`NPM-PUBLISH`·`README-VERSION-UPDATE`·`PLUGIN-VERSION-SYNC` 및 각 프로젝트 배포 CICD)가
**릴리스 시 자동으로 트리거**되어야 하기 때문이다. (default 브랜치 push = 배포 트리거)

무한 루프가 없는 이유:

- `VERSION-CONTROL` 안전망은 `paths-ignore(version.yml)` + `release_guard`(커밋에 version.yml
  변경이 포함됐는지 감지)로 이 릴리스 커밋을 인식해 **재bump를 건너뛴다**.
- `README-VERSION-UPDATE`·`PLUGIN-VERSION-SYNC`는 자신이 만드는 후속 커밋에 `[skip ci]`를
  유지하므로 서로 재트리거하지 않는다.
- develop을 push 트리거로 쓰는 워크플로우가 없어, 릴리스 커밋이 develop에 있을 때 중복 CI가
  발생하지 않는다.

> 버전 확정 커밋에 `[skip ci]`를 다시 붙이면 릴리스마다 배포·동기화가 전부 멈춘다. 붙이지 않는다.

---

## 관련 문서

- [버전 관리](VERSION-CONTROL.md)
- [트러블슈팅](TROUBLESHOOTING.md)
