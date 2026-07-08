// projectops CLI 진입 파이프라인 (.sh main + execute_integration 등가).
// 감지 → 다운로드 → 모드 라우팅 → 통합 실행 → 정리. 비대화형(--force) 우선.
import { join } from "node:path";
import { parseArgs, parsePathsCsv, CliError } from "./cli/args.js";
import { HELP_TEXT } from "./cli/help.js";
import { createContext } from "./context.js";
import { PATHS } from "./core/paths.js";
import { remove } from "./core/fsutil.js";
import { acquireTemplate, readTemplateVersion } from "./core/assets.js";
import { detectTypes, detectVersion, detectDefaultBranch, detectRepoName } from "./core/detect-fs.js";
import { runFull } from "./commands/full.js";
import { runVersion } from "./commands/version.js";
import { runWorkflows } from "./commands/workflows.js";
import { runIssues } from "./commands/issues.js";

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
  if (opts.help) { console.log(HELP_TEXT); return 0; }

  // skills 모드는 IDE 설치 전용 (SP2-D)
  if (opts.mode === "skills") {
    console.error("skills 모드는 아직 지원되지 않습니다 (SP2-D 예정). 기존 template_integrator를 사용하세요.");
    return 1;
  }
  // 비대화형 전제 — interactive/대화형은 SP2-C 후반
  if (opts.mode === "interactive" || !opts.force) {
    console.error("현재 npx CLI는 비대화형 경로만 지원합니다. --mode <full|version|workflows|issues> 와 --force 를 지정하세요.");
    return 1;
  }

  // 감지 (CLI 인자 우선, 없으면 자동 감지 — version.yml 우선 규칙은 detectTypes/detectVersion 내부)
  const types = opts.types.length ? opts.types : detectTypes(cwd);
  const version = opts.version || detectVersion(cwd);
  const branch = detectDefaultBranch(cwd);
  const repoName = detectRepoName(cwd);
  const paths = parsePathsCsv(opts.pathsCsv);
  // paths 미지정 타입은 루트(".") — basic 제외
  for (const t of types) if (t !== "basic" && !paths.has(t)) paths.set(t, ".");

  const { now, today } = clock || utcNow();
  const tempDir = join(cwd, PATHS.tempDir);

  const context = createContext({
    mode: opts.mode, force: true, types, version, branch,
    paths, includeNexus: opts.includeNexus === true, includeSecretBackup: opts.includeSecretBackup === true,
    repoName,
    resolvers: {
      repo: () => repoName,
      "spring-app-yml-dir": () => "",
      "spring-app-yml-path": () => "",
      "flutter-root": () => paths.get("flutter") || ".",
    },
    now, today,
  });

  try {
    acquireTemplate({ tempDir, source });
    context.templateVersion = readTemplateVersion(tempDir);

    switch (opts.mode) {
      case "full": runFull(context, tempDir, cwd); break;
      case "version": runVersion(context, tempDir, cwd); break;
      case "workflows": runWorkflows(context, tempDir, cwd); break;
      case "issues": runIssues(context, tempDir, cwd); break;
      default:
        // 알 수 없는 모드 → .sh와 동일하게 복사 0건, 에러 아님
        break;
    }
  } finally {
    remove(tempDir);
  }
  return 0;
}
