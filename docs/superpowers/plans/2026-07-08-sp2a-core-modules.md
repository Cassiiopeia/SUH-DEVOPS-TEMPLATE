# SP2-A (스캐폴딩 + core 순수 모듈) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Steps use checkbox (`- [ ]`) tracking.

**Goal:** Node CLI 패키지 스캐폴딩을 만들고, 외부 부수효과가 없는 **순수 로직 모듈**(exclusions·breaking·detect·version-yml·wizard-env·options)을 `node:test` 단위테스트와 함께 이식한다. 이 단계는 파일시스템 복사·네트워크·프롬프트를 건드리지 않는다.

**Architecture:** ESM. 각 core 모듈은 순수 함수 위주로 설계해 단위테스트 가능하게 한다. 공유 상태는 `context` 객체로 주입한다. `.sh`의 동작 명세(`docs/superpowers/plans/2026-07-08-sp2-behavior-spec.md`)와 구조맵을 기준으로 한다.

**Tech Stack:** Node >= 18, ESM, `node:test` + `node:assert`, 의존성: `yaml`(파싱 검증용, 재직렬화는 안 함), 나머지 core는 내장만.

**GitHub 이슈:** https://github.com/Cassiiopeia/projectops/issues/424
**마스터 스펙:** `docs/superpowers/specs/2026-07-08-sp2-node-cli-porting-design.md`

## Global Constraints

- ESM(`"type":"module"` 이미 설정됨). 파일 확장자 `.js`, import에 확장자 명시.
- **순수성**: SP2-A 모듈은 fs write·network·prompt 금지 (fs read는 테스트에서 픽스처 경로로만). 부수효과는 SP2-B/C/D.
- 단위테스트는 `test/` 하위. `node --test` 로 실행.
- develop 브랜치 직접 작업. push는 사용자 명시 요청 시에만.
- 커밋 메시지: `projectops npx CLI 전환 및 npm 배포 자동화 : feat : {설명} https://github.com/Cassiiopeia/projectops/issues/424` (이모지·태그·AI trailer 금지).
- **등가 기준**: 각 순수 함수는 .sh 대응 함수와 동일 입력→동일 출력. 명세 문서의 규칙을 그대로 구현.
- breaking-changes는 **버그 수정 포함**(D2): 비교 기준을 실제 템플릿 버전으로 (하드코딩 1.3.14 복제 안 함).

## File Structure

| 파일 | 책임 | 대응 .sh |
|------|------|---------|
| `src/context.js` | 공유 상태 객체 팩토리 + 기본값 | 전역 변수군 |
| `src/core/exclusions.js` | 복사 제외 데이터(docs_to_remove, plugin_items_to_remove) | download_template 내부 배열 |
| `src/core/breaking.js` | compareVersions, 범위 필터 (버그 수정판) | compare_versions, check_breaking_changes 로직부 |
| `src/core/version-yml.js` | version.yml 파싱(기존값 추출) + 생성 문자열 빌더 | detect의 version.yml 읽기 + create_version_yml |
| `src/core/detect.js` | 타입/버전/브랜치 감지 순수 로직 | detect_project_types, classify_package_json, detect_version, marker_for_type |
| `src/core/wizard-env.js` | @wizard 마커 파싱·치환·unchanged 비교 (라인 단위) | configure_workflow_env, _wf_is_unchanged, resolver |
| `test/*.test.js` | 각 모듈 단위테스트 | — |

---

### Task 1: 패키지 스캐폴딩 + context

**Files:**
- Create: `src/context.js`
- Modify: `package.json` (devDependencies 없음 — node:test 내장, dependencies에 `yaml` 추가는 SP2-B에서)

**Interfaces:**
- Produces: `createContext(overrides)` → `{mode, force, types:[], version:'', branch:'', paths:new Map(), includeNexus:null, includeSecretBackup:null, templateVersion:'', tempDir:'', deployValues:new Map(), counters:{}}`

- [ ] **Step 1: src/context.js 작성**

```js
// 마법사 전역 상태를 하나의 객체로 명시화 (bash 전역 변수군 대체)
export const VALID_TYPES = [
  "spring", "flutter", "next", "react",
  "react-native", "react-native-expo", "node", "python", "basic",
];

export const DEFAULT_VERSION = "1.3.14"; // .sh DEFAULT_VERSION (배너 폴백용 — breaking 비교엔 안 씀)

export function createContext(overrides = {}) {
  return {
    mode: "interactive",
    force: false,
    types: [],
    version: "",
    branch: "",
    paths: new Map(),        // type -> path
    includeNexus: null,      // null=미설정, true/false=명시
    includeSecretBackup: null,
    templateVersion: "",
    tempDir: "",
    deployValues: new Map(), // "type.KEY" -> value
    counters: {},
    ...overrides,
  };
}
```

- [ ] **Step 2: 스모크 테스트 작성 + 실행**

Create `test/context.test.js`:
```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { createContext, VALID_TYPES } from "../src/context.js";

test("createContext defaults", () => {
  const c = createContext();
  assert.equal(c.mode, "interactive");
  assert.equal(c.force, false);
  assert.ok(c.paths instanceof Map);
  assert.equal(VALID_TYPES.length, 9);
});

test("createContext overrides", () => {
  const c = createContext({ force: true, types: ["spring"] });
  assert.equal(c.force, true);
  assert.deepEqual(c.types, ["spring"]);
});
```

Run: `node --test test/context.test.js`
Expected: `pass 2`

- [ ] **Step 3: 커밋**

```bash
git add src/context.js test/context.test.js
git commit -m "projectops npx CLI 전환 및 npm 배포 자동화 : feat : SP2-A Node CLI context 상태 객체 스캐폴딩 https://github.com/Cassiiopeia/projectops/issues/424"
```

---

### Task 2: exclusions 데이터 모듈

**Files:**
- Create: `src/core/exclusions.js`
- Create: `test/exclusions.test.js`

**Interfaces:**
- Produces: `DOCS_TO_REMOVE:string[]`, `PLUGIN_ITEMS_TO_REMOVE:string[]`

- [ ] **Step 1: 실측으로 현재 배열 확정**

Run: `grep -A 20 "docs_to_remove=(" template_integrator.sh | head -25`
현재 코드에서 정확한 목록을 읽어 아래 상수로 옮긴다.

- [ ] **Step 2: src/core/exclusions.js 작성**

동작명세 §4.1 기준:
```js
// 템플릿 다운로드 후 제거하는 항목 — .sh download_template 내부 배열과 동기화
// ⚠️ CLAUDE.md "3곳 동시 수정" 규칙의 4번째 동기화 지점:
//    template_initializer.sh / template_integrator.sh / .ps1 / 이 파일
export const DOCS_TO_REMOVE = [
  "CONTRIBUTING.md",
  "CLAUDE.md",
  "AGENTS.md",
  "GEMINI.md",
  "gemini-extension.json",
];

export const PLUGIN_ITEMS_TO_REMOVE = [
  ".claude-plugin",
  ".codex-plugin",
  ".agents",
  ".cursor",
  "scripts",
  "package.json",
  "harness",
  "bin",
  "src",
  ".github/workflows/PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml",
  ".github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml",
];
// ⚠️ skills/ 는 제외하지 않는다 (Cursor 설치 소스로 보존)
```

- [ ] **Step 3: 테스트 — .sh 배열과 일치 검증**

Create `test/exclusions.test.js`: `PLUGIN_ITEMS_TO_REMOVE`에 `bin`·`src`·두 워크플로우 포함, `skills` 미포함 assert.
```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { PLUGIN_ITEMS_TO_REMOVE, DOCS_TO_REMOVE } from "../src/core/exclusions.js";

test("plugin items include CLI + npm workflows, exclude skills", () => {
  for (const x of ["bin", "src", ".claude-plugin", ".github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml"])
    assert.ok(PLUGIN_ITEMS_TO_REMOVE.includes(x), `missing ${x}`);
  assert.ok(!PLUGIN_ITEMS_TO_REMOVE.includes("skills"));
});
test("docs removed include CLAUDE.md", () => {
  assert.ok(DOCS_TO_REMOVE.includes("CLAUDE.md"));
});
```

Run: `node --test test/exclusions.test.js`
Expected: `pass 2`

- [ ] **Step 4: 커밋**

```bash
git add src/core/exclusions.js test/exclusions.test.js
git commit -m "projectops npx CLI 전환 및 npm 배포 자동화 : feat : SP2-A 복사 제외 목록 단일 소스 모듈 https://github.com/Cassiiopeia/projectops/issues/424"
```

---

### Task 3: breaking (버전 비교 + 범위 필터, 버그 수정판)

**Files:**
- Create: `src/core/breaking.js`
- Create: `test/breaking.test.js`

**Interfaces:**
- Consumes: 없음 (순수)
- Produces: `compareVersions(a,b) -> -1|0|1`, `collectBreaking(json, current, target) -> {critical:[], warnings:[]}`

- [ ] **Step 1: src/core/breaking.js 작성**

`.sh compare_versions`(2475행) 동작 그대로: v 접두 제거, `.` 분리, 3자리, 누락 자리=0, 숫자 비교.
```js
// .sh compare_versions 등가: v 접두 제거, 3자리 숫자 비교, 누락 자리=0
export function compareVersions(a, b) {
  const parse = (v) => String(v).replace(/^v/, "").split(".").map((n) => parseInt(n, 10) || 0);
  const pa = parse(a), pb = parse(b);
  for (let i = 0; i < 3; i++) {
    const x = pa[i] ?? 0, y = pb[i] ?? 0;
    if (x > y) return 1;
    if (x < y) return -1;
  }
  return 0;
}

// breaking-changes.json에서 current < ver <= target 범위 항목 수집.
// ⚠️ .sh 버그 수정: target은 하드코딩 1.3.14가 아니라 실제 templateVersion을 넘긴다 (D2).
// _ 로 시작하는 키(메타) 제외. severity critical / 그 외(warning).
export function collectBreaking(json, current, target) {
  const critical = [], warnings = [];
  for (const [ver, entry] of Object.entries(json || {})) {
    if (ver.startsWith("_")) continue;
    if (compareVersions(current, ver) < 0 && compareVersions(ver, target) <= 0) {
      const rec = { version: ver, ...entry };
      (entry?.severity === "critical" ? critical : warnings).push(rec);
    }
  }
  return { critical, warnings };
}
```

- [ ] **Step 2: 테스트**

Create `test/breaking.test.js`:
```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { compareVersions, collectBreaking } from "../src/core/breaking.js";

test("compareVersions", () => {
  assert.equal(compareVersions("1.2.3", "1.2.3"), 0);
  assert.equal(compareVersions("v2.0.0", "1.9.9"), 1);
  assert.equal(compareVersions("1.2", "1.2.0"), 0);   // 누락 자리=0
  assert.equal(compareVersions("1.0.0", "1.0.1"), -1);
});

test("collectBreaking range + bug fix (target beyond 1.3.14)", () => {
  const json = {
    _meta: { severity: "critical" },
    "3.0.0": { severity: "critical", title: "x" },   // .sh 버그였다면 1.3.14 초과라 누락됨
    "1.2.0": { severity: "warning", title: "y" },     // current 이하 → 제외
  };
  const { critical, warnings } = collectBreaking(json, "2.9.9", "3.0.5");
  assert.equal(critical.length, 1);   // 3.0.0 잡힘 (버그 수정 효과)
  assert.equal(warnings.length, 0);
});
```

Run: `node --test test/breaking.test.js`
Expected: `pass 2`

- [ ] **Step 3: 커밋**

```bash
git add src/core/breaking.js test/breaking.test.js
git commit -m "projectops npx CLI 전환 및 npm 배포 자동화 : feat : SP2-A breaking-changes 비교 모듈(하드코딩 버전 버그 수정 포함) https://github.com/Cassiiopeia/projectops/issues/424"
```

---

### Task 4: detect (타입/버전 감지 순수 로직)

**Files:**
- Create: `src/core/detect.js`
- Create: `test/detect.test.js` + `test/fixtures/` (마커 파일 픽스처)

**Interfaces:**
- Produces:
  - `classifyPackageJson(pkgObj) -> "react-native-expo"|"react-native"|"next"|"react"|"node"`
  - `detectTypesFromMarkers({has}) -> string[]` (has: (relpath)=>bool 주입)
  - `detectVersionFromFiles({read, hasJq}) -> string` (read: (relpath)=>string|null)
  - `markerForType(type) -> string`, `extraMarkers(type) -> string[]`

- [ ] **Step 1: src/core/detect.js 작성** (동작명세 §3.1·§3.3)

fs를 직접 안 읽고 주입받는 순수 함수로 설계 (테스트 용이). 명세 §3.1 package.json 분류 순서:
```js
// package.json 내용 분류 (동작명세 §3.1) — 문자열/키 존재 기준, 순서 중요
export function classifyPackageJson(pkg) {
  const s = JSON.stringify(pkg || {});
  if (s.includes("@react-native") || s.includes("react-native")) {
    return s.includes("expo") ? "react-native-expo" : "react-native";
  }
  const deps = { ...(pkg?.dependencies || {}), ...(pkg?.devDependencies || {}) };
  if ("next" in deps) return "next";
  if ("react" in deps) return "react";
  return "node";
}

// 마커 스캔 (동작명세 §3.1). has(relpath)=>bool 주입. node는 다른 타입 있으면 미추가.
export function detectTypesFromMarkers({ has, readJson }) {
  const types = [];
  if (has("pubspec.yaml")) types.push("flutter");
  if (has("build.gradle") || has("build.gradle.kts") || has("pom.xml")) types.push("spring");
  if (has("pyproject.toml") || has("setup.py") || has("requirements.txt")) types.push("python");
  if (has("package.json")) {
    const cls = classifyPackageJson(readJson("package.json") || {});
    if (cls === "node") { if (types.length === 0) types.push("node"); }
    else types.push(cls);
  }
  return types.length ? [...new Set(types)] : ["basic"];
}

const VERSION_RE = /^\d+\.\d+\.\d+$/;
// 버전 감지 (동작명세 §3.3) — 순서대로 첫 성공. read(relpath)=>string|null 주입.
export function detectVersionFromFiles({ read, readJson, hasJq, gitTag }) {
  const pkg = readJson?.("package.json");
  if (hasJq && pkg?.version && VERSION_RE.test(pkg.version)) return pkg.version;
  const grab = (content, re) => {
    for (const line of (content || "").split("\n")) {
      const m = line.match(re);
      if (m && VERSION_RE.test(m[1])) return m[1];
    }
    return null;
  };
  let v;
  if ((v = grab(read("build.gradle"), /version\s*=\s*["']?(\d+\.\d+\.\d+)/))) return v;
  if ((v = grab(read("pubspec.yaml"), /^version:\s*(\d+\.\d+\.\d+)/))) return v;
  if ((v = grab(read("pyproject.toml"), /version\s*=\s*["']?(\d+\.\d+\.\d+)/))) return v;
  if (gitTag) { const t = String(gitTag).replace(/^v/, ""); if (VERSION_RE.test(t)) return t; }
  return "0.0.1";
}

export function markerForType(type) {
  return { flutter: "pubspec.yaml", "react-native-expo": "app.json", python: "pyproject.toml", spring: "build.gradle" }[type] || "package.json";
}
export function extraMarkers(type) {
  return { python: ["setup.py", "requirements.txt"], spring: ["build.gradle.kts", "pom.xml"] }[type] || [];
}
```

- [ ] **Step 2: 테스트** — package.json 분류 5종, 마커 스캔(node 억제 규칙), 버전 감지 순서.

Create `test/detect.test.js`:
```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { classifyPackageJson, detectTypesFromMarkers, detectVersionFromFiles } from "../src/core/detect.js";

test("classifyPackageJson", () => {
  assert.equal(classifyPackageJson({ dependencies: { "react-native": "1", expo: "1" } }), "react-native-expo");
  assert.equal(classifyPackageJson({ dependencies: { "react-native": "1" } }), "react-native");
  assert.equal(classifyPackageJson({ dependencies: { next: "1", react: "1" } }), "next");
  assert.equal(classifyPackageJson({ dependencies: { react: "1" } }), "react");
  assert.equal(classifyPackageJson({ dependencies: { express: "1" } }), "node");
});

test("detectTypesFromMarkers suppresses node when other type present", () => {
  const has = (p) => ["build.gradle", "package.json"].includes(p);
  const readJson = () => ({ dependencies: { express: "1" } });
  assert.deepEqual(detectTypesFromMarkers({ has, readJson }), ["spring"]); // node 억제
});

test("detectTypesFromMarkers basic fallback", () => {
  assert.deepEqual(detectTypesFromMarkers({ has: () => false, readJson: () => null }), ["basic"]);
});

test("detectVersion order: gradle before pubspec", () => {
  const read = (p) => (p === "build.gradle" ? 'version = "1.2.3"' : p === "pubspec.yaml" ? "version: 9.9.9" : null);
  assert.equal(detectVersionFromFiles({ read, readJson: () => null, hasJq: false }), "1.2.3");
});

test("detectVersion fallback 0.0.1", () => {
  assert.equal(detectVersionFromFiles({ read: () => null, readJson: () => null, hasJq: false }), "0.0.1");
});
```

Run: `node --test test/detect.test.js`
Expected: `pass 5`

- [ ] **Step 3: 커밋**

```bash
git add src/core/detect.js test/detect.test.js
git commit -m "projectops npx CLI 전환 및 npm 배포 자동화 : feat : SP2-A 프로젝트 타입·버전 감지 순수 로직 모듈 https://github.com/Cassiiopeia/projectops/issues/424"
```

---

### Task 5: wizard-env (@wizard 마커 파싱·치환·unchanged 비교)

> 포팅 난이도 1위. **라인 단위 문자열 처리, YAML 파싱/재직렬화 금지** (동작명세 §4.5, 구조맵 §4.3-2).

**Files:**
- Create: `src/core/wizard-env.js`
- Create: `test/wizard-env.test.js`

**Interfaces:**
- Produces:
  - `parseWizardLine(line) -> {key, kind:'ask'|'auto'|null, arg} | null`
  - `substituteEnv(content, {values, repoName, projectPath}) -> string` (마커 치환 + 주석 제거 + 잔여 __TOKEN__ 처리)
  - `isUnchanged(templateContent, installedContent, opts) -> bool` (가상 기본값 치환 후 비교)

- [ ] **Step 1: 실측으로 마커·치환 규칙 확정**

Run: `sed -n '3200,3393p' template_integrator.sh` 로 `configure_workflow_env`·`_wf_is_unchanged` 실제 치환 코드를 읽어 정규식·순서를 그대로 옮긴다. (paths-anchor, ask/auto, __PROJECT_NAME__/__APP_ARTIFACT_NAME__ 전역치환 순서)

- [ ] **Step 2: src/core/wizard-env.js 작성** (Step 1 실측 반영)

동작명세 §4.5 기준 라인 단위 처리:
```js
// @wizard 마커 파싱 (동작명세 §4.5). env 라인 끝 주석에서 ask/auto/paths-anchor 추출.
const ASK_RE = /^(\s*)([A-Za-z0-9_]+):\s*"([^"]*)"\s*#\s*@wizard\s+ask:(.+)$/;
const AUTO_RE = /^(\s*)([A-Za-z0-9_]+):\s*"([^"]*)"\s*#\s*@wizard\s+auto:(.+)$/;
const PATHS_ANCHOR_RE = /#\s*@wizard\s+paths-anchor/;

export function parseWizardLine(line) {
  let m;
  if ((m = line.match(ASK_RE))) return { indent: m[1], key: m[2], kind: "ask", arg: m[4].trim() };
  if ((m = line.match(AUTO_RE))) return { indent: m[1], key: m[2], kind: "auto", arg: m[4].trim() };
  return null;
}

// 값 치환 + @wizard 주석 제거 (라인 단위, YAML 재직렬화 금지).
// values: Map<key,value>. paths-anchor는 projectPath!=='.'일 때 paths 라인으로 교체.
export function substituteEnv(content, { values = new Map(), repoName = "", projectPath = "." } = {}) {
  const out = content.split("\n").map((line) => {
    const p = parseWizardLine(line);
    if (p) {
      const val = values.get(p.key) ?? p.arg; // 기본값=마커 arg
      return `${p.indent}${p.key}: "${val}"`;
    }
    if (PATHS_ANCHOR_RE.test(line) && projectPath !== ".") {
      const indent = (line.match(/^(\s*)/) || ["", ""])[1];
      return `${indent}paths: ['${projectPath}/**']`;
    }
    return line;
  }).join("\n");
  // 잔여 전역 토큰
  return out
    .replaceAll("__PROJECT_NAME__", repoName)
    .replaceAll("__APP_ARTIFACT_NAME__", repoName);
}

// 설치본이 "기본값으로 치환한 템플릿 최종형"과 동일한지 (동작명세 §4.4).
export function isUnchanged(templateContent, installedContent, opts = {}) {
  const virtual = substituteEnv(templateContent, opts); // WF_USE_DEFAULTS=true 등가
  return virtual === installedContent;
}
```

주의: Step 1 실측에서 치환 순서·정규식이 위와 다르면 **실측을 정답으로** 조정 (명세는 요약, 코드가 진실).

- [ ] **Step 3: 테스트**

Create `test/wizard-env.test.js`:
```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseWizardLine, substituteEnv, isUnchanged } from "../src/core/wizard-env.js";

test("parseWizardLine ask/auto", () => {
  assert.equal(parseWizardLine('  KEY: "__X__"  # @wizard ask:default').kind, "ask");
  assert.equal(parseWizardLine('  KEY: "v"  # @wizard auto:repo').kind, "auto");
  assert.equal(parseWizardLine('  KEY: "v"'), null);
});

test("substituteEnv replaces value and strips comment", () => {
  const out = substituteEnv('  APP: "__X__"  # @wizard ask:myapp', { values: new Map([["APP", "chosen"]]) });
  assert.equal(out, '  APP: "chosen"');
});

test("substituteEnv uses default when no value", () => {
  const out = substituteEnv('  APP: "__X__"  # @wizard ask:myapp', {});
  assert.equal(out, '  APP: "myapp"');
});

test("paths-anchor replaced when path not root", () => {
  const out = substituteEnv("    # @wizard paths-anchor", { projectPath: "app" });
  assert.equal(out.trim(), "paths: ['app/**']");
});

test("isUnchanged: default-substituted template equals install", () => {
  const tpl = '  APP: "__X__"  # @wizard ask:myapp';
  assert.equal(isUnchanged(tpl, '  APP: "myapp"'), true);
  assert.equal(isUnchanged(tpl, '  APP: "other"'), false);
});
```

Run: `node --test test/wizard-env.test.js`
Expected: `pass 5`

- [ ] **Step 4: 커밋**

```bash
git add src/core/wizard-env.js test/wizard-env.test.js
git commit -m "projectops npx CLI 전환 및 npm 배포 자동화 : feat : SP2-A @wizard env 치환·unchanged 비교 엔진(라인 단위) https://github.com/Cassiiopeia/projectops/issues/424"
```

---

### Task 6: version-yml (파싱 + 생성 문자열 빌더)

> 전체 재생성 전략(D4). YAML 재직렬화 금지 — heredoc 등가 템플릿 문자열.

**Files:**
- Create: `src/core/version-yml.js`
- Create: `test/version-yml.test.js`

**Interfaces:**
- Produces:
  - `parseExisting(content) -> {version, versionCode, types:[], paths:Map, templateVersion}` (기존값 추출)
  - `buildVersionYml({version, types, paths, branch, versionCode, templateVersion, now}) -> string`

- [ ] **Step 1: 실측** — `sed -n '2181,2360p' template_integrator.sh` 로 create_version_yml 헤더 주석·필드 순서·문구를 정확히 확보(바이트 동일 목표).

- [ ] **Step 2: src/core/version-yml.js 작성** (동작명세 §5.1 + Step 1 실측 문자열)

`parseExisting`: `^version:` `^version_code:` `^project_types:` `project_paths:` 블록·`template:` 블록 내 version 을 grep 등가 정규식으로 추출. `buildVersionYml`: Step 1의 헤더 주석 + 필드를 그대로 조립 (`integrated_from: "projectops"`, `last_updated_by: "template_integrator"`).

- [ ] **Step 3: 테스트** — 왕복(roundtrip): buildVersionYml 출력 → parseExisting → 값 보존. 기존값 우선 규칙(version 보존).

Create `test/version-yml.test.js`:
```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { parseExisting, buildVersionYml } from "../src/core/version-yml.js";

test("roundtrip version/types/paths", () => {
  const yml = buildVersionYml({
    version: "1.2.3", types: ["spring", "react"], paths: new Map([["spring", "."]]),
    branch: "main", versionCode: 5, templateVersion: "3.0.188", now: "2026-07-08 00:00:00",
  });
  const p = parseExisting(yml);
  assert.equal(p.version, "1.2.3");
  assert.deepEqual(p.types, ["spring", "react"]);
  assert.equal(p.versionCode, 5);
});

test("parseExisting version is source of truth", () => {
  const p = parseExisting('version: "9.9.9"\nproject_types: ["basic"]\n');
  assert.equal(p.version, "9.9.9");
});
```

Run: `node --test test/version-yml.test.js`
Expected: `pass 2`

- [ ] **Step 4: 커밋**

```bash
git add src/core/version-yml.js test/version-yml.test.js
git commit -m "projectops npx CLI 전환 및 npm 배포 자동화 : feat : SP2-A version.yml 파싱·생성 빌더(전체 재생성 전략) https://github.com/Cassiiopeia/projectops/issues/424"
```

---

### Task 7: SP2-A 전체 검증 게이트

- [ ] **Step 1: 전체 테스트 실행**

Run: `node --test`
Expected: 모든 테스트 pass, fail 0.

- [ ] **Step 2: 실 데이터 대조 (wizard-env)** — 실제 워크플로우 파일 하나로 substituteEnv 검증

Run:
```bash
# @wizard 마커가 있는 실제 워크플로우 하나 찾기
grep -rl "@wizard ask:" .github/workflows/project-types/ | head -1
```
찾은 파일에 대해 Node로 substituteEnv(기본값) 실행 결과를, .sh `configure_workflow_env`를 WF_USE_DEFAULTS=true로 격리 실행한 결과와 `diff`로 비교. 불일치 시 wizard-env.js를 실측에 맞춰 조정(코드가 진실).

- [ ] **Step 3: 최종 커밋 (없으면 스킵)**

SP2-A 완료. 다음: SP2-B(assets·복사 엔진, 실제 파일트리 diff 0 게이트) 계획 작성.

## Self-Review 기록

1. **커버리지**: 마스터 스펙 SP2-A 산출물(exclusions·detect·version-yml·wizard-env·breaking·options) 중 options는 폴더스캔 의존이 커 SP2-B로 이관(순수부만 SP2-A). 나머지 5모듈+context 매핑.
2. **순수성**: 전 모듈 fs write·network·prompt 없음. detect/version-yml/wizard-env는 주입 기반이라 단위테스트 가능.
3. **버그 처리**: breaking Task 3에서 1.3.14 하드코딩 복제 안 하고 target 인자화(D2).
4. **실측 우선**: Task 5·6은 명세가 요약이므로 Step 1에서 실제 코드를 읽어 정답으로 삼도록 명시.
