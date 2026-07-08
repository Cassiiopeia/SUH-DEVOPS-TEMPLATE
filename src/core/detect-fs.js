// 실 파일시스템 프로젝트 감지 (.sh detect_* 실행부 등가).
// SP2-A detect.js 순수 함수를 fs/git으로 구동한다.
import { existsSync, readFileSync } from "node:fs";
import { join, basename } from "node:path";
import { execFileSync } from "node:child_process";
import { detectTypesFromMarkers, detectVersionFromFiles } from "./detect.js";
import { parseExisting } from "./version-yml.js";

const hasFile = (root) => (rel) => existsSync(join(root, rel));
const readFile = (root) => (rel) => {
  try { return readFileSync(join(root, rel), "utf8"); } catch { return null; }
};

function gitOut(root, args) {
  try {
    return execFileSync("git", args, { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
  } catch { return ""; }
}

// 타입 감지 — version.yml의 project_types 최우선(source of truth), 없으면 마커 스캔.
export function detectTypes(root) {
  const vy = join(root, "version.yml");
  if (existsSync(vy)) {
    const { types } = parseExisting(readFileSync(vy, "utf8"));
    if (types.length) return types; // basic 포함, 명시돼 있으면 그대로
  }
  return detectTypesFromMarkers({ has: hasFile(root), read: readFile(root) });
}

// 버전 감지 — .sh detect_version 순서. jq 유무는 command 존재로 판정.
export function detectVersion(root, { hasJq } = {}) {
  const read = readFile(root);
  const readJson = (rel) => { const c = read(rel); try { return c ? JSON.parse(c) : null; } catch { return null; } };
  const jq = hasJq ?? hasCommand("jq");
  const gitTag = gitOut(root, ["describe", "--tags", "--abbrev=0"]);
  return detectVersionFromFiles({ read, readJson, hasJq: jq, gitTag });
}

// 기본 브랜치 감지 — symbolic-ref → remote show → main.
export function detectDefaultBranch(root) {
  let b = gitOut(root, ["symbolic-ref", "refs/remotes/origin/HEAD"]);
  if (b) return b.replace(/^refs\/remotes\/origin\//, "");
  const show = gitOut(root, ["remote", "show", "origin"]);
  const m = show.match(/HEAD branch:\s*(\S+)/);
  if (m) return m[1];
  return "main";
}

// 레포명 — git remote get-url origin 마지막 세그먼트, 실패 시 폴더명.
export function detectRepoName(root) {
  const url = gitOut(root, ["remote", "get-url", "origin"]);
  if (url) {
    const seg = url.replace(/\.git$/, "").split(/[/:]/).pop();
    if (seg) return seg;
  }
  return basename(root);
}

function hasCommand(cmd) {
  try {
    execFileSync(process.platform === "win32" ? "where" : "which", [cmd], { stdio: "ignore" });
    return true;
  } catch { return false; }
}
