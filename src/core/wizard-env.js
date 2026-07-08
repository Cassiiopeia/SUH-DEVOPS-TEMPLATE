// @wizard env 토큰 엔진 (.sh configure_workflow_env / _wf_set_env / _wf_is_unchanged 등가).
// ⚠️ YAML 파싱/재직렬화 금지 — 라인 단위 문자열 처리 (포맷·주석 보존이 unchanged 판정 전제).
// 실측 기준: template_integrator.sh 3282~3360, 3003~3012.

// KEY 정규식: .sh는 [A-Z_]+ (대문자+언더스코어만). ask/auto 마커가 있는 라인만 대상.
const MARKER_RE = /#\s*@wizard\s+(ask|auto):(.*)$/;
const KEY_RE = /^(\s*)([A-Z_]+):/;
const PATHS_ANCHOR_RE = /#\s*@wizard\s+paths-anchor/;

// 한 라인을 파싱해 {indent,key,action,arg} 반환. ask/auto 마커 없으면 null.
export function parseWizardLine(line) {
  const marker = line.match(MARKER_RE);
  if (!marker) return null;
  const km = line.match(KEY_RE);
  if (!km) return null; // KEY: 형식 아니면 (예: paths-anchor 주석) 무시
  return { indent: km[1], key: km[2], action: marker[1], arg: marker[2].trim() };
}

// .sh _wf_set_env 등가: `KEY: "..."` 따옴표 안 값 치환 + 그 줄 끝 `# @wizard ...` 주석 제거.
// 라인 하나에 대해 수행. value가 빈문자면 (.sh는 [ -n "$_val" ] 가드) 치환 스킵.
export function setEnvLine(line, key, value) {
  if (value === "" || value == null) return line;
  // CRLF 안전: 라인 끝 \r을 분리해 처리 후 복원 (autocrlf 프로젝트 대응)
  const cr = line.endsWith("\r") ? "\r" : "";
  const body = cr ? line.slice(0, -1) : line;
  // 값 치환: KEY: "기존값" → KEY: "value"
  let out = body.replace(
    new RegExp(`^(\\s*${key}:\\s*")[^"]*(")`),
    (_m, p1, p2) => `${p1}${value}${p2}`,
  );
  // 그 줄 끝 # @wizard ... 주석 제거 (앞 공백째)
  out = out.replace(/(\S)[^\S\r\n]*#[^\S\r\n]*@wizard[^\S\r\n].*$/, "$1");
  return out + cr;
}

// resolver — .sh resolve_token 등가. 값 계산은 주입된 resolvers로 위임(순수성 유지).
// resolvers: { repo, "spring-app-yml-dir"(type), "spring-app-yml-path"(type), "flutter-root" }
export function resolveToken(name, type, resolvers = {}) {
  const fn = resolvers[name];
  return typeof fn === "function" ? (fn(type) ?? "") : "";
}

// 파일 전체 치환 (configure_workflow_env 등가).
// content: 원본 워크플로우 텍스트. 반환: 치환된 텍스트.
// opts:
//   type          - 프로젝트 타입 (resolver·값 조회용)
//   values        - Map<key,value>: ask 키의 사용자 선택값 (없으면 기본값=arg 또는 resolver)
//   useDefaults   - true면 ask도 기본값 사용 (WF_USE_DEFAULTS=true, unchanged 비교의 전제)
//   resolvers     - resolveToken용
//   repoName      - __PROJECT_NAME__/__APP_ARTIFACT_NAME__ 치환값
//   projectPath   - paths-anchor 치환용 ('.'이면 anchor 미변경)
export function substituteEnv(content, opts = {}) {
  const { type = "", values = new Map(), useDefaults = true, resolvers = {}, repoName = "", projectPath = "." } = opts;
  if (!content.includes("@wizard")) return content;

  const lines = content.split("\n");
  for (let i = 0; i < lines.length; i++) {
    const p = parseWizardLine(lines[i]);
    if (!p) continue;
    let val = "";
    if (p.action === "auto") {
      val = resolveToken(p.arg, type, resolvers);
    } else { // ask
      let def = p.arg.startsWith("@") ? resolveToken(p.arg.slice(1), type, resolvers) : p.arg;
      const chosen = values.get(p.key);
      if (chosen != null && chosen !== "" && !useDefaults) val = chosen;
      else val = def;
    }
    lines[i] = setEnvLine(lines[i], p.key, val);
  }
  let out = lines.join("\n");

  // 잔여 전역 토큰 (.sh 3347~3351)
  if (out.includes("__PROJECT_NAME__") || out.includes("__APP_ARTIFACT_NAME__")) {
    out = out.replaceAll("__PROJECT_NAME__", repoName).replaceAll("__APP_ARTIFACT_NAME__", repoName);
  }

  // paths-anchor (.sh 3353~3360): 경로가 '.'이 아니면 주석 라인 전체를 paths 라인으로 교체
  if (PATHS_ANCHOR_RE.test(out) && projectPath && projectPath !== ".") {
    out = out.split("\n").map((line) => {
      if (PATHS_ANCHOR_RE.test(line)) {
        const indent = (line.match(/^(\s*)/) || ["", ""])[1];
        return `${indent}paths: ['${projectPath}/**']`;
      }
      return line;
    }).join("\n");
  }
  return out;
}

// .sh _wf_is_unchanged 등가: 원본을 "기본값으로 가상 치환한 최종형"과 설치본을 바이트 비교.
export function isUnchanged(templateContent, installedContent, opts = {}) {
  const virtual = substituteEnv(templateContent, { ...opts, useDefaults: true });
  return virtual === installedContent;
}
