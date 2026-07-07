#!/usr/bin/env node
// projectops 스텁 CLI — 이름 선점 및 배포 파이프라인 검증용 (SP1)
// 마법사 본체(SP2)가 이식되기 전까지 기존 template_integrator 안내를 제공한다.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const nodeMajor = Number(process.versions.node.split(".")[0]);
if (nodeMajor < 18) {
  console.error(`Node.js 18 이상이 필요합니다 (현재: ${process.versions.node})`);
  process.exit(1);
}

const pkg = JSON.parse(
  readFileSync(join(dirname(fileURLToPath(import.meta.url)), "..", "package.json"), "utf8"),
);

const args = process.argv.slice(2);
if (args.includes("--version") || args.includes("-v")) {
  console.log(pkg.version);
  process.exit(0);
}

const RESET = "\x1b[0m";
const CYAN = "\x1b[36m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const DIM = "\x1b[2m";

console.log(`
${CYAN}=========================================================
  ProjectOps v${pkg.version}
  완전 자동화 GitHub 프로젝트 관리 템플릿 통합 CLI
=========================================================${RESET}

${YELLOW}npx 마법사는 준비 중입니다.${RESET} 지금은 아래 기존 방식으로 통합하세요.

${GREEN}macOS / Linux:${RESET}
  bash <(curl -fsSL "https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.sh")

${GREEN}Windows (PowerShell):${RESET}
  $wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;iex $wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/projectops/main/template_integrator.ps1")

${DIM}문서: https://github.com/Cassiiopeia/projectops${RESET}
`);
