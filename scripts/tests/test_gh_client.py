import sys
import json
from io import BytesIO
from pathlib import Path
from unittest.mock import patch, MagicMock
sys.path.insert(0, str(Path(__file__).parent.parent))

from suh_template.gh_client import (
    create_issue, add_comment, get_issue, list_issues,
    create_pull_request, GitHubAPIError,
)


def _mock_response(data, status: int = 200):
    """urllib.request.urlopen 반환값을 흉내 내는 mock을 만든다."""
    mock = MagicMock()
    mock.status = status
    mock.read.return_value = json.dumps(data).encode()
    mock.__enter__ = lambda s: s
    mock.__exit__ = MagicMock(return_value=False)
    return mock


def test_create_issue_success():
    resp = _mock_response({"number": 42, "html_url": "https://github.com/o/r/issues/42", "title": "테스트"})
    with patch("urllib.request.urlopen", return_value=resp):
        result = create_issue("owner", "repo", "테스트", "본문", ["작업전"], "ghp_fake")
    assert result["number"] == 42
    assert result["url"] == "https://github.com/o/r/issues/42"


def test_create_issue_auth_error():
    import urllib.error
    with patch("urllib.request.urlopen", side_effect=urllib.error.HTTPError(
        url=None, code=401, msg="Unauthorized", hdrs=None, fp=BytesIO(b'{"message":"Bad credentials"}')
    )):
        try:
            create_issue("owner", "repo", "제목", "본문", [], "bad_pat")
            assert False, "예외가 발생해야 함"
        except GitHubAPIError as e:
            assert e.status_code == 401


def test_add_comment_success():
    resp = _mock_response({"id": 99, "html_url": "https://github.com/o/r/issues/1#issuecomment-99"})
    with patch("urllib.request.urlopen", return_value=resp):
        result = add_comment("owner", "repo", 1, "댓글 내용", "ghp_fake")
    assert result["id"] == 99
    assert "url" in result


def test_add_comment_not_found():
    import urllib.error
    with patch("urllib.request.urlopen", side_effect=urllib.error.HTTPError(
        url=None, code=404, msg="Not Found", hdrs=None, fp=BytesIO(b'{"message":"Not Found"}')
    )):
        try:
            add_comment("owner", "repo", 9999, "댓글", "ghp_fake")
            assert False
        except GitHubAPIError as e:
            assert e.status_code == 404


def test_get_issue_success():
    resp = _mock_response({"number": 5, "title": "제목", "html_url": "https://...", "state": "open", "body": "본문"})
    with patch("urllib.request.urlopen", return_value=resp):
        result = get_issue("owner", "repo", 5, "ghp_fake")
    assert result["number"] == 5
    assert result["state"] == "open"


def test_get_issue_not_found():
    import urllib.error
    with patch("urllib.request.urlopen", side_effect=urllib.error.HTTPError(
        url=None, code=404, msg="Not Found", hdrs=None, fp=BytesIO(b'{"message":"Not Found"}')
    )):
        try:
            get_issue("owner", "repo", 9999, "ghp_fake")
            assert False
        except GitHubAPIError as e:
            assert e.status_code == 404


def test_list_issues_success():
    resp = _mock_response([{"number": 1, "title": "이슈1", "html_url": "https://...", "state": "open"}])
    with patch("urllib.request.urlopen", return_value=resp):
        result = list_issues("owner", "repo", "ghp_fake")
    assert len(result) == 1
    assert result[0]["number"] == 1


def test_create_pull_request_success():
    resp = _mock_response({"number": 10, "html_url": "https://github.com/o/r/pull/10"})
    with patch("urllib.request.urlopen", return_value=resp):
        result = create_pull_request("owner", "repo", "PR 제목", "본문", "feature-branch", "main", "ghp_fake")
    assert result["number"] == 10
    assert result["url"] == "https://github.com/o/r/pull/10"


def test_create_pull_request_already_exists():
    import urllib.error
    with patch("urllib.request.urlopen", side_effect=urllib.error.HTTPError(
        url=None, code=422, msg="Unprocessable Entity",
        hdrs=None, fp=BytesIO(b'{"message":"A pull request already exists"}')
    )):
        try:
            create_pull_request("owner", "repo", "PR", "본문", "branch", "main", "ghp_fake")
            assert False
        except GitHubAPIError as e:
            assert e.status_code == 422
