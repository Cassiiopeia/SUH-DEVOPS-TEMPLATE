# 마법사 타입 탈출구 + 고아 타입 워크플로우 정리 구현 계획 (#487)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 경로 확정 단계에서 오감지된 타입을 "이 타입 제외"로 뺄 수 있게 하고, 선택 해제된 타입의 잔존 템플릿 워크플로우를 .bak 무해화로 정리 제안한다.

**Architecture:** (1) `resolveProjectPaths`의 대화형 세 지점(후보 1개 확인, 후보 다수 select, 직접입력 실패)에 제외 선택지를 추가 — 제외된 타입은 반환 Map에 안 들어가고, 호출부가 `filterExcludedTypes`로 types를 갱신한다(전부 제외 시 basic 폴백). (2) 새 모듈 `orphan-workflows.js`가 템플릿 인벤토리(타입 직하위 + server-deploy + publish/*)와 대상 레포 `.github/workflows/`를 대조해 선택 안 된 타입의 파일을 정확한 파일명 일치로만 감지, 레거시 정리와 같은 UX(.bak)로 정리한다.

**Tech Stack:** Node.js ESM (src/), node:test (test/), 기존 io 주입 계약(select/text/confirm) 유지.

## Global Constraints

- 이슈: https://github.com/Cassiiopeia/projectops/issues/487
- 작업 브랜치: `develop` 직접 커밋 (feature 브랜치 금지, push는 사용자 요청 시에만)
- 커밋 메시지: `마법사 타입 오감지 탈출구 부재, 타입 변경 시 구 타입 워크플로우 잔존 : {type} : {설명} https://github.com/Cassiiopeia/projectops/issues/487` — 이모지·태그 접두 금지
- 비대화형(`--force`/no-TTY) 동작 무변경: 제외는 대화형 전용, 고아 정리는 안내 출력만
- 사용자 커스텀 워크플로우 보호: prefix 매칭 금지, 템플릿 인벤토리 정확 일치만
- `PROJECT-COMMON-*`/`PROJECT-TEMPLATE-*`는 절대 비대상 (common 폴더는 타입 순회에서 제외)
- 제외 센티넬은 기존 관례대로 한국어 value 문자열(`"이 타입 제외"`) — symbol 노출 금지 (기존 `"직접 입력"` 패턴)
- 테스트 실행: `npm test` (node:test 러너)

---

### Task 1: paths-resolve.js 타입 탈출구

**Files:**
- Modify: `src/core/paths-resolve.js:184-238` (대화형 분기 + 직접입력 루프)
- Modify: `src/core/paths-resolve.js` 말미 (새 export `filterExcludedTypes`)
- Test: `test/paths-resolve.test.js`

**Interfaces:**
- Produces: `resolveProjectPaths` 반환 Map에서 제외된 타입은 키가 없음 (시그니처 무변경).
- Produces: `export function filterExcludedTypes(types, paths)` → `string[]` — basic이 아니면서 paths에 없는 타입을 제거, 결과가 비면 `["basic"]`.
- 기존 io 계약 변화: 후보 1개 확인이 `io.confirm` → `io.select`(3지선)로, 직접입력 실패 확인이 `io.confirm` → `io.select`(3지선)로 바뀐다.

- [ ] **Step 1: 실패하는 테스트 작성** — `test/paths-resolve.test.js`에 추가:

```js
test("resolveProjectPaths 대화형: 후보 1개에서 '이 타입 제외' → Map에서 빠짐", async () => {
  const root = makeTmp();
  try {
    touch(root, "code-archive/old/build.gradle"); // 아카이브 오감지 시나리오
    const io = stubIo({ selects: ["이 타입 제외"] });
    const map = await resolveProjectPaths({ root, types: ["spring"], tty: true, io });
    assert.equal(map.has("spring"), false);
    assert.equal(io.calls.text.length, 0); // 직접입력 루프로 안 빠져야 함
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("resolveProjectPaths 대화형: 복수 후보 메뉴에 '이 타입 제외' 항목 + 선택 시 제외", async () => {
  const root = makeTmp();
  try {
    touch(root, "api/build.gradle");
    touch(root, "batch/build.gradle");
    const io = stubIo({ selects: ["이 타입 제외"] });
    const map = await resolveProjectPaths({ root, types: ["spring"], tty: true, io });
    assert.equal(map.has("spring"), false);
    const values = io.calls.select[0].options.map((o) => o.value);
    assert.ok(values.includes("직접 입력"));
    assert.ok(values.includes("이 타입 제외"));
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("resolveProjectPaths 대화형: 직접입력 검증 실패 → '이 타입 제외'로 탈출", async () => {
  const root = makeTmp();
  try {
    // 후보 0개 → 바로 직접입력 → 마커 없는 경로 → 실패 select에서 제외
    const io = stubIo({ selects: ["이 타입 제외"], texts: ["nowhere"] });
    const map = await resolveProjectPaths({ root, types: ["spring"], tty: true, io });
    assert.equal(map.has("spring"), false);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("resolveProjectPaths 대화형: 직접입력 실패 → '다시 입력' 후 유효 경로로 확정", async () => {
  const root = makeTmp();
  try {
    touch(root, "srv/build.gradle");
    const io = stubIo({ selects: ["retry"], texts: ["nowhere", "srv"] });
    const map = await resolveProjectPaths({ root, types: ["spring"], tty: true, io });
    assert.equal(map.get("spring"), "srv");
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("filterExcludedTypes: 제외 타입 제거 + 전부 제외 시 basic 폴백", () => {
  assert.deepEqual(filterExcludedTypes(["spring", "python"], new Map([["python", "."]])), ["python"]);
  assert.deepEqual(filterExcludedTypes(["spring"], new Map()), ["basic"]);
  assert.deepEqual(filterExcludedTypes(["basic"], new Map()), ["basic"]);
  assert.deepEqual(filterExcludedTypes(["flutter", "basic"], new Map()), ["basic"]);
});
```

import 줄에 `filterExcludedTypes` 추가.

- [ ] **Step 2: 실패 확인**

Run: `node --test test/paths-resolve.test.js`
Expected: FAIL — `filterExcludedTypes is not a function` 및 제외 테스트들 실패(현행은 confirm 기반이라 select 응답이 소진되지 않음).

- [ ] **Step 3: 구현** — `src/core/paths-resolve.js`의 ⑤-b 대화형 분기와 직접입력 루프를 다음으로 교체:

```js
    // ── ⑤-b 대화형: 후보 개수별 분기 (.sh L1492~1525) + 타입 탈출구 (#487) ──
    const EXCLUDE = "이 타입 제외"; // 센티넬 — 한국어 value로 노출 (기존 "직접 입력" 패턴)
    let excluded = false;
    if (candidates.length === 1) {
      const cand = candidates[0];
      const candMarker = existingMarkerInDir(t, cand === "." ? root : join(root, cand));
      const candFull = cand === "." ? candMarker : `${cand}/${candMarker}`;
      say("");
      say(`  ${prog} 🔍 ${t} — ${candMarker} 발견`);
      say(`      위치: <레포루트>/${candFull}`);
      const sel = await io.select({
        message: `  ${t} 프로젝트 루트를 '${cand}'(으)로 설정할까요?`,
        options: [
          { value: cand, label: `예 — '${cand}' 사용 (${candFull} 기준)` },
          { value: "직접 입력", label: "아니오 — 경로 직접 입력" },
          { value: EXCLUDE, label: `이 타입 아님 — ${t} 설치 대상에서 제외` },
        ],
      });
      if (sel === EXCLUDE) excluded = true;
      else if (!isCancel(sel) && sel != null && sel !== "직접 입력") chosen = sel;
      // ESC/직접 입력 → 아래 직접입력 루프로
    } else if (candidates.length > 1) {
      say("");
      say(`  ${prog} 🔍 ${t}: 경로 후보 ${candidates.length}개 발견`);
      const options = candidates.map((c) => ({
        value: c,
        label: `${c} (${existingMarkerInDir(t, c === "." ? root : join(root, c))})`,
      }));
      options.push({ value: "직접 입력", label: "직접 입력" });
      options.push({ value: EXCLUDE, label: `이 타입 아님 — ${t} 설치 대상에서 제외` });
      const sel = await io.select({ message: `  ${t} 프로젝트 루트를 선택하세요`, options });
      if (sel === EXCLUDE) excluded = true;
      else if (!isCancel(sel) && sel != null && sel !== "직접 입력") chosen = sel;
    } else {
      say("");
      say(`  ⚠️ ${prog} ${t}: 프로젝트를 찾지 못했습니다 (maxdepth 3).`);
    }

    // ── 직접 입력 루프 (위에서 미확정 시, .sh L1528~1553) — 제외 탈출구 포함 (#487) ──
    while (!chosen && !excluded) {
      const hintMarker = existingMarkerInDir(t, root);
      let prompt = `  ${t} 프로젝트 루트 경로 입력 (${hintMarker} 이 있는 폴더, 예: server, app — 루트면 그냥 Enter`;
      if (existing) prompt += `, 현재값: ${existing}`;
      prompt += "): ";
      let input = await io.text({ message: prompt, defaultValue: "" });
      if (isCancel(input) || input == null) input = ""; // ESC → 빈값 (아래 폴백)
      input = String(input).trim();
      input = input === "" ? (existing || ".") : normalizePath(input);
      const m = existingMarkerInDir(t, input === "." ? root : join(root, input));
      if (m && existsSync(join(root, input === "." ? "" : input, m))) {
        chosen = input;
      } else {
        say(`  ⚠️ ${input}/${m} 파일이 없습니다.`);
        const act = await io.select({
          message: "  어떻게 할까요?",
          options: [
            { value: "retry", label: "다시 입력" },
            { value: "force", label: `그래도 '${input}' 경로 사용` },
            { value: EXCLUDE, label: `이 타입 아님 — ${t} 설치 대상에서 제외` },
          ],
        });
        if (act === "force") chosen = input;
        else if (act === EXCLUDE) excluded = true;
        // retry/ESC → 루프 계속
      }
    }

    if (excluded) {
      say(`  ➖ ${t} 제외 — 이 타입은 버전 동기화·워크플로우 설치 대상에서 빠집니다`);
      continue;
    }

    result.set(t, chosen);
    say(`  ✅ ${t} → ${chosen}`);
```

파일 말미에 export 추가:

```js
// 경로 단계에서 제외된 타입 반영 (#487) — basic이 아니면서 paths에 없는 타입 제거.
// 전부 제외되면 basic 폴백 (타입 0개 상태 금지). 비대화형은 제외가 불가능하므로 no-op.
export function filterExcludedTypes(types, paths) {
  const kept = types.filter((t) => t === "basic" || paths.has(t));
  return kept.length ? kept : ["basic"];
}
```

- [ ] **Step 4: 기존 테스트 3개를 새 io 계약으로 갱신** — `test/paths-resolve.test.js`:

`"resolveProjectPaths 대화형: '직접 입력' 선택 → 마커 없는 경로는 경고 후 강제확인"` (구 confirms:[true]) →

```js
    // select(후보메뉴)에서 직접 입력 → text로 마커 없는 경로 → 실패 select에서 '그래도 사용'
    const io = stubIo({ selects: ["직접 입력", "force"], texts: ["nowhere"] });
    const map = await resolveProjectPaths({ root, types: ["react"], tty: true, io });
    assert.equal(map.get("react"), "nowhere");
    assert.equal(io.calls.select.length, 2); // 후보메뉴 1회 + 실패확인 1회
```

`"resolveProjectPaths 대화형: 후보 1개 확인 '아니오' → 직접 입력 루프"` (구 confirms:[false]) →

```js
    // 후보 1개 select에서 '직접 입력' → text "other/" (정규화 검증: 끝 슬래시 제거)
    const io = stubIo({ selects: ["직접 입력"], texts: ["other/"] });
    const map = await resolveProjectPaths({ root, types: ["flutter"], tty: true, io });
    assert.equal(map.get("flutter"), "other");
```

`"resolveProjectPaths 대화형: 복수 후보 select 경로"`의 options 검증 →

```js
    assert.deepEqual(options.map((o) => o.value), ["admin", "web", "직접 입력", "이 타입 제외"]);
```

- [ ] **Step 5: 통과 확인**

Run: `node --test test/paths-resolve.test.js`
Expected: PASS (전체)

- [ ] **Step 6: 커밋**

```bash
git add src/core/paths-resolve.js test/paths-resolve.test.js
git commit -m "마법사 타입 오감지 탈출구 부재, 타입 변경 시 구 타입 워크플로우 잔존 : feat : 경로 확정 세 지점(후보 확인, 후보 선택, 직접입력 실패)에 '이 타입 제외' 탈출구 추가 + filterExcludedTypes https://github.com/Cassiiopeia/projectops/issues/487"
```

---

### Task 2: interactive.js에 제외 반영 배선

**Files:**
- Modify: `src/commands/interactive.js:14` (import), `:195-198` (resolve 직후)

**Interfaces:**
- Consumes: Task 1의 `filterExcludedTypes(types, paths)`.
- Produces: 제외 반영된 `types`가 이후 `promptEnvPlan`, `createContext`, `runFull` 전부에 흐른다 (별도 신규 인터페이스 없음).

- [ ] **Step 1: import 추가 및 resolve 직후 필터 삽입**

```js
import { resolveProjectPaths, filterExcludedTypes } from "../core/paths-resolve.js";
```

`resolveProjectPaths` 호출(195-198) 직후에:

```js
      paths = await resolveProjectPaths({
        root: cwd, types, paths, existingPaths: existing?.paths ?? new Map(),
        force: false, tty: realTty, io: io.engineIo ?? {},
      });
      // 타입 탈출구 (#487) — 경로 단계에서 제외된 타입은 version.yml·복사·env 전 단계에서 뺀다
      types = filterExcludedTypes(types, paths);
```

- [ ] **Step 2: 전체 테스트로 회귀 확인**

Run: `npm test`
Expected: PASS (interactive.test.js 포함 전체 — 기존 대화형 스텁은 제외를 안 쓰므로 no-op)

- [ ] **Step 3: 커밋**

```bash
git add src/commands/interactive.js
git commit -m "마법사 타입 오감지 탈출구 부재, 타입 변경 시 구 타입 워크플로우 잔존 : feat : 대화형 마법사에 제외 타입 반영 배선 (전부 제외 시 basic 폴백) https://github.com/Cassiiopeia/projectops/issues/487"
```

---

### Task 3: orphan-workflows.js 고아 감지·정리 모듈

**Files:**
- Create: `src/core/orphan-workflows.js`
- Test: `test/orphan-workflows.test.js`

**Interfaces:**
- Consumes: `PATHS`(`src/core/paths.js`), `exists`/`listYamlFiles`(`src/core/fsutil.js`).
- Produces: `detectOrphanWorkflows({ tempDir, targetRoot, selectedTypes })` → `[{ filename, type }]` (filename 오름차순 정렬).
- Produces: `applyOrphanCleanup(targetRoot, orphans)` → `[{ filename, action: "bak" | "error", error? }]`.

- [ ] **Step 1: 실패하는 테스트 작성** — `test/orphan-workflows.test.js` 신규:

```js
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync, mkdirSync, writeFileSync, existsSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { detectOrphanWorkflows, applyOrphanCleanup } from "../src/core/orphan-workflows.js";

function touch(root, rel, content = "x") {
  const p = join(root, rel);
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, content);
}
function makeTmp() { return mkdtempSync(join(tmpdir(), "orphanwf-")); }

// 템플릿 tempDir 픽스처 — spring(직하위+server-deploy+publish)·python 두 타입
function makeTemplate() {
  const tempDir = makeTmp();
  const base = ".github/workflows/project-types";
  touch(tempDir, `${base}/common/PROJECT-COMMON-RELEASE-CHANGELOG.yaml`);
  touch(tempDir, `${base}/spring/PROJECT-SPRING-NEXUS-CI.yaml`);
  touch(tempDir, `${base}/spring/server-deploy/PROJECT-SPRING-SIMPLE-CICD.yaml`);
  touch(tempDir, `${base}/spring/publish/nexus/PROJECT-SPRING-NEXUS-PUBLISH.yaml`);
  touch(tempDir, `${base}/python/PROJECT-PYTHON-CI.yaml`);
  return tempDir;
}

test("detectOrphanWorkflows: 선택 안 된 타입의 실재 파일만 감지 (서브폴더 포함)", () => {
  const tempDir = makeTemplate();
  const target = makeTmp();
  try {
    touch(target, ".github/workflows/PROJECT-SPRING-SIMPLE-CICD.yaml");   // server-deploy 출신 고아
    touch(target, ".github/workflows/PROJECT-SPRING-NEXUS-PUBLISH.yaml"); // publish 출신 고아
    touch(target, ".github/workflows/PROJECT-PYTHON-CI.yaml");            // 선택된 타입 — 비대상
    touch(target, ".github/workflows/PROJECT-COMMON-RELEASE-CHANGELOG.yaml"); // common — 비대상
    touch(target, ".github/workflows/PROJECT-SPRING-MY-CUSTOM.yaml");     // 사용자 커스텀 — 인벤토리에 없어 비대상
    const orphans = detectOrphanWorkflows({ tempDir, targetRoot: target, selectedTypes: ["python"] });
    assert.deepEqual(orphans, [
      { filename: "PROJECT-SPRING-NEXUS-PUBLISH.yaml", type: "spring" },
      { filename: "PROJECT-SPRING-SIMPLE-CICD.yaml", type: "spring" },
    ]);
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
    rmSync(target, { recursive: true, force: true });
  }
});

test("detectOrphanWorkflows: 대상 레포에 파일 없으면 빈 배열 / 전 타입 선택이면 빈 배열", () => {
  const tempDir = makeTemplate();
  const target = makeTmp();
  try {
    assert.deepEqual(detectOrphanWorkflows({ tempDir, targetRoot: target, selectedTypes: ["python"] }), []);
    touch(target, ".github/workflows/PROJECT-SPRING-NEXUS-CI.yaml");
    assert.deepEqual(detectOrphanWorkflows({ tempDir, targetRoot: target, selectedTypes: ["spring", "python"] }), []);
  } finally {
    rmSync(tempDir, { recursive: true, force: true });
    rmSync(target, { recursive: true, force: true });
  }
});

test("applyOrphanCleanup: .bak 리네임 + 기존 .bak 덮어쓰기 (Windows 대비)", () => {
  const target = makeTmp();
  try {
    touch(target, ".github/workflows/PROJECT-SPRING-NEXUS-CI.yaml", "live");
    touch(target, ".github/workflows/PROJECT-SPRING-NEXUS-CI.yaml.bak", "stale");
    const results = applyOrphanCleanup(target, [{ filename: "PROJECT-SPRING-NEXUS-CI.yaml", type: "spring" }]);
    assert.deepEqual(results, [{ filename: "PROJECT-SPRING-NEXUS-CI.yaml", action: "bak" }]);
    assert.equal(existsSync(join(target, ".github/workflows/PROJECT-SPRING-NEXUS-CI.yaml")), false);
    assert.equal(readFileSync(join(target, ".github/workflows/PROJECT-SPRING-NEXUS-CI.yaml.bak"), "utf8"), "live");
  } finally { rmSync(target, { recursive: true, force: true }); }
});
```

- [ ] **Step 2: 실패 확인**

Run: `node --test test/orphan-workflows.test.js`
Expected: FAIL — `Cannot find module '../src/core/orphan-workflows.js'`

- [ ] **Step 3: 구현** — `src/core/orphan-workflows.js` 신규:

```js
// 고아 타입 워크플로우 감지·정리 (#487) — 타입 변경으로 선택에서 빠진 타입의
// 템플릿 워크플로우를 감지해 .bak 무해화한다 (레거시 마이그레이션과 동일 방식).
// 안전 원칙: 템플릿 인벤토리와 "정확한 파일명 일치"만 대상 — prefix 매칭 금지
// (사용자 커스텀 워크플로우 오살 방지). common/은 타입이 아니므로 순회에서 제외.
import { existsSync, renameSync, rmSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { PATHS } from "./paths.js";
import { exists, listYamlFiles } from "./fsutil.js";

// 템플릿의 project-types/<type>/ 인벤토리 — 직하위 + server-deploy/ + publish/*/ (copy 엔진과 동일 범위)
function typeInventory(projectTypesDir, type) {
  const typeDir = join(projectTypesDir, type);
  const dirs = [typeDir, join(typeDir, "server-deploy")];
  const pubRoot = join(typeDir, "publish");
  if (exists(pubRoot)) {
    for (const e of readdirSync(pubRoot, { withFileTypes: true })) {
      if (e.isDirectory()) dirs.push(join(pubRoot, e.name));
    }
  }
  const files = new Set();
  for (const d of dirs) {
    if (!exists(d)) continue;
    for (const f of listYamlFiles(d)) files.add(f);
  }
  return files;
}

// 선택 안 된 타입의 템플릿 워크플로우가 대상 레포에 실재하면 고아로 반환.
export function detectOrphanWorkflows({ tempDir, targetRoot = ".", selectedTypes = [] }) {
  const projectTypesDir = join(tempDir, PATHS.workflowsDir, PATHS.projectTypesDir);
  if (!exists(projectTypesDir)) return [];
  const selected = new Set(selectedTypes);
  // 선택된 타입이 쓰는 파일명 집합 — 교차 방어 (파일명은 타입 prefix로 유일하지만 안전망)
  const keep = new Set();
  for (const t of selected) for (const f of typeInventory(projectTypesDir, t)) keep.add(f);
  const workflowsDir = join(targetRoot, PATHS.workflowsDir);
  const orphans = [];
  for (const e of readdirSync(projectTypesDir, { withFileTypes: true })) {
    if (!e.isDirectory() || e.name === "common" || selected.has(e.name)) continue;
    for (const f of typeInventory(projectTypesDir, e.name)) {
      if (keep.has(f)) continue;
      if (existsSync(join(workflowsDir, f))) orphans.push({ filename: f, type: e.name });
    }
  }
  return orphans.sort((a, b) => a.filename.localeCompare(b.filename));
}

// .bak 무해화 실행기 — 부분 실패 허용 (migrations applySafeMigrations와 동일 원칙).
export function applyOrphanCleanup(targetRoot, orphans) {
  const workflowsDir = join(targetRoot, PATHS.workflowsDir);
  const results = [];
  for (const { filename } of orphans) {
    try {
      const src = join(workflowsDir, filename);
      const bak = `${src}.bak`;
      if (existsSync(bak)) rmSync(bak, { force: true }); // Windows rename은 대상 존재 시 실패
      renameSync(src, bak);
      results.push({ filename, action: "bak" });
    } catch (err) {
      results.push({ filename, action: "error", error: err.message });
    }
  }
  return results;
}
```

- [ ] **Step 4: 통과 확인**

Run: `node --test test/orphan-workflows.test.js`
Expected: PASS (3개)

- [ ] **Step 5: 커밋**

```bash
git add src/core/orphan-workflows.js test/orphan-workflows.test.js
git commit -m "마법사 타입 오감지 탈출구 부재, 타입 변경 시 구 타입 워크플로우 잔존 : feat : 고아 타입 워크플로우 감지·정리 모듈 (템플릿 인벤토리 정확 일치, .bak 무해화) https://github.com/Cassiiopeia/projectops/issues/487"
```

---

### Task 4: 마법사·비대화형 배선 + 문서

**Files:**
- Modify: `src/commands/interactive.js` (runMigrations 블록 직후, 248-254 부근)
- Modify: `src/index.js` (run switch 직전, 154 부근)
- Modify: `CLAUDE.md` (워크플로우 리네임/삭제 주의 블록에 한 줄)

**Interfaces:**
- Consumes: Task 3의 `detectOrphanWorkflows` / `applyOrphanCleanup`.

- [ ] **Step 1: interactive.js 배선** — import 추가 후 runMigrations 블록(`if (mode === "full" || mode === "workflows")`) 바로 아래에:

```js
import { detectOrphanWorkflows, applyOrphanCleanup } from "../core/orphan-workflows.js";
```

```js
    // 고아 타입 워크플로우 정리 (#487) — 타입 변경으로 선택에서 빠진 타입의 잔존 워크플로우
    if (mode === "full" || mode === "workflows") {
      const orphans = detectOrphanWorkflows({ tempDir, targetRoot: cwd, selectedTypes: types });
      if (orphans.length > 0) {
        io.note?.(
          orphans.map((o) => `• ${o.filename} (${o.type} 타입 — 현재 미선택)`).join("\n"),
          `🧹 선택되지 않은 타입의 워크플로우 ${orphans.length}개 발견`,
        );
        const yes = await io.askYesNo(`위 ${orphans.length}개를 정리할까요? (.bak 무해화 — 복원 가능)`, true);
        if (yes === true) {
          const results = applyOrphanCleanup(cwd, orphans);
          const ok = results.filter((r) => r.action === "bak");
          const failed = results.filter((r) => r.action === "error");
          io.note?.(`✅ 고아 워크플로우 정리: ${ok.length}개${failed.length ? ` (실패 ${failed.length}개)` : ""}`, "정리 완료");
        }
      }
    }
```

> `io.note` 시그니처는 기존 사용처(`io.note?.(body, title)`, interactive.js:136)와 동일하게 맞춘다. 스텁에 note가 없어도 옵셔널 체이닝으로 무해.

- [ ] **Step 2: index.js 비대화형 안내** — import 추가 후 run switch(`case "full"...`) 직전에:

```js
import { detectOrphanWorkflows } from "./core/orphan-workflows.js";
```

```js
    // 고아 타입 워크플로우 안내 (#487) — 비대화형은 자동 무해화 금지(배포 파이프라인일 수 있음), 안내만
    if (opts.mode === "full" || opts.mode === "workflows") {
      const orphans = detectOrphanWorkflows({ tempDir, targetRoot: cwd, selectedTypes: types });
      for (const o of orphans) {
        console.error(`⚠️ 선택되지 않은 타입(${o.type})의 워크플로우가 남아있습니다: ${o.filename} — 대화형 마법사(npx projectops)에서 정리할 수 있습니다.`);
      }
    }
```

> switch가 참조하는 모드 변수명(`opts.mode` 또는 로컬 변수)은 해당 파일의 실제 switch 조건과 동일하게 맞춘다.

- [ ] **Step 3: CLAUDE.md 문서 한 줄** — "⚠️ 워크플로우를 리네임/삭제할 때" 블록 끝에 추가:

```markdown
> 참고: **타입 선택 해제로 남는 고아 워크플로우**는 registry가 아니라 `src/core/orphan-workflows.js`가 동적 감지한다(#487) — registry는 리네임·폐기 전용, 고아 정리는 템플릿 인벤토리 대조 방식이다.
```

- [ ] **Step 4: 전체 테스트 회귀 확인**

Run: `npm test`
Expected: PASS (전체)

- [ ] **Step 5: 커밋**

```bash
git add src/commands/interactive.js src/index.js CLAUDE.md
git commit -m "마법사 타입 오감지 탈출구 부재, 타입 변경 시 구 타입 워크플로우 잔존 : feat : 마법사에 고아 정리 배선 (대화형 확인 후 .bak, 비대화형 안내만) https://github.com/Cassiiopeia/projectops/issues/487"
```

---

### Task 5: 수동 시나리오 검증 (이슈 재현 경로)

**Files:** 없음 (검증만)

- [ ] **Step 1: 오감지 탈출구 시나리오** — 임시 폴더에 이슈 재현 구조를 만들어 마법사 실행:

```bash
SCEN=$(mktemp -d)
mkdir -p "$SCEN/code-archive/old" "$SCEN/suh-ai-server/flask"
echo "" > "$SCEN/code-archive/old/build.gradle"
echo "" > "$SCEN/suh-ai-server/flask/requirements.txt"
git -C "$SCEN" init -q && git -C "$SCEN" commit -q --allow-empty -m init
cd "$SCEN" && node E:/github/SUH-DEVOPS-TEMPLATE/bin/projectops.js
```

Expected: spring 경로 확인 화면에 "이 타입 아님 — spring 설치 대상에서 제외" 항목이 보이고, 선택 시 spring 질문·워크플로우 없이 python만 진행된다.

- [ ] **Step 2: 고아 정리 시나리오** — 위 폴더에 `PROJECT-SPRING-SIMPLE-CICD.yaml`을 `.github/workflows/`에 수동 생성 후 마법사 재실행(타입 python 단독):

Expected: "🧹 선택되지 않은 타입의 워크플로우 1개 발견" 안내 → 예 → `.bak` 리네임 확인.

- [ ] **Step 3: 임시 폴더 정리**

```bash
rm -rf "$SCEN"
```
