# SP2-C 후반 (대화형 마법사) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) tracking.

**Goal:** 인자 없이 `npx projectops` 실행 시 대화형 마법사(모드 선택 → 정보 확인/수정 → 실행)가 뜨도록 한다. `@clack/prompts`로 화살표 메뉴를 구현하고, 비대화형 경로(SP2-C 1차)와 동일한 오케스트레이터를 재사용한다.

**Architecture:** `src/ui/prompts.js`가 clack 래핑(select·confirm·text·multiselect + ESC/취소 처리). `src/commands/interactive.js`가 `.sh interactive_mode` 흐름(§2)을 재현: 모드 선택 → 다운로드 → 감지 → 확인 화면(계속/수정/취소) → 수정 루프 → 해당 run* 위임. index.js가 mode=interactive면 이 커맨드로 라우팅.

**Tech Stack:** `@clack/prompts`(내부망 미러 확인됨), `picocolors`(색상). 기존 SP2-A~C 모듈.

**GitHub 이슈:** https://github.com/Cassiiopeia/projectops/issues/424
**동작 명세:** `docs/superpowers/plans/2026-07-08-sp2-behavior-spec.md` §2 (대화형 흐름)

## Global Constraints

- develop 브랜치 작업. push는 사용자 명시 요청 시에만.
- 커밋 메시지: `projectops npx CLI 전환 및 npm 배포 자동화 : feat : {설명} https://github.com/Cassiiopeia/projectops/issues/424`
- **비대화형 경로 무손상**: 대화형은 index.js에 mode 분기 추가만. 기존 --force 경로·70 테스트 회귀 없어야 함.
- `@clack/prompts`·`picocolors`를 `dependencies`에 추가 (npx 실행 시 자동 설치). node_modules는 .gitignore(완료).
- ESC/Ctrl+C 취소 = 정상 종료(exit 0), 에러 아님 (.sh 철학).
- **대화형은 실기 검증** — 골든 diff는 불가(입력 필요). 대신 clack의 select/confirm 스텁으로 흐름 단위테스트 + 수동 스모크.

## File Structure

| 파일 | 책임 |
|------|------|
| `src/ui/prompts.js` | clack 래핑: selectMode·confirmProject·editMenu·askText·askOptional·isCancel 처리 |
| `src/commands/interactive.js` | interactive_mode 흐름 (모드선택→다운로드→감지→확인/수정 루프→run*) |
| `src/index.js` (Modify) | mode=interactive면 runInteractive 라우팅. TTY 체크 |
| `package.json` (Modify) | dependencies에 @clack/prompts·picocolors |
| `test/interactive.test.js` | 흐름 단위테스트 (prompts 스텁) |

---

### Task 1: 의존성 추가 + ui/prompts.js

**Files:**
- Modify: `package.json` (dependencies)
- Create: `src/ui/prompts.js`
- Create: `test/prompts.test.js`

- [ ] **Step 1: 의존성 설치**
```bash
npm install @clack/prompts picocolors
```
`npm pack --dry-run`으로 node_modules 미포함(files 화이트리스트라 자동) 확인.

- [ ] **Step 2: src/ui/prompts.js 작성** — clack 래핑. 각 함수는 취소 시 특수값 반환(호출부가 exit 0).
  - `selectMode()` → 'full'|'version'|'workflows'|'issues'|'skills'|null(취소). 한국어 라벨.
  - `confirmProjectMenu(summary)` → 'continue'|'edit'|'cancel'.
  - `editMenu(ctx)` → 'type'|'version'|'branch'|'nexus'|'secret'|'done'|'back'.
  - `selectTypes(current)` → string[]|null (multiselect).
  - `askText(prompt, default)` → string.
  - `askYesNo(prompt, default)` → bool.
  - prompts를 주입 가능하게(테스트용): 모듈 상단에서 clack import하되, 함수는 얇게.

- [ ] **Step 3: 테스트** — clack을 모킹하기 어려우면 순수 매핑 로직(라벨→키)만 단위테스트. 나머지는 수동 스모크.

- [ ] **Step 4: 커밋**

---

### Task 2: commands/interactive.js — 대화형 흐름

**Files:**
- Create: `src/commands/interactive.js`

**Interfaces:**
- `runInteractive(baseContext, {cwd, source, clock, io}) -> exitCode`
  1. 배너 출력.
  2. `io.selectMode()` — null이면 "취소" exit 0.
  3. skills면 "SP2-D 예정" 안내 exit 1 (임시). issues면 정보수집 없이 다운로드→runIssues.
  4. full/version/workflows: acquireTemplate → 감지(detectTypes/Version/Branch) → 확인 루프:
     - summary 출력 → confirmProjectMenu → continue/edit/cancel.
     - edit면 editMenu 루프 (타입·버전·브랜치·nexus·secret 수정).
  5. 확정 후 해당 run*(context) 실행. tempDir 정리(finally).

- [ ] **Step 1: 구현** (io 주입으로 테스트 가능하게 — io = prompts 함수 묶음)
- [ ] **Step 2: index.js 수정** — mode=interactive면 TTY 확인 후 runInteractive. 비TTY면 기존 안내.
- [ ] **Step 3: 흐름 테스트** — io 스텁으로 "모드 full 선택 → continue → runFull 호출" 검증.
- [ ] **Step 4: 커밋**

---

### Task 3: 수동 스모크 + 정리

- [ ] **Step 1: 수동 스모크** — 실제 터미널에서 `node bin/projectops.js`(인자 없이) → 모드 메뉴 뜨는지, 취소·선택 동작. (사용자가 확인하거나 스크린샷)
- [ ] **Step 2: 비대화형 회귀** — `node --test` 70개 유지 + `--mode full --force` 여전히 동작.
- [ ] **Step 3: 최종 커밋**

SP2-C 완료 후: `npx projectops`(대화형) + `npx projectops --mode full --force`(비대화형) 둘 다 동작. 남음: SP2-D(IDE skills), SP2-E(OS매트릭스·컷오버).

## Self-Review 기록

1. **범위**: 대화형 UI만. 오케스트레이터는 SP2-C 1차 재사용. skills 모드는 SP2-D 유예(임시 안내).
2. **회귀 안전**: index.js에 분기 추가만, --force 경로 무손상.
3. **검증 한계**: 대화형은 골든 불가 → io 스텁 흐름 테스트 + 수동 스모크로 대체.
