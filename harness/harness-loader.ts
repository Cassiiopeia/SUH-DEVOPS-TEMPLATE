import * as fs from "node:fs";
import * as path from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// 자기 자신(harness-loader.ts)이 위치한 폴더 = harness/ 를 기준으로 옆의 md를 읽는다.
// package가 어디에 clone되든(~/.pi/agent/git/.../SUH-DEVOPS-TEMPLATE/harness) 자동으로 따라간다.
const HARNESS_DIR = path.dirname(fileURLToPath(import.meta.url));

export default function harnessGlobalExtension(pi: ExtensionAPI) {
  pi.on("before_agent_start", async (event, ctx) => {
    if (!fs.existsSync(HARNESS_DIR)) return;

    let appendedPrompt = "";
    try {
      const files = fs.readdirSync(HARNESS_DIR);
      for (const file of files) {
        if (file.endsWith(".md")) {
          const filePath = path.join(HARNESS_DIR, file);
          if (fs.statSync(filePath).isFile()) {
            const content = fs.readFileSync(filePath, "utf-8");
            appendedPrompt += `\n\n--- FILE: harness/${file} ---\n\n${content}`;
          }
        }
      }
    } catch (err) {
      ctx.ui.notify(`Failed to read harness guidelines: ${err}`, "error");
    }

    if (appendedPrompt) {
      return {
        systemPrompt:
          event.systemPrompt +
          "\n\n## SYSTEM GUIDELINES & PERSONAS (Dynamically loaded global harness)" +
          appendedPrompt,
      };
    }
  });
}
