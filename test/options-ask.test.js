import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { parseTemplateOptions, askAllOptionalWorkflows } from "../src/core/options-ask.js";
import { parseExisting, buildVersionYml } from "../src/core/version-yml.js";

function touch(root, rel, content = "") {
  const p = join(root, rel);
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, content);
}
function makeTmp() { return mkdtempSync(join(tmpdir(), "optask-")); }

// #455에서 추가된 changelog/code_review 필드의 기본값(미기재 → null).
// 기존 deepEqual 기대값에 spread해 필드 추가로 인한 회귀를 막는다.
const CL_NULL = { changelogProvider: null, changelogBaseUrl: null, codeReviewCoderabbit: null, deployBranch: null };

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

// version.yml — changelog/code_review 옵션 포함 (#455)
const VY_CHANGELOG = (provider, baseUrl, coderabbit) => `version: "1.0.0"
project_types: ["basic"]
metadata:
  last_updated: "2026-07-09"
  template:
    source: "projectops"
    version: "4.3.0"
    options:
      deploy: "none"
      publish: []
      secret_backup: false
      code_review:
        coderabbit: ${coderabbit}
      changelog:
        provider: "${provider}"
        base_url: "${baseUrl}"
`;

// io 스텁 — confirm(Secret/CodeRabbit) + select(deploy/changelog) + multiselect(publish) + text(ollama base_url) 응답 시퀀스
function stubIo({ confirms = [], selects = [], multiselects = [], texts = [] } = {}) {
  const calls = { confirm: [], select: [], multiselect: [], text: [] };
  return {
    calls,
    log: () => {},
    confirm: async (a) => { calls.confirm.push(a.message); return confirms.shift(); },
    select: async (a) => { calls.select.push(a.message); return selects.shift(); },
    multiselect: async (a) => { calls.multiselect.push(a.message); return multiselects.shift(); },
    text: async (a) => { calls.text.push(a.message); return texts.shift(); },
  };
}

test("parseTemplateOptions: 신 축 deploy/publish 파싱", () => {
  assert.deepEqual(parseTemplateOptions(VY_NEW("vercel", ["npm", "nexus"], false)),
    { deploy: "vercel", publish: ["npm", "nexus"], secretBackup: false, ...CL_NULL });
  assert.deepEqual(parseTemplateOptions(VY_NEW("docker-ssh", [], true)),
    { deploy: "docker-ssh", publish: [], secretBackup: true, ...CL_NULL });
  assert.deepEqual(parseTemplateOptions('version: "1.0.0"\nproject_types: ["spring"]\n'),
    { deploy: null, publish: null, secretBackup: null, ...CL_NULL }); // options 블록 없음 → null
});

test("parseTemplateOptions: 구 키 자동 마이그레이션 (nexus:true → publish:[nexus] + deploy:none)", () => {
  assert.deepEqual(parseTemplateOptions(VY_LEGACY("true", "false")),
    { deploy: "none", publish: ["nexus"], secretBackup: false, ...CL_NULL });
  assert.deepEqual(parseTemplateOptions(VY_LEGACY("false", "true")),
    { deploy: null, publish: [], secretBackup: true, ...CL_NULL }); // nexus:false → publish 빈배열, deploy 미변경
});

test("parseTemplateOptions: 신 publish 키가 있으면 구 키 마이그레이션 안 함", () => {
  const y = VY_NEW("vercel", ["npm"], false) + "      nexus: true\n";
  const r = parseTemplateOptions(y);
  assert.equal(r.deploy, "vercel");
  assert.deepEqual(r.publish, ["npm"]); // 신 publish 우선 — 구 nexus 무시
});

test("parseTemplateOptions: changelog/code_review 파싱 (#455)", () => {
  const r = parseTemplateOptions(VY_CHANGELOG("github-ai", "", "true"));
  assert.equal(r.changelogProvider, "github-ai");
  assert.equal(r.changelogBaseUrl, "");
  assert.equal(r.codeReviewCoderabbit, true);

  const r2 = parseTemplateOptions(VY_CHANGELOG("ollama", "https://ai.suhsaechan.kr/v1", "false"));
  assert.equal(r2.changelogProvider, "ollama");
  assert.equal(r2.changelogBaseUrl, "https://ai.suhsaechan.kr/v1");
  assert.equal(r2.codeReviewCoderabbit, false);

  // 필드 없으면 null (기존 형식 하위호환)
  const r3 = parseTemplateOptions(VY_NEW("vercel", ["npm"], false));
  assert.equal(r3.changelogProvider, null);
  assert.equal(r3.changelogBaseUrl, null);
  assert.equal(r3.codeReviewCoderabbit, null);
});

test("buildVersionYml: changelog/code_review 블록 생성 + round-trip (#455)", () => {
  const yml = buildVersionYml({
    version: "1.0.0", types: ["basic"], branch: "main", versionCode: 1,
    now: "2026-07-09 00:00:00", today: "2026-07-09",
    templateOptions: {
      templateVersion: "4.3.0", deployTarget: "none", publishTargets: [], includeSecretBackup: false,
      changelogProvider: "github-ai", changelogBaseUrl: "", codeReviewCoderabbit: true,
    },
  });
  assert.match(yml, /changelog:/);
  assert.match(yml, /provider: "github-ai"/);
  assert.match(yml, /coderabbit: true/);
  // round-trip: 생성 → 파싱 동일
  const parsed = parseTemplateOptions(yml);
  assert.equal(parsed.changelogProvider, "github-ai");
  assert.equal(parsed.codeReviewCoderabbit, true);
  assert.equal(parsed.changelogBaseUrl, "");
});

test("buildVersionYml: ollama base_url round-trip (#455)", () => {
  const yml = buildVersionYml({
    version: "1.0.0", types: ["basic"], branch: "main", versionCode: 1,
    now: "2026-07-09 00:00:00", today: "2026-07-09",
    templateOptions: {
      templateVersion: "4.3.0", deployTarget: "none", publishTargets: [], includeSecretBackup: false,
      changelogProvider: "ollama", changelogBaseUrl: "https://ai.suhsaechan.kr/v1", codeReviewCoderabbit: false,
    },
  });
  const parsed = parseTemplateOptions(yml);
  assert.equal(parsed.changelogProvider, "ollama");
  assert.equal(parsed.changelogBaseUrl, "https://ai.suhsaechan.kr/v1");
  assert.equal(parsed.codeReviewCoderabbit, false);
});

test("parseTemplateOptions: template 섹션 밖의 nexus 키는 무시", () => {
  const y = 'nexus: true\nmetadata:\n  foo: "bar"\n';
  assert.deepEqual(parseTemplateOptions(y), { deploy: null, publish: null, secretBackup: null, ...CL_NULL });
});

test("parseExisting: options 필드 포함 반환 (신 축)", () => {
  const r = parseExisting(VY_NEW("vercel", ["npm"], false));
  assert.deepEqual(r.options, { deploy: "vercel", publish: ["npm"], secretBackup: false, ...CL_NULL });
  assert.equal(r.version, "1.0.0");
});

test("askAllOptionalWorkflows: changelog provider + coderabbit 질문 (#455)", async () => {
  const tempDir = makeTemplateFixture({ secretBackup: false });
  const target = makeTmp();
  try {
    // basic 단독이라 deploy/publish select 스킵 → select는 changelog provider 하나만
    // confirm: code_review coderabbit / text: deploy_branch(#456)
    const io = stubIo({ confirms: [true], selects: ["github-ai"], texts: ["develop"] });
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["basic"], targetRoot: target, tty: true, io,
    });
    assert.equal(r.codeReviewCoderabbit, true);
    assert.equal(r.changelogProvider, "github-ai");
    assert.equal(r.changelogBaseUrl, "");
    assert.equal(r.deployBranch, "develop");
    assert.equal(io.calls.text.length, 1, "github-ai면 base_url 질문은 없고 deploy_branch만 1회");
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("parseTemplateOptions: deploy_branch(metadata 직속) 파싱 (#456)", () => {
  const yml = 'version: "1.0.0"\nmetadata:\n  default_branch: "main"\n  deploy_branch: "release"\n';
  assert.equal(parseTemplateOptions(yml).deployBranch, "release");
  const noBranch = 'version: "1.0.0"\nmetadata:\n  default_branch: "main"\n';
  assert.equal(parseTemplateOptions(noBranch).deployBranch, null);
});

test("askAllOptionalWorkflows: deploy_branch 기본값 develop (#456)", async () => {
  const tempDir = makeTemplateFixture({ secretBackup: false });
  const target = makeTmp();
  try {
    // deploy_branch 질문에 빈 응답이면 기본 develop 유지
    const io = stubIo({ confirms: [false], selects: ["github-ai"], texts: [""] });
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["basic"], targetRoot: target, tty: true, io,
    });
    assert.equal(r.deployBranch, "develop");
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: changelog=ollama면 base_url 질문 (#455)", async () => {
  const tempDir = makeTemplateFixture({ secretBackup: false });
  const target = makeTmp();
  try {
    // text 순서: base_url(ollama) → deploy_branch(#456)
    const io = stubIo({ confirms: [false], selects: ["ollama"], texts: ["https://ai.suhsaechan.kr/v1", "release"] });
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["basic"], targetRoot: target, tty: true, io,
    });
    assert.equal(r.changelogProvider, "ollama");
    assert.equal(r.changelogBaseUrl, "https://ai.suhsaechan.kr/v1");
    assert.equal(r.deployBranch, "release");
    assert.equal(io.calls.text.length, 2, "ollama면 base_url + deploy_branch 2회");
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: 대화형 — deploy=vercel / publish=[npm] / secret=아니오", async () => {
  const tempDir = makeTemplateFixture();
  const target = makeTmp();
  try {
    // confirm 순서: code_review(false) → secret(false). select: deploy(vercel) → changelog(github-ai)
    const io = stubIo({ selects: ["vercel", "github-ai"], multiselects: [["npm"]], confirms: [false, false] });
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["spring"], targetRoot: target, tty: true, io,
    });
    assert.equal(r.deploy, "vercel");
    assert.deepEqual(r.publish, ["npm"]);
    assert.equal(r.secretBackup, false);
    assert.equal(r.changelogProvider, "github-ai");
    assert.equal(io.calls.select.length, 2, "deploy + changelog");
    assert.equal(io.calls.multiselect.length, 1);
    assert.equal(io.calls.confirm.length, 2, "code_review + secret");
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: basic 단독 타입은 배포/publish 질문 스킵 → none·[] (UX 개선)", async () => {
  const tempDir = makeTemplateFixture({ secretBackup: false }); // Secret 폴더 없음 → 질문 0
  const target = makeTmp();
  try {
    // deploy select은 스킵돼야 함. 단 changelog select는 물어봄(github-ai). code_review confirm(false).
    const io = stubIo({ selects: ["github-ai"], confirms: [false], multiselects: [["npm"]] });
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["basic"], targetRoot: target, tty: true, io,
    });
    assert.equal(r.deploy, "none");
    assert.deepEqual(r.publish, []);
    assert.equal(r.secretBackup, false);
    assert.equal(io.calls.multiselect.length, 0, "publish 질문 안 함");
    // select은 changelog 하나만(배포 스킵), multiselect의 npm은 소비 안 됨
    assert.equal(io.calls.select.length, 1, "배포 스킵, changelog만");
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: basic이어도 Secret 백업 폴더가 있으면 그 질문은 유지", async () => {
  const tempDir = makeTemplateFixture({ secretBackup: true });
  const target = makeTmp();
  try {
    // confirm 순서: code_review(false) → secret(false). select: changelog(github-ai)
    const io = stubIo({ confirms: [false, false], selects: ["github-ai"] });
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["basic"], targetRoot: target, tty: true, io,
    });
    assert.equal(r.deploy, "none");
    assert.deepEqual(r.publish, []);
    assert.equal(r.secretBackup, false);
    assert.equal(io.calls.multiselect.length, 0);
    assert.equal(io.calls.confirm.length, 2, "code_review + Secret 백업");
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
    assert.deepEqual(r, { deploy: "vercel", publish: [], secretBackup: false,
      codeReviewCoderabbit: false, changelogProvider: "github-ai", changelogBaseUrl: "", deployBranch: "develop" });
    assert.equal(io.calls.select.length, 0);
    assert.equal(io.calls.multiselect.length, 0);
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: version.yml 저장값 있으면 재질문 생략", async () => {
  const tempDir = makeTemplateFixture();
  const target = makeTmp();
  try {
    touch(target, "version.yml", VY_NEW("vercel", ["nexus"], false));
    // deploy/publish/secret은 저장값 유지 → 질문 없음. changelog는 저장값에 없어 질문 나옴.
    // deploy multiselect가 호출되면 반대값이지만, 저장값 유지로 select은 changelog만.
    const io = stubIo({ selects: ["github-ai"], confirms: [false] });
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["spring"], targetRoot: target, tty: true, io,
    });
    assert.equal(r.deploy, "vercel");
    assert.deepEqual(r.publish, ["nexus"]);
    assert.equal(r.secretBackup, false);
    assert.equal(r.changelogProvider, "github-ai");
    assert.equal(io.calls.select.length, 1, "deploy 저장값 유지, changelog만 질문");
    assert.equal(io.calls.multiselect.length, 0);
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: 구 키 저장 파일 → 신 축으로 마이그레이션해 읽음", async () => {
  const tempDir = makeTemplateFixture({ secretBackup: false });
  const target = makeTmp();
  try {
    touch(target, "version.yml", VY_LEGACY("true", "false"));
    // deploy/publish는 구 키 마이그레이션으로 채워짐 → 질문 없음. changelog는 없어 질문 나옴.
    const io = stubIo({ selects: ["github-ai"], confirms: [false] });
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["spring"], targetRoot: target, tty: true, io,
    });
    assert.equal(r.deploy, "none");
    assert.deepEqual(r.publish, ["nexus"]);
    assert.equal(r.secretBackup, false);
    assert.equal(io.calls.select.length, 1, "deploy 마이그레이션 유지, changelog만 질문");
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: forceAsk=true — 저장값 무시하고 재질문", async () => {
  const tempDir = makeTemplateFixture();
  const target = makeTmp();
  try {
    touch(target, "version.yml", VY_NEW("docker-ssh", [], false));
    // forceAsk → 전부 재질문. select: deploy(none) → changelog(github-ai).
    // confirm: code_review(false) → secret(true).
    const io = stubIo({ selects: ["none", "github-ai"], multiselects: [["nexus", "github-packages"]], confirms: [false, true] });
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["spring"], targetRoot: target, tty: true, io, forceAsk: true,
    });
    assert.equal(r.deploy, "none");
    assert.deepEqual(r.publish, ["nexus", "github-packages"]);
    assert.equal(r.secretBackup, true);
    assert.equal(r.changelogProvider, "github-ai");
    assert.equal(io.calls.select.length, 2, "deploy + changelog");
    assert.equal(io.calls.multiselect.length, 1);
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});

test("askAllOptionalWorkflows: multiselect ESC(cancel) → publish 빈 배열", async () => {
  const tempDir = makeTemplateFixture({ secretBackup: false });
  const target = makeTmp();
  try {
    // select: deploy(docker-ssh) → changelog(github-ai). confirm: code_review(false).
    const io = stubIo({ selects: ["docker-ssh", "github-ai"], multiselects: [Symbol("cancel")], confirms: [false] });
    const r = await askAllOptionalWorkflows({
      tempDir, types: ["spring"], targetRoot: target, tty: true, io,
    });
    assert.equal(r.deploy, "docker-ssh");
    assert.deepEqual(r.publish, []);
    assert.equal(r.secretBackup, false);
  } finally { rmSync(tempDir, { recursive: true, force: true }); rmSync(target, { recursive: true, force: true }); }
});
