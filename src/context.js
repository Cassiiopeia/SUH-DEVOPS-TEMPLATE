// 마법사 전역 상태를 하나의 객체로 명시화 (bash 전역 변수군 대체)
// next 타입은 v4.1.0에서 react로 흡수됨 (breaking)
export const VALID_TYPES = [
  "spring", "flutter", "react",
  "react-native", "react-native-expo", "node", "python", "basic",
];

export const DEFAULT_VERSION = "1.3.14"; // .sh DEFAULT_VERSION (배너 폴백용 — breaking 비교엔 안 씀)

export function createContext(overrides = {}) {
  return {
    mode: "interactive",
    force: false,
    types: [],
    version: "",
    branch: "",
    paths: new Map(),        // type -> path
    includeNexus: null,      // null=미설정, true/false=명시
    includeSecretBackup: null,
    templateVersion: "",
    tempDir: "",
    deployValues: new Map(), // "type.KEY" -> value
    counters: {},
    ...overrides,
  };
}
