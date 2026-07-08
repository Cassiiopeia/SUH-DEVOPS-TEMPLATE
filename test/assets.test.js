import { test } from "node:test";
import assert from "node:assert/strict";
import { acquireTemplate, applyExclusions, readTemplateVersion } from "../src/core/assets.js";
import { writeText, exists } from "../src/core/fsutil.js";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

function makeSource(dir) {
  // 가짜 템플릿 트리
  writeText(join(dir, ".github", "workflows", "PROJECT-COMMON-X.yaml"), "name: x\n");
  writeText(join(dir, "CLAUDE.md"), "template only\n");
  writeText(join(dir, "CONTRIBUTING.md"), "c\n");
  writeText(join(dir, ".claude-plugin", "plugin.json"), "{}\n");
  writeText(join(dir, "bin", "projectops.js"), "// cli\n");
  writeText(join(dir, "skills", "x", "SKILL.md"), "keep me\n");
  writeText(join(dir, "version.yml"), 'version: "3.0.192"\nproject_types: ["basic"]\n');
  writeText(join(dir, ".github", "workflows", "PROJECT-TEMPLATE-NPM-PUBLISH.yaml"), "name: npm\n");
}

test("acquireTemplate local + applyExclusions: 마켓 전용 제거, skills 보존", () => {
  const src = mkdtempSync(join(tmpdir(), "assrc-"));
  const tmp = mkdtempSync(join(tmpdir(), "astmp-"));
  rmSync(tmp, { recursive: true, force: true }); // acquire가 새로 만듦
  try {
    makeSource(src);
    acquireTemplate({ tempDir: tmp, source: { type: "local", path: src } });
    // 제거되어야
    assert.equal(exists(join(tmp, "CLAUDE.md")), false);
    assert.equal(exists(join(tmp, "CONTRIBUTING.md")), false);
    assert.equal(exists(join(tmp, ".claude-plugin")), false);
    assert.equal(exists(join(tmp, "bin")), false);
    assert.equal(exists(join(tmp, ".github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml")), false);
    // 보존되어야
    assert.equal(exists(join(tmp, "skills/x/SKILL.md")), true);
    assert.equal(exists(join(tmp, ".github/workflows/PROJECT-COMMON-X.yaml")), true);
    // 버전
    assert.equal(readTemplateVersion(tmp), "3.0.192");
  } finally {
    rmSync(src, { recursive: true, force: true });
    rmSync(tmp, { recursive: true, force: true });
  }
});

test("readTemplateVersion fallback DEFAULT when no version.yml", () => {
  const d = mkdtempSync(join(tmpdir(), "asver-"));
  try {
    assert.equal(readTemplateVersion(d), "1.3.14");
  } finally {
    rmSync(d, { recursive: true, force: true });
  }
});
