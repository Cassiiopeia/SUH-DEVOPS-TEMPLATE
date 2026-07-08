// 첫 화면 배너 (#446 층1) — 클래식 박스형 (사용자 확정 시안 A)
// .ps1 Print-Banner 계승 + 브랜딩을 projectops로 갱신.
import { A, paint, visualWidth } from "./ansi.js";

const INNER = 56; // 박스 내부 폭

function boxLine(out, content = "") {
  const pad = Math.max(0, INNER - visualWidth(content));
  out(paint("║", A.cyan) + content + " ".repeat(pad) + paint("║", A.cyan) + "\n");
}

// 대화형 첫 화면 배너 — 박스 타이틀 + 메타 4줄 (.ps1 Print-Banner 등가, #446 확정 시안 A)
export function printBanner({ version, modeLabel }, out = (s) => process.stdout.write(s)) {
  out("\n");
  out(paint(`╔${"═".repeat(INNER)}╗`, A.cyan) + "\n");
  boxLine(out);
  boxLine(out, `      ${paint("✦", A.yellow)}  ${paint("P R O J E C T O P S", A.bold)}  ${paint("✦", A.yellow)}`);
  boxLine(out);
  out(paint(`╚${"═".repeat(INNER)}╝`, A.cyan) + "\n");
  out(`     🌙 Version : ${paint(`v${version}`, A.green)}\n`);
  out(`     🐵 Author  : Cassiiopeia\n`);
  out(`     🪐 Mode    : ${modeLabel}\n`);
  out(`     📦 Repo    : ${paint("github.com/Cassiiopeia/projectops", A.dim)}\n`);
  out("\n");
}

// 비대화형(--force/CI) 축약 배너 — 1줄 (사용자 확정: 로그 오염 최소 + 버전 추적)
export function printBannerCompact({ version, mode }, out = (s) => process.stdout.write(s)) {
  out(`${paint("✦", A.yellow)} ${paint("projectops", A.bold)} v${version} — ${mode} 모드 (--force)\n`);
}
