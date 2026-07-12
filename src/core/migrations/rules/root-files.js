// root-file 카테고리 규칙 (#470) — 레포 루트의 구 템플릿 문서를 삭제.
// 문서라 무해화가 필요 없고, 사용자가 매번 수동 삭제하던 잔재라 delete가 기대 동작.
import { existsSync, readFileSync, rmSync } from "node:fs";
import { join } from "node:path";

function target(targetRoot, entry) {
  return join(targetRoot, entry.file);
}

export function detect(targetRoot, entry) {
  const p = target(targetRoot, entry);
  if (!existsSync(p)) return false;
  // 범용 파일명 오탐 방지 — contentMarker가 있으면 내용까지 확인해야 템플릿 소유로 판정
  if (entry.contentMarker) {
    try { return readFileSync(p, "utf8").includes(entry.contentMarker); }
    catch { return false; }
  }
  return true;
}

export function apply(targetRoot, entry) {
  rmSync(target(targetRoot, entry), { force: true });
  return { action: "deleted", from: entry.file, to: null };
}
