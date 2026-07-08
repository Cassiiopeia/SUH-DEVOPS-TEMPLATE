import { test } from "node:test";
import assert from "node:assert/strict";
import { classifyPackageText, classifyPackageJson, detectTypesFromMarkers, detectVersionFromFiles } from "../src/core/detect.js";

test("classifyPackageText (raw grep 등가)", () => {
  assert.equal(classifyPackageText('{"dependencies":{"react-native":"1","expo":"1"}}'), "react-native-expo");
  assert.equal(classifyPackageText('{"dependencies":{"react-native":"1"}}'), "react-native");
  assert.equal(classifyPackageText('{"dependencies":{"next":"1","react":"1"}}'), "next");
  assert.equal(classifyPackageText('{"dependencies":{"react":"1"}}'), "react");
  assert.equal(classifyPackageText('{"dependencies":{"express":"1"}}'), "node");
});

test("classifyPackageText: react-scripts triggers react via substring (matches .sh)", () => {
  // .sh grep '"react"' 는 "react-scripts" 안의 따옴표 있는 '"react"'만 매칭 —
  // scripts 값 "react-scripts start" 에는 따옴표+react+따옴표 조합이 없으므로 node.
  assert.equal(classifyPackageText('{"scripts":{"start":"react-scripts start"}}'), "node");
  // 하지만 dependencies에 "react" 키가 있으면 react.
  assert.equal(classifyPackageText('{"dependencies":{"react":"18"}}'), "react");
});

test("classifyPackageJson accepts object or raw string", () => {
  assert.equal(classifyPackageJson({ dependencies: { react: "1" } }), "react");
  assert.equal(classifyPackageJson('{"dependencies":{"react":"1"}}'), "react");
});

test("detectTypesFromMarkers suppresses node when other type present", () => {
  const has = (p) => ["build.gradle", "package.json"].includes(p);
  const read = () => '{"dependencies":{"express":"1"}}';
  assert.deepEqual(detectTypesFromMarkers({ has, read }), ["spring"]); // node 억제
});

test("detectTypesFromMarkers basic fallback", () => {
  assert.deepEqual(detectTypesFromMarkers({ has: () => false, read: () => null }), ["basic"]);
});

test("detectVersion order: gradle before pubspec", () => {
  const read = (p) => (p === "build.gradle" ? 'version = "1.2.3"' : p === "pubspec.yaml" ? "version: 9.9.9" : null);
  assert.equal(detectVersionFromFiles({ read, readJson: () => null, hasJq: false }), "1.2.3");
});

test("detectVersion fallback 0.0.1", () => {
  assert.equal(detectVersionFromFiles({ read: () => null, readJson: () => null, hasJq: false }), "0.0.1");
});
