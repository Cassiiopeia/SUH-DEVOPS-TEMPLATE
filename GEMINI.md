# SUH DevOps Skills for Gemini CLI

This repository is both a GitHub project template and an agent skill package.
When working as Gemini CLI, treat `skills/` as the shared skill library.

## Skill Usage

Before acting on a task, check whether a local skill applies. Skill bodies live
at:

```text
skills/{skill-name}/SKILL.md
```

If a skill applies, read its `SKILL.md` first and follow its workflow before
editing files, creating issues, committing, or reporting completion.

Common routing:

| User intent | Skill |
|-------------|-------|
| Create or register a GitHub issue | `skills/suh-issue/SKILL.md` |
| Commit staged work | `skills/suh-commit/SKILL.md` |
| Analyze code without editing | `skills/suh-analyze/SKILL.md` |
| Create an implementation plan | `skills/suh-plan/SKILL.md` |
| Implement a planned change | `skills/suh-implement/SKILL.md` |
| Review code or changes | `skills/suh-review/SKILL.md` |
| Debug failures | `skills/suh-troubleshoot/SKILL.md` |
| Generate implementation reports | `skills/suh-report/SKILL.md` |
| Create or improve skills | `skills/suh-skill-creator/SKILL.md` |
| Query or manage GitHub issues/PRs | `skills/suh-github/SKILL.md` |
| Deploy (main push → deploy PR) | `skills/suh-changelog-deploy/SKILL.md` |

## Repository Safety

This repository also initializes other projects. Be careful when editing:

- `.github/scripts/template_initializer.sh`
- `.github/workflows/`
- `template_integrator.sh`
- `template_integrator.ps1`
- `skills/`

Keep agent package files in this repository, but make sure generated projects do
not keep files such as `skills/`, `.claude-plugin/`, `.codex-plugin/`,
`gemini-extension.json`, `GEMINI.md`, or `AGENTS.md` after template
initialization.

Do not commit or push unless the user explicitly asks for it.
