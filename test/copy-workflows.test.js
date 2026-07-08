import { test } from "node:test";
import assert from "node:assert/strict";
import { copyWorkflows } from "../src/core/copy/workflows.js";
import { writeText, exists, readText } from "../src/core/fsutil.js";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

function fresh(p) { return mkdtempSync(join(tmpdir(), p)); }

// 소형 템플릿 트리 (tempDir/.github/workflows/project-types/...)
function makeTemplate(tempDir) {
  const base = join(tempDir, ".github/workflows/project-types");
  writeText(join(base, "common/PROJECT-COMMON-CI.yaml"), "name: common-ci\n");
  writeText(join(base, "react/PROJECT-REACT-CICD.yaml"), '  APP: "__X__"  # @wizard ask:myapp\n');
  writeText(join(base, "spring/server-deploy/PROJECT-SPRING-SIMPLE-CICD.yaml"), "name: spring-deploy\n");
  writeText(join(base, "spring/nexus/PROJECT-SPRING-NEXUS-PUBLISH.yaml"), "name: nexus\n");
  writeText(join(base, "common/secret-backup/PROJECT-COMMON-SECRET.yaml"), "name: secret\n");
}

test("copyWorkflows: common 복사 + 타입별 신규 + env 치환", () => {
  const tmp = fresh("wf-t-"); const tgt = fresh("wf-g-");
  try {
    makeTemplate(tmp);
    const ctx = { types: ["react"], paths: new Map(), includeNexus: false, includeSecretBackup: false, force: true, repoName: "projectops", resolvers: { repo: () => "projectops" } };
    const c = copyWorkflows(ctx, tmp, tgt);
    // common 복사됨
    assert.ok(exists(join(tgt, ".github/workflows/PROJECT-COMMON-CI.yaml")));
    // react 복사 + env 치환 (기본값 myapp)
    const react = readText(join(tgt, ".github/workflows/PROJECT-REACT-CICD.yaml"));
    assert.equal(react, '  APP: "myapp"\n'); // 원본 끝 개행 보존
    assert.ok(c.copied >= 2);
  } finally { rmSync(tmp, { recursive: true, force: true }); rmSync(tgt, { recursive: true, force: true }); }
});

test("copyWorkflows: server-deploy 포함(nexus 아님), nexus 제외", () => {
  const tmp = fresh("wf2t-"); const tgt = fresh("wf2g-");
  try {
    makeTemplate(tmp);
    const ctx = { types: ["spring"], paths: new Map(), includeNexus: false, includeSecretBackup: false, force: true, repoName: "r", resolvers: {} };
    copyWorkflows(ctx, tmp, tgt);
    assert.ok(exists(join(tgt, ".github/workflows/PROJECT-SPRING-SIMPLE-CICD.yaml")), "server-deploy 포함");
    assert.equal(exists(join(tgt, ".github/workflows/PROJECT-SPRING-NEXUS-PUBLISH.yaml")), false, "nexus 제외(opt-in)");
  } finally { rmSync(tmp, { recursive: true, force: true }); rmSync(tgt, { recursive: true, force: true }); }
});

test("copyWorkflows: --nexus면 server-deploy 폴더째 제외 + nexus 포함", () => {
  const tmp = fresh("wf3t-"); const tgt = fresh("wf3g-");
  try {
    makeTemplate(tmp);
    const ctx = { types: ["spring"], paths: new Map(), includeNexus: true, includeSecretBackup: false, force: true, repoName: "r", resolvers: {} };
    copyWorkflows(ctx, tmp, tgt);
    assert.equal(exists(join(tgt, ".github/workflows/PROJECT-SPRING-SIMPLE-CICD.yaml")), false, "nexus 프로젝트라 server-deploy 제외");
    assert.ok(exists(join(tgt, ".github/workflows/PROJECT-SPRING-NEXUS-PUBLISH.yaml")), "nexus 포함");
  } finally { rmSync(tmp, { recursive: true, force: true }); rmSync(tgt, { recursive: true, force: true }); }
});

test("copyWorkflows: secret-backup은 opt-in", () => {
  const tmp = fresh("wf4t-"); const tgt = fresh("wf4g-");
  try {
    makeTemplate(tmp);
    const noSB = { types: ["react"], paths: new Map(), includeNexus: false, includeSecretBackup: false, force: true, repoName: "r", resolvers: {} };
    copyWorkflows(noSB, tmp, tgt);
    assert.equal(exists(join(tgt, ".github/workflows/PROJECT-COMMON-SECRET.yaml")), false, "옵션 없으면 제외");

    const tgt2 = fresh("wf4g2-");
    const withSB = { ...noSB, includeSecretBackup: true };
    copyWorkflows(withSB, tmp, tgt2);
    assert.ok(exists(join(tgt2, ".github/workflows/PROJECT-COMMON-SECRET.yaml")), "옵션 있으면 포함");
    rmSync(tgt2, { recursive: true, force: true });
  } finally { rmSync(tmp, { recursive: true, force: true }); rmSync(tgt, { recursive: true, force: true }); }
});

test("copyWorkflows: common unchanged면 재복사 스킵", () => {
  const tmp = fresh("wf5t-"); const tgt = fresh("wf5g-");
  try {
    makeTemplate(tmp);
    // 대상에 이미 동일 common 설치돼 있음
    writeText(join(tgt, ".github/workflows/PROJECT-COMMON-CI.yaml"), "name: common-ci\n");
    const ctx = { types: ["react"], paths: new Map(), includeNexus: false, includeSecretBackup: false, force: true, repoName: "r", resolvers: {} };
    const c = copyWorkflows(ctx, tmp, tgt);
    assert.ok(c.skipped >= 1, "unchanged common 스킵");
  } finally { rmSync(tmp, { recursive: true, force: true }); rmSync(tgt, { recursive: true, force: true }); }
});
