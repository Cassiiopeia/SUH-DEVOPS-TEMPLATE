#!/usr/bin/env node
// projectops CLI 엔트리 — argv를 src/index.js의 run()에 넘긴다.
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { pathToFileURL } from "node:url";

const nodeMajor = Number(process.versions.node.split(".")[0]);
if (nodeMajor < 18) {
  console.error(`Node.js 18 이상이 필요합니다 (현재: ${process.versions.node})`);
  process.exit(1);
}

const here = dirname(fileURLToPath(import.meta.url));
const indexPath = join(here, "..", "src", "index.js");
const { run } = await import(pathToFileURL(indexPath).href);

const code = await run(process.argv.slice(2), { cwd: process.cwd() });
process.exit(code);
