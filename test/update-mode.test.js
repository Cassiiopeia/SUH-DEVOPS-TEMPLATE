// 업데이트 모드 (#502) — 메뉴 노출, 저장 범위 재실행, 충돌 일괄 처리, env carryover, mode 기록.
import { test } from "node:test";
import assert from "node:assert/strict";
import { runInteractive } from "../src/commands/interactive.js";
import { buildVersionYml, parseExisting } from "../src/core/version-yml.js";
import { extractEnvValues } from "../src/core/wizard-env.js";
import { writeText, exists } from "../src/core/fsutil.js";
import { mkdtempSync, rmSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

function makeSource(dir) {
  const b = join(dir, ".github/workflows/project-types");
  writeText(join(b, "common/PROJECT-COMMON-CI.yaml"), "name: ci\n");
  writeText(join(b, "react/PROJECT-REACT-CICD.yaml"), '  APP: "__X__"  # @wizard ask:myapp\n');
  writeText(join(dir, ".github/scripts/version_manager.sh"), "#!/bin/bash\n");
  writeText(join(dir, ".github/ISSUE_TEMPLATE/bug.md"), "bug\n");
  writeText(join(dir, "version.yml"), 'version: "4.2.22"\n');
}

// 기존 통합 흔적이 있는 대상 레포 version.yml (template 블록 + mode)
function existingVersionYml({ mode = "full" } = {}) {
  return [
    'version: "1.0.0"',
    "version_code: 3",
    'project_types: ["react"]',
    "metadata:",
    '  last_updated: "x"',
    '  default_branch: "main"',
    "  template:",
    '    source: "projectops"',
    '    version: "4.2.20"',
    ...(mode ? [`    mode: "${mode}"`] : []),
    '    integrated_date: "2026-07-01"',
    "    options:",
    '      intent: "app"',
    '      deploy: "docker-ssh"',
    "      publish: []",
    "      secret_backup: false",
    "",
  ].join("\n");
}

function stubIo(overrides = {}) {
  const noop = () => {};
  return {
    intro: noop, outro: noop, note: noop, cancelMessage: noop,
    selectMode: async () => "update",
    confirmProjectMenu: async () => { throw new Error("업데이트 모드는 확인 루프를 건너뛰어야 한다"); },
    editMenu: async () => "done",
    selectTypes: async () => ["react"],
    askText: async (_m, d) => d,
    askYesNo: async (_m, i) => i, // 기본값 그대로 (충돌 질문 기본 Y)
    ...overrides,
  };
}

// ── version.yml mode 기록 라운드트립 ─────────────────────────────────

test("version.yml: template mode 기록 → parseExisting.templateMode 라운드트립", () => {
  const yml = buildVersionYml({
    version: "1.0.0", types: ["react"], branch: "main", versionCode: 1,
    now: "n", today: "t",
    templateOptions: { templateVersion: "4.2.22", mode: "full" },
  });
  assert.match(yml, /^\s+mode: "full"/m);
  assert.equal(parseExisting(yml).templateMode, "full");
});

test("version.yml: mode 없는 구 파일은 templateMode null", () => {
  assert.equal(parseExisting(existingVersionYml({ mode: null })).templateMode, null);
});

test("version.yml: 알 수 없는 mode 값은 무시 (null)", () => {
  assert.equal(parseExisting(existingVersionYml({ mode: "banana" })).templateMode, null);
});

// ── extractEnvValues ─────────────────────────────────────────────────

test("extractEnvValues: KEY 라인 실값 추출, 빈 값 제외, CRLF 허용", () => {
  const installed = '  APP: "custom-app"\r\n  EMPTY: ""\r\n  lower: "x"\n  PORT: "8080"\n';
  const v = extractEnvValues(installed);
  assert.equal(v.get("APP"), "custom-app");
  assert.equal(v.get("PORT"), "8080");
  assert.equal(v.has("EMPTY"), false); // 빈 값은 기본값 사용 (substituteEnv 규칙과 동일)
  assert.equal(v.has("lower"), false); // 대문자 KEY만
});

// ── 대화형 업데이트 경로 ─────────────────────────────────────────────

test("업데이트: 저장 mode 재실행 + 충돌 일괄 backup + env 실값 carryover + 스킬 installedOnly", async () => {
  const src = mkdtempSync(join(tmpdir(), "upsrc-"));
  const cwd = mkdtempSync(join(tmpdir(), "upcwd-"));
  try {
    makeSource(src);
    writeText(join(cwd, "version.yml"), existingVersionYml());
    // 설치본 워크플로우 — 사용자가 채운 실값 보유 (템플릿 기본값 myapp과 다름 → changed 충돌)
    writeText(join(cwd, ".github/workflows/PROJECT-REACT-CICD.yaml"), '  APP: "custom-app"\n');

    let selectModeArg = null;
    let skillsArgs = null;
    const code = await runInteractive({}, {
      cwd, source: { type: "local", path: src }, clock: { now: "2026-07-20 00:00:00", today: "2026-07-20" },
      io: stubIo({ selectMode: async (o) => { selectModeArg = o; return "update"; } }),
      skills: async (o) => { skillsArgs = o; return 0; },
    });
    assert.equal(code, 0);

    // 메뉴에 업데이트 정보가 전달됐다 (from/to)
    assert.equal(selectModeArg?.update?.from, "4.2.20");
    assert.equal(selectModeArg?.update?.to, "4.2.22");

    // 충돌 파일: .bak 백업 + 새 버전 교체 + 실값 carryover (기본값 myapp이 아니라 custom-app)
    const wf = readFileSync(join(cwd, ".github/workflows/PROJECT-REACT-CICD.yaml"), "utf8");
    assert.match(wf, /APP: "custom-app"/);
    assert.ok(!wf.includes("@wizard"), "치환 완료된 최종형이어야 한다");
    assert.ok(exists(join(cwd, ".github/workflows/PROJECT-REACT-CICD.yaml.bak")));

    // full 범위 재실행 산출물 + version.yml mode 기록 유지
    assert.ok(exists(join(cwd, ".github/workflows/PROJECT-COMMON-CI.yaml")));
    const vy = parseExisting(readFileSync(join(cwd, "version.yml"), "utf8"));
    assert.equal(vy.templateMode, "full");
    assert.equal(vy.templateVersion, "4.2.22");
    assert.deepEqual(vy.types, ["react"]); // 저장 타입 유지 (react 마커 없어도)

    // 스킬: 설치된 IDE만 질문 없이 업데이트
    assert.equal(skillsArgs?.interactive, false);
    assert.equal(skillsArgs?.installedOnly, true);
  } finally { rmSync(src, { recursive: true, force: true }); rmSync(cwd, { recursive: true, force: true }); }
});

test("업데이트: 교체 거절 시 기존 파일 유지 (skip, .bak 없음)", async () => {
  const src = mkdtempSync(join(tmpdir(), "upsrc2-"));
  const cwd = mkdtempSync(join(tmpdir(), "upcwd2-"));
  try {
    makeSource(src);
    writeText(join(cwd, "version.yml"), existingVersionYml());
    writeText(join(cwd, ".github/workflows/PROJECT-REACT-CICD.yaml"), '  APP: "custom-app"\n');

    const code = await runInteractive({}, {
      cwd, source: { type: "local", path: src }, clock: { now: "n", today: "t" },
      io: stubIo({ askYesNo: async () => false }),
      skills: async () => 0,
    });
    assert.equal(code, 0);
    assert.equal(readFileSync(join(cwd, ".github/workflows/PROJECT-REACT-CICD.yaml"), "utf8"), '  APP: "custom-app"\n');
    assert.equal(exists(join(cwd, ".github/workflows/PROJECT-REACT-CICD.yaml.bak")), false);
  } finally { rmSync(src, { recursive: true, force: true }); rmSync(cwd, { recursive: true, force: true }); }
});

test("업데이트: templateMode 기록 없는 구 레포는 full로 재실행", async () => {
  const src = mkdtempSync(join(tmpdir(), "upsrc3-"));
  const cwd = mkdtempSync(join(tmpdir(), "upcwd3-"));
  try {
    makeSource(src);
    writeText(join(cwd, "version.yml"), existingVersionYml({ mode: null }));

    const code = await runInteractive({}, {
      cwd, source: { type: "local", path: src }, clock: { now: "n", today: "t" },
      io: stubIo(),
      skills: async () => 0,
    });
    assert.equal(code, 0);
    // full 산출물 (이슈 템플릿 포함) + 이후 업데이트를 위한 mode 기록 생성
    assert.ok(exists(join(cwd, ".github/ISSUE_TEMPLATE/bug.md")));
    assert.equal(parseExisting(readFileSync(join(cwd, "version.yml"), "utf8")).templateMode, "full");
  } finally { rmSync(src, { recursive: true, force: true }); rmSync(cwd, { recursive: true, force: true }); }
});

test("신규 레포: selectMode에 update 미전달 (항목 미노출 조건)", async () => {
  const src = mkdtempSync(join(tmpdir(), "upsrc4-"));
  const cwd = mkdtempSync(join(tmpdir(), "upcwd4-"));
  try {
    makeSource(src);
    let selectModeArg = null;
    const code = await runInteractive({}, {
      cwd, source: { type: "local", path: src }, clock: { now: "n", today: "t" },
      io: stubIo({
        selectMode: async (o) => { selectModeArg = o; return "issues"; },
      }),
      skills: async () => 0,
    });
    assert.equal(code, 0);
    assert.equal(selectModeArg?.update ?? null, null);
  } finally { rmSync(src, { recursive: true, force: true }); rmSync(cwd, { recursive: true, force: true }); }
});
