// workflow 카테고리 규칙 (#470) — .github/workflows/의 구 템플릿 워크플로우를 .bak으로 무해화.
// GitHub Actions는 .yaml/.yml만 실행하므로 .bak 리네임 = 즉시 무해화 + 복원 가능.
import { existsSync, readFileSync, renameSync, rmSync } from "node:fs";
import { join } from "node:path";

const WF_DIR = join(".github", "workflows");

function target(targetRoot, entry) {
  return join(targetRoot, WF_DIR, entry.file);
}

export function detect(targetRoot, entry) {
  const p = target(targetRoot, entry);
  if (!existsSync(p)) return false;
  if (entry.contentMarker) {
    try { return readFileSync(p, "utf8").includes(entry.contentMarker); }
    catch { return false; }
  }
  return true;
}

export function apply(targetRoot, entry) {
  const src = target(targetRoot, entry);
  const bak = `${src}.bak`;
  if (existsSync(bak)) rmSync(bak, { force: true }); // Windows rename은 대상 존재 시 실패
  renameSync(src, bak);
  return { action: "bak", from: entry.file, to: `${entry.file}.bak` };
}
