// 배포/publish 축(#439) + Secret 백업 opt-in 질문 (.sh ask_deploy_publish /
// ask_optional_workflow / ask_all_optional_workflows 등가).
//
// io 주입 계약(readline-engine 시그니처):
//   io.confirm({message, initialValue})            → bool | CANCEL(symbol)
//   io.select({message, options})                  → value | CANCEL   (deploy 택1)
//   io.multiselect({message, options, initialValues}) → value[] | CANCEL (publish 다중)
//   io.log(line)                                   → 안내 출력 (없으면 stderr)
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { listYamlFiles } from "./fsutil.js";
import { PATHS } from "./paths.js";
import { parseTemplateOptions } from "./version-yml.js";

// 재노출 — 파서 본체는 version-yml.js에 있다 (순환 import 방지: options-ask → version-yml 방향만 허용)
export { parseTemplateOptions };

export const DEPLOY_TARGETS = ["docker-ssh", "vercel", "none"];
export const PUBLISH_TARGETS = ["nexus", "npm", "github-packages"];

const isCancel = (v) => typeof v === "symbol";

// Secret 백업 등 폴더 기반 opt-in 1종 질문 (.sh ask_optional_workflow 등가).
// 반환: true/false/null(폴더 없음·파일 0개로 질문 자체 생략 → 현재값 유지).
async function askOptionalWorkflow({ dir, icon, short, desc, current, force, tty, io, forceAsk, say }) {
  // 폴더가 없거나 yaml이 0개면 조용히 건너뜀 — 질문 자체가 성립 안 함
  if (!existsSync(dir)) return current;
  const files = listYamlFiles(dir);
  if (files.length === 0) return current;

  // 이미 값이 설정돼 있고 force-ask 아니면 유지 (CLI/version.yml 우선)
  if (!forceAsk && (current === true || current === false)) return current;

  // 비대화형(--force 또는 TTY 없음)이면 기본 제외
  if (force || !tty) return false;

  say("");
  say(`${icon} ${short} 워크플로우를 발견했습니다. (${files.length}개 파일)`);
  say(`   ${desc}`);
  say("");
  say("   포함되는 워크플로우:");
  for (const f of files) say(`     • ${f}`);
  say("");

  const ans = await io.confirm({ message: `${short} 워크플로우를 포함할까요?`, initialValue: false });
  const include = ans === true && !isCancel(ans);
  say(include
    ? `${short} 워크플로우를 포함합니다 — GitHub Actions에 추가됩니다`
    : `${short} 워크플로우를 제외합니다 (나중에 옵션으로 추가 가능)`);
  return include;
}

// 배포/publish 축 + Secret 백업을 순서대로 질문 (.sh ask_all_optional_workflows 등가).
// tempDir: 템플릿 다운로드 루트 — project-types는 {tempDir}/.github/workflows/project-types
// current: { deploy: string|null, publish: string[]|null, secretBackup: bool|null } — CLI 명시값
// 반환: { deploy: string, publish: string[], secretBackup: bool }
export async function askAllOptionalWorkflows({
  tempDir, types = [], current = {}, targetRoot = ".",
  force = false, tty = true, io = {}, forceAsk = false,
}) {
  const say = io.log || ((m) => process.stderr.write(`${m}\n`));
  let deploy = current.deploy ?? null;
  let publish = current.publish ?? null;
  let secretBackup = current.secretBackup ?? null;

  // basic 단독 타입은 서버 배포도 라이브러리 publish도 개념상 성립하지 않는다.
  // 배포/publish 질문을 건너뛰고 none·[]로 조용히 확정한다 (타입 변경 시 재질문됨).
  // (basic은 "그 외" 폴백이라 항상 단독으로만 존재 — every로 안전 판정)
  const isBasicOnly = types.length > 0 && types.every((t) => t === "basic");

  // ① --force-ask가 아니면 version.yml 저장값을 먼저 읽어 재질문을 건너뛴다.
  //    CLI 명시값(current)이 이미 있으면 그쪽이 우선 — 저장값은 빈 자리만 채운다.
  if (!forceAsk) {
    const vy = join(targetRoot, PATHS.versionFile);
    if (existsSync(vy)) {
      const saved = parseTemplateOptions(readFileSync(vy, "utf8"));
      if (deploy === null && saved.deploy !== null) {
        deploy = saved.deploy;
        say(`배포 방식: version.yml 저장값(${deploy}) 유지 — 재질문 생략`);
      }
      if (publish === null && saved.publish !== null) {
        publish = saved.publish;
        say(`Publish 타겟: version.yml 저장값(${publish.join(",") || "없음"}) 유지 — 재질문 생략`);
      }
      if (secretBackup === null && saved.secretBackup !== null) {
        secretBackup = saved.secretBackup;
        say(`Secret 백업 옵션: version.yml 저장값(${secretBackup}) 유지 — 재질문 생략`);
      }
    }
  }

  // ── ② 배포 방식 (택1) — basic 단독이면 질문 스킵, none으로 확정 ──
  if (isBasicOnly) {
    if (deploy === null) deploy = "none";
    if (publish === null) publish = [];
  } else {
    if (forceAsk || deploy === null) {
      if (force || !tty || typeof io.select !== "function") {
        deploy = deploy ?? "docker-ssh";
      } else {
        say("");
        say("🚀 이 프로젝트를 어디에 배포하나요?");
        say("   서버·호스팅에 올릴 계획이 있으면 고르고, 지금 없으면 '배포 안 함'으로 두면 됩니다.");
        const ans = await io.select({
          message: "배포 방식을 선택하세요",
          options: [
            { value: "docker-ssh", label: "Docker + SSH 서버 배포 (기본)" },
            { value: "vercel", label: "Vercel" },
            { value: "none", label: "배포하지 않음 (라이브러리/CI 전용)" },
          ],
        });
        deploy = (!isCancel(ans) && DEPLOY_TARGETS.includes(ans)) ? ans : (deploy ?? "docker-ssh");
        say(`배포 방식: ${deploy}`);
      }
    }

    // ── ③ publish 타겟 (다중 선택) ──
    if (forceAsk || publish === null) {
      if (force || !tty || typeof io.multiselect !== "function") {
        publish = publish ?? [];
      } else {
        say("");
        say("📦 라이브러리로 배포(publish)할 계획이 있나요?");
        say("   사내 Nexus·npmjs·GitHub Packages 중 해당되는 걸 고르세요. 없으면 그냥 Enter.");
        const ans = await io.multiselect({
          message: "publish 타겟을 선택하세요 (Space 토글, Enter 확정)",
          options: [
            { value: "nexus", label: "사내 Maven(Nexus) 라이브러리 배포" },
            { value: "npm", label: "공개 npmjs 패키지 배포 (NPM_TOKEN)" },
            { value: "github-packages", label: "GitHub Packages 라이브러리 배포" },
          ],
          initialValues: publish ?? [],
          required: false,
        });
        publish = (!isCancel(ans) && Array.isArray(ans))
          ? ans.filter((t) => PUBLISH_TARGETS.includes(t))
          : (publish ?? []);
        say(`Publish 타겟: ${publish.join(",") || "없음"}`);
      }
    }
  }

  // ── ④ Secret 백업: 공통 폴더 (배포축 아님 — 기존 폴더 질문 유지) ──
  const real = join(tempDir, PATHS.workflowsDir, PATHS.projectTypesDir);
  const ptDir = existsSync(real) ? real : join(tempDir, PATHS.projectTypesDir);
  secretBackup = await askOptionalWorkflow({
    dir: join(ptDir, "common", "secret-backup"), icon: "🔐", short: "Secret 서버 백업",
    desc: "GitHub Secret에 저장한 설정 파일을 SSH로 서버에 업로드·이력관리하는 워크플로우입니다.",
    current: secretBackup, force, tty, io, forceAsk, say,
  });

  return { deploy: deploy ?? "docker-ssh", publish: publish ?? [], secretBackup: secretBackup === true };
}
