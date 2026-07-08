// 워크플로우 복사 엔진 (.sh copy_workflows + _copy_workflows_for_type 등가).
// 실측: template_integrator.sh 3398~3815. SP2-B는 --force 경로만 구현.
// (대화형 3지선 메뉴·env 계획 질문은 SP2-C. force/비TTY의 기본 선택은 "건너뛰기"이므로 등가.)
import { join, basename } from "node:path";
import { existsSync, readFileSync, writeFileSync, renameSync } from "node:fs";
import { PATHS } from "../paths.js";
import { exists, copyFileSync, listYamlFiles } from "../fsutil.js";
import { isUnchanged, substituteEnv } from "../wizard-env.js";

// 한 파일에 env 치환(기본값)을 적용해 대상 파일을 갱신 (.sh configure_workflow_env 등가).
function configureEnv(targetPath, { type, projectPath = ".", repoName = "", resolvers = {}, collectAsks = null }) {
  const content = readFileSync(targetPath, "utf8");
  if (!content.includes("@wizard")) return;
  const out = substituteEnv(content, { type, useDefaults: true, projectPath, repoName, resolvers, collectAsks });
  writeFileSync(targetPath, out);
}

// 3분류 (신규/unchanged/changed) — 대상 워크플로우 디렉토리 기준.
function classify(srcDir, workflowsDir, envOpts) {
  const result = { newFiles: [], unchanged: [], changed: [] };
  for (const filename of listYamlFiles(srcDir)) {
    const src = join(srcDir, filename);
    const dst = join(workflowsDir, filename);
    if (existsSync(dst)) {
      const tpl = readFileSync(src, "utf8");
      const inst = readFileSync(dst, "utf8");
      if (isUnchanged(tpl, inst, envOpts)) result.unchanged.push(filename);
      else result.changed.push(filename);
    } else {
      result.newFiles.push(filename);
    }
  }
  return result;
}

// copy_workflows 본체.
// context: { types:[], paths:Map, includeNexus, includeSecretBackup, force, repoName, resolvers }
// tempDir: 다운로드 원본. targetRoot: 통합 대상 루트.
// 반환: {copied, skipped, templateAdded, optionalCopied}
export function copyWorkflows(context, tempDir, targetRoot = ".") {
  const { types = [], paths = new Map(), includeNexus = false, includeSecretBackup = false, repoName = "", resolvers = {} } = context;
  const workflowsDir = join(targetRoot, PATHS.workflowsDir);
  const projectTypesDir = join(tempDir, PATHS.workflowsDir, PATHS.projectTypesDir);
  if (!exists(projectTypesDir)) throw new Error("템플릿 저장소 구조 오류 — project-types 폴더를 찾지 못했습니다.");

  const counters = { copied: 0, skipped: 0, templateAdded: 0, optionalCopied: 0 };
  const deployValues = new Map(); // Map<type, Map<key,value>> — deploy 블록용 ask 값
  counters.deployValues = deployValues;
  const envOptsFor = (type) => ({ type, projectPath: paths.get(type) || ".", repoName, resolvers });

  // (1) common — unchanged면 스킵, 아니면 무조건 덮어쓰기
  const commonDir = join(projectTypesDir, "common");
  if (exists(commonDir)) {
    for (const filename of listYamlFiles(commonDir)) {
      const src = join(commonDir, filename);
      const dst = join(workflowsDir, filename);
      if (existsSync(dst) && isUnchanged(readFileSync(src, "utf8"), readFileSync(dst, "utf8"), envOptsFor("common"))) {
        counters.skipped++;
        continue;
      }
      copyFileSync(src, dst);
      counters.copied++;
    }
  }

  // (2~4) 타입별
  for (const type of types) {
    const asks = new Map();
    copyWorkflowsForType(type, projectTypesDir, workflowsDir, { includeNexus, ...context, envOptsFor, collectAsks: asks }, counters);
    if (asks.size) deployValues.set(type, asks);
  }

  // (5) common/secret-backup — 있으면 무조건 스킵/신규만 복사
  const secretDir = join(commonDir, "secret-backup");
  if (exists(secretDir) && includeSecretBackup) {
    for (const filename of listYamlFiles(secretDir)) {
      const dst = join(workflowsDir, filename);
      if (existsSync(dst)) continue; // 이미 존재하면 스킵
      copyFileSync(join(secretDir, filename), dst);
      counters.optionalCopied++;
      counters.copied++;
    }
  }

  return counters;
}

function copyWorkflowsForType(type, projectTypesDir, workflowsDir, ctx, counters) {
  const { includeNexus, force = false, paths = new Map(), repoName = "", resolvers = {}, envOptsFor, collectAsks = null } = ctx;
  const typeDir = join(projectTypesDir, type);
  const envOpts = envOptsFor(type);
  let unchangedNames = [];

  // 타입별 워크플로우 (직하위)
  if (exists(typeDir)) {
    const { newFiles, unchanged, changed } = classify(typeDir, workflowsDir, envOpts);
    unchangedNames = unchanged.slice();
    for (const f of unchanged) counters.skipped++;
    for (const f of newFiles) { copyFileSync(join(typeDir, f), join(workflowsDir, f)); counters.copied++; }
    // changed: force/비TTY 기본은 "건너뛰기"(기존 유지)
    if (!force) { /* 대화형 메뉴는 SP2-C */ }
    for (const f of changed) counters.skipped++; // force 경로 = skip
  }

  // server-deploy
  const serverDeployDir = join(typeDir, "server-deploy");
  if (exists(serverDeployDir)) {
    if (includeNexus) {
      // Nexus 프로젝트 → 폴더째 제외 (복사 안 함)
    } else {
      const { newFiles, unchanged, changed } = classify(serverDeployDir, workflowsDir, envOpts);
      for (const f of unchanged) counters.skipped++;
      for (const f of newFiles) { copyFileSync(join(serverDeployDir, f), join(workflowsDir, f)); counters.copied++; }
      for (const f of changed) counters.skipped++; // force = skip
    }
  }

  // nexus (opt-in)
  const nexusDir = join(typeDir, "nexus");
  if (exists(nexusDir) && includeNexus) {
    for (const filename of listYamlFiles(nexusDir)) {
      const src = join(nexusDir, filename);
      const dst = join(workflowsDir, filename);
      if (existsSync(dst) && isUnchanged(readFileSync(src, "utf8"), readFileSync(dst, "utf8"), envOpts)) {
        counters.skipped++;
        continue;
      }
      if (existsSync(dst)) renameSync(dst, dst + ".bak");
      copyFileSync(src, dst);
      counters.optionalCopied++;
      counters.copied++;
    }
  }

  // env 치환 — 이 타입의 원본 디렉토리들에서 복사돼 존재하고 unchanged 아닌 파일만
  for (const srcDir of [typeDir, serverDeployDir, nexusDir]) {
    if (!exists(srcDir)) continue;
    for (const filename of listYamlFiles(srcDir)) {
      const target = join(workflowsDir, filename);
      if (!existsSync(target)) continue;            // 건너뛴 파일 제외
      if (unchangedNames.includes(filename)) continue; // unchanged 제외
      configureEnv(target, { type, projectPath: paths.get(type) || ".", repoName, resolvers, collectAsks });
    }
  }
}
