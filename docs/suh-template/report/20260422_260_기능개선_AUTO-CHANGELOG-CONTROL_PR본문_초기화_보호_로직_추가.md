# 🚀[기능개선][ChangeLog] AUTO-CHANGELOG-CONTROL PR 본문 초기화 보호 로직 추가

## 개요

`changelog-deploy` 스킬이 deploy PR 생성 직후 PR 본문에 릴리스 노트를 작성했음에도, `AUTO-CHANGELOG-CONTROL` 워크플로우가 트리거되면서 본문을 무조건 초기화해 작성된 내용이 사라지는 문제를 수정했다. PR 본문 초기화 전에 "Summary by CodeRabbit" 존재 여부를 먼저 확인하여, 이미 있으면 초기화를 건너뛰고 이후 폴링 단계도 생략하도록 개선했다.

## 변경 사항

### 워크플로우
- `.github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml`
  - `PR 본문 초기화` 스텝에 `id: clear_body` 추가 및 초기화 전 본문 사전 확인 로직 삽입
  - `CodeRabbit Summary 요청` 스텝에 `already_found=true` 조건부 스킵 추가
  - `CodeRabbit Summary 감지(폴링)` 스텝에 `already_found=true` 시 즉시 성공 처리 분기 추가

## 주요 구현 내용

**PR 본문 초기화 보호 로직 (`clear_body` 스텝)**

초기화 전에 GitHub API로 현재 PR 본문을 조회한다. `"Summary by CodeRabbit"` 문자열이 존재하면 본문을 `pr_body.md`로 즉시 저장하고 `already_found=true`를 출력값으로 설정한 뒤 초기화를 건너뛴다. 없으면 기존과 동일하게 본문을 초기화하고 `already_found=false`를 설정한다.

**CodeRabbit Summary 요청 스텝 조건부 스킵**

`already_found=true`이면 `@coderabbitai summary` 댓글 요청 자체를 건너뛴다. 불필요한 API 호출을 방지한다.

**폴링 즉시 종료 분기**

폴링 스텝 시작 시 `already_found=true`이면 즉시 `summary_found=true`를 출력하고 `exit 0`으로 종료한다. 10분 대기 없이 바로 CHANGELOG 업데이트 단계로 진행한다.

**결과적인 두 가지 실행 경로**

| 상황 | 동작 |
|------|------|
| changelog-deploy가 먼저 본문 작성 완료 | 초기화 생략 → 요청 생략 → 폴링 생략 → 즉시 CHANGELOG 업데이트 |
| changelog-deploy가 본문 미작성 | 초기화 → CodeRabbit 요청 → 최대 10분 폴링 (기존 동작 유지) |

## 주의사항

- `changelog-deploy`가 PR 본문에 작성하는 릴리스 노트는 반드시 `"Summary by CodeRabbit"` 문자열을 포함해야 이 보호 로직이 동작한다. 포맷이 변경되면 감지 조건도 함께 수정해야 한다.
- `project-types/common/` 원본 워크플로우 파일과 루트 `.github/workflows/` 파일이 동일하게 유지되어야 한다 — 현재는 루트 파일만 수정된 상태이므로, 추후 `project-types/common/`도 동일하게 반영이 필요하다.
