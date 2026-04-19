import sys
import os
import subprocess
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))


def _run_cli(*args, env=None):
    """cli.py를 서브프로세스로 실행하고 (stdout, stderr, returncode)를 반환한다."""
    base_env = os.environ.copy()
    if env:
        base_env.update(env)
    result = subprocess.run(
        [sys.executable, "-m", "suh_template.cli", *args],
        capture_output=True, text=True,
        cwd=str(Path(__file__).parent.parent),
        env=base_env,
    )
    return result.stdout.strip(), result.stderr.strip(), result.returncode


def test_create_branch_name_basic():
    stdout, stderr, code = _run_cli("create-branch-name", "드롭다운 디자인 변경", "427", "--date", "20260115")
    assert code == 0
    assert stdout == "20260115_#427_드롭다운_디자인_변경"


def test_create_branch_name_no_date():
    stdout, stderr, code = _run_cli("create-branch-name", "테스트 제목", "1")
    assert code == 0
    import re
    assert re.match(r"\d{8}_#1_테스트_제목", stdout)


def test_create_branch_name_missing_args():
    stdout, stderr, code = _run_cli("create-branch-name")
    assert code == 1
    assert "missing_argument" in stderr


def test_create_issue_missing_pat():
    """GITHUB_PAT 없을 때 exit 1 + missing_pat 오류 코드."""
    env = {k: v for k, v in os.environ.items() if k != "GITHUB_PAT"}
    stdout, stderr, code = _run_cli(
        "create-issue", "owner", "repo", "제목", "/dev/null", "",
        env=env,
    )
    assert code == 1
    assert "missing_pat" in stderr


def test_add_comment_missing_pat():
    env = {k: v for k, v in os.environ.items() if k != "GITHUB_PAT"}
    stdout, stderr, code = _run_cli(
        "add-comment", "owner", "repo", "1", "/dev/null",
        env=env,
    )
    assert code == 1
    assert "missing_pat" in stderr
