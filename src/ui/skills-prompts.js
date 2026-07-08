// IDE Skills 대화형 프롬프트 (.sh 라우터 choose_menu 등가).
// node:readline 기반 자체 엔진 사용 (@clack/prompts 는 Windows TTY Enter 버그로 제거).
import * as engine from "./readline-engine.js";

export const CANCEL = engine.CANCEL;

// 동작 선택: 설치/업데이트 · 제거 · 그대로. 취소=skip.
export async function selectAction() {
  const v = await engine.select({
    message: "AI 스킬을 어떻게 할까요?",
    options: [
      { value: "apply", label: "설치 / 업데이트 — 최신 상태로 맞추기" },
      { value: "remove", label: "제거 — 설치된 스킬 삭제하기" },
      { value: "skip", label: "그대로 두기" },
    ],
  });
  return v === CANCEL ? "skip" : v;
}

// IDE 멀티셀렉트. choices=[{id,label,disabled}], preselect=[id...], action.
export async function selectTargets(choices, preselect = [], action = "apply") {
  const options = choices.map((c) => ({
    value: c.id,
    label: c.label + (c.disabled ? " (미감지)" : ""),
    hint: c.disabled ? "CLI 없음" : undefined,
    disabled: c.disabled,
  }));
  return engine.multiselect({
    message: `${action === "apply" ? "설치 / 업데이트" : "제거"}할 IDE를 고르세요 (Space 토글, Enter 확정)`,
    options,
    initialValues: preselect,
    required: false,
  });
}

export function note(text, title) { engine.note(text, title); }
