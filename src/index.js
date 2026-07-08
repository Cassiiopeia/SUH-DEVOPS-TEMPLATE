// projectops CLI 진입 파이프라인 (.sh main + execute_integration 등가).
// 감지 → 다운로드 → 모드 라우팅 → 통합 실행 → 정리. 비대화형(--force) 우선.
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { readFileSync, existsSync } from "node:fs";
import { parseArgs, parsePathsCsv, CliError } from "./cli/args.js";
import { HELP_TEXT } from "./cli/help.js";
import { createContext } from "./context.js";
import { PATHS } from "./core/paths.js";
import { remove } from "./core/fsutil.js";
import { acquireTemplate, readTemplateVersion } from "./core/assets.js";
import { detectTypes, detectVersion, detectDefaultBranch, detectRepoName, makeResolvers } from "./core/detect-fs.js";
import { parseExisting } from "./core/version-yml.js";
import { runBreakingCheck } from "./core/breaking-check.js";
import { resolveProjectPaths } from "./core/paths-resolve.js";
import { printBannerCompact } from "./ui/banner.js";
import { printSummary } from "./ui/summary.js";
import { runFull } from "./commands/full.js";
import { runVersion } from "./commands/version.js";
import { runWorkflows } from "./commands/workflows.js";
import { runIssues } from "./commands/issues.js";
import { runInteractive } from "./commands/interactive.js";
import { runSkills } from "./commands/skills.js";

// projectops 패키지 버전 읽기 (-v/--version 출력용). src/../package.json.
function readPkgVersion() {
  try {
    const here = dirname(fileURLToPath(import.meta.url));
    const pkg = JSON.parse(readFileSync(join(here, "..", "package.json"), "utf8"));
    return pkg.version || "unknown";
  } catch {
    return "unknown";
  }
}

// 결정적 UTC 타임스탬프 (주입 가능 — 테스트/골든용)
function utcNow(date = new Date()) {
  const p = (n) => String(n).padStart(2, "0");
  const d = `${date.getUTCFullYear()}-${p(date.getUTCMonth() + 1)}-${p(date.getUTCDate())}`;
  const t = `${p(date.getUTCHours())}:${p(date.getUTCMinutes())}:${p(date.getUTCSeconds())}`;
  return { now: `${d} ${t}`, today: d };
}

// run(argv, opts) → exitCode. opts: { cwd, source?, clock? }
//   source: acquireTemplate용 (기본 git clone). 테스트는 {type:'local', path} 주입.
//   clock: {now, today} 주입 (기본 현재 UTC).
export async function run(argv, { cwd = process.cwd(), source = { type: "git" }, clock } = {}) {
  let opts;
  try {
    opts = parseArgs(argv);
  } catch (e) {
    if (e instanceof CliError) { console.error(e.message); return 1; }
    throw e;
  }
  if (opts.showVersion) { console.log(readPkgVersion()); return 0; }
  if (opts.help) { console.log(HELP_TEXT); return 0; }

  // skills 모드 — IDE 스킬 설치/업데이트/제거 (템플릿 통합 없음).
  // Cursor 복사용 skills/ 소스가 필요하므로 템플릿을 획득한 뒤 실행한다.
  if (opts.mode === "skills") {
    const tempDir = join(cwd, PATHS.tempDir);
    const interactive = !opts.force && process.stdout.isTTY;
    try {
      acquireTemplate({ tempDir, source });
      const templateVersion = readTemplateVersion(tempDir);
      return await runSkills({ templateVersion, tempDir, interactive });
    } finally {
      remove(tempDir);
    }
  }
  // 대화형 모드 — 인자 없이 실행 or --mode interactive
  if (opts.mode === "interactive") {
    if (!process.stdout.isTTY) {
      console.error("대화형 입력이 불가능한 환경입니다. --mode <full|version|workflows|issues> 와 --force 를 지정하세요.");
      return 1;
    }
    return await runInteractive({}, { cwd, source, clock });
  }
  // 명시 모드인데 --force 없으면 (비대화형 CLI는 --force 필요)
  if (!opts.force && !process.stdout.isTTY) {
    console.error("비대화형 환경에서는 --force 옵션이 필요합니다.");
    return 1;
  }

  // 기존 version.yml 로드 — version/version_code/project_paths 보존의 단일 진실 (.sh L2208~2239 SSoT)
  const vyPath = join(cwd, "version.yml");
  const existing = existsSync(vyPath) ? parseExisting(readFileSync(vyPath, "utf8")) : null;

  // 감지 (CLI 인자 우선, 없으면 자동 감지 — version.yml 우선 규칙은 detectTypes/detectVersion 내부)
  const types = opts.types.length ? opts.types : detectTypes(cwd);
  // version: 기존 version.yml 최우선(SSoT — 재실행 시 덮어쓰기 방지) → CLI 지정 → 파일 감지
  const version = (existing?.version) || opts.version || detectVersion(cwd);
  const versionCode = existing?.versionCode ?? 1; // 기존 빌드번호 보존 (.sh L2208~2221)
  const branch = detectDefaultBranch(cwd);
  const repoName = detectRepoName(cwd);
  // 경로 확정 (.sh resolve_project_paths 비대화형 경로 — --paths 우선 → 저장값 → 후보 1개 자동 → 루트 폴백)
  const paths = await resolveProjectPaths({
    root: cwd, types, paths: parsePathsCsv(opts.pathsCsv),
    existingPaths: existing?.paths ?? new Map(), force: true, tty: false, io: {},
  });

  const { now, today } = clock || utcNow();
  const tempDir = join(cwd, PATHS.tempDir);

  const context = createContext({
    mode: opts.mode, force: true, types, version, versionCode, branch,
    paths,
    // 옵션 워크플로우: CLI 플래그 최우선 → version.yml 저장 옵션(.sh read_template_options 등가) → false
    includeNexus: opts.includeNexus ?? existing?.options?.nexus ?? false,
    includeSecretBackup: opts.includeSecretBackup ?? existing?.options?.secretBackup ?? false,
    repoName,
    // 실 resolver 4종 (.sh resolve_token 등가 — spring-app-yml 스텁 제거)
    resolvers: makeResolvers(cwd, repoName, paths),
    now, today,
  });

  let result = null;
  try {
    acquireTemplate({ tempDir, source });
    context.templateVersion = readTemplateVersion(tempDir);

    // 비대화형 축약 배너 (#446 확정 — 1줄, 로그 오염 최소)
    printBannerCompact({ version: context.templateVersion, mode: opts.mode });

    // Breaking Changes 게이트 (.sh execute_integration L4415~4420 등가 — 비대화형은 경고 후 진행)
    const proceed = await runBreakingCheck({ cwd, tempDir, templateVersion: context.templateVersion });
    if (!proceed) return 0;

    switch (opts.mode) {
      case "full": result = runFull(context, tempDir, cwd); break;
      case "version": result = runVersion(context, tempDir, cwd); break;
      case "workflows": result = runWorkflows(context, tempDir, cwd); break;
      case "issues": result = runIssues(context, tempDir, cwd); break;
      default:
        // 알 수 없는 모드 → .sh와 동일하게 복사 0건, 에러 아님
        break;
    }
  } finally {
    remove(tempDir);
  }

  // 완료 요약 (.sh print_summary — CLI 모드에서도 출력)
  printSummary({
    mode: opts.mode, types, version,
    counters: { workflows: result?.workflows?.copied ?? 0, utilModules: 0 },
  }, cwd);
  return 0;
}
