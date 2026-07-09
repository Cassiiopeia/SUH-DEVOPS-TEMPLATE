import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { printSummary } from "../src/ui/summary.js";

function touch(root, rel, content = "") {
  const p = join(root, rel);
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, content);
}

// stderr 캡처 — printSummary는 전부 stderr로 쓴다
function captureStderr(fn) {
  const orig = process.stderr.write;
  let out = "";
  process.stderr.write = (chunk) => { out += chunk; return true; };
  try { fn(); } finally { process.stderr.write = orig; }
  return out;
}

test("printSummary: full 모드 스모크 — 워크플로우 분류·타입 안내 포함", () => {
  const root = mkdtempSync(join(tmpdir(), "summary-"));
  try {
    touch(root, ".github/workflows/PROJECT-COMMON-VERSION-CONTROL.yaml");
    touch(root, ".github/workflows/PROJECT-SPRING-SIMPLE-CICD.yaml");
    touch(root, ".github/workflows/PROJECT-TEMPLATE-INITIALIZER.yaml");
    touch(root, ".github/util/flutter/testflight-wizard/index.html");
    const out = captureStderr(() => printSummary({
      mode: "full", types: ["spring", "flutter"], version: "1.2.3",
      counters: { workflows: 2, utilModules: 1 },
    }, root));
    assert.match(out, /Setup Complete/);
    assert.match(out, /version\.yml \(버전: 1\.2\.3, 타입: spring,flutter\)/);
    assert.match(out, /📌 PROJECT-COMMON-VERSION-CONTROL\.yaml/);       // 공통 분류
    assert.match(out, /🎯 PROJECT-SPRING-SIMPLE-CICD\.yaml/);           // 타입 분류
    assert.match(out, /PROJECT-TEMPLATE-INITIALIZER\.yaml \(템플릿 전용\)/); // 기존유지 분류
    assert.match(out, /testflight-wizard \(flutter\)/);                 // util 모듈 트리
    assert.match(out, /Spring 프로젝트 추가 설정/);                       // spring 안내
    assert.match(out, /Flutter 배포 마법사 사용법/);                      // flutter 안내
    assert.match(out, /_GITHUB_PAT_TOKEN/);                             // 다음 3가지 작업
    assert.match(out, /coderabbit\.ai/);
    assert.match(out, /PROJECTOPS-SETUP-GUIDE\.md/);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("printSummary: skills 모드 — 간결 종료 (파일 목록·3가지 작업 없음)", () => {
  const root = mkdtempSync(join(tmpdir(), "summarysk-"));
  try {
    const out = captureStderr(() => printSummary({
      mode: "skills", types: [], version: "", counters: {},
    }, root));
    assert.match(out, /Agent Skill 설치/);
    assert.match(out, /TEMPLATE REPO/);
    assert.doesNotMatch(out, /추가된 파일/);
    assert.doesNotMatch(out, /다음 3가지 작업/);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("printSummary: issues 모드 — 체크리스트에 템플릿만", () => {
  const root = mkdtempSync(join(tmpdir(), "summaryis-"));
  try {
    const out = captureStderr(() => printSummary({
      mode: "issues", types: ["basic"], version: "0.0.1", counters: {},
    }, root));
    assert.match(out, /이슈\/PR\/Discussion 템플릿/);
    assert.doesNotMatch(out, /버전 관리 시스템/);
  } finally { rmSync(root, { recursive: true, force: true }); }
});
