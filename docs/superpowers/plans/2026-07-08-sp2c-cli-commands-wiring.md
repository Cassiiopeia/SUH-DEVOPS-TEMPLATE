# SP2-C (CLI · commands · bin 연결) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) tracking.

**Goal:** `bin/projectops.js`를 `src/index.js`(인자 파싱·모드 라우팅·통합 실행)에 연결해 **`npx projectops --mode <full|version|workflows|issues|skills> --force ...`가 실제로 동작**하게 만든다. 비대화형(`--force`) 경로를 완성하는 것이 SP2-C의 1차 목표. 대화형 메뉴(interactive_menu)는 SP2-C 후반 또는 SP2-D로 분리한다.

**Architecture:** SP2-A(순수 로직)·SP2-B(복사 엔진)를 조합한다. `index.js`가 argv→context를 만들고, 실제 프로젝트를 감지(detect)→다운로드(assets)→모드별 복사 오케스트레이터 실행. `bin/projectops.js`는 스텁 배너를 걷어내고 `index.js`를 호출한다. `files` 화이트리스트에 `src/` 추가(bin이 src를 import하므로).

**Tech Stack:** Node >= 18 ESM, `node:util parseArgs`(인자), 기존 SP2-A/B 모듈. 대화형은 `@clack/prompts`(SP2-C 후반).

**GitHub 이슈:** https://github.com/Cassiiopeia/projectops/issues/424
**마스터 스펙:** `docs/superpowers/specs/2026-07-08-sp2-node-cli-porting-design.md`
**동작 명세:** `docs/superpowers/plans/2026-07-08-sp2-behavior-spec.md` (§1 CLI, §4.2 모드별 순서)

## Global Constraints

- develop 브랜치 작업. push는 사용자 명시 요청 시에만.
- 커밋 메시지: `projectops npx CLI 전환 및 npm 배포 자동화 : feat : {설명} https://github.com/Cassiiopeia/projectops/issues/424`
- **비대화형 우선**: SP2-C 1차는 `--force` + 명시 플래그 경로만. 대화형 메뉴는 후반.
- **등가 기준**: `npx projectops --mode full --force --type <t>` == 기존 `.sh --mode full --force --type <t>` (SP2-B 골든 방식 재사용, 실제 통합 실행).
- `files`에 `src/` 추가 시 npm 패키지 크기 확인 (skills/docs/test 여전히 제외).
- CLI 플래그는 `.sh`와 100% 동일(--mode/--type/--version/--paths/--nexus/--secret-backup/--force/-h). 검증 없는 --version, 무효 --type exit 1 등 §1.1 규칙 준수.

## File Structure

| 파일 | 책임 | 대응 .sh |
|------|------|---------|
| `src/cli/args.js` | argv → {mode, types, version, paths, nexus, secretBackup, force, help} 파싱 + 검증 | top-level while-case 파싱 |
| `src/cli/help.js` | --help 텍스트 | show_help |
| `src/index.js` | 파싱 → 실 프로젝트 감지 → 다운로드 → 모드 라우팅 → 통합 실행 → 정리 | main + execute_integration |
| `src/commands/{version,workflows,issues}.js` | 모드별 복사 순서 (full의 부분집합) | execute_integration case |
| `src/core/detect-fs.js` | 실제 파일시스템 감지 래퍼 (detect.js 순수함수 + fs) | detect_project_types 등 실행부 |
| `bin/projectops.js` | 스텁 → index.js 호출로 교체 | 엔트리 |
| `package.json` | `files`에 `src/` 추가, `dependencies`에 yaml·@clack/prompts | — |
| `test/cli-*.test.js`, `test/golden-cli.*` | 인자 파싱 단위 + CLI E2E 골든 | — |

---

### Task 1: 인자 파싱 (args.js) + help

**Files:**
- Create: `src/cli/args.js`, `src/cli/help.js`
- Create: `test/cli-args.test.js`

**Interfaces (동작명세 §1.1):**
- `parseArgs(argv) -> {mode, types:[], version, paths:Map, includeNexus, includeSecretBackup, force, help}`
  - `--mode` 값 검증 없음(알 수 없는 모드는 통과 → 나중에 복사 0건). `--version` 형식 검증 없음.
  - `--type csv`: 공백 제거·중복 제거·VALID_TYPES 검증(무효/빈 → throw). 첫 항목 primary.
  - `--nexus`/`--no-nexus`, `--secret-backup`/`--no-secret-backup` → true/false, 미지정 null.
  - `--paths "t=p,..."` → Map. 타입 검증(무효 → throw). 경로 정규화(앞뒤 공백·`\`→`/`·끝 `/`·앞 `./` 제거·빈→`.`).
  - 알 수 없는 옵션 → throw (호출부에서 exit 1).

- [ ] **Step 1: 실측** `sed -n '830,920p' template_integrator.sh` 로 top-level 파싱·검증 확인.
- [ ] **Step 2: args.js 작성** (node:util parseArgs 또는 수동 루프)
- [ ] **Step 3: help.js** — show_help 텍스트 이식(플래그·예시).
- [ ] **Step 4: 테스트** — 모드/타입 csv/무효타입 throw/paths 정규화/nexus 플래그/알 수 없는 옵션 throw.
- [ ] **Step 5: 커밋**

---

### Task 2: 실 프로젝트 감지 래퍼 (detect-fs.js)

**Files:**
- Create: `src/core/detect-fs.js`
- Create: `test/detect-fs.test.js`

**Interfaces:**
- `detectTypes(root) -> string[]` — detect.js의 detectTypesFromMarkers를 fs has/read로 구동. version.yml 우선(source of truth).
- `detectVersion(root, {hasJq}) -> string` — detectVersionFromFiles를 fs로 구동.
- `detectDefaultBranch(root) -> string` — git symbolic-ref → remote show → "main" 폴백.
- `detectRepoName(root) -> string` — git remote get-url → 마지막 세그먼트, 실패 시 basename.

- [ ] **Step 1: 구현** (fs·child_process git 래핑, 순수함수에 주입)
- [ ] **Step 2: 테스트** — 픽스처 폴더로 타입·버전 감지, git 없는 폴더 폴백.
- [ ] **Step 3: 커밋**

---

### Task 3: 나머지 모드 오케스트레이터 (version/workflows/issues)

**Files:**
- Create: `src/commands/version.js`, `src/commands/workflows.js`, `src/commands/issues.js`
- Create: `test/commands.test.js`

**Interfaces (동작명세 §4.2):**
- `runVersion(context, tempDir, root)` — version.yml → readme → scripts → config → gitignore → setup_guide.
- `runWorkflows(context, tempDir, root)` — copy_workflows → scripts → config → util(타입별) → setup_guide.
- `runIssues(context, tempDir, root)` — issue → discussion 템플릿만.
- 전부 SP2-B 복사 함수 재사용. full.js와 공유 로직은 헬퍼로 추출.

- [ ] **Step 1: 구현** (full.js에서 공통 추출)
- [ ] **Step 2: 골든 검증** — version/workflows/issues 각각 .sh와 diff 0 (react 기준)
- [ ] **Step 3: 커밋**

---

### Task 4: index.js — 통합 실행 파이프라인

**Files:**
- Create: `src/index.js`
- Create: `test/index.test.js`

**Interfaces:**
- `run(argv, {cwd}) -> exitCode` — 전체 흐름:
  1. parseArgs. --help면 help 출력 exit 0.
  2. 실 프로젝트 감지 (types/version/branch/repoName) — CLI 인자 우선, 없으면 감지. version.yml 있으면 그 값 우선.
  3. acquireTemplate(git clone) → tempDir.
  4. 모드 라우팅: full/version/workflows/issues → 해당 run*. skills는 SP2-D(IDE)라 여기선 미지원 안내.
  5. tempDir 정리 (finally).
  6. exit 0.
- 비대화형 전제: TTY 없거나 --force 아니면 interactive 모드는 "SP2-C 후반 예정" 안내 + exit (또는 --force 요구).

- [ ] **Step 1: 구현** (감지→다운로드→라우팅→정리, try/finally cleanup)
- [ ] **Step 2: 테스트** — 각 모드 run() 호출 시 올바른 오케스트레이터 실행 (모킹 or 실 폴더)
- [ ] **Step 3: 커밋**

---

### Task 5: bin 연결 + package.json files

**Files:**
- Modify: `bin/projectops.js` (스텁 → index.js 호출)
- Modify: `package.json` (`files`에 src/ 추가, dependencies에 yaml·@clack/prompts)

- [ ] **Step 1: bin/projectops.js 교체**
```js
#!/usr/bin/env node
import { run } from "../src/index.js";
const code = await run(process.argv.slice(2), { cwd: process.cwd() });
process.exit(code);
```
(Node < 18 체크는 index.js 초입에서)

- [ ] **Step 2: package.json** — `"files": ["bin/", "src/"]`, `dependencies` 추가. `npm pack --dry-run`으로 skills/docs/test 미포함 확인.

- [ ] **Step 3: 스모크** — `node bin/projectops.js --help` / `--version` 동작.

- [ ] **Step 4: 커밋**

---

### Task 6: CLI E2E 골든 diff 0

**Files:**
- Create: `test/golden-cli/run.sh`

- [ ] **Step 1: E2E 하네스** — 빈 픽스처(react/spring)에서 `node bin/projectops.js --mode full --force --type <t>` 실행 (git clone 대신 local 소스 주입 or 실 clone). 기존 `.sh --mode full --force --type <t>`와 `diff -r`.
- [ ] **Step 2: react diff 0 확인** (SP2-B에서 이미 runFull 등가 증명 — CLI 배선 후에도 유지되는지)
- [ ] **Step 3: 최종 커밋**

SP2-C 완료 후: **`npx projectops --mode full --force --type react`가 실제 통합을 수행**한다. 남은 것: 대화형 메뉴(SP2-C 후반), IDE skills(SP2-D), OS 매트릭스·컷오버(SP2-E).

## Self-Review 기록

1. **커버리지**: 동작명세 §1 CLI·§4.2 모드 순서 매핑. skills 모드는 IDE라 SP2-D로 명시 분리.
2. **범위**: 비대화형(--force) 우선. 대화형은 명시적으로 후반/SP2-D 유예.
3. **검증**: Task 6 CLI E2E diff 0이 게이트. SP2-B runFull 등가가 토대.
4. **리스크**: `files`에 src/ 추가 시 patch 사용자에게 흘러가지 않는지 — src/는 이미 initializer/integrator 제외 목록(SP1)에 있어 안전.
