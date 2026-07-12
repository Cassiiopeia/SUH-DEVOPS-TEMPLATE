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
import { branchStatus, createBranch, pushBranch } from "./git-branch.js";

// 개발(배포) 브랜치 존재 확인 + 생성 제안 (#477) — 대화형 전용.
// 로컬에 없고 원격에도 없(거나 불명이)면 기본 브랜치에서 생성을 제안하고, 생성 후 push 여부도 묻는다.
// git 미설치·비레포·질문 불가(io.confirm 없음)면 조용히 통과 — 마법사 진행을 막지 않는다.
export async function ensureDeployBranch({ targetRoot = ".", deployBranch = "", defaultBranch = "", io = {}, say = () => {} }) {
  if (!deployBranch || typeof io.confirm !== "function") return { created: false, pushed: false };
  const st = branchStatus(targetRoot, deployBranch);
  if (!st.isRepo || st.local) return { created: false, pushed: false };
  if (st.remote === true) {
    say(`ℹ️ '${deployBranch}' 브랜치가 원격에는 있고 로컬에 없습니다 — 필요 시 'git switch ${deployBranch}'로 가져오세요.`);
    return { created: false, pushed: false };
  }
  say(`⚠️ 배포 브랜치 '${deployBranch}'가 없습니다 — 릴리스 파이프라인(${deployBranch}→${defaultBranch || "기본 브랜치"} PR)이 동작하려면 필요합니다.`);
  const mk = await io.confirm({ message: `${defaultBranch || "현재"} 브랜치에서 '${deployBranch}' 브랜치를 만들까요?`, initialValue: true });
  if (mk !== true) {
    say(`→ 건너뜁니다. 나중에 직접: git checkout -b ${deployBranch} && git push -u origin ${deployBranch}`);
    return { created: false, pushed: false };
  }
  if (!createBranch(targetRoot, deployBranch, defaultBranch)) {
    say(`⚠️ 브랜치 생성 실패 — 직접 실행해주세요: git branch ${deployBranch}${defaultBranch ? ` ${defaultBranch}` : ""}`);
    return { created: false, pushed: false };
  }
  say(`✅ 로컬 브랜치 '${deployBranch}' 생성 완료 (checkout은 하지 않았습니다)`);
  const up = await io.confirm({ message: "원격(origin)에도 push할까요?", initialValue: true });
  if (up !== true) return { created: true, pushed: false };
  if (pushBranch(targetRoot, deployBranch)) {
    say(`✅ origin/${deployBranch} push 완료`);
    return { created: true, pushed: true };
  }
  say(`⚠️ push 실패(자격/네트워크) — 직접 실행해주세요: git push -u origin ${deployBranch}`);
  return { created: true, pushed: false };
}

// 재노출 — 파서 본체는 version-yml.js에 있다 (순환 import 방지: options-ask → version-yml 방향만 허용)
export { parseTemplateOptions };

export const DEPLOY_TARGETS = ["docker-ssh", "vercel", "none"];
export const PUBLISH_TARGETS = ["nexus", "npm", "github-packages"];
// #455 — changelog 생성기 provider. github-ai가 기본(설정 제로). openai/gemini/claude/ollama는 openai 호환 한 갈래.
export const CHANGELOG_PROVIDERS = ["github-ai", "coderabbit", "openai", "gemini", "claude", "ollama", "commit"];

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

// 옵션 질문의 축 키 (#483 수정 스코프 단위) — 수정 메뉴가 이 단위로 한 축만 재질문한다.
export const OPTION_AXES = ["deploy", "publish", "code-review", "changelog", "release-branch", "secret"];

// 배포/publish 축 + Secret 백업을 순서대로 질문 (.sh ask_all_optional_workflows 등가).
// tempDir: 템플릿 다운로드 루트 — project-types는 {tempDir}/.github/workflows/project-types
// current: { deploy: string|null, publish: string[]|null, secretBackup: bool|null } — CLI 명시값
// scope: null이면 전 축(초기 통합·전체 재질문). Set/배열이면 그 축만 forceAsk 대상 (#483 수정 메뉴 격리).
//        스코프 밖 축은 forceAsk여도 current/저장값을 그대로 유지하고 다시 묻지 않는다.
// 반환: { deploy, publish, secretBackup, codeReviewCoderabbit, changelogProvider, changelogBaseUrl, deployBranch }
export async function askAllOptionalWorkflows({
  tempDir, types = [], current = {}, targetRoot = ".",
  force = false, tty = true, io = {}, forceAsk = false, defaultBranch = "", scope = null,
}) {
  const say = io.log || ((m) => process.stderr.write(`${m}\n`));
  // 축별 재질문 여부: 전역 forceAsk이고, scope가 없거나 그 축을 포함할 때만 강제 질문.
  const scopeSet = scope == null ? null : new Set(scope);
  const ask = (axis) => forceAsk && (scopeSet === null || scopeSet.has(axis));
  let deploy = current.deploy ?? null;
  let publish = current.publish ?? null;
  let secretBackup = current.secretBackup ?? null;
  let codeReviewCoderabbit = current.codeReviewCoderabbit ?? null;
  let changelogProvider = current.changelogProvider ?? null;
  let changelogBaseUrl = current.changelogBaseUrl ?? null;
  let deployBranch = current.deployBranch ?? null; // #456 릴리스 PR head 브랜치

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
      // #455 changelog/code_review 저장값 재사용
      if (codeReviewCoderabbit === null && saved.codeReviewCoderabbit !== null) codeReviewCoderabbit = saved.codeReviewCoderabbit;
      if (changelogProvider === null && saved.changelogProvider !== null) changelogProvider = saved.changelogProvider;
      if (changelogBaseUrl === null && saved.changelogBaseUrl !== null) changelogBaseUrl = saved.changelogBaseUrl;
      // #456 deploy_branch 저장값 재사용
      if (deployBranch === null && saved.deployBranch != null) deployBranch = saved.deployBranch;
    }
  }

  // ── ② 배포 방식 (택1) — basic 단독이면 질문 스킵, none으로 확정 ──
  if (isBasicOnly) {
    if (deploy === null) deploy = "none";
    if (publish === null) publish = [];
  } else {
    if (ask("deploy") || deploy === null) {
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
    if (ask("publish") || publish === null) {
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

  // ── code_review: CodeRabbit AI 코드 리뷰 (changelog와 무관 — #455) ──
  if (ask("code-review") || codeReviewCoderabbit === null) {
    if (force || !tty || typeof io.confirm !== "function") {
      codeReviewCoderabbit = codeReviewCoderabbit ?? false;
    } else {
      say("");
      say("🤖 CodeRabbit AI 코드 리뷰를 쓸까요? (PR 올릴 때 코드 리뷰 댓글을 답니다)");
      const ans = await io.confirm({ message: "CodeRabbit AI 코드 리뷰 사용", initialValue: false });
      codeReviewCoderabbit = (ans === true && !isCancel(ans));
      say(`CodeRabbit 코드 리뷰: ${codeReviewCoderabbit ? "사용" : "미사용"}`);
    }
  }

  // ── changelog: 릴리스 노트 생성기 (기본 커서 = github-ai — #455) ──
  if (ask("changelog") || changelogProvider === null) {
    if (force || !tty || typeof io.select !== "function") {
      changelogProvider = changelogProvider ?? "github-ai";
    } else {
      say("");
      say("📝 릴리스 노트(changelog)는 뭘로 만들까요?");
      say("   GitHub AI는 설정 없이 바로 됩니다. 나머지는 나중에 GitHub Secret 등록이 필요할 수 있어요.");
      const ans = await io.select({
        message: "changelog 생성기를 선택하세요",
        options: [
          { value: "github-ai", label: "GitHub AI (추천 · 설정 불필요)" },
          { value: "coderabbit", label: "CodeRabbit" },
          { value: "openai", label: "OpenAI 호환 API (키 등록 필요)" },
          { value: "commit", label: "커밋 분석만 (AI 없음)" },
        ],
      });
      changelogProvider = (!isCancel(ans) && CHANGELOG_PROVIDERS.includes(ans)) ? ans : (changelogProvider ?? "github-ai");
      say(`changelog 생성기: ${changelogProvider}`);
    }
  }

  // ollama 선택 시에만 base_url 질문 (나머지 provider는 preset base_url 자동 — #455)
  if (changelogProvider === "ollama" && (ask("changelog") || changelogBaseUrl === null || changelogBaseUrl === "")) {
    if (force || !tty || typeof io.text !== "function") {
      changelogBaseUrl = changelogBaseUrl ?? "";
    } else {
      const ans = await io.text({ message: "Ollama 서버 base_url (예: https://ai.suhsaechan.kr/v1)" });
      changelogBaseUrl = (typeof ans === "string" && !isCancel(ans)) ? ans.trim() : "";
      say(`Ollama base_url: ${changelogBaseUrl || "(미지정)"}`);
    }
  } else if (changelogBaseUrl === null) {
    changelogBaseUrl = "";
  }

  // ── deploy_branch: 릴리스 PR의 head 브랜치 (#456 — default_branch와 별개) ──
  //    대부분 develop→main 릴리스 구조라 기본값 develop. 다른 head를 쓰는 레포를 위해 물어본다.
  if (ask("release-branch") || deployBranch === null) {
    if (force || !tty || typeof io.text !== "function") {
      deployBranch = deployBranch ?? "develop";
    } else {
      say("");
      say("🌿 릴리스 배포 브랜치(릴리스 PR의 head)는 무엇인가요?");
      say("   develop→main 릴리스 구조면 develop 그대로 두세요. 배포 브랜치가 따로면 그 이름을 적어주세요.");
      const ans = await io.text({ message: "배포 브랜치", initialValue: deployBranch ?? "develop" });
      deployBranch = (typeof ans === "string" && !isCancel(ans) && ans.trim()) ? ans.trim() : (deployBranch ?? "develop");
      say(`배포 브랜치: ${deployBranch}`);
      // 브랜치 존재 확인 + 생성 제안 (#477) — 없으면 릴리스 파이프라인이 조용히 놀게 된다
      await ensureDeployBranch({ targetRoot, deployBranch, defaultBranch, io, say });
    }
  }

  // ── ④ Secret 백업: 공통 폴더 (배포축 아님 — 기존 폴더 질문 유지) ──
  const real = join(tempDir, PATHS.workflowsDir, PATHS.projectTypesDir);
  const ptDir = existsSync(real) ? real : join(tempDir, PATHS.projectTypesDir);
  secretBackup = await askOptionalWorkflow({
    dir: join(ptDir, "common", "secret-backup"), icon: "🔐", short: "Secret 서버 백업",
    desc: "GitHub Secret에 저장한 설정 파일을 SSH로 서버에 업로드·이력관리하는 워크플로우입니다.",
    current: secretBackup, force, tty, io, forceAsk: ask("secret"), say,
  });

  return {
    deploy: deploy ?? "docker-ssh", publish: publish ?? [], secretBackup: secretBackup === true,
    codeReviewCoderabbit: codeReviewCoderabbit === true,
    changelogProvider: changelogProvider ?? "github-ai",
    changelogBaseUrl: changelogBaseUrl ?? "",
    deployBranch: deployBranch ?? "develop",
  };
}
