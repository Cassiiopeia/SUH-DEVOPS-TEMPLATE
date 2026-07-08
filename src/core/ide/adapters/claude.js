// Claude Code 어댑터 (.sh _manage_claude_section / _do_claude_plugin_install /
// _remove_claude_section / _remove_claude_plugin_data 등가).
// 마켓플레이스 Cassiiopeia/projectops, 플러그인 cassiiopeia@cassiiopeia-marketplace.
import { join } from "node:path";
import { existsSync, readdirSync, mkdirSync, cpSync, rmSync } from "node:fs";
import { compareCacheName } from "../util.js";

const MARKETPLACE = "Cassiiopeia/projectops";
const PLUGIN = "cassiiopeia@cassiiopeia-marketplace";

function detect(io) {
  if (!io.which("claude")) return { installed: false, version: null, cliMissing: true, note: "CLI 없음" };
  const r = io.run("claude", ["plugin", "list", "--json"]);
  let scope = "", version = null;
  try {
    const arr = JSON.parse(r.stdout || "[]");
    const list = Array.isArray(arr) ? arr : (arr.plugins || []);
    for (const p of list) {
      const name = String(p.name || p.id || "");
      if (name.includes("cassiiopeia@") || name === "cassiiopeia") { scope = p.scope || ""; version = p.version || null; break; }
    }
  } catch { /* 파싱 실패 → 미설치 취급 */ }
  return { installed: !!scope, version, cliMissing: false, scope };
}

function apply(io, ctx = {}) {
  const st = detect(io);
  if (st.cliMissing) { io.log(manualHint(io)); return false; }
  if (st.installed) return update(io, st.scope);
  return install(io, "user");
}

function install(io, scope = "user") {
  io.log("Claude Code 마켓플레이스 등록 중...");
  const add = io.run("claude", ["plugin", "marketplace", "add", MARKETPLACE]);
  io.log(add.code === 0 ? "  마켓플레이스 등록 완료" : "  마켓플레이스 이미 등록되어 있거나 등록 생략");
  io.log(`Claude Code 플러그인 설치 중 (scope: ${scope})...`);
  const ins = io.run("claude", ["plugin", "install", PLUGIN, "--scope", scope]);
  if (ins.code === 0) { io.log(`  Claude Code 플러그인 설치 완료 (scope: ${scope})`); return true; }
  io.log(`  플러그인 설치 실패. 수동: claude plugin install ${PLUGIN} --scope ${scope}`);
  return false;
}

function update(io, scope) {
  const cacheRoot = join(io.home(), ".claude/plugins/cache/cassiiopeia-marketplace/cassiiopeia");
  const oldCache = latestCacheDir(cacheRoot);
  io.log("플러그인 업데이트 중...");
  const up = io.run("claude", ["plugin", "update", PLUGIN, "--scope", scope]);
  if (up.code !== 0) { io.log(`  업데이트 실패. 수동: claude plugin update ${PLUGIN} --scope ${scope}`); return false; }
  io.log(`  업데이트 완료 (scope: ${scope})`);
  migrateConfig(io, oldCache, latestCacheDir(cacheRoot));
  return true;
}

function remove(io) {
  const st = detect(io);
  if (st.cliMissing || !st.installed) { io.log("  설치된 Claude Code 플러그인이 없어 건너뜁니다"); return true; }
  io.log(`  제거할 대상: ${PLUGIN} (scope: ${st.scope})`);
  const un = io.run("claude", ["plugin", "uninstall", PLUGIN, "--scope", st.scope]);
  if (un.code === 0) { io.log("  플러그인 uninstall 완료"); removePluginData(io); return true; }
  io.log(`  삭제 실패. 수동: claude plugin uninstall ${PLUGIN} --scope ${st.scope}`);
  return false;
}

function manualHint() {
  return `  💡 Claude Code 사용자: claude plugin marketplace add ${MARKETPLACE}\n     claude plugin install ${PLUGIN} --scope user`;
}

// ── 내부 헬퍼 ──
function latestCacheDir(root) {
  if (!existsSync(root)) return "";
  const dirs = readdirSync(root, { withFileTypes: true }).filter((e) => e.isDirectory()).map((e) => e.name).sort(compareCacheName);
  return dirs.length ? join(root, dirs[dirs.length - 1]) : "";
}
function migrateConfig(io, oldCache, newCache) {
  if (!oldCache || !newCache || oldCache === newCache) return;
  const oldCfg = join(oldCache, "config"), newCfg = join(newCache, "config");
  if (!existsSync(oldCfg)) return;
  try {
    mkdirSync(newCfg, { recursive: true });
    let copied = 0;
    for (const f of readdirSync(oldCfg)) if (f.endsWith(".json")) { cpSync(join(oldCfg, f), join(newCfg, f)); copied++; }
    if (copied) io.log("  config.json 마이그레이션 완료 (이전 버전 설정 유지)");
  } catch { /* 무해 */ }
}
function removePluginData(io) {
  const dataDir = join(io.home(), ".claude/plugins/data", PLUGIN);
  if (existsSync(dataDir)) { try { rmSync(dataDir, { recursive: true, force: true }); io.log("  플러그인 데이터(config) 삭제 완료"); } catch { /* 무해 */ } }
}

export const claudeAdapter = {
  id: "claude", label: "Claude Code", order: 10,
  detect, apply, remove, manualHint,
};
