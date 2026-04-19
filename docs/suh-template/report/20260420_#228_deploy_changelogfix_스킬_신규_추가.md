# ⚙️[기능추가][Skills] deploy, changelogfix 스킬 신규 추가

## 개요

deploy PR automerge 실패 문제와 CodeRabbit 10분 대기 비효율을 해결하기 위해 `deploy`, `changelogfix` 스킬 2종을 신규 추가했다. 또한 AI가 확인 없이 커밋/이슈를 생성하는 문제를 방지하기 위해 `common-rules.md`에 행동 강제 원칙을 추가했다.

## 변경 사항

### 신규 스킬

- `skills/deploy/SKILL.md`: main push → deploy PR 생성 → git diff 분석 → 릴리스 노트 즉시 작성 → PR 본문 업데이트. 워크플로우가 `Summary by CodeRabbit` 감지 시 automerge 자동 진행. CodeRabbit 10분 대기 없이 처리.
- `skills/changelogfix/SKILL.md`: automerge 실패 시 복구용. 기존 deploy PR 닫고 새 PR 생성으로 `AUTO-CHANGELOG-CONTROL` 워크플로우 재트리거. PR 생성 직후 릴리스 노트 즉시 작성.
- `.cursor/skills/deploy/SKILL.md`, `.cursor/skills/changelogfix/SKILL.md`: Cursor IDE 동기화

### 규칙 강화

- `skills/references/common-rules.md`: AI 행동 강제 원칙 추가
  - 확인 없이 절대 하지 않는 것 (커밋/이슈생성/삭제/push) 명문화
  - 이슈 없이 커밋 금지
  - 이슈 이모지+태그 허용 목록 명시 (`⚙️[기능추가]`, `🚀[기능개선]` 등)
  - 이슈 저장 위치 `docs/suh-template/issue/` 강제
  - 이슈 등록 → 번호 확정 → 커밋 순서 강제

### 플러그인 메타데이터

- `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`: 스킬 수 `23+`로 업데이트
- `CLAUDE.md`: Skills 섹션에 `deploy`, `changelogfix` 항목 추가

## 주요 구현 내용

**deploy 스킬 핵심 흐름**:
`AUTO-CHANGELOG-CONTROL` 워크플로우는 `pull_request_target: [opened]`에만 트리거되고, PR 본문에서 `Summary by CodeRabbit`을 폴링한다. 스킬이 PR 생성 직후 CodeRabbit 형식(`<!-- This is an auto-generated comment: release notes by coderabbit.ai -->`)으로 본문을 작성하면, 워크플로우가 즉시 감지해 10분 대기 없이 automerge를 진행한다.

**changelogfix 스킬 핵심 흐름**:
기존 PR은 `pull_request_target: [opened]` 조건을 이미 소진했으므로, 닫고 새로 열어야 워크플로우가 재트리거된다. 새 PR 생성 후 동일하게 릴리스 노트를 즉시 작성해 대기 시간을 제거한다.

## 주의사항

- `changelogfix` 스킬 내 PR 생성/닫기는 `suh_template.cli`가 아닌 `gh` CLI를 사용 — Windows 환경에서 별도 설치 필요
- 워크플로우가 PR 본문을 초기화하는 타이밍과 스킬이 본문을 올리는 타이밍이 겹칠 경우 `changelogfix` 재실행 필요
