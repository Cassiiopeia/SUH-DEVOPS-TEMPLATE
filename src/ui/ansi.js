// 공용 ANSI 헬퍼 — banner/status-cards가 공유 (readline-engine 내부 헬퍼와 독립, 의존성 0)
const E = "\x1b[";
export const A = {
  reset: `${E}0m`,
  bold: `${E}1m`,
  dim: `${E}2m`,
  cyan: `${E}36m`,
  green: `${E}32m`,
  yellow: `${E}33m`,
  magenta: `${E}35m`,
  gray: `${E}90m`,
};
export const paint = (s, color) => `${color}${s}${A.reset}`;

// 대략적 표시 폭 (CJK 2칸 · ANSI 시퀀스 0칸) — 박스 우변 정렬용
export function visualWidth(s) {
  const plain = String(s).replace(/\x1b\[[0-9;]*m/g, "");
  let w = 0;
  for (const ch of plain) {
    const cp = ch.codePointAt(0);
    // 한글·CJK·이모지 대략 2칸 (터미널 관례)
    w += (cp >= 0x1100 && (cp <= 0x115f || (cp >= 0x2e80 && cp <= 0xa4cf) || (cp >= 0xac00 && cp <= 0xd7a3)
      || (cp >= 0xf900 && cp <= 0xfaff) || (cp >= 0xff00 && cp <= 0xff60) || cp >= 0x1f300)) ? 2 : 1;
  }
  return w;
}
