// .gitignore 보장 (.sh ensure_gitignore + normalize/check 등가) — template_integrator.sh 3996~4111.
import { join } from "node:path";
import { existsSync, readFileSync, writeFileSync } from "node:fs";

const REQUIRED_ENTRIES = ["/.idea", "/.claude/settings.local.json"];

// .sh normalize_gitignore_entry: 주석 제거·트림·앞 / 제거·앞 ./ 제거·뒤 / 제거. 빈값이면 원본.
export function normalizeGitignoreEntry(entry) {
  let e = String(entry);
  e = e.replace(/#.*$/, "");        // 주석 제거
  e = e.trim();                      // 앞뒤 공백
  e = e.replace(/^\//, "");         // 앞 /
  e = e.replace(/^\.\//, "");       // 앞 ./
  e = e.replace(/\/$/, "");         // 뒤 /
  return e === "" ? String(entry) : e;
}

function entryExists(target, content) {
  const nt = normalizeGitignoreEntry(target);
  for (const line of content.split("\n")) {
    if (/^\s*#/.test(line)) continue;
    if (/^\s*$/.test(line)) continue;
    if (normalizeGitignoreEntry(line) === nt) return true;
  }
  return false;
}

const NEW_FILE_CONTENT =
  "# IDE Settings\n" +
  "/.idea\n" +
  "\n" +
  "# Claude AI Settings\n" +
  "/.claude/settings.local.json\n";

// 반환: {created, added:[...]}
export function ensureGitignore(targetRoot = ".") {
  const p = join(targetRoot, ".gitignore");
  if (!existsSync(p)) {
    writeFileSync(p, NEW_FILE_CONTENT);
    return { created: true, added: REQUIRED_ENTRIES.slice() };
  }
  let content = readFileSync(p, "utf8");
  const toAdd = REQUIRED_ENTRIES.filter((e) => !entryExists(e, content));
  if (toAdd.length === 0) return { created: false, added: [] };

  // 파일 끝에 개행 없으면 추가 (.sh: tail -c 1 이 non-empty면 echo "")
  if (content.length > 0 && !content.endsWith("\n")) content += "\n";
  content += "\n";
  content += "# ====================================================================\n";
  content += "# projectops: Auto-added entries\n";
  content += "# ====================================================================\n";
  for (const e of toAdd) content += e + "\n";
  writeFileSync(p, content);
  return { created: false, added: toAdd };
}
