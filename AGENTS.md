# SUH DevOps Skills Agent Instructions

This repository is both a GitHub project template and an agent skill package.
For Codex and other agents, `skills/` is the shared local skill library.

## Required Skill Flow

Before responding with an implementation, issue, commit, review, or debugging
result, check whether a local skill applies. Skill bodies live at:

```text
skills/{skill-name}/SKILL.md
```

If a skill applies, read the relevant `SKILL.md` and follow it. Codex does not
need a slash-command skill UI for this repository; use the local files directly.

Common routing:

| Request | Use |
|---------|-----|
| "이슈 작성", "issue", "GitHub 이슈 만들어줘" | `skills/issue/SKILL.md` |
| "커밋해줘", "commit" | `skills/commit/SKILL.md` |
| "분석해줘", "영향 범위 봐줘" | `skills/analyze/SKILL.md` |
| "계획 세워줘", "plan" | `skills/plan/SKILL.md` |
| "구현해줘", "수정해줘" | `skills/implement/SKILL.md` |
| "리뷰해줘" | `skills/review/SKILL.md` |
| "문제 원인 찾아줘", "디버깅" | `skills/troubleshoot/SKILL.md` |
| "작업 보고서 작성" | `skills/report/SKILL.md` |
| "스킬 만들기/개선" | `skills/skill-creator/SKILL.md` |

## Codex Installation Model

**Method 1 (recommended):** Plugin marketplace source registration:

```bash
codex plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE
```

After registering, open `/plugins` in Codex and verify the `cassiiopeia` entry.

**Method 2 (fallback):** Direct clone + symlink for immediate activation without
marketplace:

```bash
git clone https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE.git ~/.codex/cassiiopeia
mkdir -p ~/.agents/skills
ln -s ~/.codex/cassiiopeia/skills ~/.agents/skills/cassiiopeia
```

Codex reads `.agents/plugins/marketplace.json` to discover the marketplace entry
and `.codex-plugin/plugin.json` to load the plugin metadata.

## Repository Safety

This repository is also used as a template for new projects. Agent package files
belong here, but should be removed from generated projects by the initializer:

- `AGENTS.md`
- `GEMINI.md`
- `gemini-extension.json`
- `.agents/`
- `.claude-plugin/`
- `.codex-plugin/`
- `.cursor/`
- `skills/`

Be especially careful when editing `.github/scripts/template_initializer.sh`,
`.github/workflows/`, `template_integrator.sh`, and `template_integrator.ps1`.
Do not push unless the user explicitly asks for it.
