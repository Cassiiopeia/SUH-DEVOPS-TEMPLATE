import { test } from "node:test";
import assert from "node:assert/strict";
import { copyCoderabbit } from "../src/core/copy/coderabbit.js";
import { copyUtilModules } from "../src/core/copy/util.js";
import { writeText, exists, readText } from "../src/core/fsutil.js";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

function fresh(p) { return mkdtempSync(join(tmpdir(), p)); }

test("copyCoderabbit 신규 복사", () => {
  const tmp = fresh("cr-t-"); const tgt = fresh("cr-g-");
  try {
    writeText(join(tmp, ".coderabbit.yaml"), "language: ko-KR\n");
    assert.equal(copyCoderabbit(tmp, { force: true }, tgt), "copied-new");
    assert.ok(exists(join(tgt, ".coderabbit.yaml")));
  } finally { rmSync(tmp, { recursive: true, force: true }); rmSync(tgt, { recursive: true, force: true }); }
});

test("copyCoderabbit 기존 있으면 force로 .bak 백업 후 덮어쓰기", () => {
  const tmp = fresh("cr2t-"); const tgt = fresh("cr2g-");
  try {
    writeText(join(tmp, ".coderabbit.yaml"), "new\n");
    writeText(join(tgt, ".coderabbit.yaml"), "old\n");
    assert.equal(copyCoderabbit(tmp, { force: true }, tgt), "overwritten-backup");
    assert.equal(readText(join(tgt, ".coderabbit.yaml")), "new\n");
    assert.equal(readText(join(tgt, ".coderabbit.yaml.bak")), "old\n");
  } finally { rmSync(tmp, { recursive: true, force: true }); rmSync(tgt, { recursive: true, force: true }); }
});

test("copyCoderabbit 소스 없으면 스킵", () => {
  const tmp = fresh("cr3t-"); const tgt = fresh("cr3g-");
  try {
    assert.equal(copyCoderabbit(tmp, { force: true }, tgt), "skip-no-src");
  } finally { rmSync(tmp, { recursive: true, force: true }); rmSync(tgt, { recursive: true, force: true }); }
});

test("copyUtilModules force로 모듈 복사 + 카운트", () => {
  const tmp = fresh("ut-t-"); const tgt = fresh("ut-g-");
  try {
    writeText(join(tmp, ".github/util/flutter/wizard-a/run.sh"), "a\n");
    writeText(join(tmp, ".github/util/flutter/wizard-b/run.sh"), "b\n");
    const r = copyUtilModules(tmp, "flutter", { force: true }, tgt);
    assert.equal(r.copied, true);
    assert.equal(r.moduleCount, 2);
    assert.ok(exists(join(tgt, ".github/util/flutter/wizard-a/run.sh")));
  } finally { rmSync(tmp, { recursive: true, force: true }); rmSync(tgt, { recursive: true, force: true }); }
});

test("copyUtilModules 소스 없으면 스킵", () => {
  const tmp = fresh("ut2t-"); const tgt = fresh("ut2g-");
  try {
    assert.deepEqual(copyUtilModules(tmp, "spring", { force: true }, tgt), { copied: false, moduleCount: 0 });
  } finally { rmSync(tmp, { recursive: true, force: true }); rmSync(tgt, { recursive: true, force: true }); }
});
