import { test } from "node:test";
import assert from "node:assert/strict";
import { parseExisting, buildVersionYml } from "../src/core/version-yml.js";

test("roundtrip version/types/versionCode", () => {
  const yml = buildVersionYml({
    version: "1.2.3", types: ["spring", "react"], paths: new Map(),
    branch: "main", versionCode: 5, now: "2026-07-08 00:00:00", today: "2026-07-08",
  });
  const p = parseExisting(yml);
  assert.equal(p.version, "1.2.3");
  assert.deepEqual(p.types, ["spring", "react"]);
  assert.equal(p.versionCode, 5);
});

test("parseExisting version is source of truth", () => {
  const p = parseExisting('version: "9.9.9"\nproject_types: ["basic"]\n');
  assert.equal(p.version, "9.9.9");
});

test("parseExisting ignores comment lines (version_code oversight guard)", () => {
  const p = parseExisting('# version_code: 1 - Play Store 빌드 번호\nversion_code: 42\n');
  assert.equal(p.versionCode, 42);
});

test("parseExisting versionCode defaults to 1 when invalid", () => {
  assert.equal(parseExisting("version_code: 0\n").versionCode, 1);
  assert.equal(parseExisting("no code here\n").versionCode, 1);
});

test("parseExisting project_paths block", () => {
  const yml = 'project_paths:\n  flutter: "app"\n  react: "client"\nmetadata:\n';
  const p = parseExisting(yml);
  assert.equal(p.paths.get("flutter"), "app");
  assert.equal(p.paths.get("react"), "client");
});

test("buildVersionYml emits integrated_from projectops and template_integrator", () => {
  const yml = buildVersionYml({ version: "1.0.0", types: ["basic"], now: "n", today: "t" });
  assert.ok(yml.includes('integrated_from: "projectops"'));
  assert.ok(yml.includes('last_updated_by: "template_integrator"'));
  assert.ok(yml.includes('project_type: "basic"'));
});
