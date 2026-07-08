import { test } from "node:test";
import assert from "node:assert/strict";
import { PLUGIN_ITEMS_TO_REMOVE, DOCS_TO_REMOVE } from "../src/core/exclusions.js";

test("plugin items include CLI + npm workflows, exclude skills", () => {
  for (const x of ["bin", "src", ".claude-plugin", ".github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml"])
    assert.ok(PLUGIN_ITEMS_TO_REMOVE.includes(x), `missing ${x}`);
  assert.ok(!PLUGIN_ITEMS_TO_REMOVE.includes("skills"));
});

test("docs removed include CLAUDE.md", () => {
  assert.ok(DOCS_TO_REMOVE.includes("CLAUDE.md"));
});
