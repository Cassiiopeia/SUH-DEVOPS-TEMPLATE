// Gemini CLI 어댑터 (.sh _manage_gemini_extension / _remove_gemini_section 등가).
// extension install/update/uninstall. 마켓플레이스 대신 git URL 확장.
const EXT = "projectops";
const URL = "https://github.com/Cassiiopeia/projectops";

function detect(io) {
  if (!io.which("gemini")) return { installed: false, version: null, cliMissing: true, note: "CLI 없음" };
  // .sh는 gemini 설치 상태를 정밀 조회하지 않고 "설치 가능"으로만 표기 → installed 미상.
  return { installed: false, version: null, cliMissing: false, note: "설치 가능 (CLI 감지됨)" };
}

function apply(io) {
  if (!io.which("gemini")) { io.log(manualHint()); return false; }
  io.log("Gemini CLI extension 업데이트 중...");
  if (io.run("gemini", ["extensions", "update", EXT]).code === 0) { io.log("  Gemini CLI extension 업데이트 완료"); return true; }
  io.log("Gemini CLI extension 설치 중...");
  if (io.run("gemini", ["extensions", "install", URL]).code === 0) { io.log("  Gemini CLI extension 설치 완료"); return true; }
  io.log(`  Gemini extension 관리 오류 — 수동: gemini extensions install ${URL}`);
  return false;
}

function remove(io) {
  if (!io.which("gemini")) { io.log("  gemini CLI 미감지 — 건너뜁니다"); return true; }
  if (io.run("gemini", ["extensions", "uninstall", EXT]).code === 0) { io.log("  Gemini CLI extension 제거 완료"); return true; }
  io.log(`  제거할 Gemini extension이 없거나 실패 — 수동: gemini extensions uninstall ${EXT}`);
  return true; // 미설치 제거는 실패로 보지 않음
}

function manualHint() { return `  💡 Gemini CLI: gemini extensions install ${URL}`; }

export const geminiAdapter = {
  id: "gemini", label: "Gemini CLI", order: 30,
  detect, apply, remove, manualHint,
};
