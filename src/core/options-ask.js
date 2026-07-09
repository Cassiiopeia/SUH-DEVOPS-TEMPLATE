// 선택(opt-in) 워크플로우 포함 여부 질문 (.sh ask_optional_workflow L2651~2702 /
// ask_all_optional_workflows L2708~2732 등가). Nexus publish + Secret 서버 백업.
//
// io 주입 계약(readline-engine 시그니처):
//   io.confirm({message, initialValue}) → bool | CANCEL(symbol)
//   io.log(line)                        → 안내 출력 (없으면 stderr)
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { listYamlFiles } from "./fsutil.js";
import { PATHS } from "./paths.js";
import { parseTemplateOptions } from "./version-yml.js";

// 재노출 — 파서 본체는 version-yml.js에 있다 (순환 import 방지: options-ask → version-yml 방향만 허용)
export { parseTemplateOptions };

const isCancel = (v) => typeof v === "symbol";

// 옵션 1종 질문 (.sh ask_optional_workflow 등가).
// 반환: true/false/null(폴더 없음·파일 0개로 질문 자체 생략 → 현재값 유지).
async function askOptionalWorkflow({ dir, icon, short, desc, current, force, tty, io, forceAsk, say }) {
  // 폴더가 없거나 yaml이 0개면 조용히 건너뜀 (.sh L2664~2669) — 질문 자체가 성립 안 함
  if (!existsSync(dir)) return current;
  const files = listYamlFiles(dir);
  if (files.length === 0) return current;

  // 이미 값이 설정돼 있고 force-ask 아니면 유지 (CLI/version.yml 우선, .sh L2672~2674)
  if (!forceAsk && (current === true || current === false)) return current;

  // 비대화형(--force 또는 TTY 없음)이면 기본 제외 (.sh L2677~2679)
  if (force || !tty) return false;

  say("");
  say(`${icon} ${short} 워크플로우를 발견했습니다. (${files.length}개 파일)`);
  say(`   ${desc}`);
  say("");
  say("   포함되는 워크플로우:");
  for (const f of files) say(`     • ${f}`);
  say("");

  const ans = await io.confirm({ message: `${short} 워크플로우를 포함할까요?`, initialValue: false });
  // ESC(취소)는 '아니오'와 동일 취급 (.sh ask_yes_no 비-0 반환 등가)
  const include = ans === true && !isCancel(ans);
  say(include
    ? `${short} 워크플로우를 포함합니다 — GitHub Actions에 추가됩니다`
    : `${short} 워크플로우를 제외합니다 (나중에 옵션으로 추가 가능)`);
  return include;
}

// 모든 opt-in 워크플로우를 순서대로 질문 (.sh ask_all_optional_workflows 등가).
// tempDir: 템플릿 다운로드 루트 — project-types는 {tempDir}/.github/workflows/project-types
//          (copyWorkflows와 동일 규약. 테스트 픽스처용으로 {tempDir}/project-types 도 허용.)
// current: { nexus: bool|null, secretBackup: bool|null, npmPublish: bool|null } — CLI(--nexus 등) 명시값
// 반환: { nexus: bool, secretBackup: bool, npmPublish: bool } (미결정 null은 false로 확정)
export async function askAllOptionalWorkflows({
  tempDir, types = [], current = {}, targetRoot = ".",
  force = false, tty = true, io = {}, forceAsk = false,
}) {
  const say = io.log || ((m) => process.stderr.write(`${m}\n`));
  let nexus = current.nexus ?? null;
  let secretBackup = current.secretBackup ?? null;
  let npmPublish = current.npmPublish ?? null;

  // ① --force-ask가 아니면 version.yml 저장값을 먼저 읽어 재질문을 건너뛴다 (.sh L2715~2717).
  //    CLI 명시값(current)이 이미 있으면 그쪽이 우선 — 저장값은 빈 자리만 채운다.
  if (!forceAsk) {
    const vy = join(targetRoot, PATHS.versionFile);
    if (existsSync(vy)) {
      const saved = parseTemplateOptions(readFileSync(vy, "utf8"));
      if (nexus === null && saved.nexus !== null) {
        nexus = saved.nexus;
        say(`Nexus 옵션: version.yml 저장값(${nexus}) 유지 — 재질문 생략`);
      }
      if (secretBackup === null && saved.secretBackup !== null) {
        secretBackup = saved.secretBackup;
        say(`Secret 백업 옵션: version.yml 저장값(${secretBackup}) 유지 — 재질문 생략`);
      }
      if (npmPublish === null && saved.npmPublish !== null) {
        npmPublish = saved.npmPublish;
        say(`npm publish 옵션: version.yml 저장값(${npmPublish}) 유지 — 재질문 생략`);
      }
    }
  }

  // project-types 루트 결정 — 실제 temp 레이아웃 우선, 픽스처(직하위) 폴백
  const real = join(tempDir, PATHS.workflowsDir, PATHS.projectTypesDir);
  const ptDir = existsSync(real) ? real : join(tempDir, PATHS.projectTypesDir);

  // ② Nexus: 각 타입의 nexus/ 폴더 (현재 spring만 존재, .sh L2719~2725)
  for (const t of types) {
    nexus = await askOptionalWorkflow({
      dir: join(ptDir, t, "nexus"), icon: "📦", short: "Nexus 라이브러리 publish",
      desc: "라이브러리/모듈을 Maven 저장소(Nexus)에 배포하는 워크플로우입니다. 일반 서버 배포가 아니라 라이브러리 프로젝트에만 필요합니다.",
      current: nexus, force, tty, io, forceAsk, say,
    });
  }
  // ②-2 npm publish: 각 타입의 npm-publish/ 폴더 (현재 node만 존재)
  for (const t of types) {
    npmPublish = await askOptionalWorkflow({
      dir: join(ptDir, t, "npm-publish"), icon: "📦", short: "npm 패키지 publish",
      desc: "패키지를 공개 npmjs 레지스트리에 자동 배포하는 워크플로우입니다. npm 라이브러리/CLI 프로젝트에만 필요합니다 (NPM_TOKEN secret 필요).",
      current: npmPublish, force, tty, io, forceAsk, say,
    });
  }
  // ③ Secret 백업: 공통 폴더 (.sh L2726~2729)
  secretBackup = await askOptionalWorkflow({
    dir: join(ptDir, "common", "secret-backup"), icon: "🔐", short: "Secret 서버 백업",
    desc: "GitHub Secret에 저장한 설정 파일을 SSH로 서버에 업로드·이력관리하는 워크플로우입니다.",
    current: secretBackup, force, tty, io, forceAsk, say,
  });

  // ④ 미결정(null)은 false로 확정 — .sh에서 빈 INCLUDE_* 가 이후 false 취급되는 것과 동일
  return { nexus: nexus === true, secretBackup: secretBackup === true, npmPublish: npmPublish === true };
}
