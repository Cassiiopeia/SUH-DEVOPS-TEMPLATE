// 대화형 프롬프트 래핑 (.sh interactive_menu/choose_menu/ask_* 등가).
// node:readline 기반 자체 엔진 사용 (@clack/prompts 는 Windows TTY에서 Enter가 멈추는 버그로 제거).
// 취소(ESC/Ctrl+C)는 각 함수가 CANCEL 심볼을 반환 → 호출부가 정상 종료(exit 0) 처리.
import * as engine from "./readline-engine.js";

export const CANCEL = engine.CANCEL;

// 모드 선택 — 한국어 라벨, 내부 키 반환. 취소 시 CANCEL.
// update(#502): { from, to } — 기존 통합 레포로 판별된 경우. 맨 위에 업데이트 항목을 추가하고
// 기본 선택으로 둔다 (첫 항목 = 기본). 신규 레포(update 미전달)는 현행 5개 그대로.
export async function selectMode({ update = null } = {}) {
  const options = [];
  if (update) {
    const range = update.from ? `v${update.from} → v${update.to}` : `v${update.to}`;
    options.push({ value: "update", label: `업데이트 (v${range})` });
  }
  options.push(
    { value: "full", label: "전체 설치 (버전관리 + 워크플로우 + 템플릿)" },
    { value: "version", label: "버전 관리 전용 (자동화 시스템)" },
    { value: "workflows", label: "워크플로우 전용 (GitHub Actions 빌드, 배포)" },
    { value: "issues", label: "이슈/PR 템플릿 전용" },
    { value: "skills", label: "AI 스킬 전용 (Claude, Cursor, Gemini, Codex, PI)" },
  );
  return engine.select({ message: "무엇을 설치할까요?", options });
}

// 프로젝트 확인 화면 메뉴 (계속/수정/취소).
export async function confirmProjectMenu() {
  return engine.select({
    message: "이 정보로 진행할까요?",
    options: [
      { value: "continue", label: "예, 계속 진행" },
      { value: "edit", label: "수정하기" },
      { value: "cancel", label: "아니오, 취소" },
    ],
  });
}

// 수정 메뉴 — 어떤 항목을 고칠지. showOptional=full/workflows에서만 nexus/secret 노출.
// axes(#498): applicableTargets(types) 결과 — 적용 불가 축의 항목은 숨긴다 (모바일 앱/basic 단독 등).
// null이면 기존처럼 전부 노출 (테스트 스텁 하위호환).
export async function editMenu({ showOptional = false, axes = null } = {}) {
  const options = [
    { value: "type", label: "프로젝트 타입" },
    { value: "version", label: "버전" },
    { value: "branch", label: "기본 브랜치" },
  ];
  if (showOptional) {
    const hasDeploy = axes == null || axes.deploy.length > 0;
    const hasPublish = axes == null || axes.publish.length > 0;
    // #485 — 프로젝트 성격(intent): 재선택 시 배포/publish 축을 재유도한다. 축이 하나도 없으면 무의미 → 숨김.
    if (hasDeploy || hasPublish) options.push({ value: "intent", label: "프로젝트 성격 (배포 유형)" });
    // #483 — 항목별 격리: 한 축만 골라 그 축만 재질문한다 (통짜 "배포/Publish 방식" 분해)
    if (hasDeploy) options.push({ value: "deploy", label: "배포 방식 (서버 실행물)" });
    if (hasPublish) options.push({ value: "publish", label: "라이브러리 배포(publish) 타겟" });
    options.push({ value: "code-review", label: "CodeRabbit 코드 리뷰" });
    options.push({ value: "changelog", label: "릴리스 노트(changelog) 생성기" });
    options.push({ value: "release-branch", label: "릴리스 소스(개발) 브랜치" });
    options.push({ value: "secret", label: "Secret 백업 포함 여부" });
  }
  options.push({ value: "done", label: "모두 맞음, 계속" });
  return engine.select({ message: "어떤 항목을 수정할까요?", options });
}

// 타입 멀티선택.
export async function selectTypes(current = []) {
  const all = ["spring", "flutter", "react", "react-native", "react-native-expo", "node", "python", "basic"];
  return engine.multiselect({
    message: "프로젝트 타입을 선택하세요 (Space 토글, Enter 확정)",
    options: all.map((t) => ({ value: t, label: t })),
    initialValues: current.length ? current : ["basic"],
    required: true,
  });
}

// 텍스트 입력 (빈 입력=기본값 유지).
export async function askText(message, defaultValue = "") {
  const v = await engine.text({ message, defaultValue });
  if (v === CANCEL) return CANCEL;
  return v === "" || v == null ? defaultValue : v;
}

// 예/아니오.
export async function askYesNo(message, initial = true) {
  return engine.confirm({ message, initialValue: initial });
}

// 배너·안내 출력.
export function intro(text) { engine.intro(text); }
export function outro(text) { engine.outro(text); }
export function note(text, title) { engine.note(text, title); }
export function cancelMessage(text = "취소했습니다.") { engine.cancelMessage(text); }

// ── #446 첫 화면 UI 5층 + SP2-C 대화형 계층 실물 io ─────────────────
// runInteractive는 io.<method>?.() 옵셔널 호출 — 테스트 스텁은 이 메서드들을 생략해
// 시각 층·env 질문을 건너뛴다 (실행 계약은 그대로).
import { printBanner as _printBanner } from "./banner.js";
import {
  printDetectionLog as _detLog, printAnalysisCard as _card,
  printIdeStatus as _ideStatus, printInstallKind as _installKind, collectIdeStatuses,
} from "./status-cards.js";
import { printSummary as _summary } from "./summary.js";
import { defaultIo } from "../core/ide/runner.js";

export function banner(info) { _printBanner(info); }
export function detectionLog(info) { _detLog(info); }
export function analysisCard(info) { _card(info); }
export function installKind(info) { _installKind(info); }
export function ideStatus() { _ideStatus(collectIdeStatuses(defaultIo())); }
export function summary(ctx, targetRoot) { _summary(ctx, targetRoot); }

// env 계획·경로 해석·충돌 메뉴가 쓰는 저수준 엔진 io (env-plan/paths-resolve의 io 계약)
export const engineIo = {
  select: engine.select,
  multiselect: engine.multiselect,
  text: engine.text,
  confirm: engine.confirm,
};
