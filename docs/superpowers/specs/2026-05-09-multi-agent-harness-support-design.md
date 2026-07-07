# Multi-Agent Harness Support Design

Date: 2026-05-09

## Goal

Extend SUH-DEVOPS-TEMPLATE so its skill library can be used from Claude Code,
Cursor, Gemini CLI, and Codex CLI while preserving the repository's existing
role as a GitHub project template.

The repository must keep a clear boundary between:

- Template assets installed into generated projects, such as `.github/`,
  workflows, scripts, issue templates, and `version.yml`.
- Agent skill package assets used to distribute this repository's `skills/`
  library to coding agents.

## Current State

The repository currently supports Claude Code and Cursor-oriented skill use:

- `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` define the
  Claude Code plugin metadata.
- `skills/` is the source skill library.
- `.cursor/skills/` contains a copied Cursor-compatible skill tree.
- `template_integrator.sh` and `template_integrator.ps1` expose a `skills` mode
  for Claude Code and Cursor.
- `.github/scripts/template_initializer.sh` removes `.claude-plugin/` and
  `skills/` from projects generated from the template.
- `.github/workflows/PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml` syncs version
  metadata for Claude plugin files only.

This is not enough for Gemini CLI and Codex CLI because those harnesses have
different installation and discovery models.

## Supported Harnesses

Claude Code remains supported through the existing marketplace-style plugin
metadata.

Cursor remains supported through the existing copy-based `.cursor/skills`
installation flow.

Gemini CLI will be supported through a root `gemini-extension.json` manifest and
a root `GEMINI.md` context file. Users install it with:

```bash
gemini extensions install https://github.com/Cassiiopeia/projectops
```

Codex CLI will be supported primarily through user-registered plugin marketplace
sources, not OpenAI official marketplace publication. Users register this
repository as a marketplace source:

```bash
codex plugin marketplace add Cassiiopeia/projectops
```

The installer wizard should also prepare the native skill discovery fallback so
users do not need to manually install through `/plugins`.

macOS/Linux:

```bash
git clone https://github.com/Cassiiopeia/projectops.git ~/.codex/cassiiopeia
mkdir -p ~/.agents/skills
ln -s ~/.codex/cassiiopeia/skills ~/.agents/skills/cassiiopeia
```

Windows:

```powershell
git clone https://github.com/Cassiiopeia/projectops.git "$env:USERPROFILE\.codex\cassiiopeia"
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.agents\skills"
cmd /c mklink /J "%USERPROFILE%\.agents\skills\cassiiopeia" "%USERPROFILE%\.codex\cassiiopeia\skills"
```

`.agents/plugins/marketplace.json` and `.codex-plugin/plugin.json` provide Codex
marketplace and plugin metadata. The design must not depend on official Codex
marketplace publication.

## Repository Layout

The root-level skill package layout should be:

```text
.
├── AGENTS.md
├── GEMINI.md
├── gemini-extension.json
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── .codex-plugin/
│   └── plugin.json
├── .cursor/
│   └── skills/
└── skills/
    ├── analyze/
    ├── implement/
    ├── review/
    └── ...
```

`skills/` remains the single source of truth for all skill bodies. Harness
metadata should adapt to that source instead of creating separate skill copies,
except for the existing Cursor copy target.

## New Root Files

### `gemini-extension.json`

This file is the Gemini CLI extension manifest. It should live at the repository
root and point Gemini at `GEMINI.md`.

Expected shape:

```json
{
  "name": "cassiiopeia",
  "version": "3.0.35",
  "mcpServers": {},
  "contextFileName": "GEMINI.md"
}
```

The version must be kept in sync with `version.yml` and the Claude plugin
manifest.

### `GEMINI.md`

This file is the Gemini CLI bootstrap context. It should instruct Gemini to use
the shared `skills/` directory and to read relevant `SKILL.md` files before
acting.

It should include:

- A short explanation that this repository is the SUH DevOps skill package.
- The location of the skill library: `skills/{skill-name}/SKILL.md`.
- A requirement to use relevant skills before implementation, debugging,
  review, documentation, issue, or planning work.
- A concise mapping from common user intents to local skills.
- A note that this repository is also a project template, so changes to
  `.github/scripts`, `.github/workflows`, `template_integrator.sh`, and
  `template_integrator.ps1` require extra care.

### `AGENTS.md`

This file is the Codex and general agent bootstrap context. It should live at
the repository root and provide the same operational rules as `GEMINI.md`, with
Codex-specific wording.

It should include:

- A requirement to inspect relevant local skills before acting.
- A statement that Codex does not rely on a slash-command skill UI for this
  repository.
- A note that Codex installation is primarily via plugin marketplace source
  registration, with `~/.agents/skills` as a fallback.
- A mapping from tasks to skills.
- Repository-specific safety rules for template initializer and integrator
  changes.

### `.codex-plugin/plugin.json`

This is Codex plugin metadata. It should be paired with
`.agents/plugins/marketplace.json` so users can register this repository as a
Codex plugin marketplace source.

Expected minimal shape:

```json
{
  "name": "cassiiopeia",
  "version": "3.0.35",
  "description": "DevOps automation skills for coding agents",
  "skills": "./skills/"
}
```

The exact schema should stay conservative so it is easy to update if Codex
marketplace requirements change.

## Template Initializer Behavior

Projects generated from this repository should not keep the skill package
distribution files. Those files belong to this template repository, not to
ordinary generated projects.

`.github/scripts/template_initializer.sh` should remove:

```text
AGENTS.md
GEMINI.md
gemini-extension.json
.claude-plugin/
.codex-plugin/
.agents/
.cursor/
skills/
```

This preserves the existing distinction between template assets and skill
package assets.

The initializer should not remove broad documentation directories just because
they contain agent-related documentation. Any install documentation should stay
in `README.md` and `docs/SKILLS.md` so no extra docs cleanup is needed.

## Template Integrator Behavior

`template_integrator.sh` and `template_integrator.ps1` should expand `skills`
mode from "Claude, Cursor" to "Claude, Cursor, Gemini, Codex".

The scripts should support:

- Claude Code: existing marketplace add/install/update/uninstall flow.
- Cursor: existing copy flow to user or project `.cursor/skills`.
- Gemini CLI: run `gemini extensions install` or `gemini extensions update`
  when the `gemini` command is available, otherwise print the manual command.
- Codex CLI: register the repository with `codex plugin marketplace add
  Cassiiopeia/projectops`, then prepare the native skills fallback
  automatically so wizard users do not need manual `/plugins` installation. If
  the Codex plugin marketplace command is unavailable, clone or update the
  repository under a stable local directory and create a symlink or junction
  from `~/.agents/skills/cassiiopeia` to the cloned repository's `skills/`
  directory.

Codex plugin marketplace registration requires the `codex` CLI. The native skill
discovery fallback should remain available when `codex` is not installed.

The interactive flow should show detected installation status where possible and
let the user install, update, reinstall, or remove each harness installation.

The non-interactive flow should keep existing behavior stable and should not
change project template files when `--mode skills` is used.

## Version Sync

`.github/workflows/PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC.yaml` should sync the
template version into every harness metadata file:

- `.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
- `.codex-plugin/plugin.json`
- `.agents/plugins/marketplace.json`
- `gemini-extension.json`
- `.cursor/skills/cursor-skills-meta.json`, if the Cursor copy remains
  committed

This keeps all installation channels aligned with `version.yml`.

## Documentation

No separate `docs/CODEX.md` or `docs/GEMINI-CLI.md` files are required.

Installation and usage documentation should be consolidated into:

- `README.md` for short installation commands.
- `docs/SKILLS.md` for detailed skill usage and harness-specific notes.

This avoids adding documentation files that would later need special cleanup
when the repository is used as a project template.

## Testing Strategy

Shell script changes should be checked with:

```bash
bash -n template_integrator.sh
bash -n .github/scripts/template_initializer.sh
```

PowerShell changes should be checked with:

```powershell
pwsh -NoProfile -Command { $null = [scriptblock]::Create((Get-Content -Raw template_integrator.ps1)) }
```

If PowerShell is unavailable locally, note that limitation explicitly.

Version sync changes should be verified by reviewing the workflow diff and, if
possible, running the JSON update commands against temporary copies.

Documentation should be checked for consistency with the actual install paths
and commands.

## Non-Goals

This design does not require official Codex plugin marketplace publication.

This design does not replace the current Claude Code marketplace support.

This design does not move or rename the existing `skills/` directory.

This design does not install agent skill package files into projects generated
from the template.
