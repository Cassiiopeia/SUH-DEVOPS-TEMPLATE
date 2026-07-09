# Skills plan/analyze/implement 재설계 — 구현 보고서

## 개요

기존 `plan` / `analyze` / `implement` 3종 스킬을 somansa-claude-code의 `planning` / `analyze` / `implement` 패턴으로 풀 포팅했다. 책임 분리(WHAT/HOW/DO), HARD-GATE, Phase 구조, No-Placeholder, Self-Review, 서브에이전트 병렬 위임, Finishing 4옵션을 도입했고, 회사 전용 통합(Redmine·PAD·Drive·SSH·GitLab)을 SUH 일반 GitHub 환경(github·init-worktree)으로 매핑했다.

## 변경 사항

### Skills 재작성 (3 파일)
- `skills/plan/SKILL.md`: WHAT 전용으로 책임 한정. HARD-GATE(HOW 침범 금지) + Phase -1(github 이슈 fetch) + Phase 0(의도 추출) + Phase 1(brainstorming · Scope 판정 · sub-project 분해) + Phase 2(plan 템플릿 — Must/Should/Nice) + Phase 3(Self-Review) + Phase 4(HARD-GATE 제출) 구조.
- `skills/analyze/SKILL.md`: HOW 구체화 책임. No-Placeholder HARD-GATE + Phase -1(사전 상태 확인) + Phase 0(plan.md 로드) + Phase 1(코드베이스 정찰 — Read/Grep) + Phase 2(writing-plans 패턴 — 파일/함수/라인/Before/After/검증 + 병렬 태스크 식별 `[병렬]`) + Phase 3(Self-Review) + Phase 4(HARD-GATE 제출). somansa의 SSH Phase 제거.
- `skills/implement/SKILL.md`: DO 실제 구현. HARD-GATE(설계 필수) + Phase 0-0(보호 브랜치 가드 3옵션 — worktree/새 브랜치/그대로) + Phase 0(plan/analyze 자동 로드) + Phase 1(TaskCreate) + Phase 2-A(직접 구현) + Phase 2-B(서브에이전트 병렬 위임) + Phase 3(실제 명령 실행, "통과될 것 같습니다" 금지) + Phase 4(메모리 보관) + Phase 5(Self-Review) + Phase 6(Finishing 4옵션: GitHub PR·로컬 머지·보관·폐기) 구조.

### 신규 reference (1 파일)
- `skills/references/self-review-checklist.md`: 3 스킬 공유 Self-Review 체크리스트. plan(HARD-GATE/placeholder/Must·Should·Nice 균형/가정 명시/이슈 정보 반영), analyze(No-Placeholder/파일+함수+라인/Before·After 실제 인용/병렬 표시/검증 구체성/Must 반영), implement(편집 전 Read/plan 외 변경 금지/검증 실제 실행/실패 정직 보고/자동 commit 금지/내부망 룰) 3 섹션.

### 설계 문서 (2 파일)
- `docs/superpowers/specs/2026-06-01-skills-3pack-redesign-design.md`: 재설계 spec — 배경/시나리오/요구사항(Must·Should·Nice)/제약/성공기준/가정.
- `docs/superpowers/plans/2026-06-01-skills-3pack-redesign.md`: 구현 plan — File Structure + 5 Task 분해 + 검증 요약.

### 이슈 본문 보존 (1 파일)
- `docs/suh-template/issue/20260601_323_Skills_suh-plan-analyze-implement_somansa_패턴_재설계.md`: 이슈 #323 본문 로컬 보존.

## 주요 구현 내용

**책임 분리 — WHAT/HOW/DO**

| 스킬 | 책임 | 산출물 |
|------|------|--------|
| `plan` | WHAT | `docs/suh-template/plan/YYYYMMDD_{이슈번호}_{제목}.md` |
| `analyze` | HOW (파일/함수/라인) | `docs/suh-template/analyze/YYYYMMDD_{이슈번호}_{제목}.md` |
| `implement` | DO (실제 코드) | 코드 자체. 별도 산출 md 없음 |

**HARD-GATE 3종**

- `plan`: 파일+함수+라인 조합·변경 계획 표·Before/After 코드 plan 문서 진입 시 즉시 실패. "→ `/analyze`에서 구체화" 한 줄로 대체.
- `analyze`: "TBD"/"TODO"/"나중에"/"적절히"/"필요 시"/"유사하게" 진입 시 즉시 실패. 파일 경로·함수명·라인·Before/After 코드 누락도 실패.
- `implement`: 2개↑ 파일 영향·새 기능·외부동작 변경·다중 대안 설계 결정 중 하나라도 충족 시 plan 없으면 사용자 명시 승인("바로 구현해") 요구. "그냥 해" 같은 중립 응답으로 스킵 불가.

**Phase 0-0 브랜치 가드 (implement)**

`git rev-parse --abbrev-ref HEAD` 조회 후 보호 브랜치(main/master/develop/`*release*`/`R_\d+` 패턴/`origin/HEAD` 결과/detached HEAD) 위면 3옵션 제시 — worktree 새로(init-worktree 위임) / 새 브랜치만(`git checkout -b`) / 그대로 진행. 사용자 선택 전 코드 편집 차단.

**Phase 6 Finishing 4옵션 (implement)**

진입 조건: 모든 Phase 2 태스크 completed + Phase 3 검증 통과. Step 1 최종 테스트 → Step 2 환경 감지(worktree·base branch) → Step 3 4옵션(GitHub PR·로컬 머지·보관·폐기) → Step 4 옵션별 실행(PR은 github 호출, 폐기는 'discard' typed 확인) → Step 5 `/report` 안내.

**SUH 환경 매핑**

| Somansa | SUH 대응 |
|---------|----------|
| Redmine 이슈 fetch | `github` 스킬 (이슈 본문/댓글 조회) |
| GitLab MR 생성 | `github` 스킬 (PR 생성) |
| `create-worktree` 스킬 | `init-worktree` |
| SSH 자동 제안 Phase | **제거** |
| PAD/Drive fetch | **제거** |
| `docs/somansa/{plan,analyze}/` | `docs/suh-template/{plan,analyze}/` |
| `{YYYY-MM-DD}_{slug}.md` | `YYYYMMDD_{이슈번호}_{정규화된제목}.md` (SUH 컨벤션 유지) |

## 검증

각 SKILL.md 파일에서 Grep 기반 검증 수행. 모든 조건 통과:

| 항목 | 결과 |
|------|------|
| plan HARD-GATE 표식 | 3회 |
| analyze No Placeholders / HARD-GATE | 4회 |
| analyze `[병렬]` 마커 | 3회 |
| implement HARD-GATE/보호 브랜치/Phase 0-0/Finishing | 18회 |
| implement github/init-worktree/report 호출 | 9회 |
| 3 SKILL 금지 단어 (Redmine/PAD/SSH/GitLab/gitlab.somansa/create-worktree) | 0회 |
| Self-Review 체크리스트 참조 | 3 SKILL 모두 매치 |
| 산출물 경로 (`docs/suh-template/{plan,analyze}/`) | 3 SKILL 모두 매치 |

## 커밋 이력

- `589e0f4` — suh 3종 스킬 somansa 패턴 재설계 : refactor : 4 파일 변경 (736 insertions, 152 deletions)
- `3f99702` — suh 3종 스킬 재설계 spec + plan 문서화 : docs : 2 파일 추가 (217 insertions)
- `e04c79a` — Skills plan/analyze/implement 재설계 : docs : 이슈 #323 본문 보존 (73 insertions)

## 주의사항

- 본 변경분은 322 브랜치(`20260601_#322_skill_py_실행_구조_MCP-style_표준화_및_OS_호환성_강건화`)에 cherry-pick되어 있어 322 PR(#324)에 함께 묶여 main에 반영된다. 별도 PR로 분리하지 않은 이유는 322 PR이 이미 진행 중이며 사용자 판단으로 한 번에 처리하기로 결정했기 때문이다.
- 322 PR 머지 시 main에 자동 반영. 머지 후 `/plan` · `/analyze` · `/implement` 호출하면 새 동작 시작.
- 추후 신규 SUH 스킬 작성 시 본 3종을 reference 모델로 활용 가능 (HARD-GATE + Phase + Self-Review 패턴).
