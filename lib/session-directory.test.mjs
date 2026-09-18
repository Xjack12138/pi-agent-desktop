import assert from "node:assert/strict";
import { join, resolve } from "node:path";
import test from "node:test";

test("keeps sessions in the configured shared directory", async () => {
  const previous = process.env.PI_CODING_AGENT_SESSION_DIR;
  process.env.PI_CODING_AGENT_SESSION_DIR = "C:\\Users\\Example\\.pi\\agent\\sessions";
  try {
    const { getProjectSessionDir, getSessionStorageRoot } = await import("./session-directory.ts");
    const root = resolve(process.env.PI_CODING_AGENT_SESSION_DIR);
    assert.equal(getSessionStorageRoot(), root);
    assert.equal(getProjectSessionDir("E:\\UnityPJGit\\PJ1"), join(root, "--E--UnityPJGit-PJ1--"));
  } finally {
    if (previous === undefined) delete process.env.PI_CODING_AGENT_SESSION_DIR;
    else process.env.PI_CODING_AGENT_SESSION_DIR = previous;
  }
});
