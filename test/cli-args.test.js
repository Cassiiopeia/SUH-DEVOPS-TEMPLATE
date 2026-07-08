import { test } from "node:test";
import assert from "node:assert/strict";
import { parseArgs, parsePathsCsv, normalizePath, CliError } from "../src/cli/args.js";

test("기본값", () => {
  const r = parseArgs([]);
  assert.equal(r.mode, "interactive");
  assert.equal(r.force, false);
  assert.equal(r.includeNexus, null);
  assert.deepEqual(r.types, []);
});

test("mode/version/force/type csv dedup", () => {
  const r = parseArgs(["--mode", "full", "--version", "1.2.3", "--force", "--type", "spring,react,spring"]);
  assert.equal(r.mode, "full");
  assert.equal(r.version, "1.2.3");
  assert.equal(r.force, true);
  assert.deepEqual(r.types, ["spring", "react"]); // dedup
  assert.equal(r.primaryType, "spring");
});

test("무효 타입 throw", () => {
  assert.throws(() => parseArgs(["--type", "spring,bogus"]), CliError);
});

test("빈 타입 throw", () => {
  assert.throws(() => parseArgs(["--type", " , "]), CliError);
});

test("nexus/secret-backup 플래그", () => {
  assert.equal(parseArgs(["--nexus"]).includeNexus, true);
  assert.equal(parseArgs(["--no-nexus"]).includeNexus, false);
  assert.equal(parseArgs(["--secret-backup"]).includeSecretBackup, true);
});

test("알 수 없는 옵션 throw", () => {
  assert.throws(() => parseArgs(["--no-backup"]), CliError); // 도움말 전용 허구 → exit 1
  assert.throws(() => parseArgs(["--bogus"]), CliError);
});

test("help 플래그", () => {
  assert.equal(parseArgs(["-h"]).help, true);
  assert.equal(parseArgs(["--help"]).help, true);
});

test("normalizePath 정규화", () => {
  assert.equal(normalizePath("  app/  "), "app");
  assert.equal(normalizePath("./client"), "client");
  assert.equal(normalizePath("a\\b\\"), "a/b");
  assert.equal(normalizePath(""), ".");
  assert.equal(normalizePath("."), ".");
});

test("parsePathsCsv → Map, 무효 타입 throw", () => {
  const m = parsePathsCsv("flutter=app,react=./client");
  assert.equal(m.get("flutter"), "app");
  assert.equal(m.get("react"), "client");
  assert.throws(() => parsePathsCsv("bogus=x"), CliError);
});
