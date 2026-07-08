// PI 패키지 어댑터 (.sh _manage_pi_section / _remove_pi_section 등가).
// pi install/update/remove. skill은 복사되지 않고 pi가 startup마다 스캔 → 설치 검증은 'pi list'.
import { PI_PACKAGE_URL, piInstalled, harnessEnabled, harnessRemove } from "./pi-common.js";

function detect(io) {
  if (!io.which("pi")) return { installed: false, version: null, cliMissing: true, note: "CLI 없음" };
  return { installed: piInstalled(io), version: null, cliMissing: false };
}

function apply(io) {
  if (!io.which("pi")) { io.log(manualHint()); return false; }
  if (piInstalled(io)) {
    io.log("PI 패키지 업데이트 중...");
    if (io.run("pi", ["update", PI_PACKAGE_URL]).code !== 0) io.run("pi", ["install", PI_PACKAGE_URL]);
  } else {
    io.log("PI 패키지 설치 중...");
    io.run("pi", ["install", PI_PACKAGE_URL]);
  }
  if (piInstalled(io)) {
    io.log("  PI 패키지 설치 / 업데이트 완료");
    io.log("  → 'pi' 재실행 후 'pi list' 로 확인, 채팅창에서 /suh-analyze 등 호출");
    return true;
  }
  io.log(`  PI 설치/업데이트 실패 — 수동: pi install ${PI_PACKAGE_URL}`);
  return false;
}

function remove(io) {
  if (!io.which("pi")) { io.log("  pi CLI 미감지 — 건너뜁니다"); return true; }
  if (!piInstalled(io)) { io.log("  설치된 PI 패키지가 없어 건너뜁니다"); return true; }
  io.log(`  pi remove ${PI_PACKAGE_URL}`);
  io.run("pi", ["remove", PI_PACKAGE_URL]);
  if (piInstalled(io)) io.log("  제거 후에도 패키지가 남아있습니다 — 'pi list'로 확인하세요.");
  else io.log("  PI 패키지 제거 완료");
  // package 클론이 사라지면 harness loader 경로가 허공을 가리킴 → 함께 해제
  if (harnessEnabled(io)) { io.log("  Persona Harness 등록도 함께 해제됩니다."); harnessRemove(io); }
  return true;
}

function manualHint() { return `  💡 PI: pi install ${PI_PACKAGE_URL}`; }

export const piAdapter = {
  id: "pi", label: "PI", order: 50,
  detect, apply, remove, manualHint,
};
