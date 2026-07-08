// CLI 인자 파싱 (.sh top-level while-case 등가) — template_integrator.sh 842~920.
import { VALID_TYPES } from "../context.js";

// argv(process.argv.slice(2)) → 파싱 결과. 오류 시 throw(호출부에서 exit 1).
export function parseArgs(argv) {
  const result = {
    mode: "interactive",
    version: "",             // 통합 대상 프로젝트의 초기 버전 (--project-version)
    types: [],
    primaryType: "",
    includeNexus: null,      // null=미설정
    includeSecretBackup: null,
    pathsCsv: "",            // "flutter=app,react=client" 원문 (정규화는 resolve 단계)
    force: false,
    help: false,
    showVersion: false,      // -v/--version → projectops 패키지 버전 출력 (npm 관례)
  };
  const args = [...argv];
  while (args.length > 0) {
    const a = args.shift();
    switch (a) {
      case "-m": case "--mode":
        result.mode = args.shift() ?? ""; break;
      case "-v": case "--version":
        // npm 관례: -v/--version 은 패키지 버전 출력. (초기 버전 지정은 --project-version)
        result.showVersion = true; break;
      case "--project-version":
        result.version = args.shift() ?? ""; break;
      case "-t": case "--type": {
        const csv = args.shift() ?? "";
        const seen = new Set();
        const types = [];
        for (let t of csv.split(",")) {
          t = t.replace(/\s/g, "");
          if (t === "") continue;
          if (seen.has(t)) continue;         // dedup
          if (!VALID_TYPES.includes(t)) {
            throw new CliError(`지원하지 않는 타입: '${t}'\n지원 타입: ${VALID_TYPES.join(" ")}`);
          }
          seen.add(t);
          types.push(t);
        }
        if (types.length === 0) throw new CliError("--type 인자가 비어 있습니다");
        result.types = types;
        result.primaryType = types[0];
        break;
      }
      case "--force": result.force = true; break;
      case "--nexus": result.includeNexus = true; break;
      case "--no-nexus": result.includeNexus = false; break;
      case "--secret-backup": result.includeSecretBackup = true; break;
      case "--no-secret-backup": result.includeSecretBackup = false; break;
      case "--paths": result.pathsCsv = args.shift() ?? ""; break;
      case "-h": case "--help": result.help = true; break;
      default:
        throw new CliError(`알 수 없는 옵션: ${a}`);
    }
  }
  return result;
}

export class CliError extends Error {}

// 경로 정규화 (.sh resolve_project_paths §3.4): 앞뒤 공백·\→/·끝 /·앞 ./ 제거, 빈값→"."
export function normalizePath(p) {
  let s = String(p).trim();
  s = s.replace(/\\/g, "/");
  s = s.replace(/\/+$/, "");   // 끝 /
  s = s.replace(/^\.\//, "");  // 앞 ./
  return s === "" ? "." : s;
}

// "flutter=app,react=client" → Map<type, normalizedPath>. 타입 검증(무효 → throw).
export function parsePathsCsv(csv) {
  const map = new Map();
  if (!csv) return map;
  for (const pair of csv.split(",")) {
    if (pair.trim() === "") continue;
    const eq = pair.indexOf("=");
    const type = (eq >= 0 ? pair.slice(0, eq) : pair).trim();
    const rawPath = eq >= 0 ? pair.slice(eq + 1) : "";
    if (!VALID_TYPES.includes(type)) {
      throw new CliError(`--paths에 지원하지 않는 타입: '${type}'`);
    }
    map.set(type, normalizePath(rawPath));
  }
  return map;
}
