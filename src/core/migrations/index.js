// 레거시 마이그레이션 진입점 (#470) — 신호 기반·멱등.
// 감지(registry × rules) → 계획 표시 → safe 티어 확인 1회 → 적용 → confirm 티어 안내.
// 버전 번호를 믿지 않는다: 절반의 레거시 레포는 version.yml에 template 메타가 없다(실측).
import { MIGRATIONS } from "./registry.js";
import * as workflowRule from "./rules/obsolete-workflows.js";
import * as rootFileRule from "./rules/root-files.js";
import * as legacyDirRule from "./rules/legacy-dirs.js";

const RULES = {
  workflow: workflowRule,
  "root-file": rootFileRule,
  "legacy-dir": legacyDirRule,
  "util-file": rootFileRule, // #500 — util 모듈 내 폐기 파일: 정확 경로 삭제 (root-file rule 재사용)
};

// 대상 레포에서 레거시 잔재 감지. 반환: { safe: [entry], confirm: [entry], ask: [entry] }
export function detectMigrations(targetRoot = ".") {
  const safe = [];
  const confirm = [];
  const ask = [];
  for (const entry of MIGRATIONS) {
    const rule = RULES[entry.category];
    if (!rule || !rule.detect(targetRoot, entry)) continue;
    if (entry.tier === "safe") safe.push(entry);
    else if (entry.tier === "ask") ask.push(entry);
    else confirm.push(entry);
  }
  return { safe, confirm, ask };
}

// 항목 일괄 적용 실행기 (safe·ask 티어 공용). 실패해도 나머지는 계속(부분 실패 허용 — 멱등이라 재실행으로 복구).
export function applySafeMigrations(targetRoot, entries) {
  const results = [];
  for (const entry of entries) {
    try {
      results.push({ id: entry.id, ...RULES[entry.category].apply(targetRoot, entry) });
    } catch (e) {
      results.push({ id: entry.id, action: "error", from: entry.file, error: e.message });
    }
  }
  return results;
}

// 마법사 배선 진입점.
//   askYesNo - async(msg, defaultYes)→bool. null이면 비대화형(--force): safe 자동 적용
//   log      - 한 줄 출력 함수 (기본 console.log)
// 반환: { applied: [결과], confirmPending: [entry], askPending: [entry] }
export async function runMigrations({ targetRoot = ".", askYesNo = null, log = console.log } = {}) {
  const { safe, confirm, ask } = detectMigrations(targetRoot);
  if (safe.length === 0 && confirm.length === 0 && ask.length === 0) {
    return { applied: [], confirmPending: [], askPending: [] };
  }

  let applied = [];
  if (safe.length > 0) {
    log(`🧹 레거시 템플릿 파일 ${safe.length}개 감지 — 신형으로 대체되어 공존 시 중복 실행 위험:`);
    for (const e of safe) {
      const arrow = e.replacedBy ? ` → ${e.replacedBy}` : "";
      log(`   • ${e.file}${arrow}`);
      log(`     (${e.reason}, ${e.since}부터 폐기)`);
    }
    const yes = askYesNo
      ? await askYesNo(`위 ${safe.length}개를 정리할까요? (워크플로우는 .bak 무해화 — 복원 가능)`, true)
      : true;
    if (yes) {
      applied = applySafeMigrations(targetRoot, safe);
      const ok = applied.filter((r) => r.action !== "error");
      const failed = applied.filter((r) => r.action === "error");
      log(`✅ 레거시 정리 완료: ${ok.length}개${failed.length ? ` (실패 ${failed.length}개)` : ""}`);
      for (const f of failed) log(`   ⚠️ ${f.from}: ${f.error}`);
    } else {
      log("→ 레거시 정리를 건너뜁니다 (다음 업데이트 때 다시 안내)");
    }
  }

  // ask 티어 (#476) — 사용자 문서가 담긴 구명칭 폴더: 대화형은 확인 후 이동, 비대화형은 안내만
  let askPending = [];
  if (ask.length > 0) {
    log(`📁 구명칭 산출물 폴더 ${ask.length}개 감지 — 사용자 문서가 들어 있어 확인 후 이동합니다:`);
    for (const e of ask) {
      log(`   • ${e.file}/ → ${e.replacedBy}/`);
      log(`     (${e.reason})`);
    }
    if (askYesNo) {
      const yes = await askYesNo("위 폴더를 새 이름으로 이동할까요? (파일 손실 없음 — 충돌 시 원본 유지)", true);
      if (yes === true) {
        const results = applySafeMigrations(targetRoot, ask);
        applied = applied.concat(results);
        for (const r of results) {
          if (r.action === "error") log(`   ⚠️ ${r.from}: ${r.error}`);
          else log(`   ✅ ${r.from}/ → ${r.to}/ (이동 ${r.moved ?? 0}개${r.skipped ? `, 충돌 유지 ${r.skipped}개` : ""})`);
        }
      } else {
        askPending = ask;
        log("→ 폴더 이동을 건너뜁니다 (다음 업데이트 때 다시 안내)");
      }
    } else {
      askPending = ask;
      log("   비대화형 실행이라 자동으로 이동하지 않습니다 — 대화형 마법사(npx projectops)에서 확인 후 이동하세요.");
    }
  }

  if (confirm.length > 0) {
    log(`⚠️ 구세대 배포 워크플로우 ${confirm.length}개 발견 — 현역 배포일 수 있어 자동으로 건드리지 않습니다:`);
    for (const e of confirm) {
      const arrow = e.replacedBy ? ` (신형: ${e.replacedBy})` : "";
      log(`   • ${e.file}${arrow} — ${e.reason}`);
    }
    log("   신형 워크플로우로 전환을 마친 뒤 구 파일을 직접 삭제하세요.");
  }

  return { applied, confirmPending: confirm, askPending };
}
