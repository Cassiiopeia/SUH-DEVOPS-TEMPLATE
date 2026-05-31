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


def _call_get_issue(issue, comments, args_rest, capsys):
    from suh_template import suh_command
    with patch.object(suh_command, "_get_pat", return_value="ghp_fake"), \
         patch.object(suh_command._github, "get_issue", return_value=issue), \
         patch.object(suh_command._github, "get_issue_comments", return_value=comments):
        suh_command.cmd_get_issue(["owner", "repo", *args_rest])
    return _json.loads(capsys.readouterr().out.strip())


def test_get_issue_with_comments(capsys):
    issue = {"number": 5, "title": "제목", "url": "u", "state": "open", "body": "본문",
             "labels": ["작업중"], "assignees": [], "created_at": "c", "updated_at": "u2",
             "comments_count": 1}
    comments = [{"author": "me", "body": "댓글", "created_at": "c"}]
    result = _call_get_issue(issue, comments, ["5", "--with-comments"], capsys)
    assert result["ok"] is True
    assert result["issue"]["labels"] == ["작업중"]
    assert result["comments"] == comments
    assert result["next"] is None


def test_get_issues_partial_failure(capsys):
    from suh_template import suh_command
    err = suh_command._github.GitHubAPIError(404, "Not Found")
    with patch.object(suh_command, "_get_pat", return_value="ghp_fake"), \
         patch.object(suh_command._github, "get_issue", side_effect=[
             {"number": 1, "title": "A", "url": "u", "state": "open", "body": "",
              "labels": [], "assignees": [], "created_at": "c", "updated_at": "u", "comments_count": 0},
             err,
         ]):
        suh_command.cmd_get_issues(["owner", "repo", "1", "999"])
    result = _json.loads(capsys.readouterr().out.strip())
    assert result["ok"] is True
    assert result["count"] == 2
    assert result["issues"][0]["number"] == 1
    assert result["issues"][1]["number"] == 999
    assert result["issues"][1]["code"] == "github_api_404"


def test_explore_list_repos_auto(capsys):
    from suh_template import suh_command
    repos = [{"name": "repo", "desc": "설명", "lang": "Python", "stars": 7,
              "updated": "2026-05-31T10:00:00Z", "fork": False, "private": False,
              "url": "https://github.com/o/repo", "topics": []}]
    with patch.object(suh_command, "_get_pat", return_value="ghp_fake"), \
         patch.object(suh_command._github, "get_user_type", return_value="org"), \
         patch.object(suh_command._github, "list_repos", return_value=repos):
        suh_command.cmd_explore(["list-repos", "owner", "--type", "auto"])
    result = _json.loads(capsys.readouterr().out.strip())
    assert result["ok"] is True
    assert result["owner_type"] == "org"
    assert result["repos"] == repos
    assert result["next"] == "explore repo-detail owner repo"


def test_explore_languages(capsys):
    from suh_template import suh_command
    langs = [{"lang": "Python", "percent": 75.0}]
    with patch.object(suh_command, "_get_pat", return_value="ghp_fake"), \
         patch.object(suh_command._github, "get_languages", return_value=langs):
        suh_command.cmd_explore(["languages", "owner", "repo"])
    result = _json.loads(capsys.readouterr().out.strip())
    assert result["ok"] is True
    assert result["languages"] == langs
    assert result["next"] is None


def test_secrets_list(capsys):
    from suh_template import suh_command
    secrets = [{"name": "BACKEND_ENV_FILE", "updated_at": "2026-05-31T10:00:00Z"}]
    with patch.object(suh_command, "_get_pat", return_value="ghp_fake"), \
         patch.object(suh_command._github, "list_secrets", return_value=secrets):
        suh_command.cmd_secrets(["list", "owner", "repo"])
    result = _json.loads(capsys.readouterr().out.strip())
    assert result["ok"] is True
    assert result["secrets"] == secrets
    assert result["next"] == "secrets set owner repo <NAME> (SECRET_VALUE 환경변수 사용)"


def test_secrets_set_uses_secret_value_env(capsys, monkeypatch):
    from suh_template import suh_command
    monkeypatch.setenv("SECRET_VALUE", "line1\nline2")
    with patch.object(suh_command, "_get_pat", return_value="ghp_fake"), \
         patch.object(suh_command._github, "set_secret", return_value={"name": "BACKEND_ENV_FILE", "status": "updated"}) as set_secret:
        suh_command.cmd_secrets(["set", "owner", "repo", "BACKEND_ENV_FILE"])
    result = _json.loads(capsys.readouterr().out.strip())
    assert result["ok"] is True
    assert result["name"] == "BACKEND_ENV_FILE"
    set_secret.assert_called_once_with("owner", "repo", "BACKEND_ENV_FILE", "line1\nline2", "ghp_fake")


def test_secrets_set_reports_pynacl_missing(capsys, monkeypatch):
    from suh_template import suh_command
    monkeypatch.setenv("SECRET_VALUE", "value")
    with patch.object(suh_command, "_get_pat", return_value="ghp_fake"), \
         patch.object(suh_command._github, "set_secret", side_effect=suh_command._github.PyNaClMissingError("missing")):
        suh_command.cmd_secrets(["set", "owner", "repo", "BACKEND_ENV_FILE"])
    result = _json.loads(capsys.readouterr().out.strip())
    assert result["ok"] is False
    assert result["code"] == "pynacl_missing"
    assert "pip install PyNaCl" in result["hint"]
