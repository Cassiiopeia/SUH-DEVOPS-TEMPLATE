// wizard-labels 파서 테스트 — 실제 .github/config/wizard-prompts.yml 픽스처 기반.
import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { writeText } from "../src/core/fsutil.js";
import { loadWizardPrompts, parseWizardPrompts, wfField, workflowDisplayName, LABELS_FILE } from "../src/core/wizard-labels.js";

const REAL_YML = fileURLToPath(new URL("../.github/config/wizard-prompts.yml", import.meta.url));

function fresh(p) { return mkdtempSync(join(tmpdir(), p)); }

// 실물 wizard-prompts.yml을 targetRoot 픽스처로 복사
function makeTarget() {
  const root = fresh("wl-");
  writeText(join(root, LABELS_FILE), readFileSync(REAL_YML, "utf8"));
  return root;
}

test("wfField: 실물 yml에서 label/help/example 조회", () => {
  const root = makeTarget();
  try {
    const p = loadWizardPrompts(root, "");
    assert.ok(p, "파싱 객체 반환");
    assert.equal(wfField(p, "spring", "PROJECT_NAME", "label"), "서비스 식별자 (영문 슬러그)");
    assert.match(wfField(p, "spring", "PROJECT_NAME", "help"), /Docker 컨테이너명/);
    assert.equal(wfField(p, "spring", "PROJECT_NAME", "example"), "my-service");
    assert.equal(wfField(p, "spring", "JAVA_VERSION", "example"), "21");
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("wfField: dotted 타입 오버라이드 — flutter.APP_ARTIFACT_NAME", () => {
  const root = makeTarget();
  try {
    const p = loadWizardPrompts(root, "");
    // flutter 타입은 오버라이드 블록 적용
    assert.equal(wfField(p, "flutter", "APP_ARTIFACT_NAME", "label"), "앱 산출물 이름 (영문)");
    // 오버라이드만 존재하고 공통 블록이 없는 키 → 다른 타입은 폴백(KEY명)
    assert.equal(wfField(p, "spring", "APP_ARTIFACT_NAME", "label"), "APP_ARTIFACT_NAME");
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("wfField: 없는 키 폴백 — label은 KEY명, help/example은 빈 문자열", () => {
  const root = makeTarget();
  try {
    const p = loadWizardPrompts(root, "");
    assert.equal(wfField(p, "spring", "NO_SUCH_KEY", "label"), "NO_SUCH_KEY");
    assert.equal(wfField(p, "spring", "NO_SUCH_KEY", "help"), "");
    assert.equal(wfField(p, "spring", "NO_SUCH_KEY", "example"), "");
    // prompts=null(파일 자체가 없을 때)도 동일 폴백 (.sh _wf_labels_path 빈값 등가)
    assert.equal(wfField(null, "spring", "FOO", "label"), "FOO");
    assert.equal(wfField(null, "spring", "FOO", "help"), "");
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("parseWizardPrompts: 구형 1줄 형식(KEY: \"라벨\")은 label로만 사용", () => {
  const p = parseWizardPrompts('OLD_KEY: "구형 라벨"\n');
  assert.equal(wfField(p, "spring", "OLD_KEY", "label"), "구형 라벨");
  assert.equal(wfField(p, "spring", "OLD_KEY", "help"), "");
});

test("workflowDisplayName: _workflow_names 최장 키 매칭 + 미매칭 시 확장자 제거", () => {
  const root = makeTarget();
  try {
    const p = loadWizardPrompts(root, "");
    assert.equal(workflowDisplayName(p, "PROJECT-SPRING-NONSTOP-NGINX-CICD.yaml"), "무중단배포(Nginx)");
    // REACT-CI와 REACT-CICD 둘 다 부분일치 → 최장 키(REACT-CICD) 우선 (.sh bestlen 등가)
    assert.equal(workflowDisplayName(p, "PROJECT-REACT-CICD.yaml"), "프론트 배포");
    assert.equal(workflowDisplayName(p, "PROJECT-REACT-CI.yaml"), "프론트 빌드");
    // 미매칭 → .yaml/.yml만 제거
    assert.equal(workflowDisplayName(p, "SOMETHING-ELSE.yml"), "SOMETHING-ELSE");
    // prompts 없음(null) → 확장자 제거 폴백
    assert.equal(workflowDisplayName(null, "PROJECT-X.yaml"), "PROJECT-X");
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("loadWizardPrompts: 대상에 없으면 tempDir 폴백, 둘 다 없으면 null", () => {
  const empty = fresh("wl-empty-");
  const temp = fresh("wl-temp-");
  try {
    writeText(join(temp, LABELS_FILE), 'FOO:\n  label: "템프 라벨"\n');
    // 1) 대상엔 없고 tempDir엔 있음 → 폴백 (.sh _wf_labels_path 2809~2814 등가)
    const p = loadWizardPrompts(empty, temp);
    assert.equal(wfField(p, "spring", "FOO", "label"), "템프 라벨");
    // 2) 둘 다 없음 → null
    assert.equal(loadWizardPrompts(empty, join(empty, "nope")), null);
  } finally {
    rmSync(empty, { recursive: true, force: true });
    rmSync(temp, { recursive: true, force: true });
  }
});
