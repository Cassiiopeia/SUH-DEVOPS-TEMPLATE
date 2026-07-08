// 등가성 회귀 수정 검증 — A1(version/version_code 보존), A2(spring resolver), A3(breaking 게이트)
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync, mkdirSync, writeFileSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { findSpringAppYml, makeResolvers } from "../src/core/detect-fs.js";
import { runBreakingCheck } from "../src/core/breaking-check.js";
import { run } from "../src/index.js";

const fresh = (p) => mkdtempSync(join(tmpdir(), p));
const write = (root, rel, content) => {
  mkdirSync(join(root, rel, ".."), { recursive: true });
  writeFileSync(join(root, rel), content);
};

// ── A2: spring application.yml 탐색 ──
test("findSpringAppYml: */src/main/resources/application*.yml 첫 매치 (상대경로)", () => {
  const root = fresh("spring-");
  try {
    write(root, "server/src/main/resources/application.yml", "spring:\n");
    write(root, "server/src/main/resources/application-prod.yml", "spring:\n");
    const hit = findSpringAppYml(root, ".");
    assert.equal(hit, "server/src/main/resources/application-prod.yml"); // 정렬 첫 매치 (find | head -1 결정화)
    // 모노레포 base 지정
    assert.equal(findSpringAppYml(root, "server"), "server/src/main/resources/application-prod.yml");
    // 매치 없음
    assert.equal(findSpringAppYml(root, "nowhere"), "");
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("makeResolvers: spring-app-yml-dir/path가 실값 반환 (스텁 아님)", () => {
  const root = fresh("resv-");
  try {
    write(root, "src/main/resources/application.yml", "spring:\n");
    const r = makeResolvers(root, "myrepo", new Map([["spring", "."]]));
    assert.equal(r.repo(), "myrepo");
    assert.equal(r["spring-app-yml-path"]("spring"), "src/main/resources/application.yml");
    assert.equal(r["spring-app-yml-dir"]("spring"), "src/main/resources");
    assert.equal(r["flutter-root"](), ".");
  } finally { rmSync(root, { recursive: true, force: true }); }
});

// ── A3: breaking 게이트 ──
const BC_FIXTURE = {
  _metadata: { note: "meta" },
  "4.0.0": { severity: "critical", title: "npx 전환", message: "curl 방식 폐기" },
  "3.5.0": { severity: "warning", title: "경고", message: "설정 이동" },
};

function targetWithTemplateMeta(root, current) {
  writeFileSync(join(root, "version.yml"), [
    'version: "1.0.0"',
    "version_code: 5",
    'project_types: ["basic"]',
    'project_type: "basic"',
    "metadata:",
    "  template:",
    `    version: "${current}"`,
    "",
  ].join("\n"));
}

test("runBreakingCheck: critical + 대화형 거부 → false(중단)", async () => {
  const root = fresh("bc1-");
  try {
    targetWithTemplateMeta(root, "3.0.0");
    const ok = await runBreakingCheck({
      cwd: root, tempDir: root, templateVersion: "4.0.3",
      askYesNo: async () => false, loader: async () => BC_FIXTURE,
    });
    assert.equal(ok, false);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("runBreakingCheck: critical + 비대화형(askYesNo 없음) → 경고 후 진행", async () => {
  const root = fresh("bc2-");
  try {
    targetWithTemplateMeta(root, "3.0.0");
    const ok = await runBreakingCheck({
      cwd: root, tempDir: root, templateVersion: "4.0.3",
      loader: async () => BC_FIXTURE,
    });
    assert.equal(ok, true);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("runBreakingCheck: 범위 밖(이미 최신)·메타 없음 → 진행", async () => {
  const root = fresh("bc3-");
  try {
    targetWithTemplateMeta(root, "4.0.2"); // 4.0.2 → 4.0.3 사이 breaking 없음
    assert.equal(await runBreakingCheck({ cwd: root, tempDir: root, templateVersion: "4.0.3", loader: async () => BC_FIXTURE }), true);
    // version.yml 자체가 없으면 신규 통합 — 항상 진행
    const empty = fresh("bc4-");
    try {
      assert.equal(await runBreakingCheck({ cwd: empty, tempDir: empty, templateVersion: "4.0.3", loader: async () => BC_FIXTURE }), true);
    } finally { rmSync(empty, { recursive: true, force: true }); }
  } finally { rmSync(root, { recursive: true, force: true }); }
});

// ── A1: E2E — 재실행 시 version/version_code 보존 ──
function makeTemplateFixture() {
  const tpl = fresh("tplfix-");
  write(tpl, ".github/scripts/version_manager.sh", "#!/bin/bash\n");
  write(tpl, ".github/scripts/changelog_manager.py", "# py\n");
  write(tpl, ".github/config/wizard-prompts.yml", "PROJECT_NAME:\n  label: \"이름\"\n");
  write(tpl, ".github/workflows/project-types/common/PROJECT-COMMON-CI.yaml", "name: ci\n");
  writeFileSync(join(tpl, "version.yml"), 'version: "4.0.3"\n');
  writeFileSync(join(tpl, "SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md"), "# guide\n");
  return tpl;
}

test("run(--mode version --force): 기존 version(9.9.9)·version_code(380) 보존 — 리셋 회귀 방지", async () => {
  const tpl = makeTemplateFixture();
  const target = fresh("tgt-");
  try {
    writeFileSync(join(target, "version.yml"), [
      'version: "9.9.9"',
      "version_code: 380  # app build number",
      'project_types: ["basic"]',
      'project_type: "basic"',
      "metadata:",
      '  last_updated: "2026-01-01 00:00:00"',
      "",
    ].join("\n"));
    const code = await run(["--mode", "version", "--force"], {
      cwd: target, source: { type: "local", path: tpl },
      clock: { now: "2026-07-08 00:00:00", today: "2026-07-08" },
    });
    assert.equal(code, 0);
    const out = readFileSync(join(target, "version.yml"), "utf8");
    assert.match(out, /^version: "9\.9\.9"$/m, "기존 버전이 보존돼야 함 (SSoT)");
    assert.match(out, /^version_code: 380/m, "기존 빌드번호가 보존돼야 함 (1로 리셋 금지)");
  } finally {
    rmSync(tpl, { recursive: true, force: true });
    rmSync(target, { recursive: true, force: true });
  }
});
