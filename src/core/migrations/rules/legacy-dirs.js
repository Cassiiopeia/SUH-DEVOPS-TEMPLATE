// legacy-dir 카테고리 규칙 (#476) — 구명칭 산출물 폴더를 신명칭으로 이동.
// 폴더 안은 사용자가 작성한 문서(이슈·보고서)라 삭제·무해화 대상이 아니다 — 손실 없는 이동만 한다.
// 대상 폴더가 이미 있으면 재귀 병합하되 충돌 파일은 원위치에 남긴다(사용자 판단 존중).
import { existsSync, statSync, readdirSync, renameSync, mkdirSync, rmdirSync } from "node:fs";
import { join } from "node:path";

export function detect(targetRoot, entry) {
  const p = join(targetRoot, entry.file);
  try { return existsSync(p) && statSync(p).isDirectory(); }
  catch { return false; }
}

// 재귀 병합: 파일은 대상에 없을 때만 이동, 하위 폴더는 재귀. 다 비운 원본 폴더는 제거.
function mergeDir(from, to) {
  mkdirSync(to, { recursive: true });
  let moved = 0, skipped = 0;
  for (const e of readdirSync(from, { withFileTypes: true })) {
    const s = join(from, e.name);
    const d = join(to, e.name);
    if (e.isDirectory()) {
      const r = mergeDir(s, d);
      moved += r.moved; skipped += r.skipped;
    } else if (existsSync(d)) {
      skipped++; // 동명 파일 충돌 — 원위치에 남긴다
    } else {
      renameSync(s, d); moved++;
    }
  }
  try { rmdirSync(from); } catch { /* 충돌 잔여로 비어있지 않으면 남긴다 */ }
  return { moved, skipped };
}

export function apply(targetRoot, entry) {
  const { moved, skipped } = mergeDir(join(targetRoot, entry.file), join(targetRoot, entry.replacedBy));
  return { action: "moved", from: entry.file, to: entry.replacedBy, moved, skipped };
}
