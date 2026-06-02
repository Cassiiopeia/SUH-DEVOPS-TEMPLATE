import re
import sys
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
        "old_suh_command": re.compile(r"-m suh_template\.suh_command|scripts/suh_template/suh_command\.py"),
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


def test_common_rules_documents_3layer_architecture():
    """common-rules.md에 3-layer 아키텍처와 7개 skill cli 매핑이 명시되어야 한다."""
    text = (ROOT / "skills" / "references" / "common-rules.md").read_text(encoding="utf-8")
    for cli in ["github_cli.py", "issue_cli.py", "commit_cli.py", "report_cli.py",
                "review_cli.py", "troubleshoot_cli.py", "changelog_cli.py"]:
        assert cli in text, f"{cli} 매핑이 common-rules.md에 없음"
    # 3-layer 핵심 키워드
    for keyword in ["scripts/common/", "skills/<skill>/scripts/", "self-contained 5줄"]:
        assert keyword in text, f"\"{keyword}\" 키워드 누락"


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


def test_issue_cli_does_not_expose_get_next_seq():
    """get-next-seq는 issue_cli.py CLI 표면에서 제거되어야 한다 (이슈 #329).

    SKILL.md 4단계는 TMP1 직접 사용 절차이므로 CLI 노출은 agent 오추론을 유도한다.
    """
    cli_path = ROOT / "skills" / "suh-issue" / "scripts" / "issue_cli.py"
    text = cli_path.read_text(encoding="utf-8")
    assert "add_parser(\"get-next-seq\"" not in text, \
        "issue_cli.py에 get-next-seq 서브커맨드가 남아있다 (이슈 #329)"
    assert "\"get-next-seq\"" not in text or "removed" in text.lower(), \
        "get-next-seq 참조가 코드에 남아있다"


def test_issue_cli_bad_args_emits_json(tmp_path):
    """issue_cli.py가 잘못된 인자를 받아도 stdout에 JSON을 emit해야 한다."""
    import subprocess
    import os
    import json
    cli_path = ROOT / "skills" / "suh-issue" / "scripts" / "issue_cli.py"
    env = {**os.environ, "PYTHONIOENCODING": "utf-8"}
    proc = subprocess.run(
        [sys.executable, str(cli_path), "nonexistent-sub"],
        capture_output=True, text=True, encoding="utf-8",
        env=env,
    )
    assert proc.stdout.strip(), f"stdout empty, stderr={proc.stderr}"
    out = json.loads(proc.stdout.strip().splitlines()[-1])
    assert out["ok"] is False
    assert out["code"] == "bad_args"


def test_commit_cli_bad_args_emits_json():
    """commit_cli.py가 잘못된 인자를 받아도 stdout에 JSON을 emit해야 한다."""
    import subprocess
    import os
    import json
    cli_path = ROOT / "skills" / "suh-commit" / "scripts" / "commit_cli.py"
    env = {**os.environ, "PYTHONIOENCODING": "utf-8"}
    proc = subprocess.run(
        [sys.executable, str(cli_path), "nonexistent-sub"],
        capture_output=True, text=True, encoding="utf-8",
        env=env,
    )
    assert proc.stdout.strip(), f"stdout empty, stderr={proc.stderr}"
    out = json.loads(proc.stdout.strip().splitlines()[-1])
    assert out["ok"] is False
    assert out["code"] == "bad_args"


def test_report_cli_bad_args_emits_json():
    """report_cli.py가 잘못된 인자를 받아도 stdout에 JSON을 emit해야 한다."""
    import subprocess
    import os
    import json
    cli_path = ROOT / "skills" / "suh-report" / "scripts" / "report_cli.py"
    env = {**os.environ, "PYTHONIOENCODING": "utf-8"}
    proc = subprocess.run(
        [sys.executable, str(cli_path), "nonexistent-sub"],
        capture_output=True, text=True, encoding="utf-8",
        env=env,
    )
    assert proc.stdout.strip(), f"stdout empty, stderr={proc.stderr}"
    out = json.loads(proc.stdout.strip().splitlines()[-1])
    assert out["ok"] is False
    assert out["code"] == "bad_args"


def test_review_cli_bad_args_emits_json():
    """review_cli.py가 잘못된 인자를 받아도 stdout에 JSON을 emit해야 한다."""
    import subprocess
    import os
    import json
    cli_path = ROOT / "skills" / "suh-review" / "scripts" / "review_cli.py"
    env = {**os.environ, "PYTHONIOENCODING": "utf-8"}
    proc = subprocess.run(
        [sys.executable, str(cli_path), "nonexistent-sub"],
        capture_output=True, text=True, encoding="utf-8",
        env=env,
    )
    assert proc.stdout.strip(), f"stdout empty, stderr={proc.stderr}"
    out = json.loads(proc.stdout.strip().splitlines()[-1])
    assert out["ok"] is False
    assert out["code"] == "bad_args"
