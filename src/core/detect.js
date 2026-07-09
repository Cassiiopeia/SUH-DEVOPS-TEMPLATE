// package.json 내용 분류 (.sh classify_package_json 등가) — 원본 파일 텍스트에 대한
// grep 부분문자열 매칭. dependencies 파싱이 아니라 raw 텍스트 검사여야 등가.
// 입력은 package.json의 원문 문자열(raw). 순서 중요.
export function classifyPackageText(raw) {
  const s = String(raw || "");
  if (s.includes("@react-native") || s.includes("react-native")) {
    return s.includes("expo") ? "react-native-expo" : "react-native";
  }
  // next 타입은 v4.1.0에서 react로 흡수 — "next" 의존성이 있어도 react로 판정
  if (s.includes('"react"') || s.includes('"next"')) return "react";
  return "node";
}

// 편의: 파싱된 객체를 받는 경우 원문으로 재직렬화해 위 규칙 적용
export function classifyPackageJson(pkgOrRaw) {
  const raw = typeof pkgOrRaw === "string" ? pkgOrRaw : JSON.stringify(pkgOrRaw || {});
  return classifyPackageText(raw);
}

// 마커 스캔 (동작명세 §3.1). has(relpath)=>bool 주입. node는 다른 타입 있으면 미추가.
// read(relpath)=>string|null 로 package.json 원문을 받아 classifyPackageText에 넘긴다.
export function detectTypesFromMarkers({ has, read }) {
  const types = [];
  if (has("pubspec.yaml")) types.push("flutter");
  if (has("build.gradle") || has("build.gradle.kts") || has("pom.xml")) types.push("spring");
  if (has("pyproject.toml") || has("setup.py") || has("requirements.txt")) types.push("python");
  if (has("package.json")) {
    const cls = classifyPackageText(read ? read("package.json") : "");
    if (cls === "node") { if (types.length === 0) types.push("node"); }
    else types.push(cls);
  }
  return types.length ? [...new Set(types)] : ["basic"];
}

const VERSION_RE = /^\d+\.\d+\.\d+$/;

// 버전 감지 (동작명세 §3.3) — 순서대로 첫 성공. read(relpath)=>string|null 주입.
export function detectVersionFromFiles({ read, readJson, hasJq, gitTag }) {
  const pkg = readJson?.("package.json");
  if (hasJq && pkg?.version && VERSION_RE.test(pkg.version)) return pkg.version;
  const grab = (content, re) => {
    for (const line of (content || "").split("\n")) {
      const m = line.match(re);
      if (m && VERSION_RE.test(m[1])) return m[1];
    }
    return null;
  };
  let v;
  if ((v = grab(read("build.gradle"), /version\s*=\s*["']?(\d+\.\d+\.\d+)/))) return v;
  if ((v = grab(read("pubspec.yaml"), /^version:\s*(\d+\.\d+\.\d+)/))) return v;
  if ((v = grab(read("pyproject.toml"), /version\s*=\s*["']?(\d+\.\d+\.\d+)/))) return v;
  if (gitTag) { const t = String(gitTag).replace(/^v/, ""); if (VERSION_RE.test(t)) return t; }
  return "0.0.1";
}

export function markerForType(type) {
  return { flutter: "pubspec.yaml", "react-native-expo": "app.json", python: "pyproject.toml", spring: "build.gradle" }[type] || "package.json";
}

export function extraMarkers(type) {
  return { python: ["setup.py", "requirements.txt"], spring: ["build.gradle.kts", "pom.xml"] }[type] || [];
}
