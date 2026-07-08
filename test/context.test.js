import { test } from "node:test";
import assert from "node:assert/strict";
import { createContext, VALID_TYPES } from "../src/context.js";

test("createContext defaults", () => {
  const c = createContext();
  assert.equal(c.mode, "interactive");
  assert.equal(c.force, false);
  assert.ok(c.paths instanceof Map);
  assert.equal(VALID_TYPES.length, 9);
});

test("createContext overrides", () => {
  const c = createContext({ force: true, types: ["spring"] });
  assert.equal(c.force, true);
  assert.deepEqual(c.types, ["spring"]);
});
