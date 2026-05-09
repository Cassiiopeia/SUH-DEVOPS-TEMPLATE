# Multi-Agent Harness Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Gemini CLI and Codex CLI support for the shared SUH DevOps `skills/` library while preserving Claude Code and Cursor support.

**Architecture:** Keep `skills/` as the single source of truth. Add harness-specific root metadata/bootstrap files, expand the skills installer flows, make template initialization remove agent package files from generated projects, and sync version metadata across all harness manifests.

**Tech Stack:** Markdown, JSON, Bash, PowerShell, GitHub Actions, existing `template_integrator` scripts.

---

### Task 1: Add Harness Metadata

**Files:**
- Create: `gemini-extension.json`
- Create: `GEMINI.md`
- Create: `AGENTS.md`
- Create: `.codex-plugin/plugin.json`

- [ ] Add Gemini extension manifest with `contextFileName: "GEMINI.md"` and version `3.0.38`.
- [ ] Add Gemini bootstrap instructions that point to `skills/{skill}/SKILL.md`.
- [ ] Add Codex/general agent bootstrap instructions that point to native skill discovery and local `skills/`.
- [ ] Add conservative Codex plugin metadata for future support.

### Task 2: Extend Template Cleanup

**Files:**
- Modify: `.github/scripts/template_initializer.sh`

- [ ] Remove generated-project copies of `AGENTS.md`, `GEMINI.md`, `gemini-extension.json`, `.codex-plugin/`, and `.cursor/`.
- [ ] Keep existing cleanup of `.claude-plugin/`, `skills/`, and `scripts/`.

### Task 3: Extend Version Sync

**Files:**
- Modify: `.github/workflows/PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml`

- [ ] Update comments to mention Gemini and Codex manifests.
- [ ] Sync `.codex-plugin/plugin.json`.
- [ ] Sync `gemini-extension.json`.
- [ ] Include both new files in the version sync commit.

### Task 4: Extend Installers

**Files:**
- Modify: `template_integrator.sh`
- Modify: `template_integrator.ps1`

- [ ] Update help text and interactive labels from "Claude, Cursor" to "Claude, Cursor, Gemini, Codex".
- [ ] Add Gemini install/update guidance using `gemini extensions install` and `gemini extensions update`.
- [ ] Add Codex native skills install/update/delete flow using `~/.agents/skills/cassiiopeia`.
- [ ] Keep `--mode skills` from changing project template files.

### Task 5: Update User Documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/SKILLS.md`

- [ ] Add quick install commands for Claude Code, Gemini CLI, Codex CLI, and Cursor.
- [ ] Explain invocation differences: Claude slash commands, Gemini/Codex bootstrap skill reading, Cursor copied skills.
- [ ] Keep details in existing docs instead of adding separate `docs/CODEX.md` or `docs/GEMINI-CLI.md`.

### Task 6: Verify and Commit

**Files:**
- All modified files

- [ ] Run `bash -n template_integrator.sh`.
- [ ] Run `bash -n .github/scripts/template_initializer.sh`.
- [ ] Run a JSON parse check for `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `.codex-plugin/plugin.json`, and `gemini-extension.json`.
- [ ] Run PowerShell parse check if `pwsh` is available.
- [ ] Commit with issue `#291`.
