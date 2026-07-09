// 첫 화면 상태 표시 층 (#446 층2~5) — 감지 로그 · 분석 카드 · IDE 상태 · 신규/업데이트 판별
// (층5의 Breaking Changes 박스는 core/breaking-check.js가 담당)
import { A, paint, padEndVisual } from "./ansi.js";
import { ADAPTERS } from "../core/ide/registry.js";
import { markerForType } from "../core/detect.js";

const GUT = paint("│", A.gray);
const HEAD = paint("◆", A.cyan);
const OK = paint("✓", A.green);

// 층2 — 감지 로그 (.ps1 감지 진행 표시 등가)
export function printDetectionLog({ types = [], version = "", branch = "" }, out = (s) => process.stdout.write(s)) {
  out(`${paint("┌", A.gray)}  🔍 프로젝트를 살펴보는 중...\n`);
  if (types.length && !(types.length === 1 && types[0] === "basic")) {
    for (const t of types) {
      const marker = markerForType(t);
      out(`${GUT}  ${OK} ${marker ? `${marker} 발견 → ` : ""}${paint(t, A.bold)} 감지\n`);
    }
  } else {
    out(`${GUT}  ${paint("─", A.dim)} 마커 파일 없음 → ${paint("basic", A.bold)} (직접 선택 가능)\n`);
  }
  out(`${GUT}  ${OK} 버전: ${paint(`v${version}`, A.green)} · 브랜치: ${paint(branch, A.green)}\n`);
  out(`${GUT}\n`);
}

// 층3 — 프로젝트 분석 개요 카드 (.ps1 Print-ProjectAnalysis 등가+)
export function printAnalysisCard({ mode = "", modeLabel = "", types = [], version = "", branch = "",
  deployTarget = null, publishTargets = null, includeSecretBackup = null, paths = new Map(), showOptional = false },
  out = (s) => process.stdout.write(s)) {
  out(`${HEAD}  ${paint("프로젝트 분석 결과", A.bold)}\n`);
  // 라벨을 시각 폭(CJK 2칸) 기준으로 패딩 — 한글·영문 혼합 라벨(타입·Publish·Secret백업) 열 정렬.
  // 가장 긴 라벨 "Secret백업"(=8칸) 기준 여유 두고 12.
  const row = (icon, label, value) => out(`${GUT}  ${icon} ${padEndVisual(label, 12)} ${value}\n`);
  row("📂", types.length > 1 ? "타입(멀티)" : "타입", paint(types.join(", ") || "basic", A.bold));
  row("🌙", "버전", paint(`v${version}`, A.green));
  row("🌿", "브랜치", branch);
  if (modeLabel || mode) row("💫", "통합 모드", modeLabel || mode);
  if (showOptional) {
    row("🚀", "배포", paint(deployTarget || "docker-ssh", A.bold));
    const pub = (publishTargets ?? []).join(",");
    row("📦", "Publish", pub ? paint(pub, A.green) : paint("없음", A.dim));
    row("🔐", "Secret백업", includeSecretBackup === true ? paint("포함", A.green) : paint("제외", A.dim));
  }
  // 모노레포 경로 — 루트가 아닌 항목이 하나라도 있으면 표시
  const nonRoot = [...paths.entries()].filter(([, p]) => p && p !== ".");
  if (nonRoot.length) {
    row("📁", "경로", [...paths.entries()].map(([t, p]) => `${t}→${p}`).join(", "));
  }
  out(`${GUT}\n`);
}

// 층4 — IDE Skills 현재 상태 수집 (어댑터 detect 순회 — 예외 없음 계약)
export function collectIdeStatuses(io) {
  return ADAPTERS.map((a) => {
    let st;
    try { st = a.detect(io); } catch { st = { installed: false, version: null, cliMissing: true, note: "감지 실패" }; }
    return { id: a.id, label: a.label, ...st };
  });
}

// 층4 — IDE Skills 현재 상태 표시
export function printIdeStatus(statuses, out = (s) => process.stdout.write(s)) {
  if (!statuses?.length) return;
  out(`${HEAD}  ${paint("AI 에이전트 스킬 상태", A.bold)}\n`);
  for (const s of statuses) {
    let mark, detail;
    if (s.installed) {
      mark = OK;
      detail = paint(`설치됨${s.version ? ` v${s.version}` : ""}${s.scope ? ` (${s.scope})` : ""}`, A.green);
    } else if (s.cliMissing) {
      mark = paint("⚠", A.yellow);
      detail = paint(s.note || "CLI 없음", A.yellow);
    } else {
      mark = paint("─", A.dim);
      detail = paint("미설치", A.dim);
    }
    out(`${GUT}  ${mark} ${s.label.padEnd(14)} ${detail}${s.note && !s.cliMissing ? paint(`  ${s.note}`, A.dim) : ""}\n`);
  }
  out(`${GUT}\n`);
}

// 층5 — 신규 통합 vs 업데이트 판별 라인 (Breaking 박스는 breaking-check.js)
// WHY 판정: version.yml의 metadata.template.version(이전 통합 흔적)이 있으면 업데이트, 없으면 신규.
// 사용자가 "무슨 기준으로 신규/업데이트인지"를 바로 알도록 판정 근거를 화면에 밝힌다.
export function printInstallKind({ currentTemplateVersion = "", templateVersion = "" }, out = (s) => process.stdout.write(s)) {
  if (currentTemplateVersion) {
    out(`${GUT}  ♻️  ${paint("업데이트", A.bold)} — 템플릿 ${paint(`v${currentTemplateVersion}`, A.dim)} → ${paint(`v${templateVersion}`, A.green)}\n`);
    out(`${GUT}     ${paint("version.yml에 이전 통합 기록이 있어 업데이트로 진행합니다", A.dim)}\n`);
  } else {
    out(`${GUT}  🆕 ${paint("신규 통합", A.bold)} — 이 프로젝트에 처음 설치합니다 (템플릿 ${paint(`v${templateVersion}`, A.green)})\n`);
    out(`${GUT}     ${paint("version.yml에 이전 통합 기록이 없어 신규로 봅니다", A.dim)}\n`);
  }
  out(`${GUT}\n`);
}
