// 기존 워크플로우 충돌 3지선(skip/backup/template) 테스트 — decisions Map + copyWorkflowsInteractive.
// (기존 copy-workflows.test.js는 무수정 — force 기본 동작 회귀는 그쪽이 보증한다.)
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { copyWorkflows, copyWorkflowsInteractive, listWorkflowConflicts } from "../src/core/copy/workflows.js";
import { writeText, exists, readText } from "../src/core/fsutil.js";

function fresh(p) { return mkdtempSync(join(tmpdir(), p)); }

// 템플릿: react 워크플로우 1개(@wizard ask, 기본값 myapp) — 설치 예상 최종형 = '  APP: "myapp"\n'
function makeTemplate(tempDir) {
  writeText(
    join(tempDir, ".github/workflows/project-types/react/PROJECT-REACT-CICD.yaml"),
    '  APP: "__X__"  # @wizard ask:myapp\n',
  );
}

// 대상: 같은 파일이 이미 존재하고 내용이 다름(changed) → 충돌
function makeConflictTarget(tgt) {
  writeText(join(tgt, ".github/workflows/PROJECT-REACT-CICD.yaml"), '  APP: "custom"\n');
}

const ctx = () => ({
  types: ["react"], paths: new Map(), includeNexus: false, includeSecretBackup: false,
  force: true, repoName: "r", resolvers: {},
});

test("decisions 'backup': 기존 → .bak 보존 + 새 버전 복사·env 치환", () => {
  const tmp = fresh("cfb-t-"); const tgt = fresh("cfb-g-");
  try {
    makeTemplate(tmp); makeConflictTarget(tgt);
    const decisions = new Map([["PROJECT-REACT-CICD.yaml", "backup"]]);
    const c = copyWorkflows(ctx(), tmp, tgt, { decisions });
    const wf = join(tgt, ".github/workflows");
    assert.equal(readText(join(wf, "PROJECT-REACT-CICD.yaml.bak")), '  APP: "custom"\n', "기존 내용 .bak 보존");
    assert.equal(readText(join(wf, "PROJECT-REACT-CICD.yaml")), '  APP: "myapp"\n', "새 버전 + env 치환");
    assert.equal(c.copied, 1);
    assert.equal(c.skipped, 0);
  } finally { rmSync(tmp, { recursive: true, force: true }); rmSync(tgt, { recursive: true, force: true }); }
});

test("decisions 'template': 기존 유지 + 새 버전을 .template.yaml로 추가", () => {
  const tmp = fresh("cft-t-"); const tgt = fresh("cft-g-");
  try {
    makeTemplate(tmp); makeConflictTarget(tgt);
    const decisions = new Map([["PROJECT-REACT-CICD.yaml", "template"]]);
    const c = copyWorkflows(ctx(), tmp, tgt, { decisions });
    const wf = join(tgt, ".github/workflows");
    assert.equal(readText(join(wf, "PROJECT-REACT-CICD.yaml")), '  APP: "custom"\n', "기존 파일 무변경");
    assert.ok(exists(join(wf, "PROJECT-REACT-CICD.template.yaml")), ".template.yaml 생성");
    assert.equal(exists(join(wf, "PROJECT-REACT-CICD.yaml.bak")), false, "백업 없음");
    assert.equal(c.templateAdded, 1);
  } finally { rmSync(tmp, { recursive: true, force: true }); rmSync(tgt, { recursive: true, force: true }); }
});

test("decisions 'skip'/미지정: 기존 유지 (현행 force 동작과 동일)", () => {
  const tmp = fresh("cfs-t-"); const tgt = fresh("cfs-g-");
  try {
    makeTemplate(tmp); makeConflictTarget(tgt);
    // 미지정(빈 decisions) = 'skip'
    const c = copyWorkflows(ctx(), tmp, tgt, { decisions: new Map() });
    const wf = join(tgt, ".github/workflows");
    assert.equal(readText(join(wf, "PROJECT-REACT-CICD.yaml")), '  APP: "custom"\n');
    assert.equal(exists(join(wf, "PROJECT-REACT-CICD.template.yaml")), false);
    assert.equal(c.skipped, 1);
  } finally { rmSync(tmp, { recursive: true, force: true }); rmSync(tgt, { recursive: true, force: true }); }
});

test("copyWorkflowsInteractive: onConflict가 (filename, type)으로 호출되고 결정이 반영됨", async () => {
  const tmp = fresh("cfi-t-"); const tgt = fresh("cfi-g-");
  try {
    makeTemplate(tmp); makeConflictTarget(tgt);
    const calls = [];
    const c = await copyWorkflowsInteractive(ctx(), tmp, tgt, {
      onConflict: async (filename, type) => { calls.push([filename, type]); return "backup"; },
    });
    assert.deepEqual(calls, [["PROJECT-REACT-CICD.yaml", "react"]]);
    const wf = join(tgt, ".github/workflows");
    assert.equal(readText(join(wf, "PROJECT-REACT-CICD.yaml")), '  APP: "myapp"\n');
    assert.ok(exists(join(wf, "PROJECT-REACT-CICD.yaml.bak")));
    assert.equal(c.copied, 1);
  } finally { rmSync(tmp, { recursive: true, force: true }); rmSync(tgt, { recursive: true, force: true }); }
});

test("copyWorkflowsInteractive: onConflict 미지정 → 전부 skip (동기 엔진 기본과 등가)", async () => {
  const tmp = fresh("cfn-t-"); const tgt = fresh("cfn-g-");
  try {
    makeTemplate(tmp); makeConflictTarget(tgt);
    const c = await copyWorkflowsInteractive(ctx(), tmp, tgt, {});
    assert.equal(readText(join(tgt, ".github/workflows/PROJECT-REACT-CICD.yaml")), '  APP: "custom"\n');
    assert.equal(c.skipped, 1);
  } finally { rmSync(tmp, { recursive: true, force: true }); rmSync(tgt, { recursive: true, force: true }); }
});

test("listWorkflowConflicts: changed만 나열 (unchanged/신규 제외) — server-deploy 포함", () => {
  const tmp = fresh("cfl-t-"); const tgt = fresh("cfl-g-");
  try {
    makeTemplate(tmp);
    // unchanged 파일(설치 예상 최종형과 동일) — 충돌 아님
    writeText(join(tmp, ".github/workflows/project-types/react/PROJECT-REACT-CI.yaml"), "name: ci\n");
    writeText(join(tgt, ".github/workflows/PROJECT-REACT-CI.yaml"), "name: ci\n");
    makeConflictTarget(tgt); // CICD만 changed
    // spring server-deploy changed 충돌
    writeText(join(tmp, ".github/workflows/project-types/spring/server-deploy/PROJECT-SPRING-SIMPLE-CICD.yaml"), "name: v2\n");
    writeText(join(tgt, ".github/workflows/PROJECT-SPRING-SIMPLE-CICD.yaml"), "name: v1\n");
    const conflicts = listWorkflowConflicts({ ...ctx(), types: ["react", "spring"] }, tmp, tgt);
    assert.deepEqual(conflicts, [
      { filename: "PROJECT-REACT-CICD.yaml", type: "react" },
      { filename: "PROJECT-SPRING-SIMPLE-CICD.yaml", type: "spring" },
    ]);
  } finally { rmSync(tmp, { recursive: true, force: true }); rmSync(tgt, { recursive: true, force: true }); }
});

test("env 계획 결과 주입: context.envValues + envUseDefaults=false → 사용자값으로 치환", () => {
  const tmp = fresh("cfv-t-"); const tgt = fresh("cfv-g-");
  try {
    makeTemplate(tmp);
    const c = { ...ctx(), envValues: new Map([["APP", "zzz"]]), envUseDefaults: false };
    copyWorkflows(c, tmp, tgt);
    assert.equal(readText(join(tgt, ".github/workflows/PROJECT-REACT-CICD.yaml")), '  APP: "zzz"\n');
  } finally { rmSync(tmp, { recursive: true, force: true }); rmSync(tgt, { recursive: true, force: true }); }
});
