# SUH 3종 스킬 재설계 — suh-plan / suh-analyze / suh-implement

작성일: 2026-06-01
작성자: chan4760@gmail.com
대상 브랜치: main (사용자 지시 — 기능개선 라벨, main에서 바로 진행)
관련 이슈: spec 승인 후 생성 예정 (제목·본문은 본 문서 기반)

---

## 1. 한 줄 요약

`skills/suh-plan` · `skills/suh-analyze` · `skills/suh-implement` 3종을 somansa-claude-code의 `planning` / `analyze` / `implement` 스킬 구조(Phase 분리·HARD-GATE·No-placeholder·Self-Review·서브에이전트 위임·Finishing)로 풀 포팅하되, 회사 전용 요소(Redmine·PAD·Drive·SSH·GitLab)를 SUH 일반 GitHub 사용자 환경(GitHub Issue·PR·suh-github·suh-init-worktree)으로 매핑한다.

## 2. 배경

기존 SUH 3종 스킬은 가볍지만 다음 한계가 있다:

- **책임 분리 모호**: suh-plan(전략)과 suh-analyze(분석+구현계획)가 겹친다. 구현 계획서를 plan에도 쓸 수 있고 analyze에도 쓸 수 있어 사용자가 매번 헷갈린다.
- **HARD-GATE 부재**: plan 문서에 파일/함수/라인을 적어도 막는 장치가 없다. 사용자가 "이미 다 정해진 거니까" 하고 analyze 스킵하는 패턴이 반복된다.
- **No-placeholder 가드 부재**: analyze에 "TBD"/"적절히"가 남은 채로 implement로 넘어가는 사고가 발생.
- **plan/analyze 자동 로드 없음**: implement가 docs 폴더를 스캔하지 않아 매번 사용자가 "이거 보고 만들어"로 첨부.
- **브랜치 가드 없음**: 보호 브랜치(main) 위에서 곧장 implement가 시작되는 사고 가능.
- **Finishing 단계 없음**: 구현 후 PR 생성·worktree 정리가 수동.
- **서브에이전트 병렬 위임 없음**: 독립 작업도 순차 처리만 가능.

somansa 버전은 위 한계를 해결한 강력한 패턴(Phase 단위 + HARD-GATE + No-placeholder + Self-Review + 서브에이전트 + Finishing)을 가지고 있다. 단 회사 전용 통합(Redmine·GitLab·SSH·PAD·Drive)이 박혀 있어 그대로 가져올 수 없다.

## 3. 사용자 시나리오 / 동작 정의

### 시나리오 1 — 일반 신규 기능

1. 사용자: "이슈 #123 기능 구현해줘"
2. `/suh-plan` 호출 → Phase -1에서 suh-github 스킬 호출해 이슈 본문 fetch → Phase 0 의도 추출 한 줄 요약 → Phase 1 brainstorming 한 메시지 = 한 질문 → Phase 2 plan.md 작성 (HOW 금지) → Phase 3 Self-Review → Phase 4 사용자 승인 대기.
3. 사용자 "OK" → `/suh-analyze` → Phase -1 plan.md 있음 확인 → Phase 1 코드베이스 정찰 (Read·Grep) → Phase 2 변경 파일 표 + 태스크별 Before/After (No-placeholder) → Phase 3 Self-Review → Phase 4 승인 + 구현 방식 선택 (Subagent-Driven / Inline).
4. 사용자 "subagent" → `/suh-implement` → Phase 0-0 브랜치 가드 (보호 브랜치면 worktree 옵션) → Phase 0 plan/analyze 자동 로드 → Phase 1 TaskCreate → Phase 2-B 병렬 task 서브에이전트 위임 → Phase 3 검증 (실제 명령) → Phase 5 Self-Review → Phase 6 Finishing 4옵션 (PR / 로컬 머지 / 보관 / 폐기).

### 시나리오 2 — 단순 버그 수정 (scope 단순 판정)

1. `/suh-plan` → Phase 1 scope 판정: 파일 2개↓ + 함수 1개 범위 + 외부동작 무변경 → "단순 작업입니다. analyze 없이 바로 implement OK?"
2. 사용자 "OK" → `/suh-implement` 바로 (analyze 스킵).

### 시나리오 3 — 사용자가 implement 직접 호출

1. 사용자: "이거 그냥 바로 구현해줘"
2. HARD-GATE 조건 충족(2개↑ 파일 영향 등) → "suh-plan부터 권장합니다. 그래도 바로 구현하려면 '바로 구현해' 라고 명시해주세요"
3. 사용자 "바로 구현해" → Phase 0-0 브랜치 가드부터 시작.

### 시나리오 4 — 보호 브랜치 위

1. main 브랜치에서 implement 호출
2. Phase 0-0: "현재 main 위입니다. 1.worktree 새로 / 2.새 브랜치만 / 3.그냥 진행" 3옵션 제시
3. 사용자 "1" → suh-init-worktree 위임 → 새 세션에서 다시 호출 안내.

## 4. 요구사항

### 필수 (Must)

- **3 스킬 책임 분리**: suh-plan=WHAT / suh-analyze=HOW / suh-implement=DO. 산출물 위치도 분리.
- **HARD-GATE**:
  - suh-plan: HOW 영역(파일+함수+라인 조합, 변경 계획 표, Before/After 코드) plan 문서에 들어가면 실패.
  - suh-analyze: placeholder(TBD/TODO/"적절히"/"필요 시"/"유사하게"), 파일 경로 없는 변경 항목, 함수명·라인 없는 변경 항목, Before/After 없는 코드 변경 항목 실패.
  - suh-implement: HARD-GATE 조건(2개↑ 파일·새 기능·외부동작·다중 대안) 충족 시 plan 없으면 명시 승인 필요.
- **Phase 자동 로드**: suh-implement는 `docs/suh-template/{plan,analyze}/` 자동 스캔 → 상태별 분기(analyze 있음 / plan만 / 둘 다 없음 / 사용자 지정).
- **브랜치 가드**: suh-implement Phase 0-0에서 보호 브랜치(main/master/develop/release 패턴/`origin/HEAD`) 판정 → 3옵션. detached HEAD = 보호 브랜치 간주.
- **Self-Review Phase**: 3 스킬 모두 제출 전 자신이 작성한 문서/변경을 Read로 다시 읽고 체크리스트 검증.
- **HARD-GATE 제출**: plan/analyze 완료 후 사용자 명시 승인 ("OK"/"진행"/다음 스킬명) 전 자동 호출 금지.
- **서브에이전트 병렬 위임**: implement Phase 2-B — 2개↑ 독립 task일 때 서브에이전트 위임 가능. 위임 프롬프트에 ⛔git commit/push 금지·plan 외 변경 금지·검증 실제 실행 필수·한국어 응답·결과 통합 재검증.
- **Finishing Phase**: implement Phase 6 — 최종 테스트 / 환경 감지 / 4옵션(PR·로컬 머지·보관·폐기) / 옵션별 worktree 정리 / `/suh-report` 안내.
- **GitHub 매핑**: Redmine→suh-github(이슈 fetch), GitLab MR→suh-github(PR 생성), create-worktree→suh-init-worktree.
- **SUH 산출물 컨벤션 유지**: `docs/suh-template/{plan,analyze}/YYYYMMDD_{이슈번호}_{정규화된제목}.md`. `suh_template` CLI(`get-output-path`/`get-issue-number`/`get-next-seq`/`normalize-title`) 활용.
- **스킬 이름 유지**: `suh-plan` · `suh-analyze` · `suh-implement` (플러그인 링크·기존 사용자 머슬 보존).

### 원함 (Should)

- **Scope 판정** (suh-plan Phase 1): 파일 2개↓ + 함수 1개 범위 + 외부동작 무변경 + 유사 패턴 존재 → "analyze 없이 바로 implement OK?" 안내.
- **Sub-project 분해** (suh-plan): 독립 서브시스템 3개↑ 감지 시 분해 제안.
- **병렬 태스크 식별** (suh-analyze): 같은 파일 안 건드림 + 순서 의존 없음 → `[병렬]` 표시 → implement Phase 2-B 후보.
- **plan 범위 밖 발견 처리** (suh-implement): 작업 중 발견 → 메모리 보관 → Phase 6 후 별건 보고. 즉흥적 손대기 금지.
- **명령 실행 결과 인용** (suh-implement Phase 3): "통과될 것 같습니다" 금지 — 실제 명령 출력 그대로 인용.

### 선택 (Nice)

- 첫 진입 시 사용자에게 한 줄 가이드: "이 스킬은 WHAT/HOW/DO 중 X 단계입니다".
- HARD-GATE 위반 감지 시 자동 수정 제안 (현재는 사용자가 수정).
- Self-Review 체크리스트를 별도 reference 파일로 분리 (3 스킬 공유) — **실제 구현됨** (`skills/references/self-review-checklist.md`).

## 5. 제약

- **기술**:
  - 기존 SUH 스킬 생태계 보존 — `suh-github` · `suh-init-worktree` · `suh-commit` · `suh-report` · `suh-review` 호출 가능해야 함.
  - `suh_template` CLI 활용 (자체 경로 계산 로직 만들지 않음).
  - 외부 패키지 추가 금지 (내부망 호환).
- **환경**:
  - Windows Git Bash + macOS 양쪽 동작.
  - 보호 브랜치 판정은 `git rev-parse` 기반 (`git symbolic-ref refs/remotes/origin/HEAD` 보조).
- **일정**: 사용자 지시 — 이슈 만들고 기능개선 라벨, main에서 바로 진행.

## 6. 성공 기준 (Definition of Done)

- [x] `skills/suh-plan/SKILL.md` 신규 버전 작성. HARD-GATE·Phase -1~4·Self-Review·산출물 경로 SUH 컨벤션 포함. PAD/Drive/Redmine 직접 참조 없음.
- [x] `skills/suh-analyze/SKILL.md` 신규 버전 작성. No-placeholder HARD-GATE·Phase -1~4·writing-plans 패턴·병렬 태스크 식별·SSH Phase 제거 확인.
- [x] `skills/suh-implement/SKILL.md` 신규 버전 작성. HARD-GATE(설계 필수)·Phase 0-0 브랜치 가드·plan/analyze 자동 로드·서브에이전트 위임·Phase 3 실제 명령 실행·Phase 6 Finishing 4옵션(suh-github 호출)·`/suh-report` 안내 포함. GitLab/Redmine/SSH 참조 없음.
- [x] 3 스킬 모두 사용자 명시 승인 전 다음 스킬 자동 호출 금지 명시.
- [x] 스킬 이름 변경 없음 확인 (`suh-plan`/`suh-analyze`/`suh-implement`).
- [x] `skills/references/self-review-checklist.md` 신규 생성 — 3 스킬 공유 체크리스트.
- [ ] CLAUDE.md의 "기능 구현 워크플로우" 섹션과 정합성 확인 (충돌 없음) — 후속 확인.
- [x] `skills/references/common-rules.md` 의존 경로 유지 (작업 시작 프로토콜 등).

## 7. 가정

- **가정 1**: 사용자는 GitHub 일반 사용자 환경 — Redmine·GitLab 없음. 이슈/PR 모두 GitHub.
- **가정 2**: `suh-github` 스킬이 이슈 본문·댓글 fetch + PR 생성 기능을 이미 제공 (CLAUDE.md skill routing 표 기준). 별도 스킬 수정 불필요.
- **가정 3**: `suh-init-worktree` 스킬은 브랜치명만 받으면 worktree 생성 가능 (기존 동작 유지).
- **가정 4**: `suh_template` CLI의 `get-output-path`·`get-issue-number`·`get-next-seq`·`normalize-title` 4개 커맨드는 SKILL.md에서 호출 가능 상태.
- **가정 5**: 사용자가 spec 승인 후 GitHub 이슈를 직접 생성하거나 suh-issue 스킬로 생성 — 본 spec 자체가 이슈 본문 후보.

## 8. 미해결 질문

- 없음.

## 9. 다음 단계

- 본 spec 승인 후 → `superpowers:writing-plans` 호출해 구현 계획 작성 → `/superpowers:executing-plans` 또는 `/superpowers:subagent-driven-development` 로 실행.
- 본 spec 자체가 GitHub 이슈 본문 후보. `/suh-issue` 스킬로 이슈 생성 가능.

## 10. 실행 결과 (2026-06-01)

본 spec은 brainstorming → writing-plans → 자율 실행 순으로 처리되어 다음 산출물로 main 브랜치에 머지됨:

- 커밋: `4a84c50 suh 3종 스킬 somansa 패턴 재설계 : refactor : suh-plan/analyze/implement HARD-GATE·Phase 분리·Self-Review·서브에이전트 위임·Finishing 도입 + GitHub 환경 적응`
- 변경 파일:
  - `skills/suh-plan/SKILL.md`
  - `skills/suh-analyze/SKILL.md`
  - `skills/suh-implement/SKILL.md`
  - `skills/references/self-review-checklist.md` (신규)
