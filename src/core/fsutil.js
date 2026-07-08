// 파일시스템 공용 유틸 (LF 보존 바이트 복사). 텍스트는 그대로 복사해 원본 줄바꿈 유지.
import {
  cpSync, existsSync, readFileSync, writeFileSync, mkdirSync,
  readdirSync, rmSync,
} from "node:fs";
import { dirname } from "node:path";

export const exists = (p) => existsSync(p);
export const readText = (p) => readFileSync(p, "utf8");

export function writeText(p, s) {
  mkdirSync(dirname(p), { recursive: true });
  writeFileSync(p, s);
}

// 단일 파일 복사 (부모 디렉토리 자동 생성, 바이트 그대로)
export function copyFileSync(src, dst) {
  mkdirSync(dirname(dst), { recursive: true });
  cpSync(src, dst);
}

// 디렉토리 재귀 복사 (내용을 dst 하위로)
export function copyDirSync(src, dst) {
  mkdirSync(dst, { recursive: true });
  cpSync(src, dst, { recursive: true });
}

// 파일/폴더 삭제 (없어도 무해)
export function remove(p) {
  rmSync(p, { recursive: true, force: true });
}

// 디렉토리 직하위 .yaml/.yml 파일명 목록 (정렬). 하위 폴더 제외.
export function listYamlFiles(dir) {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true })
    .filter((e) => e.isFile() && /\.(ya?ml)$/.test(e.name))
    .map((e) => e.name)
    .sort();
}
