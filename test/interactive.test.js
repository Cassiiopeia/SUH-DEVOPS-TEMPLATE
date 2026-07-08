import { test } from "node:test";
import assert from "node:assert/strict";
import { runInteractive } from "../src/commands/interactive.js";
import { CANCEL } from "../src/ui/prompts.js";
import { writeText, exists } from "../src/core/fsutil.js";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

// 최소 템플릿 소스 (local acquire용)
function makeSource(dir) {
  const b = join(dir, ".github/workflows/project-types");
  writeText(join(b, "common/PROJECT-COMMON-CI.yaml"), "name: ci\n");
  writeText(join(b, "react/PROJECT-REACT-CICD.yaml"), '  APP: "__X__"  # @wizard ask:myapp\n');
  writeText(join(dir, ".github/scripts/version_manager.sh"), "#!/bin/bash\n");
  writeText(join(dir, ".github/ISSUE_TEMPLATE/bug.md"), "bug\n");
  writeText(join(dir, "version.yml"), 'version: "3.0.0"\n');
}

// io 스텁 팩토리 — 지정 시퀀스대로 응답
function stubIo(answers) {
  const q = { ...answers };
  const noop = () => {};
  return {
    intro: noop, outro: noop, note: noop, cancelMessage: noop,
    selectMode: async () => q.mode,
    confirmProjectMenu: async () => q.confirm ?? "continue",
    editMenu: async () => "done",
    selectTypes: async () => q.types ?? CANCEL,
    askText: async (_m, d) => d,
    askYesNo: async (_m, i) => i,
  };
}

test("대화형: 모드 취소 → exit 0, 파일 미생성", async () => {
  const src = mkdtempSync(join(tmpdir(), "iasrc-"));
  const cwd = mkdtempSync(join(tmpdir(), "iacwd-"));
  try {
    makeSource(src);
    const code = await runInteractive({}, {
      cwd, source: { type: "local", path: src }, clock: { now: "n", today: "t" },
      io: stubIo({ mode: CANCEL }),
    });
    assert.equal(code, 0);
    assert.equal(exists(join(cwd, "version.yml")), false); // 취소라 통합 안 함
  } finally { rmSync(src, { recursive: true, force: true }); rmSync(cwd, { recursive: true, force: true }); }
});

test("대화형: full 선택 → continue → 실제 통합 실행", async () => {
  const src = mkdtempSync(join(tmpdir(), "iasrc2-"));
  const cwd = mkdtempSync(join(tmpdir(), "iacwd2-"));
  try {
    makeSource(src);
    writeText(join(cwd, "package.json"), '{"dependencies":{"react":"18"}}'); // react 감지
    const code = await runInteractive({}, {
      cwd, source: { type: "local", path: src }, clock: { now: "2026-07-08 00:00:00", today: "2026-07-08" },
      io: stubIo({ mode: "full", confirm: "continue" }),
    });
    assert.equal(code, 0);
    // full 모드 산출물
    assert.ok(exists(join(cwd, "version.yml")));
    assert.ok(exists(join(cwd, ".github/workflows/PROJECT-COMMON-CI.yaml")));
    assert.ok(exists(join(cwd, ".github/workflows/PROJECT-REACT-CICD.yaml")));
    // TEMP 정리됨
    assert.equal(exists(join(cwd, ".template_download_temp")), false);
  } finally { rmSync(src, { recursive: true, force: true }); rmSync(cwd, { recursive: true, force: true }); }
});

test("대화형: issues 모드 → 템플릿만", async () => {
  const src = mkdtempSync(join(tmpdir(), "iasrc3-"));
  const cwd = mkdtempSync(join(tmpdir(), "iacwd3-"));
  try {
    makeSource(src);
    const code = await runInteractive({}, {
      cwd, source: { type: "local", path: src }, clock: { now: "n", today: "t" },
      io: stubIo({ mode: "issues" }),
    });
    assert.equal(code, 0);
    assert.ok(exists(join(cwd, ".github/ISSUE_TEMPLATE/bug.md")));
    assert.equal(exists(join(cwd, "version.yml")), false); // issues는 version.yml 안 만듦
  } finally { rmSync(src, { recursive: true, force: true }); rmSync(cwd, { recursive: true, force: true }); }
});

test("대화형: skills 모드 → 안내 후 exit 1 (SP2-D 예정)", async () => {
  const cwd = mkdtempSync(join(tmpdir(), "iacwd4-"));
  try {
    const code = await runInteractive({}, {
      cwd, source: { type: "local", path: cwd }, io: stubIo({ mode: "skills" }),
    });
    assert.equal(code, 1);
  } finally { rmSync(cwd, { recursive: true, force: true }); }
});
