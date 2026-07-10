import { test } from "node:test";
import assert from "node:assert/strict";
import { isLegacyVersion, migrateConfigRoot, hasNonEmptyJson } from "../src/core/ide/legacy.js";
import { adapterById } from "../src/core/ide/registry.js";
import { mkdtempSync, rmSync, mkdirSync, writeFileSync, existsSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

function stubIo({ home } = {}) {
  const logs = [];
  return { logs, home: () => home, log: (m) => logs.push(m), which: () => null, run: () => ({ code: 0, stdout: "", stderr: "" }) };
}

// ── Task 1: legacy.js 공용 헬퍼 ──
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

// ── Task 2: claude 어댑터 레거시 정리 ──
// claude용 stubIo — home을 임시폴더로 두어 config 이관이 실제 fs에 안전하게 no-op.
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
    home: () => home || mkdtempSync(join(tmpdir(), "clh-")), log: (m) => logs.push(m),
  };
}

test("claude migrateLegacy: 옛 cassiiopeia 플러그인 감지 시 uninstall+marketplace remove", () => {
  const home = mkdtempSync(join(tmpdir(), "clm-"));
  try {
    const listJson = JSON.stringify([{ name: "cassiiopeia@cassiiopeia-marketplace", scope: "user", version: "4.2.3" }]);
    const io = claudeIo({ listJson, home });
    adapterById("claude").apply(io);
    assert.ok(io.calls.some((c) => c.includes("plugin uninstall cassiiopeia@cassiiopeia-marketplace")), "옛 플러그인 uninstall 호출");
    assert.ok(io.calls.some((c) => c.includes("marketplace remove cassiiopeia-marketplace")), "옛 마켓 remove 호출");
    assert.ok(io.calls.some((c) => c.includes("plugin install projectops@projectops-marketplace")), "정리 후 신규 install");
  } finally { rmSync(home, { recursive: true, force: true }); }
});

test("claude migrateLegacy: 옛것 없으면 정리 명령 미호출", () => {
  const home = mkdtempSync(join(tmpdir(), "cln-"));
  try {
    const io = claudeIo({ listJson: "[]", home });
    adapterById("claude").apply(io);
    assert.ok(!io.calls.some((c) => c.includes("uninstall cassiiopeia")), "불필요한 uninstall 없음");
  } finally { rmSync(home, { recursive: true, force: true }); }
});

// ── Task 3: codex 어댑터 레거시 정리 ──
test("codex migrateLegacy: 옛 SUH-DEVOPS-TEMPLATE native 폴더 제거 + marketplace remove", () => {
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

// ── Task 4: gemini 어댑터 레거시 정리 ──
test("gemini migrateLegacy: 옛 extension uninstall 호출", () => {
  const home = mkdtempSync(join(tmpdir(), "gm-"));
  try {
    const calls = [];
    const io = {
      calls, logs: [],
      which: (c) => (c === "gemini" ? "/usr/bin/gemini" : null),
      run: (c, a = []) => { calls.push([c, ...a].join(" ")); return { code: 0, stdout: "", stderr: "" }; },
      home: () => home, log: () => {},
    };
    adapterById("gemini").apply(io);
    assert.ok(calls.some((c) => c.includes("extensions uninstall SUH-DEVOPS-TEMPLATE")), "옛 extension uninstall");
  } finally { rmSync(home, { recursive: true, force: true }); }
});

// ── Task 5: pi 어댑터 레거시 정리 ──
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
    // pi list가 projectops를 리턴 → piInstalled=true → update 경로. run은 항상 성공.
    const io = { which: (c) => (c === "pi" ? "/usr/bin/pi" : null), run: () => ({ code: 0, stdout: "projectops", stderr: "" }), home: () => home, log: () => {} };
    adapterById("pi").apply(io);
    assert.equal(existsSync(join(base, "SUH-DEVOPS-TEMPLATE")), false, "옛 clone 제거됨");
    const settings = JSON.parse(readFileSync(join(home, ".pi/agent/settings.json"), "utf8"));
    assert.ok(!settings.extensions.includes(oldLoader), "settings에서 옛 loader 제거");
    assert.ok(settings.extensions.includes("other"), "무관 항목 보존");
  } finally { rmSync(home, { recursive: true, force: true }); }
});

// ── Task 6: cursor 선별 삭제 + remove 버그 수정 ──
test("cursor migrateLegacy: 옛 이름/버전 meta면 projectops 소유만 선별 삭제 (somansa-tools 보존)", () => {
  const home = mkdtempSync(join(tmpdir(), "cur-"));
  const src = mkdtempSync(join(tmpdir(), "csrc-"));
  try {
    mkdirSync(join(src, "pro-analyze"), { recursive: true }); writeFileSync(join(src, "pro-analyze/SKILL.md"), "x");
    mkdirSync(join(src, "references"), { recursive: true }); writeFileSync(join(src, "references/r.md"), "x");
    const skills = join(home, ".cursor/skills");
    for (const d of ["suh-analyze", "gitlab", "pro-analyze", "references"]) { mkdirSync(join(skills, d), { recursive: true }); writeFileSync(join(skills, d, "f.md"), "x"); }
    writeFileSync(join(skills, "cursor-skills-meta.json"), JSON.stringify({ name: "cassiiopeia", version: "4.2.3" }));
    const io = { which: () => null, run: () => ({ code: 0, stdout: "", stderr: "" }), home: () => home, log: () => {} };
    adapterById("cursor").apply(io, { sourceSkillsDir: src, templateVersion: "9.9.9" });
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
