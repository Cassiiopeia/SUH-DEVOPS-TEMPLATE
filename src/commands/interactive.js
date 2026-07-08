// 대화형 마법사 (.sh interactive_mode 등가) — template_integrator.sh 4262~4411.
// io 주입으로 테스트 가능. 실제 실행은 src/ui/prompts.js 함수를 io로 넘긴다.
import { join } from "node:path";
import { PATHS } from "../core/paths.js";
import { remove } from "../core/fsutil.js";
import { acquireTemplate, readTemplateVersion } from "../core/assets.js";
import { detectTypes, detectVersion, detectDefaultBranch, detectRepoName } from "../core/detect-fs.js";
import { createContext, VALID_TYPES } from "../context.js";
import { runFull } from "./full.js";
import { runVersion } from "./version.js";
import { runWorkflows } from "./workflows.js";
import { runIssues } from "./issues.js";
import { runSkills } from "./skills.js";
import * as prompts from "../ui/prompts.js";

const CANCEL = prompts.CANCEL;

// io 기본값 = 실제 prompts. 테스트는 스텁 io 주입.
// skills = runSkills 주입 지점(테스트가 실제 IDE CLI를 안 건드리게). 기본은 실제 runSkills.
export async function runInteractive(baseCtx, { cwd = process.cwd(), source = { type: "git" }, clock, io = prompts, skills = runSkills } = {}) {
  io.intro?.("projectops — 대화형 통합 마법사");

  // 1) 모드 선택
  const mode = await io.selectMode();
  if (mode === CANCEL || mode == null) { io.cancelMessage?.("설치를 취소했습니다."); return 0; }

  const tempDir = join(cwd, PATHS.tempDir);
  try {
    acquireTemplate({ tempDir, source });
    const templateVersion = readTemplateVersion(tempDir);

    // skills 모드 — IDE 스킬 설치 (템플릿 통합 없음). 대화형으로 실행.
    if (mode === "skills") {
      await skills({ templateVersion, tempDir, interactive: true });
      io.outro?.("AI 스킬 설치를 마쳤습니다.");
      return 0;
    }

    // issues 모드는 정보 수집 없이 바로 실행
    if (mode === "issues") {
      const ctx = createContext({ ...baseCtx, mode, force: true });
      runIssues(ctx, tempDir, cwd);
      io.outro?.("이슈·PR 템플릿을 설치했습니다.");
      return 0;
    }

    // full/version/workflows — 감지
    let types = detectTypes(cwd);
    let version = detectVersion(cwd);
    let branch = detectDefaultBranch(cwd);
    const repoName = detectRepoName(cwd);
    let includeNexus = false, includeSecretBackup = false;
    const showOptional = mode === "full" || mode === "workflows";

    // 확인/수정 루프
    let confirmed = false;
    while (!confirmed) {
      io.note?.(summarize({ mode, types, version, branch, includeNexus, includeSecretBackup, showOptional }), "프로젝트 분석 결과");
      const choice = await io.confirmProjectMenu();
      if (choice === CANCEL || choice === "cancel") { io.cancelMessage?.("설치를 취소했습니다."); return 0; }
      if (choice === "continue") { confirmed = true; break; }
      // edit 루프
      let editing = true;
      while (editing) {
        const what = await io.editMenu({ showOptional });
        if (what === CANCEL || what === "done") { editing = false; break; }
        if (what === "type") {
          const t = await io.selectTypes(types);
          if (t !== CANCEL && Array.isArray(t) && t.length) types = t;
        } else if (what === "version") {
          const v = await io.askText("새 버전 (예: 1.0.0)", version);
          if (v !== CANCEL) version = v;
        } else if (what === "branch") {
          const b = await io.askText("기본 브랜치", branch);
          if (b !== CANCEL) branch = b;
        } else if (what === "nexus") {
          const y = await io.askYesNo("Nexus publish 워크플로우를 포함할까요?", includeNexus);
          if (y !== CANCEL) includeNexus = y;
        } else if (what === "secret") {
          const y = await io.askYesNo("Secret 백업 워크플로우를 포함할까요?", includeSecretBackup);
          if (y !== CANCEL) includeSecretBackup = y;
        }
      }
    }

    // 경로: 미지정 타입은 루트(basic 제외)
    const paths = new Map();
    for (const t of types) if (t !== "basic") paths.set(t, ".");

    const { now, today } = clock || utcNow();
    const ctx = createContext({
      mode, force: true, types, version, branch, paths, includeNexus, includeSecretBackup, repoName, templateVersion,
      resolvers: {
        repo: () => repoName, "spring-app-yml-dir": () => "", "spring-app-yml-path": () => "",
        "flutter-root": () => paths.get("flutter") || ".",
      },
      now, today,
    });
    ctx.templateVersion = templateVersion;

    if (mode === "full") runFull(ctx, tempDir, cwd);
    else if (mode === "version") runVersion(ctx, tempDir, cwd);
    else if (mode === "workflows") runWorkflows(ctx, tempDir, cwd);

    io.outro?.(`통합 완료 — ${mode} 모드로 설치했습니다.`);
    return 0;
  } finally {
    remove(tempDir);
  }
}

function summarize({ mode, types, version, branch, includeNexus, includeSecretBackup, showOptional }) {
  const lines = [
    `통합 모드 : ${modeLabel(mode)}`,
    `프로젝트 타입 : ${types.join(", ")}${types.length > 1 ? " (멀티)" : ""}`,
    `버전 : ${version}`,
    `기본 브랜치 : ${branch}`,
  ];
  if (showOptional) {
    lines.push(`Nexus publish : ${includeNexus ? "포함" : "제외"}`);
    lines.push(`Secret 백업 : ${includeSecretBackup ? "포함" : "제외"}`);
  }
  return lines.join("\n");
}

function modeLabel(m) {
  return { full: "전체 설치", version: "버전 관리만", workflows: "워크플로우만", issues: "이슈·PR 템플릿만", skills: "AI 스킬만" }[m] || m;
}

function utcNow(date = new Date()) {
  const p = (n) => String(n).padStart(2, "0");
  const d = `${date.getUTCFullYear()}-${p(date.getUTCMonth() + 1)}-${p(date.getUTCDate())}`;
  const t = `${p(date.getUTCHours())}:${p(date.getUTCMinutes())}:${p(date.getUTCSeconds())}`;
  return { now: `${d} ${t}`, today: d };
}
