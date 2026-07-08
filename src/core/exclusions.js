// 템플릿 다운로드 후 제거하는 항목 — .sh download_template 내부 배열과 동기화
// ⚠️ CLAUDE.md "3곳 동시 수정" 규칙의 4번째 동기화 지점:
//    template_initializer.sh / template_integrator.sh / .ps1 / 이 파일
export const DOCS_TO_REMOVE = [
  "CONTRIBUTING.md",
  "CLAUDE.md",
  "AGENTS.md",
  "GEMINI.md",
  "gemini-extension.json",
];

export const PLUGIN_ITEMS_TO_REMOVE = [
  ".claude-plugin",
  ".codex-plugin",
  ".agents",
  ".cursor",
  "scripts",
  "package.json",
  "harness",
  "bin",
  "src",
  ".github/workflows/PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml",
  ".github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml",
];
// ⚠️ skills/ 는 제외하지 않는다 (Cursor 설치 소스로 보존)
