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
