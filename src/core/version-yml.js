// version.yml 파싱·생성 (.sh create_version_yml 등가, 전체 재생성 전략 D4).
// ⚠️ YAML 재직렬화 금지 — 주석이 데이터. .sh heredoc과 바이트 동일한 템플릿 문자열.
// 실측 기준: template_integrator.sh 2184~2354.

const HEADER = `# ===================================================================
# 프로젝트 버전 관리 파일
# ===================================================================
#
# 이 파일은 다양한 프로젝트 타입에서 버전 정보를 중앙 관리하기 위한 파일입니다.
# GitHub Actions 워크플로우가 이 파일을 읽어 자동으로 버전을 관리합니다.
#
# 사용법:
# 1. version: "1.0.0" - 사용자에게 표시되는 버전
# 2. version_code: 1 - Play Store/App Store 빌드 번호 (1부터 자동 증가)
# 3. project_type: 프로젝트 타입 지정
# 4. project_paths: 타입별 프로젝트 폴더 (레포 루트 기준 상대경로, 모노레포용)
#
# 자동 버전 업데이트:
# - patch: 자동으로 세 번째 자리 증가 (x.x.x -> x.x.x+1)
# - version_code: 매 빌드마다 자동으로 1씩 증가
# - minor/major: 수동으로 직접 수정 필요
#
# 프로젝트 타입별 동기화 파일:
# - spring: build.gradle (version = "x.y.z")
# - flutter: pubspec.yaml (version: x.y.z+i, buildNumber 포함)
# - react/node: package.json ("version": "x.y.z")
# - react-native: iOS Info.plist 또는 Android build.gradle
# - react-native-expo: app.json (expo.version)
# - python: pyproject.toml (version = "x.y.z")
# - basic/기타: version.yml 파일만 사용
#
# 연관된 워크플로우:
# - .github/workflows/PROJECT-VERSION-CONTROL.yaml
# - .github/workflows/PROJECT-README-VERSION-UPDATE.yaml
# - .github/workflows/PROJECT-AUTO-CHANGELOG-CONTROL.yaml
#
# 주의사항:
# - project_type은 최초 설정 후 변경하지 마세요
# - 버전은 항상 높은 버전으로 자동 동기화됩니다
# ===================================================================
`;

// 기존 version.yml에서 값 추출 (.sh grep/sed 등가, 주석 라인 오탐 방지).
export function parseExisting(content) {
  const text = String(content || "");
  const line = (re) => {
    for (const l of text.split("\n")) {
      if (l.startsWith("#")) continue; // 주석 제외
      const m = l.match(re);
      if (m) return m[1];
    }
    return null;
  };
  // version: "x.y.z" (숫자.숫자.숫자 형태만)
  const version = line(/^version:\s*["']?([0-9][0-9.]*)["']?/) || "";
  // version_code: N (양의 정수, 아니면 1)
  let versionCode = parseInt(line(/^version_code:\s*([0-9]+)/) || "", 10);
  if (!Number.isInteger(versionCode) || versionCode <= 0) versionCode = 1;
  // project_types: ["a","b"]
  const typesRaw = line(/^project_types:\s*(\[[^\]]*\])/);
  let types = [];
  if (typesRaw) types = [...typesRaw.matchAll(/"([^"]+)"/g)].map((m) => m[1]);
  // project_paths 블록: "  type: "path""
  const paths = new Map();
  let inPaths = false;
  for (const l of text.split("\n")) {
    if (/^project_paths:/.test(l)) { inPaths = true; continue; }
    if (inPaths) {
      const m = l.match(/^\s+([a-z-]+):\s*"([^"]*)"/);
      if (m) paths.set(m[1], m[2]);
      else if (/^\S/.test(l)) inPaths = false; // 들여쓰기 끝 → 블록 종료
    }
  }
  // template: 블록 내 version
  let templateVersion = "";
  let inTemplate = false;
  for (const l of text.split("\n")) {
    if (/^\s*template:/.test(l)) { inTemplate = true; continue; }
    if (inTemplate) {
      const m = l.match(/^\s*version:\s*"([0-9][0-9.]*)"/);
      if (m) { templateVersion = m[1]; break; }
      if (/^\S/.test(l)) break;
    }
  }
  return { version, versionCode, types, paths, templateVersion };
}

// version.yml 전체 생성 (.sh create_version_yml heredoc 등가).
// opts: { version, types:[], primaryType?, paths:Map, branch, versionCode, now, today }
//   now   = "YYYY-MM-DD HH:MM:SS" (UTC) — 결정성 위해 주입
//   today = "YYYY-MM-DD" (UTC)
export function buildVersionYml({ version, types = [], primaryType, paths = new Map(), branch = "main", versionCode = 1, now, today }) {
  const typesJson = types.length ? `[${types.map((t) => `"${t}"`).join(",")}]` : `["basic"]`;
  const primary = primaryType || types[0] || "basic";

  let out = HEADER + "\n";
  out += `version: "${version}"\n`;
  out += `version_code: ${versionCode}  # app build number\n`;
  out += `project_types: ${typesJson}   # 멀티타입 배열 — 첫 항목이 primary, 직접 편집 가능\n`;
  out += `project_type: "${primary}"  # project_types[0] 자동 미러 — 직접 수정 금지 (spring, flutter, next, react, react-native, react-native-expo, node, python, basic)\n`;

  if (paths.size) {
    out += `project_paths:                # 타입별 프로젝트 폴더 (레포 루트 기준 상대경로)\n`;
    for (const [t, p] of paths) out += `  ${t}: "${p}"\n`;
  }

  out += `metadata:\n`;
  out += `  last_updated: "${now}"\n`;
  out += `  last_updated_by: "template_integrator"\n`;
  out += `  default_branch: "${branch}"\n`;
  out += `  integrated_from: "projectops"\n`;
  out += `  integration_date: "${today}"\n`;
  return out;
}
