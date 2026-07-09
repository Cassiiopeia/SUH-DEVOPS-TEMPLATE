# 구현 완료 보고 — #276 github 스킬 Repo 자동 감지 워크트리 환경 오작동

## 개요

Claude Code의 primary working directory가 SUH-DEVOPS-TEMPLATE인 상태에서
다른 레포 작업을 요청할 때 `git remote get-url origin`이 잘못된 레포를 가리키던 문제를 해결했다.
멀티 레포 워크트리 환경에서의 Repo 선택 흐름을 SKILL.md에 명확히 명시했다.

## 변경 사항

### Skills
- `skills/github/SKILL.md` — 멀티레포 환경 Repo 선택 흐름 명시 (arguments 우선, config repos 목록 fallback)

### 문서
- `CLAUDE.md` — 워크트리 환경 Repo 감지 오작동 알려진 문제 및 해결 방법 기록
- `docs/suh-template/issue/20260425_#276_...md` — 이슈 파일 등록

## 주요 구현 내용

**Repo 선택 우선순위 명시 (`skills/github/SKILL.md`)**

스킬 시작 시 Repo 감지 우선순위를 아래 순서로 명확히 정의했다:

1. arguments에 `owner/repo` 형식이 명시된 경우 → git remote 감지를 건너뛰고 해당 repo 사용
2. `git remote get-url origin` 으로 현재 디렉토리 레포 추출 → config `repos` 배열과 대조
3. 매칭 실패 시 → config `repos` 목록을 번호로 나열해 사용자가 선택

**CLAUDE.md 알려진 문제 문서화**

워크트리 환경에서의 오작동 원인, 재현 조건, 해결 방법(레포 명시 또는 config 선택)을
CLAUDE.md 알려진 스킬 동작 문제 섹션에 추가해 사용자 혼선을 방지했다.

## 이슈 URL

https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/276
