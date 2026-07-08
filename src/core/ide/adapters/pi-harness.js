// PI Persona Harness 어댑터 (.sh _pi_harness_toggle / _pi_harness_remove_only /
// _pi_harness_add / _pi_harness_remove / _pi_harness_enabled 등가).
// PI skill과 독립 — skill은 그대로 두고 harness 등록(settings.json extensions)만 켜고/끈다.
import { existsSync } from "node:fs";
import { harnessEnabled, harnessAdd, harnessRemove, harnessLoaderPath } from "./pi-common.js";

// 이 어댑터는 "설치 가능" 여부가 pi 존재 + loader 파일 존재에 달림.
function available(io) { return !!io.which("pi") && existsSync(harnessLoaderPath(io)); }

function detect(io) {
  if (!io.which("pi")) return { installed: false, version: null, cliMissing: true, note: "PI 없음" };
  if (!existsSync(harnessLoaderPath(io))) return { installed: false, version: null, cliMissing: true, note: "loader 없음 (PI 설치 필요)" };
  return { installed: harnessEnabled(io), version: null, cliMissing: false, note: harnessEnabled(io) ? "활성화됨" : "비활성화" };
}

// apply = harness 활성화 (skill은 안 건드림).
function apply(io) {
  if (!available(io)) { io.log("  harness loader가 없습니다 — 먼저 PI를 설치하세요."); return false; }
  if (harnessEnabled(io)) { io.log("  Persona Harness: 이미 활성화됨 (유지)"); return true; }
  const r = harnessAdd(io);
  if (r.ok) { io.log("  Persona Harness 활성화 완료 — PI 재시작 후 적용됩니다."); return true; }
  io.log(r.reason === "no-settings" ? "  PI settings.json이 없습니다 — PI를 한 번 실행한 뒤 다시 시도하세요."
    : "  harness loader가 없습니다 — 먼저 PI 패키지를 설치/업데이트하세요.");
  return false;
}

// remove = harness만 해제 (PI skill 보존).
function remove(io) {
  if (!harnessEnabled(io)) { io.log("  Persona Harness가 활성화돼 있지 않아 건너뜁니다"); return true; }
  io.log("  PI skill은 그대로 두고 harness 등록만 해제합니다.");
  harnessRemove(io);
  io.log("  Persona Harness 해제 완료 — PI 재시작 후 적용됩니다.");
  return true;
}

function manualHint() { return "  💡 PI Persona Harness: PI 설치 후 settings.json extensions 에 harness-loader.ts 등록"; }

// harness 설명 (프롬프트에서 재사용).
export const HARNESS_DESC = [
  "Persona Harness는 PI가 대화를 시작할 때마다 '전문가 페르소나'와 'SDLC 워크플로우'를",
  "시스템 프롬프트에 자동 주입하는 기능입니다 (skill과 독립적으로 켜고/끌 수 있음).",
].join("\n");

export const piHarnessAdapter = {
  id: "pi-harness", label: "PI Persona Harness", order: 60,
  optional: true, // 감지된 경우에만 메뉴 노출 (registry 순회 시 참고)
  detect, apply, remove, manualHint,
};
