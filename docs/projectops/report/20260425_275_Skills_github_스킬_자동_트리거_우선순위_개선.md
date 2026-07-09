# 구현 완료 보고 — #275 github 스킬 자동 트리거 우선순위 개선

## 개요

`cassiiopeia:github` 스킬 description에 트리거 키워드를 구체적으로 강화하고,
CLAUDE.md Skill routing 테이블에 GitHub 작업 패턴을 우선 트리거로 명시하여
"PR 올려줘", "댓글 달아줘" 등의 요청 시 스킬이 누락되는 문제를 개선했다.

## 변경 사항

### Skills
- `skills/github/SKILL.md` — description 트리거 키워드 대폭 강화 (PR 생성, 이슈 댓글, GitHub API 등 명시적 패턴 추가)

### 문서
- `CLAUDE.md` — Skill routing 테이블에 `cassiiopeia:github` 최우선 트리거 패턴 명시
- `docs/suh-template/issue/20260425_#275_...md` — 이슈 파일 등록

## 주요 구현 내용

**description 트리거 키워드 강화 (`skills/github/SKILL.md`)**

기존 description이 넓고 모호해 범용 스킬에 우선순위가 밀리던 문제를 해결했다.
"PR 생성", "PR 올려줘", "이슈 댓글", "댓글 달아줘", "이슈 확인해줘", "GitHub API 호출" 등
GitHub 전용 트리거 키워드를 명시적으로 열거했다.

**CLAUDE.md Skill routing 최우선 등록**

Skill routing 테이블 최상단에 `cassiiopeia:github`를 배치하고
"PR 생성, PR 올려줘, 이슈 댓글, 댓글 달아줘, 이슈 확인, 이슈 닫기, PR 조회, GitHub API"
패턴을 `← 최우선 트리거`로 명시했다.

## 이슈 URL

https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/275
