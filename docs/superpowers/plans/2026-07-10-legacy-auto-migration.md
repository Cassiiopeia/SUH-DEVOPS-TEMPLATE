# IDE 어댑터 레거시 자동 마이그레이션 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `npx projectops@latest`(=IDE 어댑터 `apply()`) 실행 시, 옛 이름(`cassiiopeia`/`SUH-DEVOPS-TEMPLATE`) 플러그인·마켓·config를 자동 감지·정리·이관하여 사용자가 수동으로 remove/add/install 하지 않게 한다.

**Architecture:** 공용 헬퍼 `src/core/ide/legacy.js`(버전 판정 + config 루트 이관)를 신설하고, 5개 어댑터(claude/codex/gemini/pi/cursor) 각각에 `migrateLegacy(io, ctx)`를 추가해 `apply()` 시작 시 호출한다. 정리는 조용히 자동 실행하고 로그만 남긴다. cursor는 somansa-tools 스킬과 폴더를 공유하므로 projectops 소유 항목만 선별 삭제한다(기존 `remove()` 통째삭제 버그도 동반 수정).

**Tech Stack:** Node.js ≥20.12 (ESM), `node:fs`, `node --test`(내장), 기존 `stubIo` 테스트 패턴.

## Global Constraints

- ESM 모듈 (`import`/`export`), Node ≥20.12. `Date.now()` 등 순수성 제약 없음(런타임 코드).
- 커밋 메시지·PR 본문에 **AI/Claude 흔적 절대 금지** (`Co-Authored-By`, `Generated with` 등). 커밋 컨벤션: `내용 : type : 상세`.
- 모든 정리 명령은 **실패 무해**(없는 것 제거 = no-op). config는 **복사만·삭제 안 함**.
- `migrateLegacy`/`migrateConfigRoot`는 **idempotent** (반복 실행 안전).
- 레거시 버전 기준점: `maxLegacyVersion = "4.2.4"` (4.2.5부터 신규).
- config 루트 우선순위: `~/.suh-template/config/config.json` → `~/.cassiiopeia/config.json` → 타겟 `~/.projectops/config/config.json`.
- io 인터페이스: `which(cmd)→path|null`, `run(cmd,args)→{code,stdout,stderr}`, `home()→string`, `log(msg)`.
- 테스트는 `test/ide.test.js`의 `stubIo` 패턴 사용. 실제 fs 검증은 `mkdtempSync`로 임시 home 생성.
- cursor 소유 판정: 소스 `skills/` 폴더명(`pro-*`,`references`,`config.json.example`) ∪ `/^suh-/` ∪ `cursor-skills-meta.json`. 그 외(접두어 없는 `analyze`·`gitlab` 등 somansa-tools) 보존.

---

### Task 1: 공용 헬퍼 `legacy.js` — 버전 판정 + config 루트 이관

**Files:**
- Create: `src/core/ide/legacy.js`
- Test: `test/ide-legacy.test.js` (신규)

**Interfaces:**
- Consumes: `compareCacheName` from `./util.js`
- Produces:
  - `isLegacyVersion(version: string|null, maxLegacy: string) => boolean`
  - `migrateConfigRoot(io) => { migrated: boolean, from?: string, reason?: string }`
  - `hasNonEmptyJson(path: string) => boolean` (내부 export, 테스트용)

- [ ] **Step 1: 실패 테스트 작성** — `test/ide-legacy.test.js`

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { isLegacyVersion, migrateConfigRoot, hasNonEmptyJson } from "../src/core/ide/legacy.js";
import { mkdtempSync, rmSync, mkdirSync, writeFileSync, existsSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

function stubIo({ home } = {}) {
  const logs = [];
  return { logs, home: () => home, log: (m) => logs.push(m), which: () => null, run: () => ({ code: 0, stdout: "", stderr: "" }) };
}

test("isLegacyVersion: 기준점 이하는 true, 초과는 false, null은 false", () => {
  assert.equal(isLegacyVersion("4.2.3", "4.2.4"), true);
  assert.equal(isLegacyVersion("4.2.4", "4.2.4"), true);
  assert.equal(isLegacyVersion("4.2.5", "4.2.4"), false);
  assert.equal(isLegacyVersion("5.0.0", "4.2.4"), false);
  assert.equal(isLegacyVersion(null, "4.2.4"), false);
  assert.equal(isLegacyVersion("", "4.2.4"), false);
});

test("hasNonEmptyJson: 존재+키있음 true, 없음/빈객체/깨짐 false", () => {
  const dir = mkdtempSync(join(tmpdir(), "hnj-"));
  try {
    const full = join(dir, "a.json"); writeFileSync(full, JSON.stringify({ k: 1 }));
    assert.equal(hasNonEmptyJson(full), true);
    const empty = join(dir, "b.json"); writeFileSync(empty, "{}");
    assert.equal(hasNonEmptyJson(empty), false);
    const broke = join(dir, "c.json"); writeFileSync(broke, "not json");
    assert.equal(hasNonEmptyJson(broke), false);
    assert.equal(hasNonEmptyJson(join(dir, "none.json")), false);
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test("migrateConfigRoot: 타겟 비었고 suh-template 소스 있으면 이관", () => {
  const home = mkdtempSync(join(tmpdir(), "mcr-"));
  try {
    mkdirSync(join(home, ".suh-template/config"), { recursive: true });
    writeFileSync(join(home, ".suh-template/config/config.json"), JSON.stringify({ github: { global_pat: "X" } }));
    const io = stubIo({ home });
    const r = migrateConfigRoot(io);
    assert.equal(r.migrated, true);
    const dst = join(home, ".projectops/config/config.json");
    assert.ok(existsSync(dst));
    assert.equal(JSON.parse(readFileSync(dst, "utf8")).github.global_pat, "X");
  } finally { rmSync(home, { recursive: true, force: true }); }
});

test("migrateConfigRoot: 타겟 이미 차있으면 skip (덮어쓰지 않음)", () => {
  const home = mkdtempSync(join(tmpdir(), "mcr2-"));
  try {
    mkdirSync(join(home, ".projectops/config"), { recursive: true });
    writeFileSync(join(home, ".projectops/config/config.json"), JSON.stringify({ keep: "me" }));
    mkdirSync(join(home, ".suh-template/config"), { recursive: true });
    writeFileSync(join(home, ".suh-template/config/config.json"), JSON.stringify({ github: { global_pat: "X" } }));
    const io = stubIo({ home });
    const r = migrateConfigRoot(io);
    assert.equal(r.migrated, false);
    assert.equal(r.reason, "target-exists");
    assert.equal(JSON.parse(readFileSync(join(home, ".projectops/config/config.json"), "utf8")).keep, "me");
  } finally { rmSync(home, { recursive: true, force: true }); }
});

test("migrateConfigRoot: cassiiopeia(1세대) 폴백 소스 이관", () => {
  const home = mkdtempSync(join(tmpdir(), "mcr3-"));
  try {
    writeFileSync(join(home, ".cassiiopeia.json"), ""); // noise
    mkdirSync(join(home, ".cassiiopeia"), { recursive: true });
    writeFileSync(join(home, ".cassiiopeia/config.json"), JSON.stringify({ github: { global_pat: "Y" } }));
    const io = stubIo({ home });
    const r = migrateConfigRoot(io);
    assert.equal(r.migrated, true);
    assert.equal(JSON.parse(readFileSync(join(home, ".projectops/config/config.json"), "utf8")).github.global_pat, "Y");
  } finally { rmSync(home, { recursive: true, force: true }); }
});

test("migrateConfigRoot: 소스 없으면 no-source", () => {
  const home = mkdtempSync(join(tmpdir(), "mcr4-"));
  try {
    const io = stubIo({ home });
    assert.equal(migrateConfigRoot(io).reason, "no-source");
  } finally { rmSync(home, { recursive: true, force: true }); }
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `node --test test/ide-legacy.test.js`
Expected: FAIL — "Cannot find module '../src/core/ide/legacy.js'"

- [ ] **Step 3: `src/core/ide/legacy.js` 구현**

```js
// IDE 어댑터 공용 레거시 유틸 — 버전 판정 + config 루트 이관.
// 리브랜딩(#459) 전 설치본(cassiiopeia/SUH-DEVOPS-TEMPLATE)을 신규(projectops)로 넘길 때 공용.
import { join, dirname } from "node:path";
import { existsSync, readFileSync, mkdirSync, cpSync } from "node:fs";
import { compareCacheName } from "./util.js";

// version <= maxLegacy 이면 레거시. null/빈문자열은 판정 불가 → false(안전).
export function isLegacyVersion(version, maxLegacy) {
  if (!version || !maxLegacy) return false;
  return compareCacheName(String(version), String(maxLegacy)) <= 0;
}

// 파일이 존재하고 JSON 파싱되며 최소 1개 키가 있으면 true.
export function hasNonEmptyJson(path) {
  if (!path || !existsSync(path)) return false;
  try {
    const o = JSON.parse(readFileSync(path, "utf8"));
    return o && typeof o === "object" && Object.keys(o).length > 0;
  } catch { return false; }
}

// config 루트 이관: 타겟(~/.projectops/config/config.json)이 비었을 때만 옛 경로에서 복사.
// 옛 파일은 삭제하지 않음(민감값 보존). idempotent.
export function migrateConfigRoot(io) {
  const target = join(io.home(), ".projectops", "config", "config.json");
  if (hasNonEmptyJson(target)) return { migrated: false, reason: "target-exists" };
  const sources = [
    join(io.home(), ".suh-template", "config", "config.json"), // 2세대 우선
    join(io.home(), ".cassiiopeia", "config.json"),            // 1세대 폴백
  ];
  const src = sources.find(hasNonEmptyJson);
  if (!src) return { migrated: false, reason: "no-source" };
  try {
    mkdirSync(dirname(target), { recursive: true });
    cpSync(src, target);
    io.log(`  config 마이그레이션 완료: ${src} → ~/.projectops/config/config.json`);
    return { migrated: true, from: src };
  } catch (e) {
    io.log(`  config 마이그레이션 실패(무시): ${e.message}`);
    return { migrated: false, reason: "error" };
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `node --test test/ide-legacy.test.js`
Expected: PASS (6 tests)

- [ ] **Step 5: 커밋**

```bash
git add src/core/ide/legacy.js test/ide-legacy.test.js
git commit -m "IDE 어댑터 공용 레거시 헬퍼 추가 : feat : isLegacyVersion·migrateConfigRoot·hasNonEmptyJson(옛 config 루트 자동 이관, idempotent)"
```

---

### Task 2: claude 어댑터 — 레거시 플러그인·마켓 정리

**Files:**
- Modify: `src/core/ide/adapters/claude.js`
- Test: `test/ide-legacy.test.js` (Task 1 파일에 추가)

**Interfaces:**
- Consumes: `migrateConfigRoot`, `isLegacyVersion` from `../legacy.js`
- Produces: `apply(io, ctx)`가 install/update 전에 `migrateLegacy(io)` + `migrateConfigRoot(io)` 호출

- [ ] **Step 1: 실패 테스트 추가** — `test/ide-legacy.test.js` 하단에 append

```js
import { adapterById } from "../src/core/ide/registry.js";

// claude용 stubIo (which/run/home/log + run 호출 기록)
function claudeIo({ present = { claude: 1 }, listJson = "[]", home } = {}) {
  const calls = [], logs = [];
  return {
    calls, logs,
    which: (c) => (present[c] ? `/usr/bin/${c}` : null),
    run: (c, a = []) => {
      const key = [c, ...a].join(" "); calls.push(key);
      if (key.includes("plugin list")) return { code: 0, stdout: listJson, stderr: "" };
      return { code: 0, stdout: "", stderr: "" };
    },
    home: () => home || "/home/x", log: (m) => logs.push(m),
  };
}

test("claude migrateLegacy: 옛 cassiiopeia 플러그인 감지 시 uninstall+marketplace remove", () => {
  const listJson = JSON.stringify([{ name: "cassiiopeia@cassiiopeia-marketplace", scope: "user", version: "4.2.3" }]);
  const io = claudeIo({ listJson });
  adapterById("claude").apply(io);
  assert.ok(io.calls.some((c) => c.includes("plugin uninstall cassiiopeia@cassiiopeia-marketplace")), "옛 플러그인 uninstall 호출");
  assert.ok(io.calls.some((c) => c.includes("marketplace remove cassiiopeia-marketplace")), "옛 마켓 remove 호출");
  // 정리 후 신규 install 경로도 실행
  assert.ok(io.calls.some((c) => c.includes("plugin install projectops@projectops-marketplace")));
});

test("claude migrateLegacy: 옛것 없으면 정리 명령 미호출", () => {
  const io = claudeIo({ listJson: "[]" });
  adapterById("claude").apply(io);
  assert.ok(!io.calls.some((c) => c.includes("uninstall cassiiopeia")), "불필요한 uninstall 없음");
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `node --test test/ide-legacy.test.js`
Expected: FAIL — "옛 플러그인 uninstall 호출" (migrateLegacy 미구현)

- [ ] **Step 3: `claude.js` 수정**

기존 import 라인(`import { compareCacheName } from "../util.js";`) 아래에 추가:
```js
import { migrateConfigRoot } from "../legacy.js";
```

기존 `LEGACY`가 없으므로 `const PLUGIN = ...` 아래에 추가:
```js
const LEGACY_PLUGINS = ["cassiiopeia@cassiiopeia-marketplace", "cassiiopeia"];
const LEGACY_MARKETPLACES = ["cassiiopeia-marketplace"];
```

`apply` 함수를 다음으로 교체:
```js
function apply(io, ctx = {}) {
  const st = detect(io);
  if (st.cliMissing) { io.log(manualHint(io)); return false; }
  migrateLegacy(io);          // 옛 플러그인/마켓 정리
  migrateConfigRoot(io);      // 공용 config 루트 이관
  const st2 = detect(io);     // 정리 후 재감지
  if (st2.installed) return update(io, st2.scope);
  return install(io, "user");
}

// 옛 이름(cassiiopeia) 플러그인·마켓 정리. 조용히, 로그만. 실패 무해.
function migrateLegacy(io) {
  const r = io.run("claude", ["plugin", "list", "--json"]);
  let list = [];
  try { const arr = JSON.parse(r.stdout || "[]"); list = Array.isArray(arr) ? arr : (arr.plugins || []); } catch { /* 무시 */ }
  for (const legacy of LEGACY_PLUGINS) {
    const hit = list.find((p) => String(p.name || p.id || "") === legacy || String(p.name || p.id || "").startsWith(legacy + "@"));
    if (hit) {
      const scope = hit.scope || "user";
      io.log(`  레거시 플러그인 정리: ${legacy} (scope: ${scope})`);
      io.run("claude", ["plugin", "uninstall", legacy, "--scope", scope]);
    }
  }
  for (const mp of LEGACY_MARKETPLACES) {
    io.run("claude", ["plugin", "marketplace", "remove", mp]); // 없으면 no-op
  }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `node --test test/ide-legacy.test.js`
Expected: PASS (전체 8 tests)

- [ ] **Step 5: 기존 ide.test.js 회귀 확인**

Run: `node --test test/ide.test.js`
Expected: PASS (기존 claude apply install/update 테스트 무손상 — migrateLegacy는 옛것 없을 때 no-op이므로 기존 흐름 유지)

- [ ] **Step 6: 커밋**

```bash
git add src/core/ide/adapters/claude.js test/ide-legacy.test.js
git commit -m "claude 어댑터 레거시 자동 정리 : feat : apply 시 옛 cassiiopeia 플러그인·마켓 감지 후 uninstall+remove, config 루트 이관 호출"
```

---

### Task 3: codex 어댑터 — 옛 native skills·marketplace 정리

**Files:**
- Modify: `src/core/ide/adapters/codex.js`
- Test: `test/ide-legacy.test.js`

**Interfaces:**
- Consumes: `migrateConfigRoot` from `../legacy.js`
- Produces: `apply(io)`가 install 전에 `migrateLegacy(io)` + `migrateConfigRoot(io)` 호출

- [ ] **Step 1: 실패 테스트 추가**

```js
import { mkdtempSync as mkd2 } from "node:fs"; // 이미 상단 import 있으면 생략

test("codex migrateLegacy: 옛 SUH-DEVOPS-TEMPLATE native 심링크/폴더 제거", () => {
  const home = mkdtempSync(join(tmpdir(), "cdx-"));
  try {
    mkdirSync(join(home, ".agents/skills/SUH-DEVOPS-TEMPLATE"), { recursive: true });
    writeFileSync(join(home, ".agents/skills/SUH-DEVOPS-TEMPLATE/x.md"), "x");
    const calls = [];
    const io = {
      calls, logs: [],
      which: (c) => (c === "codex" ? "/usr/bin/codex" : null),
      run: (c, a = []) => { calls.push([c, ...a].join(" ")); return { code: 0, stdout: "", stderr: "" }; },
      home: () => home, log: () => {},
    };
    adapterById("codex").apply(io);
    assert.equal(existsSync(join(home, ".agents/skills/SUH-DEVOPS-TEMPLATE")), false, "옛 native 폴더 제거됨");
    assert.ok(calls.some((c) => c.includes("marketplace remove SUH-DEVOPS-TEMPLATE")), "옛 마켓 remove 호출");
  } finally { rmSync(home, { recursive: true, force: true }); }
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `node --test test/ide-legacy.test.js`
Expected: FAIL — "옛 native 폴더 제거됨"

- [ ] **Step 3: `codex.js` 수정**

import에 추가:
```js
import { migrateConfigRoot } from "../legacy.js";
```
`const PLUGIN = "projectops";` 아래 추가:
```js
const LEGACY_NATIVES = ["SUH-DEVOPS-TEMPLATE"];
const LEGACY_MARKETPLACES = ["SUH-DEVOPS-TEMPLATE"];
```
`apply` 함수 시작부에 migrateLegacy/config 호출 추가:
```js
function apply(io) {
  if (!io.which("codex")) { io.log(manualHint()); return false; }
  migrateLegacy(io);
  migrateConfigRoot(io);
  io.log("Codex plugin marketplace 등록 중...");
  const add = io.run("codex", ["plugin", "marketplace", "add", MARKETPLACE]);
  io.log(add.code === 0 ? "  Codex marketplace 등록 완료" : "  Codex marketplace 이미 등록되어 있거나 등록 생략");
  io.log("Codex plugin marketplace 업데이트 중...");
  if (io.run("codex", ["plugin", "marketplace", "upgrade", PLUGIN]).code === 0) { io.log("  Codex marketplace 등록 완료 (/plugins 확인)"); return true; }
  io.log(`  Codex marketplace 관리 오류 — 수동: codex plugin marketplace add ${MARKETPLACE}`);
  return false;
}

// 옛 native skills 폴더/심링크 + 옛 marketplace 정리.
function migrateLegacy(io) {
  for (const name of LEGACY_NATIVES) {
    const old = join(io.home(), ".agents/skills", name);
    if (existsSync(old) || isSymlink(old)) {
      try { rmSync(old, { recursive: true, force: true }); io.log(`  레거시 Codex skills 정리: ${name}`); } catch { /* 무시 */ }
    }
  }
  if (io.which("codex")) for (const mp of LEGACY_MARKETPLACES) io.run("codex", ["plugin", "marketplace", "remove", mp]);
}
```
> `existsSync`·`rmSync`·`lstatSync`·`join`은 codex.js가 이미 import 중. `isSymlink`도 이미 정의됨.

- [ ] **Step 4: 테스트 통과 확인**

Run: `node --test test/ide-legacy.test.js`
Expected: PASS

- [ ] **Step 5: 회귀 확인**

Run: `node --test test/ide.test.js`
Expected: PASS

- [ ] **Step 6: 커밋**

```bash
git add src/core/ide/adapters/codex.js test/ide-legacy.test.js
git commit -m "codex 어댑터 레거시 자동 정리 : feat : apply 시 옛 SUH-DEVOPS-TEMPLATE native skills·marketplace 제거, config 루트 이관"
```

---

### Task 4: gemini 어댑터 — 옛 extension 정리

**Files:**
- Modify: `src/core/ide/adapters/gemini.js`
- Test: `test/ide-legacy.test.js`

**Interfaces:**
- Consumes: `migrateConfigRoot` from `../legacy.js`
- Produces: `apply(io)`가 update/install 전에 `migrateLegacy(io)` + `migrateConfigRoot(io)` 호출

- [ ] **Step 1: 실패 테스트 추가**

```js
test("gemini migrateLegacy: 옛 extension uninstall 호출", () => {
  const calls = [];
  const io = {
    calls, logs: [],
    which: (c) => (c === "gemini" ? "/usr/bin/gemini" : null),
    run: (c, a = []) => { calls.push([c, ...a].join(" ")); return { code: 0, stdout: "", stderr: "" }; },
    home: () => "/home/x", log: () => {},
  };
  adapterById("gemini").apply(io);
  assert.ok(calls.some((c) => c.includes("extensions uninstall SUH-DEVOPS-TEMPLATE")), "옛 extension uninstall");
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `node --test test/ide-legacy.test.js`
Expected: FAIL — "옛 extension uninstall"

- [ ] **Step 3: `gemini.js` 수정**

`const URL = ...` 아래 추가 + import:
```js
import { migrateConfigRoot } from "../legacy.js";
const LEGACY_EXTS = ["SUH-DEVOPS-TEMPLATE"];
```
`apply` 시작부 수정:
```js
function apply(io) {
  if (!io.which("gemini")) { io.log(manualHint()); return false; }
  migrateLegacy(io);
  migrateConfigRoot(io);
  io.log("Gemini CLI extension 업데이트 중...");
  if (io.run("gemini", ["extensions", "update", EXT]).code === 0) { io.log("  Gemini CLI extension 업데이트 완료"); return true; }
  io.log("Gemini CLI extension 설치 중...");
  if (io.run("gemini", ["extensions", "install", URL]).code === 0) { io.log("  Gemini CLI extension 설치 완료"); return true; }
  io.log(`  Gemini extension 관리 오류 — 수동: gemini extensions install ${URL}`);
  return false;
}

// 옛 이름 extension 정리. 없으면 실패 무시.
function migrateLegacy(io) {
  for (const e of LEGACY_EXTS) io.run("gemini", ["extensions", "uninstall", e]);
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `node --test test/ide-legacy.test.js`
Expected: PASS

- [ ] **Step 5: 회귀 확인**

Run: `node --test test/ide.test.js`
Expected: PASS (기존 "gemini: update 실패 시 install 폴백" 테스트 무손상 — migrateLegacy는 앞에 uninstall 1건 추가할 뿐 update/install 순서 유지)

- [ ] **Step 6: 커밋**

```bash
git add src/core/ide/adapters/gemini.js test/ide-legacy.test.js
git commit -m "gemini 어댑터 레거시 자동 정리 : feat : apply 시 옛 SUH-DEVOPS-TEMPLATE extension uninstall, config 루트 이관"
```

---

### Task 5: pi 어댑터 — 옛 clone dir + harness loader 정리

**Files:**
- Modify: `src/core/ide/adapters/pi.js`, `src/core/ide/adapters/pi-common.js`
- Test: `test/ide-legacy.test.js`

**Interfaces:**
- Consumes: `migrateConfigRoot` from `../legacy.js`; `piSettingsPath` from `./pi-common.js`
- Produces: `pi-common.js`에 `migratePiLegacy(io) => void` export; `pi.js` `apply`가 호출

- [ ] **Step 1: 실패 테스트 추가**

```js
test("pi migrateLegacy: 신·구 clone 공존 시 옛 SUH-DEVOPS-TEMPLATE 제거 + settings loader 정리", () => {
  const home = mkdtempSync(join(tmpdir(), "pi-"));
  try {
    const base = join(home, ".pi/agent/git/github.com/Cassiiopeia");
    mkdirSync(join(base, "SUH-DEVOPS-TEMPLATE/harness"), { recursive: true });
    writeFileSync(join(base, "SUH-DEVOPS-TEMPLATE/harness/harness-loader.ts"), "x");
    mkdirSync(join(base, "projectops/harness"), { recursive: true });
    writeFileSync(join(base, "projectops/harness/harness-loader.ts"), "y");
    mkdirSync(join(home, ".pi/agent"), { recursive: true });
    const oldLoader = join(base, "SUH-DEVOPS-TEMPLATE/harness/harness-loader.ts");
    writeFileSync(join(home, ".pi/agent/settings.json"), JSON.stringify({ extensions: [oldLoader, "other"] }));
    const io = { which: (c) => (c === "pi" ? "/usr/bin/pi" : null), run: () => ({ code: 0, stdout: "projectops", stderr: "" }), home: () => home, log: () => {} };
    import("../src/core/ide/adapters/pi-common.js").then(({ migratePiLegacy }) => {});
    adapterById("pi").apply(io);
    assert.equal(existsSync(join(base, "SUH-DEVOPS-TEMPLATE")), false, "옛 clone 제거됨");
    const settings = JSON.parse(readFileSync(join(home, ".pi/agent/settings.json"), "utf8"));
    assert.ok(!settings.extensions.includes(oldLoader), "settings에서 옛 loader 제거");
    assert.ok(settings.extensions.includes("other"), "무관 항목 보존");
  } finally { rmSync(home, { recursive: true, force: true }); }
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `node --test test/ide-legacy.test.js`
Expected: FAIL — "옛 clone 제거됨"

- [ ] **Step 3: `pi-common.js`에 `migratePiLegacy` 추가**

import에 `rmSync` 추가 (`readFileSync, writeFileSync` 옆):
```js
import { existsSync, readFileSync, writeFileSync, rmSync } from "node:fs";
```
파일 하단에 추가:
```js
// 신·구 clone 공존 시 옛 SUH-DEVOPS-TEMPLATE clone 제거 + settings.json에서 그 loader 경로 제거.
export function migratePiLegacy(io) {
  const base = join(io.home(), ".pi/agent/git/github.com/Cassiiopeia");
  const oldDir = join(base, "SUH-DEVOPS-TEMPLATE");
  const newDir = join(base, "projectops");
  if (!(existsSync(oldDir) && existsSync(newDir))) return; // 공존일 때만 정리
  const oldLoader = join(oldDir, "harness/harness-loader.ts");
  const settings = piSettingsPath(io);
  if (existsSync(settings)) {
    try {
      const s = JSON.parse(readFileSync(settings, "utf8"));
      if (Array.isArray(s.extensions)) {
        s.extensions = s.extensions.filter((e) => e && e !== oldLoader);
        writeFileSync(settings, JSON.stringify(s, null, 2));
      }
    } catch { /* 무시 */ }
  }
  try { rmSync(oldDir, { recursive: true, force: true }); io.log("  레거시 PI clone 정리: SUH-DEVOPS-TEMPLATE"); } catch { /* 무시 */ }
}
```

- [ ] **Step 4: `pi.js` `apply` 수정**

import 수정:
```js
import { PI_PACKAGE_URL, piInstalled, harnessEnabled, harnessRemove, migratePiLegacy } from "./pi-common.js";
import { migrateConfigRoot } from "../legacy.js";
```
`apply` 시작부에 추가 (`if (!io.which("pi"))` 체크 직후):
```js
function apply(io) {
  if (!io.which("pi")) { io.log(manualHint()); return false; }
  migratePiLegacy(io);
  migrateConfigRoot(io);
  if (piInstalled(io)) {
    io.log("PI 패키지 업데이트 중...");
    if (io.run("pi", ["update", PI_PACKAGE_URL]).code !== 0) io.run("pi", ["install", PI_PACKAGE_URL]);
  } else {
    io.log("PI 패키지 설치 중...");
    io.run("pi", ["install", PI_PACKAGE_URL]);
  }
  if (piInstalled(io)) {
    io.log("  PI 패키지 설치 / 업데이트 완료");
    io.log("  → 'pi' 재실행 후 'pi list' 로 확인, 채팅창에서 /projectops:analyze 등 호출");
    return true;
  }
  io.log(`  PI 설치/업데이트 실패 — 수동: pi install ${PI_PACKAGE_URL}`);
  return false;
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `node --test test/ide-legacy.test.js`
Expected: PASS

- [ ] **Step 6: 회귀 확인**

Run: `node --test test/ide.test.js`
Expected: PASS

- [ ] **Step 7: 커밋**

```bash
git add src/core/ide/adapters/pi.js src/core/ide/adapters/pi-common.js test/ide-legacy.test.js
git commit -m "pi 어댑터 레거시 자동 정리 : feat : 신·구 clone 공존 시 옛 SUH-DEVOPS-TEMPLATE clone·harness loader 제거, config 루트 이관"
```

---

### Task 6: cursor 어댑터 — 선별 삭제 + remove 버그 수정

**Files:**
- Modify: `src/core/ide/adapters/cursor.js`
- Test: `test/ide-legacy.test.js`

**Interfaces:**
- Consumes: `migrateConfigRoot`, `isLegacyVersion` from `../legacy.js`
- Produces: `ownedEntries(io, ctx) => string[]`(내부), `migrateLegacy(io, ctx)`, 수정된 `remove(io, ctx)`

- [ ] **Step 1: 실패 테스트 추가** — 핵심: somansa-tools 보존 검증

```js
test("cursor migrateLegacy: 옛 이름/버전 meta면 projectops 소유만 선별 삭제 (somansa-tools 보존)", () => {
  const home = mkdtempSync(join(tmpdir(), "cur-"));
  const src = mkdtempSync(join(tmpdir(), "csrc-"));
  try {
    // 소스: pro-analyze + references
    mkdirSync(join(src, "pro-analyze"), { recursive: true }); writeFileSync(join(src, "pro-analyze/SKILL.md"), "x");
    mkdirSync(join(src, "references"), { recursive: true }); writeFileSync(join(src, "references/r.md"), "x");
    // 설치 폴더: 옛 suh-* + somansa(gitlab) + 신 pro-* + meta(옛 이름)
    const skills = join(home, ".cursor/skills");
    for (const d of ["suh-analyze", "gitlab", "pro-analyze", "references"]) { mkdirSync(join(skills, d), { recursive: true }); writeFileSync(join(skills, d, "f.md"), "x"); }
    writeFileSync(join(skills, "cursor-skills-meta.json"), JSON.stringify({ name: "cassiiopeia", version: "4.2.3" }));
    const io = { which: () => null, run: () => ({ code: 0, stdout: "", stderr: "" }), home: () => home, log: () => {} };
    adapterById("cursor").apply(io, { sourceSkillsDir: src, templateVersion: "9.9.9" });
    // suh-analyze 제거, gitlab 보존, pro-analyze 재설치 존재
    assert.equal(existsSync(join(skills, "suh-analyze")), false, "옛 suh-* 제거");
    assert.equal(existsSync(join(skills, "gitlab")), true, "somansa-tools gitlab 보존");
    assert.equal(existsSync(join(skills, "pro-analyze")), true, "신규 pro-analyze 재설치");
    const meta = JSON.parse(readFileSync(join(skills, "cursor-skills-meta.json"), "utf8"));
    assert.equal(meta.name, "projectops"); assert.equal(meta.version, "9.9.9");
  } finally { rmSync(home, { recursive: true, force: true }); rmSync(src, { recursive: true, force: true }); }
});

test("cursor remove: projectops 소유만 삭제하고 somansa-tools 보존", () => {
  const home = mkdtempSync(join(tmpdir(), "curr-"));
  const src = mkdtempSync(join(tmpdir(), "csrc2-"));
  try {
    mkdirSync(join(src, "pro-analyze"), { recursive: true }); writeFileSync(join(src, "pro-analyze/SKILL.md"), "x");
    const skills = join(home, ".cursor/skills");
    for (const d of ["pro-analyze", "gitlab"]) { mkdirSync(join(skills, d), { recursive: true }); writeFileSync(join(skills, d, "f.md"), "x"); }
    writeFileSync(join(skills, "cursor-skills-meta.json"), JSON.stringify({ name: "projectops", version: "9.9.9" }));
    const io = { which: () => null, run: () => ({ code: 0, stdout: "", stderr: "" }), home: () => home, log: () => {} };
    adapterById("cursor").remove(io, { sourceSkillsDir: src });
    assert.equal(existsSync(join(skills, "pro-analyze")), false, "pro-* 제거");
    assert.equal(existsSync(join(skills, "gitlab")), true, "somansa-tools 보존");
    assert.equal(existsSync(join(skills, "cursor-skills-meta.json")), false, "meta 제거");
  } finally { rmSync(home, { recursive: true, force: true }); rmSync(src, { recursive: true, force: true }); }
});
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `node --test test/ide-legacy.test.js`
Expected: FAIL — "옛 suh-* 제거" (migrateLegacy 미구현) / "somansa-tools 보존" (remove 통째삭제 버그)

- [ ] **Step 3: `cursor.js` 수정**

import에 추가:
```js
import { migrateConfigRoot, isLegacyVersion } from "../legacy.js";
```
`const LEGACY_NAMES`·상수 추가 (metaPath 함수 위):
```js
const LEGACY_NAMES = ["cassiiopeia", "suh-devops-template"];
const LEGACY_MAX_VERSION = "4.2.4";
```
`apply` 함수를 수정 — 맨 앞에 migrateLegacy/config 호출 삽입:
```js
function apply(io, ctx = {}) {
  migrateLegacy(io, ctx);
  migrateConfigRoot(io);
  const src = resolveSkillsSrc(ctx);
  if (!src) { io.log("  설치할 스킬 소스를 찾지 못했습니다 (skills/ 폴더 필요)."); return false; }
  const dest = join(io.home(), ".cursor/skills");
  io.log("Cursor Skills 복사 중...");
  try {
    mkdirSync(dest, { recursive: true });
    for (const e of readdirSync(src, { withFileTypes: true })) {
      cpSync(join(src, e.name), join(dest, e.name), { recursive: true });
    }
    writeMeta(io, dest, ctx.templateVersion);
    io.log(`  Cursor Skills 설치 완료 (${dest}/, v${ctx.templateVersion || "unknown"})`);
    return true;
  } catch {
    io.log("  Cursor Skills 복사 실패 — skills/ 폴더를 확인하세요.");
    return false;
  }
}

// projectops가 이 폴더에 설치했다고 볼 항목만 골라낸다.
// 소스 skills/ 폴더명(pro-*, references, config.json.example) ∪ /^suh-/ ∪ meta 파일.
function ownedEntries(io, ctx) {
  const dir = join(io.home(), ".cursor/skills");
  if (!existsSync(dir)) return [];
  let srcNames = new Set();
  const src = resolveSkillsSrc(ctx);
  if (src && existsSync(src)) srcNames = new Set(readdirSync(src));
  const EXTRA = new Set(["cursor-skills-meta.json"]);
  return readdirSync(dir).filter((name) => srcNames.has(name) || /^suh-/.test(name) || EXTRA.has(name));
}

// 옛 이름/버전 meta면 projectops 소유 항목만 선별 삭제 → apply가 신규 재설치.
function migrateLegacy(io, ctx) {
  const mp = metaPath(io);
  if (!existsSync(mp)) return;
  let meta = {};
  try { meta = JSON.parse(readFileSync(mp, "utf8")); } catch { return; }
  const oldName = meta.name && LEGACY_NAMES.includes(String(meta.name).toLowerCase());
  const oldVer = isLegacyVersion(meta.version, LEGACY_MAX_VERSION);
  if (!(oldName || oldVer)) return;
  for (const name of ownedEntries(io, ctx)) {
    try { rmSync(join(io.home(), ".cursor/skills", name), { recursive: true, force: true }); } catch { /* 무시 */ }
  }
  io.log(`  레거시 Cursor Skills 정리(선별): name=${meta.name}, v=${meta.version} → 재설치`);
}
```
`remove` 함수를 통째삭제 → 선별삭제로 교체:
```js
function remove(io, ctx = {}) {
  const dir = join(io.home(), ".cursor/skills");
  if (!existsSync(join(dir, "cursor-skills-meta.json"))) { io.log("  설치된 Cursor Skills가 없어 건너뜁니다"); return true; }
  try {
    for (const name of ownedEntries(io, ctx)) rmSync(join(dir, name), { recursive: true, force: true });
    // 폴더가 비면 폴더 자체 제거, 타 스킬 남으면 유지
    if (existsSync(dir) && readdirSync(dir).length === 0) rmSync(dir, { recursive: true, force: true });
    io.log(`  Cursor Skills 제거 완료 (projectops 소유만, ${dir}/)`);
    return true;
  } catch { io.log(`  Cursor Skills 제거 실패 — 수동 확인: ${dir}`); return false; }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `node --test test/ide-legacy.test.js`
Expected: PASS

- [ ] **Step 5: 기존 cursor 테스트 회귀 확인 (⚠️ 깨질 것 — 함께 수정)**

Run: `node --test test/ide.test.js`
Expected: 기존 "cursor: skills/ 복사 + meta.json 기록" 테스트의 마지막 줄 `assert.equal(existsSync(join(home, ".cursor/skills")), false)`가 **FAIL 가능** — remove가 이제 `sourceSkillsDir`(ctx) 없이 호출되면 `ownedEntries`가 소스 폴더명을 못 얻어 `analyze`(소스에 있던 폴더)를 못 지울 수 있음.

수정: `test/ide.test.js`의 해당 테스트에서 `remove(io)` → `remove(io, { sourceSkillsDir: src })`로 ctx 전달. 그 테스트 폴더엔 `analyze`만 있고 meta도 있으니, ownedEntries가 `analyze`(srcNames 포함)+`meta`를 지워 폴더가 비고 → 폴더 제거되어 기존 단언 유지됨.

```js
// test/ide.test.js 수정 (해당 라인)
assert.equal(adapterById("cursor").remove(io, { sourceSkillsDir: src }), true);
```

- [ ] **Step 6: 전체 테스트 통과 확인**

Run: `node --test`
Expected: PASS (ide.test.js + ide-legacy.test.js 전량)

- [ ] **Step 7: 커밋**

```bash
git add src/core/ide/adapters/cursor.js test/ide.test.js test/ide-legacy.test.js
git commit -m "cursor 어댑터 레거시 선별 정리 + remove 버그 수정 : feat : 옛 이름·버전 meta 감지 시 projectops 소유(pro-*·suh-*·meta)만 삭제·재설치, 기존 폴더통째삭제로 somansa-tools까지 날리던 버그 동반 수정"
```

---

### Task 7: 실측 검증 (이 컴퓨터의 실제 레거시로 end-to-end)

**Files:** (코드 변경 없음 — 실행 검증만)

- [ ] **Step 1: 실측 상태 재확인**

Run:
```bash
cat "$HOME/.cursor/skills/cursor-skills-meta.json"   # name:cassiiopeia, version:4.2.3 확인
ls "$HOME/.claude/plugins/cache/" | grep -i cassiio   # 좀비 캐시 존재 확인
```
Expected: cursor meta가 옛값, cassiiopeia 캐시 잔존.

- [ ] **Step 2: 실제 어댑터 apply를 드라이런 스크립트로 실행**

`node -e`로 defaultIo + cursor 어댑터만 실행 (실제 fs 변경 발생 — Task 시작 전 백업됨: `scratchpad/legacy-backup-20260710`):
```bash
node -e "import('./src/core/ide/registry.js').then(async ({adapterById})=>{ const {defaultIo}=await import('./src/core/ide/runner.js'); const io=defaultIo(); adapterById('cursor').apply(io,{sourceSkillsDir:'skills',templateVersion:'4.2.5'}); });"
```
Expected 로그: "레거시 Cursor Skills 정리(선별)" + "Cursor Skills 설치 완료".

- [ ] **Step 3: 결과 검증 — somansa-tools 보존 + pro-* 설치 + meta 갱신**

Run:
```bash
ls "$HOME/.cursor/skills/" | grep -E "gitlab|jenkins|redmine"   # somansa 보존
ls "$HOME/.cursor/skills/" | grep -c "^suh-"                     # 0 (옛것 제거)
ls "$HOME/.cursor/skills/" | grep -c "^pro-"                     # 25 (신규)
cat "$HOME/.cursor/skills/cursor-skills-meta.json"               # name:projectops, version:4.2.5
```
Expected: gitlab/jenkins/redmine 살아있음, suh-* 0개, pro-* 다수, meta 갱신됨.

- [ ] **Step 4: config 이관 검증 (claude 경로)**

이 컴퓨터는 `~/.projectops/config`가 이미 차 있어 **skip**되어야 정상. 임시로 신규를 비워 이관 동작 확인:
```bash
# 안전: 백업본이 scratchpad에 있음
node -e "import('./src/core/ide/legacy.js').then(({migrateConfigRoot})=>{ const io={home:()=>process.env.HOME||process.env.USERPROFILE, log:console.log}; console.log(migrateConfigRoot(io)); });"
```
Expected: `{ migrated: false, reason: 'target-exists' }` (신규가 이미 있으므로 보존 확인).

- [ ] **Step 5: 복원 (검증으로 변경된 실제 환경 원복은 선택)**

cursor skills는 정상 재설치된 상태라 원복 불필요. 필요 시 백업본으로 meta 복원:
```bash
# (선택) 원상태로 되돌리려면:
# cp "<scratchpad>/legacy-backup-20260710/cursor-skills-meta.json" "$HOME/.cursor/skills/"
echo "검증 완료 — 실측 환경이 신규 상태로 마이그레이션됨"
```

- [ ] **Step 6: 검증 결과 커밋 없음 (코드 무변경). 다음 Task로.**

---

### Task 8: GitHub 이슈 등록 + breaking-changes 반영 확인

**Files:**
- 확인: `.github/config/breaking-changes.json` (4.3.0 항목에 이미 재설치 안내 있는지)

- [ ] **Step 1: breaking-changes.json 현황 확인**

Run:
```bash
python -c "import json; d=json.load(open('.github/config/breaking-changes.json', encoding='utf-8')); print(list(d.keys())); print(d.get('4.3.0',{}).get('title',''))"
```
Expected: 4.3.0 항목 존재 확인. 자동 마이그레이션이 생겼으므로 "재설치 안내" 문구를 "자동 마이그레이션됨"으로 완화할지 판단(선택 — 이슈에 기록).

- [ ] **Step 2: GitHub 이슈 등록** — `/pro-issue` 스킬 사용 (curl 직접 금지)

이슈 제목: `IDE 어댑터 옛 이름(cassiiopeia/SUH-DEVOPS-TEMPLATE) 설치본 자동 마이그레이션`
본문 요지: npx 설치 시 옛 플러그인·마켓·config를 자동 정리·이관, 어댑터 5개 + 공용 legacy.js, cursor 선별삭제(somansa-tools 보존)+remove 버그 수정. 실측 검증 완료(cursor meta 4.2.3→4.2.5).

> 커밋과 별개로, 이슈는 `/pro-issue`로 템플릿 규격에 맞춰 등록한다.

- [ ] **Step 3: 최종 전체 테스트 + 커밋 정리**

Run: `node --test`
Expected: PASS 전량.

이미 Task별로 커밋됨. 미커밋 변경 있으면:
```bash
git status --short
```

---

## Self-Review

**1. Spec coverage:**
- 공용 legacy.js(isLegacyVersion/migrateConfigRoot) → Task 1 ✓
- claude 좀비 마켓 정리 → Task 2 ✓
- codex native/marketplace → Task 3 ✓
- gemini extension → Task 4 ✓
- pi clone+loader → Task 5 ✓
- cursor 선별삭제+remove 버그 → Task 6 ✓
- config 3세대 이관 → Task 1(구현)+각 어댑터 apply 호출 ✓
- 실측 검증 → Task 7 ✓
- 이슈 등록 → Task 8 ✓

**2. Placeholder scan:** 모든 스텝에 실제 코드·명령·기대출력 포함. "적절히"·"TODO" 없음.

**3. Type consistency:**
- `migrateConfigRoot(io)` 반환 `{migrated, from?, reason?}` — Task 1 정의, Task 4 검증 일치.
- `ownedEntries(io, ctx)` — Task 6에서 정의·사용 일치.
- `migratePiLegacy(io)` — Task 5 pi-common 정의, pi.js import 일치.
- `isLegacyVersion(version, maxLegacy)` — Task 1 정의, Task 6 사용 시그니처 일치.
- cursor `remove(io, ctx)` 시그니처 변경 → Task 6 Step 5에서 기존 테스트 호출부 동반 수정 명시 ✓.
