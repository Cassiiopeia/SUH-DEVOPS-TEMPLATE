# 🚀[기능개선][ChangeLog] AUTO-CHANGELOG-CONTROL PR 본문 초기화 보호 로직 추가

## 개요

이번 작업은 두 가지 독립적인 문제를 해결했다. 첫째, `changelog-deploy` 스킬이 deploy PR 본문에 릴리스 노트를 먼저 작성했을 때 `AUTO-CHANGELOG-CONTROL` 워크플로우가 이를 덮어쓰는 버그를 수정했다. 둘째, `commit`·`issue`·`init-worktree` 스킬에서 `current-issue.json` 파일을 통해 이슈 컨텍스트를 저장·읽던 방식을 제거하고, 브랜치명에서 이슈 번호를 직접 추출하는 단순한 구조로 교체했다. 함께, 커밋 메시지에 이모지·태그가 포함되던 관행을 규칙으로 금지했다.

## 변경 사항

### 워크플로우
- `.github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml`
  - `PR 본문 초기화` 스텝: 무조건 초기화 → 초기화 전 "Summary by CodeRabbit" 존재 여부 확인 후 조건부 초기화
  - `CodeRabbit Summary 요청` 스텝: `already_found=true`이면 스킵
  - `CodeRabbit Summary 감지(폴링)` 스텝: `already_found=true`이면 즉시 `summary_found=true` 처리 (10분 대기 생략)

### Skills
- `skills/commit/SKILL.md`
  - `current-issue.json` 읽기 로직 전체 제거
  - 3단계: 브랜치명(`YYYYMMDD_#번호_제목`)에서 이슈 번호 자동 추출 → GitHub API로 이슈 정보 조회
  - 5단계: 커밋 메시지 형식에 이모지·태그 제거 규칙 명시
- `skills/issue/SKILL.md`
  - 8단계: worktree/브랜치 생성 후 `current-issue.json` 저장 블록 제거
  - 7단계 커밋 템플릿 예시: 이모지·태그 포함 → 순수 내용 형식으로 수정
  - 8단계 커밋 메시지 템플릿: `{이슈제목}` → `{이슈제목에서 이모지·태그 제거한 순수 내용}`으로 수정
- `skills/init-worktree/SKILL.md`
  - 5단계(구 이슈 컨텍스트 저장) 전체 제거 → 결과 출력 단계로 대체
  - 커밋 메시지 템플릿: `{브랜치명}` → `{브랜치명에서 날짜·이슈번호·이모지·태그 제거한 순수 제목}`으로 수정

### 프로젝트 설정
- `CLAUDE.md`: 커밋 컨벤션 필수 규칙 섹션 추가 — 이모지·태그 포함 금지, 올바른/잘못된 예시 명시

### 파일 시스템
- `.suh-template/context/current-issue.json` 및 `context/` 폴더 삭제

## 주요 구현 내용

**AUTO-CHANGELOG-CONTROL 초기화 보호 플로우**

`clear_body` 스텝에서 초기화 전 GitHub API로 PR 본문을 조회한다. "Summary by CodeRabbit" 감지 시 `already_found=true`를 출력값으로 설정하고 `pr_body.md`를 즉시 저장한다. 이후 요청·폴링 스텝은 이 플래그를 보고 건너뛴다. 감지되지 않으면 기존과 동일하게 초기화 후 폴링을 진행한다.

**commit 스킬 브랜치 기반 이슈 추출 플로우**

`git rev-parse --abbrev-ref HEAD`로 브랜치명을 읽고 `#[0-9]+` 패턴으로 이슈 번호를 추출한다. 추출된 번호로 GitHub API를 조회해 이슈 제목과 URL을 가져온 뒤 커밋 메시지를 구성한다. 브랜치명에 이슈 번호가 없으면 직접 입력 또는 자유 형식 선택지를 제시한다.

## 주의사항

- `changelog-deploy`가 PR 본문에 작성하는 릴리스 노트는 반드시 `"Summary by CodeRabbit"` 문자열을 포함해야 이 보호 로직이 동작한다. 해당 포맷이 변경되면 감지 조건도 함께 수정해야 한다.
- `project-types/common/` 원본 워크플로우와 루트 `.github/workflows/` 파일이 동일하게 유지되어야 한다 — 현재 루트 파일만 수정된 상태이므로 추후 `project-types/common/`도 동일하게 반영 필요하다.
- 커밋 스킬의 이슈 번호 추출은 브랜치명이 `YYYYMMDD_#번호_제목` 형식일 때만 동작한다. 다른 브랜치 네이밍 규칙을 사용하는 프로젝트에서는 수동 입력 경로로 진행된다.
