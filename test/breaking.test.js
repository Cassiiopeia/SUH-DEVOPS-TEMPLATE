import { test } from "node:test";
import assert from "node:assert/strict";
import { compareVersions, collectBreaking } from "../src/core/breaking.js";

test("compareVersions", () => {
  assert.equal(compareVersions("1.2.3", "1.2.3"), 0);
  assert.equal(compareVersions("v2.0.0", "1.9.9"), 1);
  assert.equal(compareVersions("1.2", "1.2.0"), 0);   // 누락 자리=0
  assert.equal(compareVersions("1.0.0", "1.0.1"), -1);
});

test("collectBreaking range + bug fix (target beyond 1.3.14)", () => {
  const json = {
    _meta: { severity: "critical" },
    "3.0.0": { severity: "critical", title: "x" },   // .sh 버그였다면 1.3.14 초과라 누락됨
    "1.2.0": { severity: "warning", title: "y" },     // current 이하 → 제외
  };
  const { critical, warnings } = collectBreaking(json, "2.9.9", "3.0.5");
  assert.equal(critical.length, 1);   // 3.0.0 잡힘 (버그 수정 효과)
  assert.equal(warnings.length, 0);
});
