// Codex CLI 어댑터 (.sh _manage_codex_skills / _do_codex_marketplace_register /
// _remove_codex_section 등가).
// marketplace 등록/업그레이드가 주 경로. native ~/.agents/skills/cassiiopeia 심링크는 감지·제거에 사용.
import { join } from "node:path";
import { existsSync, lstatSync, rmSync } from "node:fs";

const MARKETPLACE = "Cassiiopeia/projectops";
const PLUGIN = "cassiiopeia";

function nativeTarget(io) { return join(io.home(), ".agents/skills/cassiiopeia"); }

function detect(io) {
  const tgt = nativeTarget(io);
  const nativeInstalled = existsSync(tgt);
  if (nativeInstalled) return { installed: true, version: null, cliMissing: false, note: "native skills" };
  if (!io.which("codex")) return { installed: false, version: null, cliMissing: true, note: "CLI 없음" };
  return { installed: false, version: null, cliMissing: false, note: "설치 가능 (CLI 감지됨)" };
}

function apply(io) {
  if (!io.which("codex")) { io.log(manualHint()); return false; }
  io.log("Codex plugin marketplace 등록 중...");
  const add = io.run("codex", ["plugin", "marketplace", "add", MARKETPLACE]);
  io.log(add.code === 0 ? "  Codex marketplace 등록 완료" : "  Codex marketplace 이미 등록되어 있거나 등록 생략");
  io.log("Codex plugin marketplace 업데이트 중...");
  if (io.run("codex", ["plugin", "marketplace", "upgrade", PLUGIN]).code === 0) { io.log("  Codex marketplace 등록 완료 (/plugins 확인)"); return true; }
  io.log(`  Codex marketplace 관리 오류 — 수동: codex plugin marketplace add ${MARKETPLACE}`);
  return false;
}

function remove(io) {
  const tgt = nativeTarget(io);
  let removed = false;
  if (existsSync(tgt) || isSymlink(tgt)) {
    try { rmSync(tgt, { recursive: true, force: true }); io.log(`  Codex native skills 제거 완료 (${tgt})`); removed = true; } catch { /* 무해 */ }
  }
  if (!removed) io.log("  제거할 Codex skills가 없어 건너뜁니다");
  if (io.which("codex")) io.log(`  marketplace 등록 해제는 수동: codex plugin marketplace remove ${PLUGIN}`);
  return true;
}

function manualHint() { return `  💡 Codex CLI: codex plugin marketplace add ${MARKETPLACE}`; }

function isSymlink(p) { try { return lstatSync(p).isSymbolicLink(); } catch { return false; } }

export const codexAdapter = {
  id: "codex", label: "Codex CLI", order: 40,
  detect, apply, remove, manualHint,
};
