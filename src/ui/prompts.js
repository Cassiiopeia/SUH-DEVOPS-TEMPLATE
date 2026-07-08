// 대화형 프롬프트 래핑 (.sh interactive_menu/choose_menu/ask_* 등가).
// node:readline 기반 자체 엔진 사용 (@clack/prompts 는 Windows TTY에서 Enter가 멈추는 버그로 제거).
// 취소(ESC/Ctrl+C)는 각 함수가 CANCEL 심볼을 반환 → 호출부가 정상 종료(exit 0) 처리.
import * as engine from "./readline-engine.js";

export const CANCEL = engine.CANCEL;

// 모드 선택 — 한국어 라벨, 내부 키 반환. 취소 시 CANCEL.
export async function selectMode() {
  return engine.select({
    message: "무엇을 설치할까요?",
    options: [
      { value: "full", label: "전체 설치 — 버전관리 + 자동화 워크플로우 + 이슈·PR 템플릿 (처음이라면 추천)" },
      { value: "version", label: "버전 관리만 — 버전 자동 증가·동기화 시스템만 설치" },
      { value: "workflows", label: "워크플로우만 — 빌드·배포 GitHub Actions만 설치" },
      { value: "issues", label: "이슈·PR 템플릿만 — GitHub 이슈/PR 양식만 설치" },
      { value: "skills", label: "AI 스킬만 — Claude·Cursor·Gemini·Codex·PI용 스킬만 설치" },
    ],
  });
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
  return engine.select({ message: "어떤 항목을 수정할까요?", options });
}

// 타입 멀티선택.
export async function selectTypes(current = []) {
  const all = ["spring", "flutter", "next", "react", "react-native", "react-native-expo", "node", "python", "basic"];
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
