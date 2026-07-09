import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { parseTemplateOptions, askAllOptionalWorkflows } from "../src/core/options-ask.js";
import { parseExisting } from "../src/core/version-yml.js";

function touch(root, rel, content = "") {
  const p = join(root, rel);
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, content);
}
function makeTmp() { return mkdtempSync(join(tmpdir(), "optask-")); }

// 실제 temp 레이아웃({tempDir}/.github/workflows/project-types)으로 픽스처 구성
function makeTemplateFixture({ nexus = true, secretBackup = true, npmPublish = false } = {}) {
  const dir = makeTmp();
  const pt = ".github/workflows/project-types";
  touch(dir, `${pt}/common/PROJECT-COMMON-CI.yaml`);
  if (nexus) touch(dir, `${pt}/spring/nexus/PROJECT-SPRING-NEXUS-PUBLISH.yaml`);
  if (secretBackup) touch(dir, `${pt}/common/secret-backup/PROJECT-COMMON-SECRET-FILE-UPLOAD.yaml`);
  if (npmPublish) touch(dir, `${pt}/node/npm-publish/PROJECT-NODE-NPM-PUBLISH.yaml`);
  return dir;
}

const VY_WITH_OPTIONS = (nexus, secret) => `version: "1.0.0"
project_types: ["spring"]
metadata:
  last_updated: "2026-07-08"
  template:
    source: "projectops"
    version: "3.0.0"
    options:
      nexus: ${nexus}
      secret_backup: ${secret}
`;

// io 스텁 — confirm 응답 시퀀스 + 호출 기록
function stubIo(confirms = []) {
  const calls = [];
  return {
    calls,
    log: () => {},
    confirm: async (a) => { calls.push(a.message); return confirms.shift(); },
  };
}

test("parseTemplateOptions: true/false/미존재", () => {
  assert.deepEqual(parseTemplateOptions(VY_WITH_OPTIONS("true", "false")),
    { nexus: true, secretBackup: false, npmPublish: null }); // npm_publish 미기재 → null
  assert.deepEqual(parseTemplateOptions(VY_WITH_OPTIONS('"false"', '"true"')),
    { nexus: false, secretBackup: true, npmPublish: null }); // 따옴표 제거 (.sh tr -d 등가)
  assert.deepEqual(parseTemplateOptions('version: "1.0.0"\nproject_types: ["spring"]\n'),
    { nexus: null, secretBackup: null, npmPublish: null }); // options 블록 없음 → null
});

test("parseTemplateOptions: template 섹션 밖의 nexus 키는 무시", () => {
  // options 블록 없이 다른 위치의 nexus: 는 상태머신에 안 걸린다
  const y = 'nexus: true\nmetadata:\n  foo: "bar"\n';
  assert.deepEqual(parseTemplateOptions(y), { nexus: null, secretBackup: null, npmPublish: null });
});

test("parseExisting: options 필드 포함 반환", () => {
  const r = parseExisting(VY_WITH_OPTIONS("true", "false"));
  assert.deepEqual(r.options, { nexus: true, secretBackup: false, npmPublish: null });
  // 기존 필드 회귀 확인
  assert.equal(r.version, "1.0.0");
});

test("askAllOptionalWorkflows: 대화형 — nexus 예 / secret 아니오", async () => {
  const tempDir = makeTemplateFixture();
  const target = makeTmp();
  try {
    const io = stubIo([true, false]); // nexus=예, secret=아니오
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["spring"], targetRoot: target, tty: true, io,
    });
    assert.deepEqual(r, { nexus: true, secretBackup: false, npmPublish: false });
    assert.equal(io.calls.length, 2);
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: 비대화형 — current 유지, 미설정은 false", async () => {
  const tempDir = makeTemplateFixture();
  const target = makeTmp();
  try {
    const io = stubIo(); // confirm 호출되면 undefined → false지만 호출 자체가 없어야 함
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["spring"], current: { nexus: true, secretBackup: null },
      targetRoot: target, force: true, tty: false, io,
    });
    assert.deepEqual(r, { nexus: true, secretBackup: false, npmPublish: false }); // CLI 명시값 유지 + 기본 false
    assert.equal(io.calls.length, 0);
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: version.yml 저장값 있으면 재질문 생략", async () => {
  const tempDir = makeTemplateFixture();
  const target = makeTmp();
  try {
    touch(target, "version.yml", VY_WITH_OPTIONS("true", "false"));
    const io = stubIo([false, true]); // 호출되면 반대값 — 호출 안 돼야 저장값이 남는다
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["spring"], targetRoot: target, tty: true, io,
    });
    assert.deepEqual(r, { nexus: true, secretBackup: false, npmPublish: false });
    assert.equal(io.calls.length, 0); // 저장값 유지 — 질문 없음
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: forceAsk=true — 저장값 무시하고 재질문", async () => {
  const tempDir = makeTemplateFixture();
  const target = makeTmp();
  try {
    touch(target, "version.yml", VY_WITH_OPTIONS("false", "false"));
    const io = stubIo([true, true]);
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["spring"], targetRoot: target, tty: true, io, forceAsk: true,
    });
    assert.deepEqual(r, { nexus: true, secretBackup: true, npmPublish: false });
    assert.equal(io.calls.length, 2);
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: node 타입 npm-publish 폴더 발견 시 질문 → 포함 (#438)", async () => {
  const tempDir = makeTemplateFixture({ nexus: false, secretBackup: false, npmPublish: true });
  const target = makeTmp();
  try {
    const io = stubIo([true]); // npm publish=예
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["node"], targetRoot: target, tty: true, io,
    });
    assert.deepEqual(r, { nexus: false, secretBackup: false, npmPublish: true });
    assert.equal(io.calls.length, 1);
    assert.match(io.calls[0], /npm 패키지 publish/);
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("parseTemplateOptions: npm_publish 키 파싱 (#438)", () => {
  const y = VY_WITH_OPTIONS("false", "false") + "      npm_publish: true\n";
  assert.deepEqual(parseTemplateOptions(y), { nexus: false, secretBackup: false, npmPublish: true });
});

test("askAllOptionalWorkflows: 폴더 없으면 질문 자체 생략 → false", async () => {
  const tempDir = makeTemplateFixture({ nexus: false, secretBackup: false, npmPublish: false });
  const target = makeTmp();
  try {
    const io = stubIo([true, true]); // 호출되면 true — 호출 안 돼야 false가 남는다
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["spring"], targetRoot: target, tty: true, io,
    });
    assert.deepEqual(r, { nexus: false, secretBackup: false, npmPublish: false });
    assert.equal(io.calls.length, 0);
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});
