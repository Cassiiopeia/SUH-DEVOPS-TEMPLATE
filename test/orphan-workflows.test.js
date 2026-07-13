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
