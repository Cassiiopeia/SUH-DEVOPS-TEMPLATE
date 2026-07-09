// 완료 요약 출력 (.sh print_summary L5438~5626 등가). 전부 stderr.
// ctx: { mode, types:[], version, counters:{ workflows, utilModules } }
import { existsSync, readdirSync } from "node:fs";
import { join } from "node:path";
import {
  PATHS, WORKFLOW_PREFIX, WORKFLOW_COMMON_PREFIX, WORKFLOW_TEMPLATE_INIT,
} from "../core/paths.js";
import { listYamlFiles } from "../core/fsutil.js";

const SEPARATOR = "────────────────────────────────────────";

export function printSummary(ctx, targetRoot = ".") {
  const { mode, types = [], version = "", counters = {} } = ctx || {};
  const err = (s = "") => process.stderr.write(`${s}\n`);
  // 색상은 TTY일 때만 (.sh YELLOW/CYAN/NC 등가)
  const isTty = !!process.stderr.isTTY;
  const YELLOW = isTty ? "\x1b[1;33m" : "";
  const CYAN = isTty ? "\x1b[0;36m" : "";
  const NC = isTty ? "\x1b[0m" : "";
  const utilModulesCopied = counters.utilModules ?? 0;
  const workflowsCopied = counters.workflows ?? 0;

  err("");
  err(SEPARATOR);
  err("");
  err("✨ projectops Setup Complete!");
  err("");
  err(SEPARATOR);
  err("");
  err("통합된 기능:");

  // 모드별 체크리스트 (.sh L5449~5481)
  switch (mode) {
    case "full":
      err("  ✅ 버전 관리 시스템 (version.yml)");
      err("  ✅ README.md 자동 버전 업데이트");
      err("  ✅ GitHub Actions 워크플로우");
      if (utilModulesCopied > 0) err(`  ✅ 유틸리티 모듈 (${utilModulesCopied} 개)`);
      err("  ✅ 이슈/PR/Discussion 템플릿");
      err("  ✅ CodeRabbit AI 리뷰 설정");
      err("  ✅ .gitignore 필수 항목");
      err("  ✅ 템플릿 설정 가이드 (SETUP-GUIDE.md)");
      break;
    case "version":
      err("  ✅ 버전 관리 시스템 (version.yml)");
      err("  ✅ README.md 자동 버전 업데이트");
      err("  ✅ .gitignore 필수 항목");
      err("  ✅ 템플릿 설정 가이드 (SETUP-GUIDE.md)");
      break;
    case "workflows":
      err("  ✅ GitHub Actions 워크플로우");
      if (utilModulesCopied > 0) err(`  ✅ 유틸리티 모듈 (${utilModulesCopied} 개)`);
      err("  ✅ 템플릿 설정 가이드 (SETUP-GUIDE.md)");
      break;
    case "issues":
      err("  ✅ 이슈/PR/Discussion 템플릿");
      break;
    case "skills":
      err("  ✅ Agent Skill 설치 (Claude, Cursor, Gemini, Codex, PI)");
      break;
  }

  // skills 모드: 파일/워크플로우 추가 없으므로 간결하게 종료 (.sh L5484~5491)
  if (mode === "skills") {
    err("");
    err("  📖 TEMPLATE REPO: https://github.com/Cassiiopeia/projectops");
    err("");
    err(SEPARATOR);
    err("");
    return;
  }

  err("");
  err("추가된 파일:");
  err(`  📄 version.yml (버전: ${version}, 타입: ${types.join(",")})`);
  err("  📝 README.md (버전 섹션 추가)");
  err("");
  err("추가된 워크플로우:");

  // 실제 복사된 워크플로우와 기존 파일 구분 (.sh L5505~5534)
  const commonWorkflows = [];
  const typeWorkflows = [];
  const existingWorkflows = [];
  const workflowsDir = join(targetRoot, PATHS.workflowsDir);
  if (existsSync(workflowsDir)) {
    const typePrefixes = types.map((t) => `${WORKFLOW_PREFIX}-${t.toUpperCase()}-`);
    for (const filename of listYamlFiles(workflowsDir)) {
      if (!filename.startsWith(`${WORKFLOW_PREFIX}-`)) continue; // PROJECT-*.{yaml,yml}만
      if (filename === WORKFLOW_TEMPLATE_INIT) {
        // TEMPLATE-INITIALIZER는 템플릿 전용 기존 파일로 분류
        existingWorkflows.push(filename);
      } else if (filename.startsWith(`${WORKFLOW_COMMON_PREFIX}-`)) {
        commonWorkflows.push(filename);
      } else if (typePrefixes.some((p) => filename.startsWith(p))) {
        typeWorkflows.push(filename);
      }
    }
  }

  if (commonWorkflows.length > 0 || typeWorkflows.length > 0) {
    err(`  📦 새로 설치됨 (${workflowsCopied}개):`);
    for (const wf of commonWorkflows) err(`     📌 ${wf}`);
    for (const wf of typeWorkflows) err(`     🎯 ${wf}`);
  }
  if (existingWorkflows.length > 0) {
    err("");
    err("  🔧 기존 파일 유지됨:");
    for (const wf of existingWorkflows) err(`     📌 ${wf} (템플릿 전용)`);
  }

  err("");
  err("  🔧 .github/scripts/");
  err("     ├─ version_manager.sh");
  err("     └─ changelog_manager.py");
  err("");

  // util 모듈 목록 (.sh L5566~5581) — 타입별 .github/util/{type}/*/ 스캔
  if (utilModulesCopied > 0) {
    err("  🧙 유틸리티 모듈:");
    for (const t of types) {
      const utilDir = join(targetRoot, ".github/util", t);
      if (!existsSync(utilDir)) continue;
      let entries = [];
      try { entries = readdirSync(utilDir, { withFileTypes: true }); } catch { /* 무시 */ }
      for (const e of entries) {
        if (e.isDirectory()) err(`     ├─ ${e.name} (${t})`);
      }
    }
    err("");
  }

  // 프로젝트 타입별 안내 (.sh L5583~5599)
  if (types.includes("spring")) {
    err("  💡 Spring 프로젝트 추가 설정:");
    err("     • build.gradle의 버전 정보가 자동 동기화됩니다");
    err("     • CI/CD 워크플로우에서 GitHub Secrets 설정이 필요합니다");
    err("     • 자세한 설정 방법: .github/workflows/project-types/spring/README.md");
    err("");
  }
  if (types.includes("flutter") && utilModulesCopied > 0) {
    err("  💡 Flutter 배포 마법사 사용법:");
    err("     • iOS TestFlight: .github/util/flutter/ios-testflight-setup-wizard/index.html");
    err("     • Android Play Store: .github/util/flutter/android-playstore-setup-wizard/index.html");
    err("     • 브라우저에서 열어 필요한 정보 입력 후 파일 생성");
    err("");
  }

  err("  📖 TEMPLATE REPO: https://github.com/Cassiiopeia/projectops");
  err("  📚 워크플로우 가이드: .github/workflows/project-types/README.md");
  err("");

  // 필수 3가지 작업 안내 (.sh L5605~5625 — 원문 유지)
  err(SEPARATOR);
  err("");
  err(`${YELLOW}⚠️  다음 3가지 작업을 완료해주세요:${NC}`);
  err("");
  err("  1️⃣  GitHub Personal Access Token 설정");
  err("     → Repository Settings > Secrets > Actions");
  err("     → Secret Name: _GITHUB_PAT_TOKEN");
  err("     → Scopes: repo, workflow");
  err("");
  err("  2️⃣  develop 브랜치 생성");
  err("     → git checkout -b develop && git push -u origin develop");
  err("");
  err("  3️⃣  CodeRabbit 활성화");
  err("     → https://coderabbit.ai 방문하여 저장소 활성화");
  err("");
  err(SEPARATOR);
  err("");
  err(`${CYAN}📖 자세한 설정 방법은 다음 파일을 참고하세요:${NC}`);
  err("   → PROJECTOPS-SETUP-GUIDE.md");
  err("");
}
