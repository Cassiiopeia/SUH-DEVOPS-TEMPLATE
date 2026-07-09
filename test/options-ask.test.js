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
function makeTemplateFixture({ secretBackup = true } = {}) {
  const dir = makeTmp();
  const pt = ".github/workflows/project-types";
  touch(dir, `${pt}/common/PROJECT-COMMON-CI.yaml`);
  if (secretBackup) touch(dir, `${pt}/common/secret-backup/PROJECT-COMMON-SECRET-FILE-UPLOAD.yaml`);
  return dir;
}

// version.yml — 신 축(deploy/publish) 형식
const VY_NEW = (deploy, publish, secret) => `version: "1.0.0"
project_types: ["spring"]
metadata:
  last_updated: "2026-07-08"
  template:
    source: "projectops"
    version: "4.2.0"
    options:
      deploy: "${deploy}"
      publish: [${publish.map((t) => `"${t}"`).join(",")}]
      secret_backup: ${secret}
`;

// version.yml — 구 축(nexus/npm_publish) 형식 (v4.2.0 이전 — 마이그레이션 확인용)
const VY_LEGACY = (nexus, secret) => `version: "1.0.0"
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

// io 스텁 — confirm(Secret) + select(deploy) + multiselect(publish) 응답 시퀀스
function stubIo({ confirms = [], selects = [], multiselects = [] } = {}) {
  const calls = { confirm: [], select: [], multiselect: [] };
  return {
    calls,
    log: () => {},
    confirm: async (a) => { calls.confirm.push(a.message); return confirms.shift(); },
    select: async (a) => { calls.select.push(a.message); return selects.shift(); },
    multiselect: async (a) => { calls.multiselect.push(a.message); return multiselects.shift(); },
  };
}

test("parseTemplateOptions: 신 축 deploy/publish 파싱", () => {
  assert.deepEqual(parseTemplateOptions(VY_NEW("vercel", ["npm", "nexus"], false)),
    { deploy: "vercel", publish: ["npm", "nexus"], secretBackup: false });
  assert.deepEqual(parseTemplateOptions(VY_NEW("docker-ssh", [], true)),
    { deploy: "docker-ssh", publish: [], secretBackup: true });
  assert.deepEqual(parseTemplateOptions('version: "1.0.0"\nproject_types: ["spring"]\n'),
    { deploy: null, publish: null, secretBackup: null }); // options 블록 없음 → null
});

test("parseTemplateOptions: 구 키 자동 마이그레이션 (nexus:true → publish:[nexus] + deploy:none)", () => {
  assert.deepEqual(parseTemplateOptions(VY_LEGACY("true", "false")),
    { deploy: "none", publish: ["nexus"], secretBackup: false });
  assert.deepEqual(parseTemplateOptions(VY_LEGACY("false", "true")),
    { deploy: null, publish: [], secretBackup: true }); // nexus:false → publish 빈배열, deploy 미변경
});

test("parseTemplateOptions: 신 publish 키가 있으면 구 키 마이그레이션 안 함", () => {
  const y = VY_NEW("vercel", ["npm"], false) + "      nexus: true\n";
  const r = parseTemplateOptions(y);
  assert.equal(r.deploy, "vercel");
  assert.deepEqual(r.publish, ["npm"]); // 신 publish 우선 — 구 nexus 무시
});

test("parseTemplateOptions: template 섹션 밖의 nexus 키는 무시", () => {
  const y = 'nexus: true\nmetadata:\n  foo: "bar"\n';
  assert.deepEqual(parseTemplateOptions(y), { deploy: null, publish: null, secretBackup: null });
});

test("parseExisting: options 필드 포함 반환 (신 축)", () => {
  const r = parseExisting(VY_NEW("vercel", ["npm"], false));
  assert.deepEqual(r.options, { deploy: "vercel", publish: ["npm"], secretBackup: false });
  assert.equal(r.version, "1.0.0");
});

test("askAllOptionalWorkflows: 대화형 — deploy=vercel / publish=[npm] / secret=아니오", async () => {
  const tempDir = makeTemplateFixture();
  const target = makeTmp();
  try {
    const io = stubIo({ selects: ["vercel"], multiselects: [["npm"]], confirms: [false] });
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["spring"], targetRoot: target, tty: true, io,
    });
    assert.deepEqual(r, { deploy: "vercel", publish: ["npm"], secretBackup: false });
    assert.equal(io.calls.select.length, 1);
    assert.equal(io.calls.multiselect.length, 1);
    assert.equal(io.calls.confirm.length, 1);
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: basic 단독 타입은 배포/publish 질문 스킵 → none·[] (UX 개선)", async () => {
  const tempDir = makeTemplateFixture({ secretBackup: false }); // Secret 폴더 없음 → 질문 0
  const target = makeTmp();
  try {
    const io = stubIo({ selects: ["vercel"], multiselects: [["npm"]] }); // 호출되면 값이 바뀜 — 호출 안 돼야 함
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["basic"], targetRoot: target, tty: true, io,
    });
    assert.deepEqual(r, { deploy: "none", publish: [], secretBackup: false });
    assert.equal(io.calls.select.length, 0, "배포 방식 질문 안 함");
    assert.equal(io.calls.multiselect.length, 0, "publish 질문 안 함");
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: basic이어도 Secret 백업 폴더가 있으면 그 질문은 유지", async () => {
  const tempDir = makeTemplateFixture({ secretBackup: true });
  const target = makeTmp();
  try {
    const io = stubIo({ confirms: [false] }); // Secret 질문만 1회
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["basic"], targetRoot: target, tty: true, io,
    });
    assert.deepEqual(r, { deploy: "none", publish: [], secretBackup: false });
    assert.equal(io.calls.select.length, 0);
    assert.equal(io.calls.multiselect.length, 0);
    assert.equal(io.calls.confirm.length, 1, "Secret 백업은 폴더 존재 게이트로 계속 질문");
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: 비대화형 — current 유지, 미설정은 기본값", async () => {
  const tempDir = makeTemplateFixture();
  const target = makeTmp();
  try {
    const io = stubIo(); // 호출 자체가 없어야 함
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["spring"], current: { deploy: "vercel", publish: null, secretBackup: null },
      targetRoot: target, force: true, tty: false, io,
    });
    assert.deepEqual(r, { deploy: "vercel", publish: [], secretBackup: false });
    assert.equal(io.calls.select.length, 0);
    assert.equal(io.calls.multiselect.length, 0);
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: version.yml 저장값 있으면 재질문 생략", async () => {
  const tempDir = makeTemplateFixture();
  const target = makeTmp();
  try {
    touch(target, "version.yml", VY_NEW("vercel", ["nexus"], false));
    const io = stubIo({ selects: ["docker-ssh"], multiselects: [[]], confirms: [true] }); // 호출되면 반대값
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["spring"], targetRoot: target, tty: true, io,
    });
    assert.deepEqual(r, { deploy: "vercel", publish: ["nexus"], secretBackup: false });
    assert.equal(io.calls.select.length, 0); // 저장값 유지 — 질문 없음
    assert.equal(io.calls.multiselect.length, 0);
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: 구 키 저장 파일 → 신 축으로 마이그레이션해 읽음", async () => {
  const tempDir = makeTemplateFixture({ secretBackup: false });
  const target = makeTmp();
  try {
    touch(target, "version.yml", VY_LEGACY("true", "false"));
    const io = stubIo(); // 저장값이 채워지므로 질문 없음
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["spring"], targetRoot: target, tty: true, io,
    });
    assert.deepEqual(r, { deploy: "none", publish: ["nexus"], secretBackup: false });
    assert.equal(io.calls.select.length, 0);
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: forceAsk=true — 저장값 무시하고 재질문", async () => {
  const tempDir = makeTemplateFixture();
  const target = makeTmp();
  try {
    touch(target, "version.yml", VY_NEW("docker-ssh", [], false));
    const io = stubIo({ selects: ["none"], multiselects: [["nexus", "github-packages"]], confirms: [true] });
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["spring"], targetRoot: target, tty: true, io, forceAsk: true,
    });
    assert.deepEqual(r, { deploy: "none", publish: ["nexus", "github-packages"], secretBackup: true });
    assert.equal(io.calls.select.length, 1);
    assert.equal(io.calls.multiselect.length, 1);
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: multiselect ESC(cancel) → publish 빈 배열", async () => {
  const tempDir = makeTemplateFixture({ secretBackup: false });
  const target = makeTmp();
  try {
    const io = stubIo({ selects: ["docker-ssh"], multiselects: [Symbol("cancel")] });
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["spring"], targetRoot: target, tty: true, io,
    });
    assert.deepEqual(r, { deploy: "docker-ssh", publish: [], secretBackup: false });
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});
