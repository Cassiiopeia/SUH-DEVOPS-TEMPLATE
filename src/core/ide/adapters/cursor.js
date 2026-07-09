// Cursor 어댑터 (.sh _manage_cursor_section / _do_cursor_skills_copy /
// _write_cursor_skills_meta / _remove_cursor_section 등가).
// 마켓플레이스 없음 → ~/.cursor/skills/ 에 skills/ 폴더를 복사하고 meta.json으로 버전 추적.
import { join } from "node:path";
import { existsSync, readFileSync, mkdirSync, cpSync, rmSync, writeFileSync, readdirSync } from "node:fs";

function metaPath(io) { return join(io.home(), ".cursor/skills/cursor-skills-meta.json"); }

function detect(io) {
  const mp = metaPath(io);
  if (!existsSync(mp)) return { installed: false, version: null, cliMissing: false };
  let version = null;
  try {
    const m = JSON.parse(readFileSync(mp, "utf8"));
    version = m.version || null;
  } catch { /* meta 손상 → 설치는 됐다고 봄 */ }
  return { installed: true, version, cliMissing: false };
}

function apply(io, ctx = {}) {
  const src = resolveSkillsSrc(ctx);
  if (!src) { io.log("  설치할 스킬 소스를 찾지 못했습니다 (skills/ 폴더 필요)."); return false; }
  const dest = join(io.home(), ".cursor/skills");
  io.log("Cursor Skills 복사 중...");
  try {
    mkdirSync(dest, { recursive: true });
    for (const e of readdirSync(src, { withFileTypes: true })) {
      cpSync(join(src, e.name), join(dest, e.name), { recursive: true });
    }
    writeMeta(io, dest, ctx.templateVersion);
    io.log(`  Cursor Skills 설치 완료 (${dest}/, v${ctx.templateVersion || "unknown"})`);
    return true;
  } catch {
    io.log("  Cursor Skills 복사 실패 — skills/ 폴더를 확인하세요.");
    return false;
  }
}

function remove(io) {
  const dir = join(io.home(), ".cursor/skills");
  if (!existsSync(join(dir, "cursor-skills-meta.json"))) { io.log("  설치된 Cursor Skills가 없어 건너뜁니다"); return true; }
  try { rmSync(dir, { recursive: true, force: true }); io.log(`  Cursor Skills 제거 완료 (${dir}/)`); return true; }
  catch { io.log(`  Cursor Skills 제거 실패 — 수동 삭제: rm -rf ${dir}`); return false; }
}

function manualHint() {
  return "  💡 Cursor: skills/ 폴더를 ~/.cursor/skills/ 로 복사하면 됩니다.";
}

// ── 헬퍼 ──
// 스킬 소스: 다운로드된 템플릿(TEMP)/skills 우선, 없으면 로컬 skills/.
function resolveSkillsSrc(ctx) {
  const cands = [ctx.sourceSkillsDir, ctx.tempDir && join(ctx.tempDir, "skills"), "skills"].filter(Boolean);
  for (const c of cands) if (existsSync(c)) return c;
  return "";
}

function writeMeta(io, destDir, templateVersion) {
  const version = templateVersion || "unknown";
  const now = new Date().toISOString().replace(/\.\d+Z$/, "Z");
  const file = join(destDir, "cursor-skills-meta.json");
  let installedAt = now;
  if (existsSync(file)) { try { installedAt = JSON.parse(readFileSync(file, "utf8")).installedAt || now; } catch { /* 무해 */ } }
  const meta = {
    name: "projectops", version, scope: "user",
    source: "https://github.com/Cassiiopeia/projectops",
    installPath: destDir, installedAt, lastUpdated: now,
  };
  mkdirSync(destDir, { recursive: true });
  writeFileSync(file, JSON.stringify(meta, null, 2) + "\n");
}

export const cursorAdapter = {
  id: "cursor", label: "Cursor", order: 20,
  detect, apply, remove, manualHint,
};
