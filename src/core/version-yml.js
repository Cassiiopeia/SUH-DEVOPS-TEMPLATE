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
# 3. project_types: 프로젝트 타입 배열 — 첫 항목이 primary
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
# - .github/workflows/PROJECT-RELEASE-CHANGELOG.yaml
#
# 주의사항:
# - project_types는 최초 설정 후 변경하지 마세요
# - 버전은 항상 높은 버전으로 자동 동기화됩니다
# ===================================================================
`;

// metadata.template.options 상태머신 파싱 (.sh read_template_options L2361~2416 등가).
// 반환(#439 배포/publish 축): { deploy: string|null, publish: string[]|null, secretBackup: bool|null }
//   deploy: 'docker-ssh'|'vercel'|'none', publish: ['nexus','npm','github-packages'] 부분집합. null=미기재.
// 구 키(nexus/npm_publish)는 신 축으로 자동 마이그레이션해 읽는다 (v4.2.0 이전 파일 호환):
//   nexus:true → publish에 'nexus' + deploy 미기재면 'none' (구 동작: nexus면 서버 배포 제외)
//   npm_publish:true → publish에 'npm'
// 구 synology 키 등 다른 키는 어느 분기에도 안 걸려 자연히 무시된다.
// (options-ask.js가 이 함수를 import한다 — 순환 방지 위해 여기(version-yml)에 정의.)
export function parseTemplateOptions(content) {
  const out = { deploy: null, publish: null, secretBackup: null,
                changelogProvider: null, changelogBaseUrl: null, codeReviewCoderabbit: null,
                deployBranch: null };
  // deploy_branch는 metadata 직속(#456) — template.options 밖이라 별도로 스캔한다.
  for (const line of String(content || "").split("\n")) {
    if (line.startsWith("#")) continue;
    const m = line.match(/^\s+deploy_branch:\s*"([^"]*)"/);
    if (m) { out.deployBranch = m[1]; break; }
  }
  let legacyNexus = null;
  let legacyNpm = null;
  // 값 정규화: 따옴표 제거 + 트림 (.sh tr -d '"' | tr -d "'" | xargs 등가)
  const strip = (s) => String(s).replace(/["']/g, "").trim();
  let inTemplate = false;
  let inOptions = false;
  let inCodeReview = false;
  let inChangelog = false;
  for (const line of String(content || "").split("\n")) {
    if (/^\s*template:/.test(line)) { inTemplate = true; continue; }
    if (inTemplate && /^\s+options:/.test(line)) { inOptions = true; continue; }
    if (inTemplate && inOptions) {
      // 중첩 블록 헤더 감지 (options 밑 한 단계) — code_review / changelog (#455)
      if (/^\s+code_review:\s*$/.test(line)) { inCodeReview = true; inChangelog = false; continue; }
      if (/^\s+changelog:\s*$/.test(line)) { inChangelog = true; inCodeReview = false; continue; }
      if (inCodeReview) {
        const cm = line.match(/^\s+coderabbit:\s*(.+)/);
        if (cm) { const v = strip(cm[1]); if (v === "true") out.codeReviewCoderabbit = true; if (v === "false") out.codeReviewCoderabbit = false; continue; }
      }
      if (inChangelog) {
        const pm = line.match(/^\s+provider:\s*(.+)/);
        if (pm) { out.changelogProvider = strip(pm[1]); continue; }
        const bm = line.match(/^\s+base_url:\s*(.*)/);
        if (bm) { out.changelogBaseUrl = strip(bm[1]); continue; }
      }
      let m = line.match(/^\s+deploy:\s*(.+)/);
      if (m) {
        const v = strip(m[1]);
        if (["docker-ssh", "vercel", "none"].includes(v)) out.deploy = v;
        continue;
      }
      m = line.match(/^\s+publish:\s*\[([^\]]*)\]/);
      if (m) {
        out.publish = strip(m[1]).split(",").map((t) => t.trim()).filter(Boolean);
        continue;
      }
      m = line.match(/^\s+nexus:\s*(.+)/);
      if (m) {
        const v = strip(m[1]);
        if (v === "true") legacyNexus = true;
        if (v === "false") legacyNexus = false;
        continue;
      }
      m = line.match(/^\s+secret_backup:\s*(.+)/);
      if (m) {
        const v = strip(m[1]);
        if (v === "true") out.secretBackup = true;
        if (v === "false") out.secretBackup = false;
        continue;
      }
      m = line.match(/^\s+npm_publish:\s*(.+)/);
      if (m) {
        const v = strip(m[1]);
        if (v === "true") legacyNpm = true;
        if (v === "false") legacyNpm = false;
        continue;
      }
      // 들여쓰기 0~4칸의 다른 키 → options 섹션 종료 (.sh L2404~2408)
      if (/^\s{0,4}[a-z_]+:/.test(line)) { inOptions = false; inTemplate = false; }
    }
    // 최상위 키 → template 섹션 종료 (.sh L2411~2415)
    if (inTemplate && /^[a-z_]+:/.test(line)) { inTemplate = false; inOptions = false; }
  }
  // ── 구 키 마이그레이션 — 신 publish 키가 없을 때만 ──
  if (out.publish === null && (legacyNexus !== null || legacyNpm !== null)) {
    out.publish = [];
    if (legacyNexus === true) {
      out.publish.push("nexus");
      if (out.deploy === null) out.deploy = "none";
    }
    if (legacyNpm === true) out.publish.push("npm");
  }
  return out;
}

// v4.1.0 이전 단수 project_type 키 → project_types 배열 최소 변환 (#471).
// version.yml을 재생성하지 않는 경로(workflows 모드)에서 신형 version_manager(단수 키 명시 거부)와의
// 정합을 맞춘다 — 해당 라인만 교체하고 나머지 내용은 손대지 않는다.
// 배열 키가 이미 있으면 남은 단수 키만 제거한다(4.1.0: 공존 시 단수 무시 — 잔재 정리).
// 반환: 변환된 전체 내용 문자열, 변환할 것이 없으면 null.
export function convertLegacySingularType(content) {
  const lines = String(content || "").split(/\r?\n/);
  let hasArray = false, idx = -1, value = "";
  lines.forEach((l, i) => {
    if (/^project_types:/.test(l)) hasArray = true;
    const m = l.match(/^project_type:\s*["']?([a-z-]+)["']?/);
    if (m && idx < 0) { idx = i; value = m[1]; }
  });
  if (idx < 0) return null;
  if (hasArray) {
    lines.splice(idx, 1);
    return lines.join("\n");
  }
  const type = value === "next" ? "react" : value; // next 타입은 4.1.0에서 react로 흡수
  lines[idx] = `project_types: ["${type}"]   # 멀티타입 배열 — 첫 항목이 primary, 직접 편집 가능`;
  return lines.join("\n");
}

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
  // 브랜치 정보 (#456) — default_branch(레포 기본)와 deploy_branch(릴리스 PR head)는 별개.
  const defaultBranch = line(/^\s*default_branch:\s*"([^"]*)"/);
  const deployBranch = line(/^\s*deploy_branch:\s*"([^"]*)"/);
  // 선택 워크플로우 옵션 (metadata.template.options — nexus/secret_backup)
  const options = parseTemplateOptions(text);
  return { version, versionCode, types, paths, templateVersion, options, defaultBranch, deployBranch };
}

// version.yml 전체 생성 (.sh create_version_yml + save_template_options 신규 케이스 등가).
// opts: { version, types:[], paths:Map, pathMarkers?:Map, branch, versionCode, now, today, templateOptions? }
// primary 타입은 별도 키 없이 project_types[0]이다 (v4.1.0 SSOT — 단수 project_type 키 제거).
//   now   = "YYYY-MM-DD HH:MM:SS" (UTC) — 결정성 위해 주입
//   today = "YYYY-MM-DD" (UTC)
//   pathMarkers = Map<type, markerFilename> (project_paths 주석용)
//   templateOptions = { templateVersion, deployTarget, publishTargets, includeSecretBackup, optionsDate } (template 블록)
export function buildVersionYml({ version, types = [], paths = new Map(), pathMarkers = new Map(), branch = "main", deployBranch = "", versionCode = 1, now, today, templateOptions = null, deployValues = new Map() }) {
  const typesJson = types.length ? `[${types.map((t) => `"${t}"`).join(",")}]` : `["basic"]`;

  let out = HEADER + "\n";
  out += `version: "${version}"\n`;
  out += `version_code: ${versionCode}  # app build number\n`;
  out += `project_types: ${typesJson}   # 멀티타입 배열 — 첫 항목이 primary, 직접 편집 가능\n`;

  // project_paths 블록. pathMarkers: Map<type, markerFilename> (있으면 "  type: "path"   # path/marker" 주석).
  if (paths.size) {
    out += `project_paths:                # 타입별 프로젝트 폴더 (레포 루트 기준 상대경로)\n`;
    for (const [t, p] of paths) {
      const marker = pathMarkers.get(t) || "";
      const pf = p === "." ? marker : (marker ? `${p}/${marker}` : p);
      out += marker ? `  ${t}: "${p}"   # ${pf}\n` : `  ${t}: "${p}"\n`;
    }
  }

  out += `metadata:\n`;
  out += `  last_updated: "${now}"\n`;
  out += `  last_updated_by: "template_integrator"\n`;
  out += `  default_branch: "${branch}"\n`;
  // deploy_branch: 릴리스 PR의 head 브랜치(#456). default_branch(레포 기본)와 별개 개념.
  // 지정된 경우에만 출력 — 미지정이면 스킬이 develop로 폴백(하위호환).
  if (deployBranch) out += `  deploy_branch: "${deployBranch}"\n`;
  out += `  integrated_from: "projectops"\n`;
  out += `  integration_date: "${today}"\n`;

  // deploy 블록 (.sh update_version_yml_deploy). deployValues: Map<type, Map<key,value>>.
  // WF ask 값이 있는 타입만. metadata 뒤, template 앞. (앞에 빈 줄 1개)
  const deployTypes = [...deployValues.keys()].filter((t) => deployValues.get(t) && deployValues.get(t).size > 0);
  if (deployTypes.length) {
    out += `\n`;
    out += `deploy:                          # 마법사가 기억하는 배포 설정 (비민감 / 직접 수정 가능)\n`;
    for (const t of deployTypes) {
      out += `  ${t}:\n`;
      for (const [k, v] of deployValues.get(t)) out += `    ${k}: "${v}"\n`;
    }
  }

  // template 옵션 블록 (.sh save_template_options 신규 추가 케이스). templateOptions 지정 시.
  if (templateOptions) {
    const { templateVersion = "unknown", deployTarget = "docker-ssh", publishTargets = [], includeSecretBackup = false, optionsDate = today,
            changelogProvider = "github-ai", changelogBaseUrl = "", codeReviewCoderabbit = true } = templateOptions;
    const publishJson = `[${publishTargets.map((t) => `"${t}"`).join(",")}]`;
    out += `  template:\n`;
    out += `    source: "projectops"\n`;
    out += `    version: "${templateVersion}"\n`;
    out += `    integrated_date: "${optionsDate}"\n`;
    out += `    last_update_date: "${optionsDate}"\n`;
    out += `    options:\n`;
    out += `      deploy: "${deployTarget}"\n`;
    out += `      publish: ${publishJson}\n`;
    out += `      secret_backup: ${includeSecretBackup}\n`;
    out += `      code_review:\n`;
    out += `        coderabbit: ${codeReviewCoderabbit}\n`;
    out += `      changelog:\n`;
    out += `        provider: "${changelogProvider}"\n`;
    out += `        base_url: "${changelogBaseUrl}"\n`;
  }
  return out;
}
