import sys
import os
import subprocess
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))


def _run_cli(*args, env=None):
    """suh_command를 서브프로세스로 실행하고 (stdout, stderr, returncode)를 반환한다."""
    base_env = os.environ.copy()
    if env:
        base_env.update(env)
    result = subprocess.run(
        [sys.executable, "-m", "suh_template.suh_command", *args],
        capture_output=True, text=True,
        cwd=str(Path(__file__).parent.parent),
        env=base_env,
    )
    return result.stdout.strip(), result.stderr.strip(), result.returncode


def _env_without_pat_and_config(tmp_home):
    """GITHUB_PAT 환경변수와 config.json 자동 로드를 모두 차단한 env를 만든다.

    PAT는 환경변수 → config.json 순으로 찾으므로, missing_pat을 재현하려면
    둘 다 막아야 한다. HOME을 빈 임시 디렉토리로 돌려 config.json을 못 찾게 한다.
    """
    env = {k: v for k, v in os.environ.items() if k != "GITHUB_PAT"}
    env["HOME"] = str(tmp_home)
    env["USERPROFILE"] = str(tmp_home)  # Windows 대비
    return env


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


def test_create_issue_missing_pat(tmp_path):
    """GITHUB_PAT 환경변수도 config.json도 없을 때 exit 1 + missing_pat."""
    env = _env_without_pat_and_config(tmp_path)
    stdout, stderr, code = _run_cli(
        "create-issue", "owner", "repo", "제목", os.devnull, "",
        env=env,
    )
    assert code == 1
    assert "missing_pat" in stderr


def test_add_comment_missing_pat(tmp_path):
    """GITHUB_PAT 환경변수도 config.json도 없을 때 exit 1 + missing_pat."""
    env = _env_without_pat_and_config(tmp_path)
    stdout, stderr, code = _run_cli(
        "add-comment", "owner", "repo", "1", os.devnull,
        env=env,
    )
    assert code == 1
    assert "missing_pat" in stderr


import json as _json
from unittest.mock import patch


def _call_deploy_status(pr_detail, runs, branch_head, args_rest, capsys):
    """cmd_deploy_status를 gh_client mock으로 호출하고 출력 JSON을 파싱해 반환한다."""
    from suh_template import suh_command
    with patch.object(suh_command, "_get_pat", return_value="ghp_fake"), \
         patch.object(suh_command._github, "find_open_pr_by_base", return_value=pr_detail), \
         patch.object(suh_command._github, "get_pull_detail", return_value=pr_detail), \
         patch.object(suh_command._github, "resolve_pr_runs", return_value={"runs": runs}), \
         patch.object(suh_command._github, "get_branch_head", return_value=branch_head):
        suh_command.cmd_deploy_status(["owner", "repo", *args_rest])
    out = capsys.readouterr().out.strip()
    return _json.loads(out)


def test_deploy_status_merged(capsys):
    pr = {"number": 740, "state": "closed", "merged": True, "mergeable_state": None,
          "body": "## Summary by CodeRabbit", "head_sha": "abc", "url": "u"}
    result = _call_deploy_status(pr, [], "abc", ["--pr", "740"], capsys)
    assert result["ok"] is True
    assert result["verdict"] == "merged"


def test_deploy_status_waiting(capsys):
    pr = {"number": 740, "state": "open", "merged": False, "mergeable_state": "clean",
          "body": "## Summary by CodeRabbit", "head_sha": "abc", "url": "u"}
    runs = [{"name": "AUTO-CHANGELOG-CONTROL", "status": "in_progress",
             "conclusion": None, "url": "ru"}]
    result = _call_deploy_status(pr, runs, "old", ["--pr", "740"], capsys)
    assert result["verdict"] == "waiting_for_automerge"
    assert result["workflow"]["name"] == "AUTO-CHANGELOG-CONTROL"


def test_deploy_status_missing_summary(capsys):
    pr = {"number": 740, "state": "open", "merged": False, "mergeable_state": "clean",
          "body": "본문이 초기화됨", "head_sha": "abc", "url": "u"}
    result = _call_deploy_status(pr, [], "old", ["--pr", "740"], capsys)
    assert result["verdict"] == "missing_coderabbit_summary"


def test_deploy_status_workflow_failed(capsys):
    pr = {"number": 740, "state": "open", "merged": False, "mergeable_state": "clean",
          "body": "## Summary by CodeRabbit", "head_sha": "abc", "url": "u"}
    runs = [{"name": "AUTO-CHANGELOG-CONTROL", "status": "completed",
             "conclusion": "failure", "url": "ru"}]
    result = _call_deploy_status(pr, runs, "old", ["--pr", "740"], capsys)
    assert result["verdict"] == "workflow_failed"


def test_deploy_status_conflict(capsys):
    pr = {"number": 740, "state": "open", "merged": False, "mergeable_state": "dirty",
          "body": "## Summary by CodeRabbit", "head_sha": "abc", "url": "u"}
    result = _call_deploy_status(pr, [], "old", ["--pr", "740"], capsys)
    assert result["verdict"] == "conflict"


def test_deploy_status_no_pr(capsys):
    result = _call_deploy_status(None, [], "head", [], capsys)
    assert result["verdict"] == "no_pr"
    assert result["pr"] is None
