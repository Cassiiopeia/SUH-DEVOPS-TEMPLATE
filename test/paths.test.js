import { test } from "node:test";
import assert from "node:assert/strict";
import { PATHS, WORKFLOW_COMMON_PREFIX, WORKFLOW_TEMPLATE_INIT } from "../src/core/paths.js";
import { listYamlFiles, writeText, exists } from "../src/core/fsutil.js";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

test("PATHS 상수 (.sh 등가)", () => {
  assert.equal(PATHS.workflowsDir, ".github/workflows");
  assert.equal(PATHS.scriptsDir, ".github/scripts");
  assert.equal(PATHS.projectTypesDir, "project-types");
  assert.equal(WORKFLOW_COMMON_PREFIX, "PROJECT-COMMON");
  assert.equal(WORKFLOW_TEMPLATE_INIT, "PROJECT-TEMPLATE-INITIALIZER.yaml");
});

test("listYamlFiles 직하위 yaml/yml만 정렬 반환", () => {
  const d = mkdtempSync(join(tmpdir(), "pathstest-"));
  try {
    writeText(join(d, "b.yaml"), "x");
    writeText(join(d, "a.yml"), "y");
    writeText(join(d, "c.txt"), "z");
    writeText(join(d, "sub", "nested.yaml"), "w"); // 하위 폴더 제외 대상
    assert.deepEqual(listYamlFiles(d), ["a.yml", "b.yaml"]);
  } finally {
    rmSync(d, { recursive: true, force: true });
  }
});

test("exists 없는 경로 false", () => {
  assert.equal(exists(join(tmpdir(), "__no_such_paths_test__")), false);
});
