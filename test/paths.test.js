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

test("listYamlFiles: .yaml 먼저 → .yml 나중, 각 그룹 알파벳순 (.sh glob 순서와 일치)", () => {
  const d = mkdtempSync(join(tmpdir(), "pathstest-"));
  try {
    // 확장자 혼합 + 그룹 내 순서 뒤섞어 넣어 그룹핑·정렬 둘 다 검증
    writeText(join(d, "b.yaml"), "x");
    writeText(join(d, "a.yml"), "y");
    writeText(join(d, "a.yaml"), "x2");
    writeText(join(d, "c.txt"), "z");
    writeText(join(d, "sub", "nested.yaml"), "w"); // 하위 폴더 제외 대상
    // .sh: `for f in *.yaml *.yml` → .yaml 그룹(a,b) 먼저, 그다음 .yml 그룹(a)
    assert.deepEqual(listYamlFiles(d), ["a.yaml", "b.yaml", "a.yml"]);
  } finally {
    rmSync(d, { recursive: true, force: true });
  }
});

test("exists 없는 경로 false", () => {
  assert.equal(exists(join(tmpdir(), "__no_such_paths_test__")), false);
});
