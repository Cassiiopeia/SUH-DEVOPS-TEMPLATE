// #459 네임스페이스 중립화 정합성 회귀 테스트.
// suh-* 스킬명·cassiiopeia 플러그인명 잔재를 막고, 외부 실체(보존 대상)는 살아있는지 지킨다.
import { test } from "node:test";
import assert from "node:assert/strict";
import { execSync } from "node:child_process";
import { readdirSync, statSync, existsSync } from "node:fs";
import { join } from "node:path";

const ROOT = process.cwd();

// 히스토리(과거 산출물·스펙)와 CHANGELOG는 당시 기록이라 검사 대상에서 제외한다.
function ripgrepCount(pattern, globs) {
  // git grep으로 추적 파일만 검사(node_modules·.git 자동 제외). 매치 0이면 exit 1.
  // 포함 pathspec은 :(glob), 제외(':!'로 시작)는 :(exclude,glob)로 감싸 magic을 올바르게 조합한다.
  const globArgs = globs.map((g) =>
    g.startsWith(":!")
      ? `':(exclude,glob)${g.slice(2)}'`
      : `':(glob)${g}'`
  ).join(" ");
  try {
    const out = execSync(`git grep -I -c -e ${JSON.stringify(pattern)} -- ${globArgs}`, {
      cwd: ROOT, encoding: "utf-8",
    });
    return out.trim().split("\n").filter(Boolean);
  } catch {
    return []; // 매치 0건
  }
}

const EXCLUDE = [
  ":!docs/superpowers/**", ":!docs/projectops/**",
  ":!CHANGELOG.md", ":!CHANGELOG.json",
];

test("skills/ 아래 suh- 폴더가 0개다", () => {
  const dirs = readdirSync(join(ROOT, "skills"))
    .filter((d) => statSync(join(ROOT, "skills", d)).isDirectory() && d.startsWith("suh-"));
  assert.deepEqual(dirs, [], `잔존 suh- 스킬 폴더: ${dirs.join(", ")}`);
});

test("25개 중립 스킬 폴더가 모두 존재한다", () => {
  const expected = [
    "analyze", "build", "changelog-deploy", "commit", "design", "design-analyze",
    "document", "figma", "github", "implement", "init-worktree", "issue", "plan",
    "ppt", "refactor", "refactor-analyze", "report", "review", "skill-creator",
    "spring-test", "ssh", "synology-expose", "test", "testcase", "troubleshoot",
  ];
  for (const s of expected) {
    assert.ok(existsSync(join(ROOT, "skills", s, "SKILL.md")), `누락: skills/${s}/SKILL.md`);
  }
});

test("활성 문서/코드에 cassiiopeia:suh- 커맨드 표기 잔재가 없다", () => {
  const hits = ripgrepCount("cassiiopeia:suh-", ["*.md", "*.js", "*.py", ...EXCLUDE]);
  assert.deepEqual(hits, [], `cassiiopeia:suh- 잔재:\n${hits.join("\n")}`);
});

test("소문자 플러그인명 cassiiopeia 잔재가 없다(대문자 조직명은 허용)", () => {
  // 매니페스트·IDE 어댑터·활성 문서 대상. 대문자 Cassiiopeia(조직명)는 git grep 대소문자 구분으로 통과.
  const hits = ripgrepCount("cassiiopeia", [
    ".claude-plugin/**", ".codex-plugin/**", ".agents/**", ".cursor/**",
    "gemini-extension.json", "src/**", "*.md", ...EXCLUDE,
  ]);
  assert.deepEqual(hits, [], `소문자 cassiiopeia 잔재:\n${hits.join("\n")}`);
});

test("@suh-lab 트리거 잔재가 없다(외부 봇 서명 Guide by SUH-LAB은 별개)", () => {
  const hits = ripgrepCount("@suh-lab", ["*.md", ".github/**", ...EXCLUDE]);
  assert.deepEqual(hits, [], `@suh-lab 잔재:\n${hits.join("\n")}`);
});

// ── 보존 대상(치환 금지)이 살아있는지 — 과잉 치환 회귀 방지 ──

test("보존: suh-logger Maven 의존성이 spring-test SKILL에 남아있다", () => {
  const hits = ripgrepCount("me.suhsaechan:suh-logger", ["skills/spring-test/**"]);
  assert.ok(hits.length > 0, "me.suhsaechan:suh-logger가 사라짐(과잉 치환)");
});

test("보존: 외부 봇 서명 'Guide by SUH-LAB' 매칭이 살아있다", () => {
  const hits = ripgrepCount("Guide by SUH-LAB", [".github/**"]);
  assert.ok(hits.length > 0, "'Guide by SUH-LAB' 서명 매칭이 사라짐(빌드 트리거 파손)");
});
