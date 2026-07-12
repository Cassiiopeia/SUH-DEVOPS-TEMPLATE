// breaking-changes 확인 흐름 배선 (.sh check_breaking_changes L2506~2616 등가).
// collectBreaking(순수 비교)은 breaking.js — 이 모듈은 로드(원격→clone본 폴백)·표시·확인 게이트.
import { readFileSync, existsSync } from "node:fs";
import { join } from "node:path";
import { collectBreaking } from "./breaking.js";
import { parseExisting } from "./version-yml.js";

const BC_URL = "https://raw.githubusercontent.com/Cassiiopeia/projectops/main/.github/config/breaking-changes.json";

// 원격 우선(3초 타임아웃) → clone된 템플릿의 번들본 폴백 → 둘 다 실패 시 null(조용히 스킵 — .sh 등가)
export async function loadBreakingJson(tempDir) {
  try {
    const res = await fetch(BC_URL, { signal: AbortSignal.timeout(3000) });
    if (res.ok) return await res.json();
  } catch { /* 원격 실패 — 폴백 */ }
  try {
    const p = join(tempDir, ".github", "config", "breaking-changes.json");
    if (existsSync(p)) return JSON.parse(readFileSync(p, "utf8"));
  } catch { /* 폴백 실패 — 스킵 */ }
  return null;
}

// 반환: true=진행, false=사용자 취소.
// opts:
//   cwd             - 통합 대상 루트 (기존 version.yml에서 현재 템플릿 버전 읽음)
//   tempDir         - clone된 템플릿 (번들 폴백용)
//   templateVersion - 설치하려는 템플릿 버전 (.sh의 DEFAULT_VERSION 고정 버그를 실버전으로 교정 — 설계 D2)
//   askYesNo        - async(message, defaultYes)→bool. null이면 비대화형: 경고만 출력 후 진행
//   loader          - 테스트 주입용 (기본 loadBreakingJson)
export async function runBreakingCheck({ cwd, tempDir, templateVersion, askYesNo = null, loader = loadBreakingJson }) {
  const vy = join(cwd, "version.yml");
  if (!existsSync(vy)) return true; // 신규 통합 — 비교 기준 없음
  const { templateVersion: current } = parseExisting(readFileSync(vy, "utf8"));
  if (!current) return true; // 템플릿 메타 없음(unknown) — .sh 동일하게 스킵

  const json = await loader(tempDir);
  if (!json) return true;

  const { critical, warnings } = collectBreaking(json, current, templateVersion);
  if (critical.length === 0 && warnings.length === 0) return true;

  // 요약 리스트 표시 (#473 — 전문 통덤프는 벽글이 되어 정작 CRITICAL이 안 읽혔고,
  // 긴 본문 래핑이 ║ 박스 경계를 붕괴시켰다. 버전·제목만 한 줄씩, 전문은 선택 열람.)
  const e = (s = "") => process.stderr.write(s + "\n");
  e("");
  e(`⚠️  BREAKING CHANGES (v${current} → v${templateVersion}) — CRITICAL ${critical.length}건 · WARNING ${warnings.length}건`);
  e("");
  for (const c of critical) e(`  ❗ [CRITICAL] ${c.version} — ${c.title || ""}`);
  for (const w of warnings) e(`  ⚠️ [WARNING]  ${w.version} — ${w.title || ""}`);
  e("");

  if (askYesNo) {
    // 대화형: 전문(조치 방법)은 원할 때만 펼친다
    const detail = await askYesNo("각 항목의 상세 내용(조치 방법)을 볼까요?", false);
    if (detail === true) {
      for (const it of [...critical, ...warnings]) {
        e("");
        e(`■ ${it.version} — ${it.title || ""}`);
        e(`  ${it.message || ""}`);
      }
      e("");
    }
  } else {
    e("  상세 내용·조치 방법: .github/config/breaking-changes.json 참고");
    e(`  (${BC_URL})`);
    e("");
  }

  if (critical.length > 0) {
    if (askYesNo) {
      // 대화형: 명시 확인 없으면 중단 (기본 N — .sh 등가)
      const ok = await askYesNo("위 호환성 변경을 확인했고 계속 진행할까요?", false);
      if (ok !== true) return false;
    } else {
      // 비대화형(--force): 게이트로 CI를 죽이지 않고 경고 후 진행 (.sh와 의도적 차이 — CI 친화)
      e("⚠️  CRITICAL 호환성 변경이 있습니다 — 비대화형 실행이라 계속 진행합니다. 위 내용을 꼭 확인하세요.");
    }
  }
  return true;
}
