// 브랜치 존재 확인·생성 헬퍼 (#477) — 마법사의 개발 브랜치 생성 제안에 사용.
// 모든 함수는 실패 시 조용히 false/null을 반환한다 (git 미설치·비레포·원격 없음에서 마법사가 죽지 않게).
import { execFileSync } from "node:child_process";

function git(root, args) {
  try {
    return execFileSync("git", args, { cwd: root, encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
  } catch { return null; }
}

// 브랜치 존재 상태. remote는 origin 조회 실패(원격 없음·네트워크) 시 null(불명).
export function branchStatus(root, name) {
  const isRepo = git(root, ["rev-parse", "--git-dir"]) !== null;
  if (!isRepo || !name) return { isRepo, local: false, remote: null };
  const local = git(root, ["show-ref", "--verify", `refs/heads/${name}`]) !== null;
  const ls = git(root, ["ls-remote", "--heads", "origin", name]);
  const remote = ls === null ? null : ls.length > 0;
  return { isRepo, local, remote };
}

// fromBranch(기본 브랜치)에서 로컬 브랜치 생성 — checkout하지 않는다.
// 로컬에 fromBranch가 없으면 origin/fromBranch → HEAD 순으로 폴백.
export function createBranch(root, name, fromBranch = "") {
  if (fromBranch) {
    if (git(root, ["branch", name, fromBranch]) !== null) return true;
    if (git(root, ["branch", name, `origin/${fromBranch}`]) !== null) return true;
  }
  return git(root, ["branch", name]) !== null;
}

// 원격(origin)에 브랜치 push (-u). 자격/네트워크 실패 시 false.
export function pushBranch(root, name) {
  return git(root, ["push", "-u", "origin", name]) !== null;
}
