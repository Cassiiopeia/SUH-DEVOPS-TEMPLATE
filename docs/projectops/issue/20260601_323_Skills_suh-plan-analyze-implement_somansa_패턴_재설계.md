📝 현재 문제점
---

기존 `plan` / `analyze` / `implement` 3종 스킬은 가볍지만 다음 한계가 있다.

- **책임 분리 모호**: `plan`(전략)과 `analyze`(분석 + 구현 계획)의 책임이 겹친다. 구현 계획서를 plan에도, analyze에도 쓸 수 있어 호출자가 매번 헷갈린다.
- **HARD-GATE 부재**: plan 문서에 파일/함수/라인을 적어도 막는 장치가 없다. 사용자가 "이미 다 정해진 거니까" 하고 analyze 단계를 스킵하는 패턴이 반복된다.
- **No-placeholder 가드 부재**: analyze 산출물에 "TBD" / "적절히"가 남은 채로 implement로 넘어가는 사고가 발생한다.
- **plan/analyze 자동 로드 없음**: `implement`가 `docs/suh-template/` 폴더를 자동 스캔하지 않아 매번 사용자가 산출물 파일을 명시적으로 첨부해야 한다.
- **브랜치 가드 없음**: 보호 브랜치(`main`/`master`/`develop`/`*release*`) 위에서 곧장 implement가 시작되는 사고가 가능하다.
- **Finishing 단계 없음**: 구현 완료 후 PR 생성·worktree 정리가 수동이며, `github`·`init-worktree` 같은 기존 스킬과의 매끄러운 연동 흐름이 없다.
- **서브에이전트 병렬 위임 없음**: 독립적인 작업도 메인 컨텍스트에서 순차로만 처리 가능했다.

somansa-claude-code의 `planning` / `analyze` / `implement` 스킬은 위 한계를 해결한 강력한 패턴(Phase 단위 + HARD-GATE + No-placeholder + Self-Review + 서브에이전트 + Finishing)을 가지고 있다. 단, 회사 전용 통합(Redmine·GitLab·SSH·PAD·Drive)이 박혀 있어 그대로 가져올 수 없다.

🛠️ 해결 방안 / 제안 기능
---

`plan` / `analyze` / `implement` 3종 스킬을 somansa 패턴으로 풀 포팅하되, 회사 전용 요소는 SUH 일반 GitHub 환경으로 매핑한다.

**책임 분리 (3종 분리)**

- `plan` = WHAT — `docs/suh-template/plan/YYYYMMDD_{이슈번호}_{제목}.md`
- `analyze` = HOW — `docs/suh-template/analyze/YYYYMMDD_{이슈번호}_{제목}.md`
- `implement` = DO — 코드 자체가 결과 (별도 산출 md 없음)

**주요 도입 패턴**

- **HARD-GATE**: plan에 HOW 침범 차단, analyze에 No-Placeholder 차단, implement에 설계 필수 게이트
- **Phase 구조**: -1(외부 컨텍스트) → 0(의도 추출/로드) → 1~4(brainstorming/정찰/작성/Self-Review/제출)
- **Self-Review Phase**: 3 스킬 공유 체크리스트 (`skills/references/self-review-checklist.md` 신규)
- **서브에이전트 병렬 위임**: implement Phase 2-B에서 2개↑ 독립 task 위임 + 통합 재검증
- **Finishing Phase**: implement Phase 6 — 최종 테스트 / 환경 감지 / 4옵션(PR / 로컬 머지 / 보관 / 폐기) / worktree 정리 / `/report` 안내
- **브랜치 가드**: implement Phase 0-0 — 보호 브랜치 판정 + 3옵션(worktree / 새 브랜치만 / 그대로 진행)

**SUH 환경 매핑 (회사 전용 제거)**

- Redmine 이슈 fetch → `github` 스킬 (이슈 본문/댓글 조회)
- GitLab MR 생성 → `github` 스킬 (PR 생성)
- create-worktree (somansa) → `init-worktree`
- SSH 자동 제안 Phase → **제거**
- PAD/Drive fetch → **제거**
- `docs/somansa/{plan,analyze}/` → `docs/suh-template/{plan,analyze}/` (기존 SUH 컨벤션 유지)
- 산출물 파일명: `YYYYMMDD_{이슈번호}_{정규화된제목}.md` (기존 SUH 컨벤션 유지)
- 스킬 이름 변경 없음 (`plan` / `analyze` / `implement` 그대로)

**관련 산출물**

- 설계 spec: `docs/superpowers/specs/2026-06-01-skills-3pack-redesign-design.md`
- 구현 plan: `docs/superpowers/plans/2026-06-01-skills-3pack-redesign.md`

⚙️ 작업 내용
---

본 이슈는 이미 구현된 작업의 사후 등록이다. 현재 브랜치(`20260601_#322_skill_py_실행_구조_MCP-style_표준화_및_OS_호환성_강건화`)에 다음 두 커밋으로 반영되어 있다.

- `589e0f4` — suh 3종 스킬 somansa 패턴 재설계 : refactor : 4 파일 변경 (736 insertions, 152 deletions)
  - `skills/plan/SKILL.md`
  - `skills/analyze/SKILL.md`
  - `skills/implement/SKILL.md`
  - `skills/references/self-review-checklist.md` (신규)
- `3f99702` — 재설계 spec + plan 문서화 : docs : 2 파일 추가
  - `docs/superpowers/specs/2026-06-01-skills-3pack-redesign-design.md`
  - `docs/superpowers/plans/2026-06-01-skills-3pack-redesign.md`

> 322 브랜치는 별도 작업(MCP-style skill py 재설계)이 진행 중이라 본 변경분이 같은 브랜치에 cherry-pick되어 PR에 함께 묶여 올라간다.

🙋‍♂️ 담당자
---

- 백엔드: Cassiiopeia
- 프론트엔드: -
- 디자인: -
