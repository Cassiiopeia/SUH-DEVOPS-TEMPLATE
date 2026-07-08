import { test } from "node:test";
import assert from "node:assert/strict";
import { parseWizardLine, setEnvLine, substituteEnv, isUnchanged, resolveToken } from "../src/core/wizard-env.js";

test("parseWizardLine ask/auto/none, KEY must be [A-Z_]+", () => {
  assert.equal(parseWizardLine('  APP_NAME: "__X__"  # @wizard ask:default').action, "ask");
  assert.equal(parseWizardLine('  REPO: "v"  # @wizard auto:repo').action, "auto");
  assert.equal(parseWizardLine('  APP: "v"'), null); // 마커 없음
  // 소문자 키는 .sh [A-Z_]+ 정규식에 안 걸림 → null
  assert.equal(parseWizardLine('  appName: "x"  # @wizard ask:d'), null);
});

test("setEnvLine replaces quoted value AND strips @wizard comment", () => {
  assert.equal(
    setEnvLine('  APP: "__X__"  # @wizard ask:myapp', "APP", "chosen"),
    '  APP: "chosen"',
  );
});

test("setEnvLine skips when value empty (.sh [ -n ] guard)", () => {
  const line = '  APP: "__X__"  # @wizard ask:myapp';
  assert.equal(setEnvLine(line, "APP", ""), line);
});

test("substituteEnv uses default (arg) when useDefaults", () => {
  const out = substituteEnv('  APP: "__X__"  # @wizard ask:myapp', { useDefaults: true });
  assert.equal(out, '  APP: "myapp"');
});

test("substituteEnv ask with user value when not useDefaults", () => {
  const out = substituteEnv('  APP: "__X__"  # @wizard ask:myapp', {
    useDefaults: false, values: new Map([["APP", "picked"]]),
  });
  assert.equal(out, '  APP: "picked"');
});

test("substituteEnv auto resolves via resolvers", () => {
  const out = substituteEnv('  REPO: "__X__"  # @wizard auto:repo', {
    resolvers: { repo: () => "projectops" },
  });
  assert.equal(out, '  REPO: "projectops"');
});

test("substituteEnv ask @resolver default", () => {
  const out = substituteEnv('  R: "__X__"  # @wizard ask:@repo', {
    useDefaults: true, resolvers: { repo: () => "myrepo" },
  });
  assert.equal(out, '  R: "myrepo"');
});

test("global tokens __PROJECT_NAME__ replaced when file also has @wizard", () => {
  // 실측: __PROJECT_NAME__ 있는 워크플로우는 전부 @wizard도 포함 (.sh 조기반환 가드가
  // 이 치환을 막는 실제 케이스 없음). @wizard 마커가 있어야 전역 토큰 치환이 돈다.
  const content = '  K: "v"  # @wizard auto:repo\n      image: __PROJECT_NAME__:latest';
  const out = substituteEnv(content, { repoName: "projectops", resolvers: { repo: () => "projectops" } });
  assert.ok(out.includes("image: projectops:latest"));
});

test("file without @wizard is returned untouched even if it has __PROJECT_NAME__ (matches .sh early-return)", () => {
  const c = "      image: __PROJECT_NAME__:latest";
  assert.equal(substituteEnv(c, { repoName: "projectops" }), c);
});

test("paths-anchor replaced only when path != '.'", () => {
  const line = "    # @wizard paths-anchor";
  assert.equal(substituteEnv(line, { projectPath: "app" }).trim(), "paths: ['app/**']");
  assert.equal(substituteEnv(line, { projectPath: "." }), line); // 루트면 유지
});

test("isUnchanged: default-substituted template equals install", () => {
  const tpl = '  APP: "__X__"  # @wizard ask:myapp';
  assert.equal(isUnchanged(tpl, '  APP: "myapp"'), true);
  assert.equal(isUnchanged(tpl, '  APP: "other"'), false);
});

test("no @wizard marker returns content unchanged", () => {
  const c = "name: test\non:\n  push:\n";
  assert.equal(substituteEnv(c, {}), c);
});
