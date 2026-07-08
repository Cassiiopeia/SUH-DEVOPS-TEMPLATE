// util 모듈 복사 (.sh copy_util_modules 등가, force 경로) — template_integrator.sh 4203~.
// tempDir/.github/util/<type>/ 있으면 (force) .github/util/<type>/로 전체 복사, 모듈 수 카운트.
import { join } from "node:path";
import { readdirSync } from "node:fs";
import { exists, copyDirSync } from "../fsutil.js";

// 반환: {copied:bool, moduleCount:number}. force가 아니면(비TTY) 스킵.
export function copyUtilModules(tempDir, type, { force = false } = {}, targetRoot = ".") {
  const src = join(tempDir, ".github", "util", type);
  if (!exists(src)) return { copied: false, moduleCount: 0 };
  if (!force) return { copied: false, moduleCount: 0 }; // SP2-B: force 경로만

  const dst = join(targetRoot, ".github", "util", type);
  copyDirSync(src, dst);

  // 하위 디렉토리 개수 = 모듈 수 (.sh: for dir in "$util_dst"/*/)
  let moduleCount = 0;
  for (const e of readdirSync(dst, { withFileTypes: true })) {
    if (e.isDirectory()) moduleCount++;
  }
  return { copied: true, moduleCount };
}
