// IDE Skills 대화형 프롬프트 (.sh 라우터 choose_menu 등가) — @clack/prompts 기반.
import * as clack from "@clack/prompts";

export const CANCEL = Symbol("cancel");
const wrap = (v) => (clack.isCancel(v) ? CANCEL : v);

// 동작 선택: 설치/업데이트 · 제거 · 그대로. 취소=skip.
export async function selectAction() {
  const v = await clack.select({
    message: "AI 스킬을 어떻게 할까요?",
    options: [
      { value: "apply", label: "설치 / 업데이트 — 최신 상태로 맞추기" },
      { value: "remove", label: "제거 — 설치된 스킬 삭제하기" },
      { value: "skip", label: "그대로 두기" },
    ],
  });
  const w = wrap(v);
  return w === CANCEL ? "skip" : w;
}

// IDE 멀티셀렉트. choices=[{id,label,disabled}], preselect=[id...], action.
export async function selectTargets(choices, preselect = [], action = "apply") {
  const options = choices.map((c) => ({
    value: c.id,
    label: c.label + (c.disabled ? " (미감지)" : ""),
    hint: c.disabled ? "CLI 없음" : undefined,
  }));
  const v = await clack.multiselect({
    message: `${action === "apply" ? "설치 / 업데이트" : "제거"}할 IDE를 고르세요 (Space 토글, Enter 확정)`,
    options,
    initialValues: preselect,
    required: false,
  });
  return wrap(v);
}

export function note(text, title) { clack.note(text, title); }
