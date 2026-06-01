# SUH 3종 스킬 재설계 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SUH 3종 스킬(suh-plan / suh-analyze / suh-implement)을 somansa planning/analyze/implement 패턴으로 풀 포팅하되, 회사 전용 통합(Redmine·PAD·Drive·SSH·GitLab)을 SUH 일반 GitHub 사용자 환경(suh-github·suh-init-worktree)으로 매핑한다.

**Architecture:** 각 스킬 SKILL.md를 신규 버전으로 덮어쓴다. 책임 분리: suh-plan=WHAT / suh-analyze=HOW / suh-implement=DO. HARD-GATE·Phase 구조·Self-Review·서브에이전트 위임·Finishing 추가. 산출물 경로는 기존 SUH 컨벤션(`docs/suh-template/{plan,analyze}/`) 유지. Self-Review 체크리스트는 신규 reference 파일로 분리해 3 스킬 공유.

**Tech Stack:** Markdown(SKILL.md) · YAML frontmatter · bash 명령(git rev-parse·grep) · 기존 SUH 스킬(suh-github/suh-init-worktree/suh-commit/suh-report) 호출.

---

## File Structure

| 경로 | 용도 | 변경 종류 |
|------|------|---------|
| `skills/references/self-review-checklist.md` | 3 스킬 공유 Self-Review 체크리스트 (plan/analyze/implement 3 섹션) | **생성** |
| `skills/suh-plan/SKILL.md` | suh-plan v2 — HARD-GATE WHAT-only + Phase -1~4 + brainstorming + Scope 판정 + Self-Review | **덮어쓰기** |
| `skills/suh-analyze/SKILL.md` | suh-analyze v2 — No-placeholder HARD-GATE + Phase -1~4 + writing-plans 패턴 + 병렬 식별 (SSH 제거) | **덮어쓰기** |
| `skills/suh-implement/SKILL.md` | suh-implement v2 — HARD-GATE(설계 필수) + Phase 0-0 브랜치 가드 + plan/analyze 자동 로드 + 서브에이전트 위임 + Phase 3 실제 명령 + Phase 6 Finishing 4옵션(suh-github 호출) | **덮어쓰기** |

`skills/references/common-rules.md` · `config-rules.md` 등 기존 reference는 **수정 안 함**.

---

## Tasks

### Task 1: Self-Review 체크리스트 reference 작성 — ✅ 완료

`skills/references/self-review-checklist.md` 신규 작성. suh-plan / suh-analyze / suh-implement 3 섹션, 각 체크리스트 5~7개 항목.

### Task 2: suh-plan v2 SKILL.md 작성 — ✅ 완료

기존 v1을 덮어씀. HARD-GATE(HOW 침범 금지), Phase -1(외부 컨텍스트 — suh-github), Phase 0(의도 추출), Phase 1(brainstorming + Scope 판정 + sub-project 분해), Phase 2(plan 템플릿), Phase 3(Self-Review), Phase 4(HARD-GATE 제출).

Grep 검증 통과: `HARD-GATE` 3회, Phase -1~4 매치, `suh-github` 매치, `Redmine/PAD/SSH/GitLab` 0회.

### Task 3: suh-analyze v2 SKILL.md 작성 — ✅ 완료

기존 v1을 덮어씀. No-Placeholder HARD-GATE, Phase -1(사전 상태), Phase 0(plan.md 로드), Phase 1(코드베이스 정찰), Phase 2(writing-plans 패턴 + 병렬 식별), Phase 3(Self-Review), Phase 4(HARD-GATE 제출).

SSH Phase 제거 (somansa 회사 전용).

Grep 검증 통과: `HARD-GATE/No Placeholders` 4회, `[병렬]` 3회, 금지단어 0회.

### Task 4: suh-implement v2 SKILL.md 작성 — ✅ 완료

기존 v1을 덮어씀. HARD-GATE(설계 필수), Phase 0-0(브랜치 가드 + 3옵션), Phase 0(plan/analyze 자동 로드), Phase 1(TaskCreate), Phase 2-A(직접 구현), Phase 2-B(서브에이전트 병렬 위임), Phase 3(실제 명령 실행), Phase 4(메모리 보관), Phase 5(Self-Review), Phase 6(Finishing 4옵션 — suh-github PR 생성).

Grep 검증 통과: `HARD-GATE/보호 브랜치/Phase 0-0/Finishing` 18회, `suh-github/suh-init-worktree/suh-report` 9회, 금지단어 0회.

### Task 5: 통합 검증 + 커밋 + push — ✅ 완료

3 스킬 cross-reference 일관성·산출물 경로 일관성 확인 완료. 4 파일 커밋 (`4a84c50`):
- skills/suh-plan/SKILL.md
- skills/suh-analyze/SKILL.md
- skills/suh-implement/SKILL.md
- skills/references/self-review-checklist.md

(외부 도구가 main을 reset해 일시 손실됐으나 cherry-pick으로 322 브랜치에 복구. 새 커밋 `589e0f4`.)

---

## 검증 요약

각 SKILL.md 파일에서 다음 Grep 조건 모두 통과:

| 조건 | 파일 | 결과 |
|------|------|------|
| HARD-GATE 표식 | 3 SKILL.md | 모두 ≥2회 |
| Phase 구조 | 3 SKILL.md | -1~4 / 0-0~6 매치 |
| 금지 단어 (Redmine/PAD/SSH/GitLab/gitlab.somansa) | 3 SKILL.md | 0회 |
| GitHub 매핑 (suh-github/suh-init-worktree) | suh-plan + suh-implement | 매치 |
| Self-Review 체크리스트 참조 | 3 SKILL.md | 각 1회 |
| 산출물 경로 (docs/suh-template/{plan,analyze}/) | 3 SKILL.md | 매치 |

## 실행 결과 (2026-06-01)

본 plan은 자율 진행으로 5 Task 모두 완료됨.

- 최종 커밋: `589e0f4` (322 브랜치, cherry-pick 결과)
- 4 파일 변경: 736 insertions(+), 152 deletions(-)
