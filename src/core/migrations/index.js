// 레거시 마이그레이션 진입점 (#470) — 신호 기반·멱등.
// 감지(registry × rules) → 계획 표시 → safe 티어 확인 1회 → 적용 → confirm 티어 안내.
// 버전 번호를 믿지 않는다: 절반의 레거시 레포는 version.yml에 template 메타가 없다(실측).
import { MIGRATIONS } from "./registry.js";
import * as workflowRule from "./rules/obsolete-workflows.js";
import * as rootFileRule from "./rules/root-files.js";

const RULES = {
  workflow: workflowRule,
  "root-file": rootFileRule,
};

// 대상 레포에서 레거시 잔재 감지. 반환: { safe: [entry], confirm: [entry] }
export function detectMigrations(targetRoot = ".") {
  const safe = [];
  const confirm = [];
  for (const entry of MIGRATIONS) {
    const rule = RULES[entry.category];
    if (!rule || !rule.detect(targetRoot, entry)) continue;
    (entry.tier === "safe" ? safe : confirm).push(entry);
  }
  return { safe, confirm };
}

// safe 티어 적용. 실패해도 나머지는 계속(부분 실패 허용 — 멱등이라 재실행으로 복구).
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
// 반환: { applied: [결과], confirmPending: [entry] }
export async function runMigrations({ targetRoot = ".", askYesNo = null, log = console.log } = {}) {
  const { safe, confirm } = detectMigrations(targetRoot);
  if (safe.length === 0 && confirm.length === 0) return { applied: [], confirmPending: [] };

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

  if (confirm.length > 0) {
    log(`⚠️ 구세대 배포 워크플로우 ${confirm.length}개 발견 — 현역 배포일 수 있어 자동으로 건드리지 않습니다:`);
    for (const e of confirm) {
      const arrow = e.replacedBy ? ` (신형: ${e.replacedBy})` : "";
      log(`   • ${e.file}${arrow} — ${e.reason}`);
    }
    log("   신형 워크플로우로 전환을 마친 뒤 구 파일을 직접 삭제하세요.");
  }

  return { applied, confirmPending: confirm };
}
