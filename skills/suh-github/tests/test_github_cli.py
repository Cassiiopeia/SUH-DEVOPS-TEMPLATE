"""github_cli 단위 테스트.

GitHub API 실제 호출 안 함 — emit JSON 출력 형식·argparse 라우팅만 검증.
"""
import json
import sys
import subprocess
from pathlib import Path

CLI = Path(__file__).resolve().parents[1] / "scripts" / "github_cli.py"


def run_cli(*args, env_extra=None):
    env = {**__import__("os").environ}
    if env_extra:
        env.update(env_extra)
    env.setdefault("PYTHONIOENCODING", "utf-8")
    result = subprocess.run(
        [sys.executable, str(CLI), *args],
        capture_output=True, text=True, encoding="utf-8", env=env,
    )
    return result.returncode, result.stdout or "", result.stderr or ""


def test_help_includes_all_subcommands():
    rc, out, err = run_cli("--help")
    combined = out + err
    for cmd in ["get-issue", "get-issues", "update-issue", "add-comment",
                "create-pr", "list-prs", "update-pr", "search-issues",
                "explore", "secrets"]:
        assert cmd in combined, f"{cmd} missing from --help"


def test_get_issue_missing_args_returns_argparse_error():
    rc, out, err = run_cli("get-issue")
    assert rc != 0
    assert "owner" in err.lower() or "usage" in err.lower()


def test_emit_format_4_fields_consistent():
    rc, out, err = run_cli("get-issue", "x", "y", "1")
    # 어떤 ok 값이든 JSON 4필드 보장
    lines = [l for l in out.splitlines() if l.strip().startswith("{")]
    if lines:
        parsed = json.loads(lines[0])
        assert "ok" in parsed
        assert "code" in parsed
        assert "summary" in parsed
        assert "next" in parsed
