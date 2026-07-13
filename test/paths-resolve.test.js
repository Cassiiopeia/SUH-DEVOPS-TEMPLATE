import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync, mkdirSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import {
  markerForType, existingMarkerInDir, findTypePathCandidates, resolveProjectPaths, filterExcludedTypes,
} from "../src/core/paths-resolve.js";

// 픽스처 헬퍼 — 상대경로 파일 생성
function touch(root, rel) {
  const p = join(root, rel);
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, "");
}
function makeTmp() { return mkdtempSync(join(tmpdir(), "pathsres-")); }

// io 스텁 — 호출 기록 + 지정 응답 시퀀스
function stubIo({ selects = [], texts = [], confirms = [] } = {}) {
  const calls = { select: [], text: [], confirm: [] };
  return {
    calls,
    log: () => {}, // 안내 출력 억제
    select: async (a) => { calls.select.push(a); return selects.shift(); },
    text: async (a) => { calls.text.push(a); return texts.shift(); },
    confirm: async (a) => { calls.confirm.push(a); return confirms.shift(); },
  };
}

test("markerForType: 대표 마커 / 미지 타입은 빈 문자열 (.sh 등가)", () => {
  assert.equal(markerForType("flutter"), "pubspec.yaml");
  assert.equal(markerForType("spring"), "build.gradle");
  assert.equal(markerForType("react"), "package.json");
  assert.equal(markerForType("basic"), ""); // .sh는 미지 타입에 "" 반환
});

test("existingMarkerInDir: 보조 마커 우선순위 (spring pom.xml, python setup.py)", () => {
  const root = makeTmp();
  try {
    touch(root, "pom.xml");
    assert.equal(existingMarkerInDir("spring", root), "pom.xml");
    touch(root, "build.gradle.kts");
    assert.equal(existingMarkerInDir("spring", root), "build.gradle.kts"); // .kts가 pom보다 앞순위
    touch(root, "setup.py");
    assert.equal(existingMarkerInDir("python", root), "setup.py");
    // 아무것도 없으면 대표 마커 반환 (표시용)
    assert.equal(existingMarkerInDir("flutter", root), "pubspec.yaml");
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("findTypePathCandidates: flutter — example/ 제외 + lib/ 동반 확인", () => {
  const root = makeTmp();
  try {
    touch(root, "app/pubspec.yaml");
    touch(root, "app/lib/main.dart");           // lib 동반 → 후보
    touch(root, "example/pubspec.yaml");
    touch(root, "example/lib/main.dart");        // example 경로 → 제외
    touch(root, "nolib/pubspec.yaml");           // lib 없음 → 제외
    assert.deepEqual(findTypePathCandidates(root, "flutter"), ["app"]);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("findTypePathCandidates: spring — settings.gradle 루트 축약 + android 오탐 제외", () => {
  const root = makeTmp();
  try {
    // settings.gradle이 있으면 그 폴더만 후보 (하위 모듈 build.gradle은 펼치지 않음)
    touch(root, "server/settings.gradle");
    touch(root, "server/build.gradle");
    touch(root, "server/module-a/build.gradle");
    touch(root, "android/build.gradle");         // Flutter의 android — prune으로 제외
    assert.deepEqual(findTypePathCandidates(root, "spring"), ["server"]);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("findTypePathCandidates: spring — settings.gradle 없으면 build.gradle 폴백", () => {
  const root = makeTmp();
  try {
    touch(root, "api/build.gradle");
    touch(root, "batch/build.gradle");
    assert.deepEqual(findTypePathCandidates(root, "spring"), ["api", "batch"]); // sort -u
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("findTypePathCandidates: maxdepth 3 초과·node_modules 제외", () => {
  const root = makeTmp();
  try {
    touch(root, "a/b/package.json");              // depth 3 → 포함
    touch(root, "a/b/c/package.json");            // depth 4 → 제외
    touch(root, "node_modules/x/package.json");   // prune → 제외
    assert.deepEqual(findTypePathCandidates(root, "react"), ["a/b"]);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("resolveProjectPaths 비대화형: 후보 1개 자동 채택", async () => {
  const root = makeTmp();
  try {
    touch(root, "app/pubspec.yaml");
    touch(root, "app/lib/main.dart");
    const map = await resolveProjectPaths({
      root, types: ["flutter"], force: true, tty: false, io: stubIo(),
    });
    assert.equal(map.get("flutter"), "app");
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("resolveProjectPaths 비대화형: 후보 0개 → 루트(.) 폴백", async () => {
  const root = makeTmp();
  try {
    const map = await resolveProjectPaths({
      root, types: ["flutter"], force: true, tty: false, io: stubIo(),
    });
    assert.equal(map.get("flutter"), ".");
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("resolveProjectPaths 비대화형: existingPaths(version.yml 저장값) 우선", async () => {
  const root = makeTmp();
  try {
    touch(root, "app/pubspec.yaml"); // 후보도 있지만 저장값이 우선
    touch(root, "app/lib/main.dart");
    const map = await resolveProjectPaths({
      root, types: ["flutter"], existingPaths: new Map([["flutter", "legacy/app"]]),
      force: true, tty: false, io: stubIo(),
    });
    assert.equal(map.get("flutter"), "legacy/app");
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("resolveProjectPaths: 루트 마커 존재 → '.' 자동 (질문 없음)", async () => {
  const root = makeTmp();
  try {
    touch(root, "pubspec.yaml");
    touch(root, "lib/main.dart");
    const io = stubIo();
    const map = await resolveProjectPaths({ root, types: ["flutter"], tty: true, io });
    assert.equal(map.get("flutter"), ".");
    assert.equal(io.calls.confirm.length, 0); // 자동 확정 — 질문 없어야 함
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("resolveProjectPaths: --paths 사전값 최우선 + basic 제외", async () => {
  const root = makeTmp();
  try {
    touch(root, "app/pubspec.yaml");
    touch(root, "app/lib/main.dart");
    const map = await resolveProjectPaths({
      root, types: ["flutter", "basic"], paths: new Map([["flutter", "custom"]]),
      force: true, tty: false, io: stubIo(),
    });
    assert.equal(map.get("flutter"), "custom"); // ① --paths 유지
    assert.equal(map.has("basic"), false);      // basic은 경로 불필요
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("resolveProjectPaths 대화형: 복수 후보 select 경로", async () => {
  const root = makeTmp();
  try {
    touch(root, "web/package.json");
    touch(root, "admin/package.json");
    const io = stubIo({ selects: ["web"] });
    const map = await resolveProjectPaths({ root, types: ["react"], tty: true, io });
    assert.equal(map.get("react"), "web");
    // 메뉴에 후보 2개 + '직접 입력' 항목이 포함돼야 함
    const options = io.calls.select[0].options;
    assert.deepEqual(options.map((o) => o.value), ["admin", "web", "직접 입력", "이 타입 제외"]);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("resolveProjectPaths 대화형: '직접 입력' 선택 → 마커 없는 경로는 경고 후 강제확인", async () => {
  const root = makeTmp();
  try {
    touch(root, "web/package.json");
    touch(root, "admin/package.json");
    // select(후보메뉴)에서 직접 입력 → text로 마커 없는 경로 → 실패 select에서 '그래도 사용'
    const io = stubIo({ selects: ["직접 입력", "force"], texts: ["nowhere"] });
    const map = await resolveProjectPaths({ root, types: ["react"], tty: true, io });
    assert.equal(map.get("react"), "nowhere");
    assert.equal(io.calls.select.length, 2); // 후보메뉴 1회 + 실패확인 1회
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("resolveProjectPaths 대화형: 후보 1개 확인 '직접 입력' → 직접 입력 루프", async () => {
  const root = makeTmp();
  try {
    touch(root, "app/pubspec.yaml");
    touch(root, "app/lib/main.dart");
    touch(root, "other/pubspec.yaml"); // lib 없어 후보는 아니지만 마커는 실재
    // 후보 1개 select에서 '직접 입력' → text "other/" (정규화 검증: 끝 슬래시 제거)
    const io = stubIo({ selects: ["직접 입력"], texts: ["other/"] });
    const map = await resolveProjectPaths({ root, types: ["flutter"], tty: true, io });
    assert.equal(map.get("flutter"), "other");
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("resolveProjectPaths 대화형: 후보 1개에서 '이 타입 제외' → Map에서 빠짐", async () => {
  const root = makeTmp();
  try {
    touch(root, "code-archive/old/build.gradle"); // 아카이브 오감지 시나리오 (#487)
    const io = stubIo({ selects: ["이 타입 제외"] });
    const map = await resolveProjectPaths({ root, types: ["spring"], tty: true, io });
    assert.equal(map.has("spring"), false);
    assert.equal(io.calls.text.length, 0); // 직접입력 루프로 안 빠져야 함
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("resolveProjectPaths 대화형: 복수 후보 메뉴에 '이 타입 제외' 항목 + 선택 시 제외", async () => {
  const root = makeTmp();
  try {
    touch(root, "api/build.gradle");
    touch(root, "batch/build.gradle");
    const io = stubIo({ selects: ["이 타입 제외"] });
    const map = await resolveProjectPaths({ root, types: ["spring"], tty: true, io });
    assert.equal(map.has("spring"), false);
    const values = io.calls.select[0].options.map((o) => o.value);
    assert.ok(values.includes("직접 입력"));
    assert.ok(values.includes("이 타입 제외"));
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("resolveProjectPaths 대화형: 직접입력 검증 실패 → '이 타입 제외'로 탈출", async () => {
  const root = makeTmp();
  try {
    // 후보 0개 → 바로 직접입력 → 마커 없는 경로 → 실패 select에서 제외
    const io = stubIo({ selects: ["이 타입 제외"], texts: ["nowhere"] });
    const map = await resolveProjectPaths({ root, types: ["spring"], tty: true, io });
    assert.equal(map.has("spring"), false);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("resolveProjectPaths 대화형: 직접입력 실패 → '다시 입력' 후 유효 경로로 확정", async () => {
  const root = makeTmp();
  try {
    touch(root, "srv/pubspec.yaml"); // lib/ 없어 후보 스캔엔 안 잡히지만 마커 검증은 통과
    const io = stubIo({ selects: ["retry"], texts: ["nowhere", "srv"] });
    const map = await resolveProjectPaths({ root, types: ["flutter"], tty: true, io });
    assert.equal(map.get("flutter"), "srv");
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("filterExcludedTypes: 제외 타입 제거 + 전부 제외 시 basic 폴백", () => {
  assert.deepEqual(filterExcludedTypes(["spring", "python"], new Map([["python", "."]])), ["python"]);
  assert.deepEqual(filterExcludedTypes(["spring"], new Map()), ["basic"]);
  assert.deepEqual(filterExcludedTypes(["basic"], new Map()), ["basic"]);
  assert.deepEqual(filterExcludedTypes(["flutter", "basic"], new Map()), ["basic"]);
});
