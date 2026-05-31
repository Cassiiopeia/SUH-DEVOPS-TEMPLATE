import sys
import json
from io import BytesIO
from pathlib import Path
from unittest.mock import patch, MagicMock
sys.path.insert(0, str(Path(__file__).parent.parent))

from suh_template.gh_client import (
    create_issue, add_comment, get_issue, list_issues,
    create_pull_request, GitHubAPIError,
    get_pull_detail, find_open_pr_by_base, get_branch_head,
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
    # create_issue는 list_labels(GET) → 이슈 생성(POST) 순으로 _request를 2번 호출한다.
    labels_resp = _mock_response([{"name": "작업전"}])
    issue_resp = _mock_response({"number": 42, "html_url": "https://github.com/o/r/issues/42", "title": "테스트"})
    with patch("suh_template.gh_client._opener.open", side_effect=[labels_resp, issue_resp]):
        result = create_issue("owner", "repo", "테스트", "본문", ["작업전"], "ghp_fake")
    assert result["number"] == 42
    assert result["url"] == "https://github.com/o/r/issues/42"


def test_create_issue_auth_error():
    import urllib.error
    with patch("suh_template.gh_client._opener.open", side_effect=urllib.error.HTTPError(
        url=None, code=401, msg="Unauthorized", hdrs=None, fp=BytesIO(b'{"message":"Bad credentials"}')
    )):
        try:
            create_issue("owner", "repo", "제목", "본문", [], "bad_pat")
            assert False, "예외가 발생해야 함"
        except GitHubAPIError as e:
            assert e.status_code == 401


def test_add_comment_success():
    resp = _mock_response({"id": 99, "html_url": "https://github.com/o/r/issues/1#issuecomment-99"})
    with patch("suh_template.gh_client._opener.open", return_value=resp):
        result = add_comment("owner", "repo", 1, "댓글 내용", "ghp_fake")
    assert result["id"] == 99
    assert "url" in result


def test_add_comment_not_found():
    import urllib.error
    with patch("suh_template.gh_client._opener.open", side_effect=urllib.error.HTTPError(
        url=None, code=404, msg="Not Found", hdrs=None, fp=BytesIO(b'{"message":"Not Found"}')
    )):
        try:
            add_comment("owner", "repo", 9999, "댓글", "ghp_fake")
            assert False
        except GitHubAPIError as e:
            assert e.status_code == 404


def test_get_issue_success():
    resp = _mock_response({"number": 5, "title": "제목", "html_url": "https://...", "state": "open", "body": "본문"})
    with patch("suh_template.gh_client._opener.open", return_value=resp):
        result = get_issue("owner", "repo", 5, "ghp_fake")
    assert result["number"] == 5
    assert result["state"] == "open"


def test_get_issue_not_found():
    import urllib.error
    with patch("suh_template.gh_client._opener.open", side_effect=urllib.error.HTTPError(
        url=None, code=404, msg="Not Found", hdrs=None, fp=BytesIO(b'{"message":"Not Found"}')
    )):
        try:
            get_issue("owner", "repo", 9999, "ghp_fake")
            assert False
        except GitHubAPIError as e:
            assert e.status_code == 404


def test_list_issues_success():
    resp = _mock_response([{"number": 1, "title": "이슈1", "html_url": "https://...", "state": "open"}])
    with patch("suh_template.gh_client._opener.open", return_value=resp):
        result = list_issues("owner", "repo", "ghp_fake")
    assert len(result) == 1
    assert result[0]["number"] == 1


def test_create_pull_request_success():
    resp = _mock_response({"number": 10, "html_url": "https://github.com/o/r/pull/10"})
    with patch("suh_template.gh_client._opener.open", return_value=resp):
        result = create_pull_request("owner", "repo", "PR 제목", "본문", "feature-branch", "main", "ghp_fake")
    assert result["number"] == 10
    assert result["url"] == "https://github.com/o/r/pull/10"


def test_create_pull_request_already_exists():
    import urllib.error
    with patch("suh_template.gh_client._opener.open", side_effect=urllib.error.HTTPError(
        url=None, code=422, msg="Unprocessable Entity",
        hdrs=None, fp=BytesIO(b'{"message":"A pull request already exists"}')
    )):
        try:
            create_pull_request("owner", "repo", "PR", "본문", "branch", "main", "ghp_fake")
            assert False
        except GitHubAPIError as e:
            assert e.status_code == 422


def test_get_pull_detail_success():
    pr_resp = _mock_response({
        "number": 740,
        "state": "open",
        "merged": False,
        "mergeable_state": "clean",
        "body": "## Summary by CodeRabbit\n릴리스 노트",
        "head": {"sha": "29df6205abc"},
        "html_url": "https://github.com/o/r/pull/740",
    })
    with patch("suh_template.gh_client._opener.open", return_value=pr_resp):
        result = get_pull_detail("owner", "repo", 740, "ghp_fake")
    assert result["number"] == 740
    assert result["merged"] is False
    assert result["mergeable_state"] == "clean"
    assert result["head_sha"] == "29df6205abc"
    assert result["body"] == "## Summary by CodeRabbit\n릴리스 노트"
    assert result["url"] == "https://github.com/o/r/pull/740"


def test_find_open_pr_by_base_found():
    # ?base=deploy는 GitHub이 서버측 필터링하므로 목록의 첫 항목이 deploy PR이다.
    # 구현은 items[0]["number"]로 상세를 재조회한다.
    list_resp = _mock_response([{"number": 740, "base": {"ref": "deploy"}}])
    detail_resp = _mock_response({
        "number": 740, "state": "open", "merged": False,
        "mergeable_state": "clean", "body": "x",
        "head": {"sha": "abc"}, "html_url": "https://github.com/o/r/pull/740",
    })
    with patch("suh_template.gh_client._opener.open", side_effect=[list_resp, detail_resp]):
        result = find_open_pr_by_base("owner", "repo", "deploy", "ghp_fake")
    assert result is not None
    assert result["number"] == 740


def test_find_open_pr_by_base_none():
    # ?base=deploy 필터 결과가 비면 빈 목록이 온다.
    list_resp = _mock_response([])
    with patch("suh_template.gh_client._opener.open", return_value=list_resp):
        result = find_open_pr_by_base("owner", "repo", "deploy", "ghp_fake")
    assert result is None


def test_get_branch_head_found():
    resp = _mock_response({"object": {"sha": "e8839805def"}})
    with patch("suh_template.gh_client._opener.open", return_value=resp):
        result = get_branch_head("owner", "repo", "deploy", "ghp_fake")
    assert result == "e8839805def"


def test_get_branch_head_missing():
    import urllib.error
    from io import BytesIO
    with patch("suh_template.gh_client._opener.open", side_effect=urllib.error.HTTPError(
        url=None, code=404, msg="Not Found", hdrs=None, fp=BytesIO(b'{"message":"Not Found"}')
    )):
        result = get_branch_head("owner", "repo", "nope", "ghp_fake")
    assert result is None
