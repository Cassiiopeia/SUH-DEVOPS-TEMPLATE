// 대화형 렌더러 wrap 계산 검증 — 긴 라벨이 터미널 폭을 넘을 때 커서 되감기가 물리 줄을
// 정확히 세는지(화면 밀림 버그 회귀 방지). 실측: Windows PowerShell 폭 80에서 메뉴가 밀림.
import { test } from "node:test";
import assert from "node:assert/strict";
import { physicalRows } from "../src/ui/readline-engine.js";

const ESC = "\x1b[";
const color = (s) => `${ESC}36m${s}${ESC}0m`; // 엔진 paint와 동일 형식

test("physicalRows: ANSI 색 코드는 폭 0, 한글은 2칸으로 계산", () => {
  // 색 코드가 폭에 안 잡혀야 함
  assert.equal(physicalRows(color("abc"), 80), 1);
  // 한글 5자 = 10칸 → 폭 80이면 1줄
  assert.equal(physicalRows("가나다라마", 80), 1);
});

test("physicalRows: 폭을 넘으면 물리 줄이 늘어난다 (wrap)", () => {
  const line = "가".repeat(50); // 100칸
  assert.equal(physicalRows(line, 80), 2, "100칸 @ 80폭 → 2줄");
  assert.equal(physicalRows(line, 40), 3, "100칸 @ 40폭 → 3줄(ceil)");
});

test("physicalRows: 실제 메뉴 라벨(80칸)이 좁은 폭에서 wrap됨 — 밀림 버그의 근본", () => {
  // 실측 재현: '전체 설치 —...' 라벨은 거터+마커 포함 시각 폭 80
  const menuLine = `${ESC}90m│${ESC}0m  ${ESC}32m●${ESC}0m ` +
    color("전체 설치 — 버전관리 + 자동화 워크플로우 + 이슈·PR 템플릿 (처음이라면 추천)");
  // 폭 80: 딱 맞아 1줄, 폭 79 이하: 2줄 → 이전 코드는 늘 1줄로 세어 밀렸다
  assert.equal(physicalRows(menuLine, 80), 1);
  assert.equal(physicalRows(menuLine, 79), 2);
  assert.equal(physicalRows(menuLine, 60), 2);
});

test("physicalRows: 빈 줄·거터만 있는 줄도 최소 1행", () => {
  assert.equal(physicalRows("", 80), 1);
  assert.equal(physicalRows(`${ESC}90m│${ESC}0m`, 80), 1);
});

test("physicalRows: cols가 0/음수면 안전하게 1 (파이프 등 폭 미상)", () => {
  assert.equal(physicalRows("가".repeat(50), 0), 1);
  assert.equal(physicalRows("가".repeat(50), -1), 1);
});
