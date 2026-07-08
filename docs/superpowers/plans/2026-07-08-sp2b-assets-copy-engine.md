# SP2-B (assets · 복사 엔진) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) tracking.

**Goal:** 템플릿 자산 획득(download)과 파일 복사 엔진(copy_workflows·copy_scripts·config·issue·discussion·coderabbit·gitignore·setup_guide·util)을 Node로 이식하고, **빈 폴더에 통합 실행 후 기존 `.sh` 결과와 파일트리 diff 0**으로 검증한다.

**Architecture:** SP2-A의 순수 모듈(wizard-env·version-yml·detect·exclusions)을 조합해 실제 파일시스템에 쓴다. 다운로드는 SP2-B에서 **로컬 소스 복사 방식**(git 인덱스 tree → TEMP)으로 먼저 구현해 네트워크 없이 등가 검증하고, codeload tarball은 SP2-E에서 확정한다(D7). 복사 충돌 정책은 카테고리별로 다르므로(동작명세 §4.2~4.7) 함수별로 정확히 재현한다.

**Tech Stack:** Node >= 18 ESM, `node:fs`, `node:path`, `node:child_process`(git clone/archive), `yaml`(설치), SP2-A 모듈.

**GitHub 이슈:** https://github.com/Cassiiopeia/projectops/issues/424
**마스터 스펙:** `docs/superpowers/specs/2026-07-08-sp2-node-cli-porting-design.md`
**동작 명세:** `docs/superpowers/plans/2026-07-08-sp2-behavior-spec.md` (§4 복사 규칙이 이 계획의 정답)

## Global Constraints

- develop 브랜치 작업. push는 사용자 명시 요청 시에만.
- 커밋 메시지: `projectops npx CLI 전환 및 npm 배포 자동화 : feat : {설명} https://github.com/Cassiiopeia/projectops/issues/424`
- **등가 기준**: 빈 폴더에 `--mode full --force --type <t>` 실행 → 기존 `.sh` 결과와 `diff -r` 빈 출력.
- **LF 기준 검증**: 소스는 `git show HEAD:` 또는 clone(=LF)로 얻는다. autocrlf 워킹트리 파일로 비교 금지.
- **격리**: 모든 검증은 스크래치 임시 폴더에서. `.sh` 실행은 서브셸 `( cd tmp && ... )`로 (루트 오염 방지, 실측).
- 복사 함수는 `context`(SP2-A) + 명시적 인자를 받고, 전역 의존을 끊는다.
- **충돌 정책 카테고리별 상이** (동작명세 §10-6): common=무조건 덮어쓰기 / secret-backup=절대 안 덮어씀 / nexus=.bak 후 덮어쓰기 / 타입별=3지선(force/비TTY는 "건너뛰기"). SP2-B는 `--force` 경로만 정확히 구현(대화형 3지선 메뉴는 SP2-C).
- `yaml` 의존성을 `dependencies`에 추가(내부망 미러 확인됨). `files` 화이트리스트에 `src/` 추가는 SP2-C(bin이 src를 쓸 때).

## File Structure

| 파일 | 책임 | 대응 .sh |
|------|------|---------|
| `src/core/paths.js` | 경로 상수(WORKFLOWS_DIR 등) + 마커·타입 폴더 규칙 | readonly 상수군 |
| `src/core/assets.js` | acquireTemplate(clone/local), cleanup, exclusion 적용 | download_template |
| `src/core/copy/simple.js` | copyScripts·copyConfig·copyIssue·copyDiscussion·copySetupGuide (무조건 덮어쓰기류) | 동명 함수 |
| `src/core/copy/gitignore.js` | ensureGitignore (정규화 비교 후 누락분 append) | ensure_gitignore |
| `src/core/copy/readme.js` | addVersionSectionToReadme (마커/패턴 검사 후 append) | add_version_section_to_readme |
| `src/core/copy/coderabbit.js` | copyCoderabbit (force: .bak 후 덮어쓰기) | copy_coderabbit_config |
| `src/core/copy/util.js` | copyUtilModules (타입별, force 자동) | copy_util_modules |
| `src/core/copy/workflows.js` | copyWorkflows (common/타입별/server-deploy/nexus/secret-backup + wizard env 치환) | copy_workflows, _copy_workflows_for_type |
| `test/copy-*.test.js` + `test/fixtures/` | 단위테스트 | — |
| `test/golden/*.sh` | 골든 픽스처 생성·비교 하네스 | — |

---

### Task 1: paths.js + fs 유틸

**Files:**
- Create: `src/core/paths.js`
- Create: `src/core/fsutil.js` (재귀 복사·존재 확인 등 공용)
- Create: `test/paths.test.js`

**Interfaces:**
- Produces: `PATHS = {tempDir:'.template_download_temp', versionFile:'version.yml', workflowsDir:'.github/workflows', scriptsDir:'.github/scripts', projectTypesDir:'project-types', ...}`, `WORKFLOW_PREFIX`, `WORKFLOW_COMMON_PREFIX`, `WORKFLOW_TEMPLATE_INIT`
- `fsutil`: `copyFileSync(src,dst)`, `copyDirSync(src,dst)`, `exists(p)`, `readText(p)`, `writeText(p,s)`, `listYamlFiles(dir)` (직하위 `.yaml`/`.yml`만)

- [ ] **Step 1: 실측 상수 확인**

Run: `grep -nE "^readonly (WORKFLOWS_DIR|SCRIPTS_DIR|PROJECT_TYPES_DIR|VERSION_FILE|WORKFLOW_PREFIX|WORKFLOW_COMMON_PREFIX|WORKFLOW_TEMPLATE_INIT)" template_integrator.sh`
읽은 값을 paths.js에 그대로 옮긴다.

- [ ] **Step 2: src/core/paths.js 작성**

```js
export const PATHS = {
  tempDir: ".template_download_temp",
  versionFile: "version.yml",
  workflowsDir: ".github/workflows",
  scriptsDir: ".github/scripts",
  projectTypesDir: "project-types",
};
export const WORKFLOW_PREFIX = "PROJECT";
export const WORKFLOW_COMMON_PREFIX = "PROJECT-COMMON";
export const WORKFLOW_TEMPLATE_INIT = "PROJECT-TEMPLATE-INITIALIZER.yaml";
```

- [ ] **Step 3: src/core/fsutil.js 작성** (node:fs 기반, LF 보존 — 바이너리 아닌 텍스트는 그대로 copyFileSync로 바이트 복사)

```js
import { cpSync, existsSync, readFileSync, writeFileSync, mkdirSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
export const exists = (p) => existsSync(p);
export const readText = (p) => readFileSync(p, "utf8");
export function writeText(p, s) { mkdirSync(dirname(p), { recursive: true }); writeFileSync(p, s); }
export function copyFileSync(src, dst) { mkdirSync(dirname(dst), { recursive: true }); cpSync(src, dst); }
export function copyDirSync(src, dst) { mkdirSync(dst, { recursive: true }); cpSync(src, dst, { recursive: true }); }
export function listYamlFiles(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true })
    .filter((e) => e.isFile() && /\.(ya?ml)$/.test(e.name))
    .map((e) => e.name).sort();
}
```

- [ ] **Step 4: 테스트 + 커밋**

Run: `node --test test/paths.test.js` → pass
```bash
git add src/core/paths.js src/core/fsutil.js test/paths.test.js
git commit -m "projectops npx CLI 전환 및 npm 배포 자동화 : feat : SP2-B 경로 상수·fs 유틸 모듈 https://github.com/Cassiiopeia/projectops/issues/424"
```

---

### Task 2: assets.js — 템플릿 획득 + 제외 적용

**Files:**
- Create: `src/core/assets.js`
- Create: `test/assets.test.js`

**Interfaces:**
- Consumes: `exclusions.js`(DOCS_TO_REMOVE·PLUGIN_ITEMS_TO_REMOVE), `PATHS`
- Produces:
  - `acquireTemplate({tempDir, source}) -> void` — source: `{type:'git', repo}` (git clone --depth 1) 또는 `{type:'local', path}` (로컬 트리 복사, 검증용). 완료 후 `applyExclusions(tempDir)` 호출.
  - `applyExclusions(tempDir) -> void` — DOCS_TO_REMOVE + PLUGIN_ITEMS_TO_REMOVE 삭제. `skills/`는 보존.
  - `readTemplateVersion(tempDir) -> string` — `tempDir/version.yml`의 `^version:`, 없으면 DEFAULT_VERSION.

- [ ] **Step 1: src/core/assets.js 작성** (동작명세 §4.1)

git clone은 `child_process.execFileSync("git", ["clone","--depth","1","--quiet",repo,tempDir])`. local은 `copyDirSync`. 제외는 각 항목을 `rmSync(join(tempDir,item), {recursive:true, force:true})`.

- [ ] **Step 2: 테스트** — local 소스로 획득 후 제외 확인 (fixtures에 가짜 .claude-plugin·skills·CLAUDE.md 만들고 실행 → .claude-plugin·CLAUDE.md 삭제, skills 잔존)

- [ ] **Step 3: 커밋**

---

### Task 3: 단순 복사 함수 (simple.js + gitignore + readme)

**Files:**
- Create: `src/core/copy/simple.js`, `src/core/copy/gitignore.js`, `src/core/copy/readme.js`
- Create: `test/copy-simple.test.js`, `test/copy-gitignore.test.js`, `test/copy-readme.test.js`

**Interfaces (동작명세 §4.7):**
- `copyScripts(tempDir) -> n` — version_manager.sh·changelog_manager.py 2개 무조건 덮어쓰기.
- `copyConfigFolder(tempDir)` — `.github/config` 전체 덮어쓰기. 없으면 스킵.
- `copyIssueTemplates(tempDir)` — `.github/ISSUE_TEMPLATE/` 전체 + `PULL_REQUEST_TEMPLATE.md` 덮어쓰기.
- `copyDiscussionTemplates(tempDir)` — `.github/DISCUSSION_TEMPLATE/` 전체. 없으면 스킵.
- `copySetupGuide(tempDir)` — `SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md` 루트로 덮어쓰기. 없으면 스킵.
- `ensureGitignore()` — 필수 `/.idea`,`/.claude/settings.local.json`. 정규화 비교 후 누락분만 "projectops: Auto-added entries" 섹션과 append. 파일 없으면 두 항목으로 신규 생성.
- `addVersionSectionToReadme(version)` — README 없으면 스킵. `<!-- AUTO-VERSION-SECTION` 마커 또는 `## (최신 버전|최신버전|Version|버전) : vX.Y.Z` 패턴 있으면 스킵. 없으면 append.

- [ ] **Step 1: 각 함수 실측** — `sed -n` 로 copy_scripts(3818)·copy_config(3845)·copy_issue(3872)·copy_discussion(3895)·copy_setup_guide(4114)·ensure_gitignore(4048)·add_version_section(2145) 정확한 로직·문구 확보.

- [ ] **Step 2: 구현** (실측 반영, LF 보존)

- [ ] **Step 3: 테스트** — fixtures로 각 함수 단위 검증 (특히 gitignore 정규화 비교, readme 마커 스킵)

- [ ] **Step 4: 커밋**

---

### Task 4: coderabbit + util (force 경로만)

**Files:**
- Create: `src/core/copy/coderabbit.js`, `src/core/copy/util.js`
- Create: `test/copy-coderabbit.test.js`, `test/copy-util.test.js`

**Interfaces (동작명세 §4.7):**
- `copyCoderabbit(tempDir, {force:true})` — 기존 없으면 복사, 있으면 (force) `.bak` 백업 후 덮어쓰기.
- `copyUtilModules(tempDir, type, {force:true})` — `tempDir/.github/util/<type>/` 있으면 (force) `.github/util/<type>/`로 전체 복사, 모듈 수 카운트.

- [ ] **Step 1: 실측** copy_coderabbit_config(3938)·copy_util_modules(4203)
- [ ] **Step 2: 구현 (force 분기만 — TTY 메뉴는 SP2-C)**
- [ ] **Step 3: 테스트 + 커밋**

---

### Task 5: copy_workflows (핵심 — 3분류 + wizard env)

> 가장 복잡. common(무조건 덮어쓰기) / 타입별·server-deploy(3분류: 신규 복사·unchanged 스킵·changed는 force면 "건너뛰기") / nexus(force면 .bak 덮어쓰기) / secret-backup(있으면 무조건 스킵). 각 복사 후 `configure_workflow_env` = SP2-A `substituteEnv` 적용.

**Files:**
- Create: `src/core/copy/workflows.js`
- Create: `test/copy-workflows.test.js`

**Interfaces (동작명세 §4.3~4.5):**
- `copyWorkflows(context, tempDir) -> counters` — context.types·paths·includeNexus·includeSecretBackup·force 사용.
  - (1) common `*.{yaml,yml}` 직하위 → unchanged면 스킵, 아니면 덮어쓰기.
  - (2) 타입별 `<type>/*.{yaml,yml}` → 신규 복사 / unchanged 스킵 / changed는 force면 스킵(기존 유지).
  - (3) server-deploy → includeNexus면 폴더째 제외, 아니면 (2)와 동일.
  - (4) nexus → includeNexus면 unchanged 스킵/기존.bak덮어쓰기/신규복사, 아니면 스킵.
  - (5) common/secret-backup → includeSecretBackup면 기존 있으면 스킵·신규만 복사, 아니면 스킵.
  - (6) 각 설치 파일에 `substituteEnv`(기본값, useDefaults) 적용 — unchanged 제외.
- unchanged 판정 = SP2-A `isUnchanged(templateContent, installedContent, {type, projectPath, repoName, resolvers})`.

- [ ] **Step 1: 실측** copy_workflows(3683)·_copy_workflows_for_type(3398) 전체 정독 — 3분류 순서·카운터·env 적용 시점 확인.
- [ ] **Step 2: 구현** (force 경로. resolvers는 repoName만 우선, spring-app-yml 등은 골든 검증에서 필요 시 추가)
- [ ] **Step 3: 단위 테스트** — fixtures 소형 워크플로우로 common 덮어쓰기·타입별 신규·secret-backup 스킵 검증
- [ ] **Step 4: 커밋**

---

### Task 6: full 모드 오케스트레이터 + 골든 픽스처 diff 0

**Files:**
- Create: `src/commands/full.js` (복사 순서 조립 — 동작명세 §4.2 full 순서)
- Create: `test/golden/run-golden.sh` (하네스), `test/golden.test.js`

**Interfaces:**
- `runFull(context, tempDir)` — create_version_yml → readme → copy_workflows → update_version_yml_deploy(있으면) → copy_scripts → copy_config → (타입별)copy_util → copy_issue → copy_discussion → copy_coderabbit → ensure_gitignore → copy_setup_guide → save_template_options.

- [ ] **Step 1: 골든 픽스처 하네스** — 스크래치에 대상 프로젝트 픽스처(spring/react/python/멀티) 빈 폴더 생성 + 각 타입 마커 파일. 소스 TEMP는 `git archive HEAD | tar -x`(LF)로 준비.

- [ ] **Step 2: `.sh` 골든 생성** (서브셸 격리)
```bash
( cd "$FIX/spring_sh" && set +e
  source "$ROOT/template_integrator.sh" 2>/dev/null || true
  # TEMP_DIR를 미리 만든 archive로 지정, FORCE_MODE=true, 대화형 스텁
  ... execute_integration )
```

- [ ] **Step 3: Node 실행** — 동일 픽스처에 `runFull(context, tempDir)`.

- [ ] **Step 4: diff 0 검증** — `diff -r "$FIX/spring_sh" "$FIX/spring_node"` 빈 출력. version.yml의 날짜 필드만 sed로 정규화 후 비교(now/today는 주입값 일치시킴).

- [ ] **Step 5: 4개 타입 전부 통과 확인 후 커밋**

## Self-Review 기록

1. **커버리지**: 동작명세 §4 복사 규칙 전부 태스크 매핑. update_version_yml_deploy(deploy 블록)는 wizard env ask 값이 있을 때만이라 Task 5~6에서 처리, 값 없으면 no-op.
2. **범위**: SP2-B는 `--force` 경로만. 대화형 3지선 메뉴·env 계획 질문은 SP2-C. 이 경계를 각 Task에 명시.
3. **검증**: Task 6 골든 diff 0이 최종 게이트. 단위테스트(Task 1~5)로 조기 발견.
4. **리스크**: resolvers(spring-app-yml 등)가 골든에서 필요하면 Task 5에서 추가. 초기엔 repo resolver만.
