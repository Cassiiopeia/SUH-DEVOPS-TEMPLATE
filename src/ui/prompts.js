// 대화형 프롬프트 래핑 (.sh interactive_menu/choose_menu/ask_* 등가) — @clack/prompts 기반.
// 취소(ESC/Ctrl+C)는 각 함수가 CANCEL 심볼을 반환 → 호출부가 정상 종료(exit 0) 처리.
import * as clack from "@clack/prompts";

export const CANCEL = Symbol("cancel");
const wrap = (v) => (clack.isCancel(v) ? CANCEL : v);

// 모드 선택 — 한국어 라벨, 내부 키 반환. 취소 시 CANCEL.
export async function selectMode() {
  const v = await clack.select({
    message: "무엇을 설치할까요?",
    options: [
      { value: "full", label: "전체 설치 — 버전관리 + 자동화 워크플로우 + 이슈·PR 템플릿 (처음이라면 추천)" },
      { value: "version", label: "버전 관리만 — 버전 자동 증가·동기화 시스템만 설치" },
      { value: "workflows", label: "워크플로우만 — 빌드·배포 GitHub Actions만 설치" },
      { value: "issues", label: "이슈·PR 템플릿만 — GitHub 이슈/PR 양식만 설치" },
      { value: "skills", label: "AI 스킬만 — Claude·Cursor·Gemini·Codex·PI용 스킬만 설치" },
    ],
  });
  return wrap(v);
}

// 프로젝트 확인 화면 메뉴 (계속/수정/취소).
export async function confirmProjectMenu() {
  const v = await clack.select({
    message: "이 정보로 진행할까요?",
    options: [
      { value: "continue", label: "예, 계속 진행" },
      { value: "edit", label: "수정하기" },
      { value: "cancel", label: "아니오, 취소" },
    ],
  });
  return wrap(v);
}

// 수정 메뉴 — 어떤 항목을 고칠지. showOptional=full/workflows에서만 nexus/secret 노출.
export async function editMenu({ showOptional = false } = {}) {
  const options = [
    { value: "type", label: "프로젝트 타입" },
    { value: "version", label: "버전" },
    { value: "branch", label: "기본 브랜치" },
  ];
  if (showOptional) {
    options.push({ value: "nexus", label: "Nexus publish 포함 여부" });
    options.push({ value: "secret", label: "Secret 백업 포함 여부" });
  }
  options.push({ value: "done", label: "모두 맞음, 계속" });
  const v = await clack.select({ message: "어떤 항목을 수정할까요?", options });
  return wrap(v);
}

// 타입 멀티선택.
export async function selectTypes(current = []) {
  const all = ["spring", "flutter", "next", "react", "react-native", "react-native-expo", "node", "python", "basic"];
  const v = await clack.multiselect({
    message: "프로젝트 타입을 선택하세요 (Space 토글, Enter 확정)",
    options: all.map((t) => ({ value: t, label: t })),
    initialValues: current.length ? current : ["basic"],
    required: true,
  });
  return wrap(v);
}

// 텍스트 입력 (빈 입력=기본값 유지).
export async function askText(message, defaultValue = "") {
  const v = await clack.text({ message, placeholder: defaultValue, defaultValue });
  const w = wrap(v);
  if (w === CANCEL) return CANCEL;
  return w === "" || w == null ? defaultValue : w;
}

// 예/아니오.
export async function askYesNo(message, initial = true) {
  const v = await clack.confirm({ message, initialValue: initial });
  return wrap(v);
}

// 배너·안내 출력.
export function intro(text) { clack.intro(text); }
export function outro(text) { clack.outro(text); }
export function note(text, title) { clack.note(text, title); }
export function cancelMessage(text = "취소했습니다.") { clack.cancel(text); }
