import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def _skill_doc_paths():
    return [
        *sorted((ROOT / "skills").glob("*/SKILL.md")),
        *sorted((ROOT / "skills" / "references").glob("*.md")),
    ]


def test_skill_docs_do_not_teach_inline_python_workarounds():
    """Skill docs must route behavior through stable scripts, not heredoc Python."""
    forbidden = {
        "python_heredoc": re.compile(r"(?:python3?|\\\$PYTHON|PYTHONIOENCODING=[^\n]*)\s+-\s+<<|<<'EOF'|<<EOF"),
        "tmp_python": re.compile(r"/tmp/[^`\s]*\.py"),
        "curl_pipe_python": re.compile(r"curl[^\n|]*\|[^\n]*(?:python3?|\\\$PYTHON)"),
        "old_cli_py": re.compile(r"\bcli\.py\b"),
    }
    allowed_files = {
        "skills/references/mcp-subcommand-rules.md",
    }
    failures = []
    for path in _skill_doc_paths():
        rel = path.relative_to(ROOT).as_posix()
        if rel in allowed_files:
            continue
        text = path.read_text(encoding="utf-8")
        for name, pattern in forbidden.items():
            if pattern.search(text):
                failures.append(f"{rel}: {name}")
    assert failures == []


def test_github_skill_docs_use_suh_command_instead_of_direct_curl_recipes():
    """GitHub-facing skills should not document direct curl API recipes."""
    github_docs = [
        ROOT / "skills" / "suh-github" / "SKILL.md",
        ROOT / "skills" / "suh-issue" / "SKILL.md",
        ROOT / "skills" / "suh-changelog-deploy" / "SKILL.md",
    ]
    failures = []
    for path in github_docs:
        rel = path.relative_to(ROOT).as_posix()
        text = path.read_text(encoding="utf-8")
        if re.search(r"curl\s+-s[^\n]*api\.github\.com|https://api\.github\.com", text):
            failures.append(rel)
    assert failures == []


def test_common_rules_lists_current_suh_command_github_commands():
    text = (ROOT / "skills" / "references" / "common-rules.md").read_text(encoding="utf-8")
    for command in ["get-issues", "update-pr", "actions", "deploy-status", "explore", "secrets"]:
        assert command in text


def test_agent_docs_do_not_recommend_direct_curl_for_github_api():
    docs = [ROOT / "CLAUDE.md", ROOT / "AGENTS.md"]
    failures = []
    for path in docs:
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        if "GitHub API 호출은 curl 직접 사용 권장" in text:
            failures.append(path.name)
    assert failures == []
