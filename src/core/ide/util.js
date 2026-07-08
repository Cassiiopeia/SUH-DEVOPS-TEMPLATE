// IDE 어댑터 공용 유틸.

// sort -V 근사: 버전형 디렉토리/문자열 비교기. "3.0.9" < "3.0.10" 을 올바로 정렬.
export function compareCacheName(a, b) {
  const pa = a.split(".").map((n) => parseInt(n, 10) || 0);
  const pb = b.split(".").map((n) => parseInt(n, 10) || 0);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] || 0) - (pb[i] || 0);
    if (d) return d;
  }
  return a.localeCompare(b);
}

// 상태 → 표시 태그 (" ✓ 최신" / " → 업데이트 가능: vX"). templateVersion 없으면 빈 문자열.
export function versionTag(installedVersion, templateVersion) {
  if (!templateVersion || !installedVersion) return "";
  return installedVersion === templateVersion ? " ✓ 최신" : ` → 업데이트 가능: v${templateVersion}`;
}
