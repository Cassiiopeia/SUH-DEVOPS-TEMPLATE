# Sub-project #6: GitHub Skill 통합 구현 플랜

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `gh_branch.py`(브랜치명 계산)와 `gh_client.py`(REST API 클라이언트)를 신규 구현하고, `cli.py`에 GitHub 커맨드를 추가한 뒤, `/issue`·`/report`·`/github` 세 스킬을 GitHub API와 연결한다.

**Architecture:** `gh_branch.py`는 순수 함수 모듈로 외부 의존성 없이 브랜치명을 계산한다. `gh_client.py`는 `urllib` 표준 라이브러리만 사용해 GitHub REST API를 호출하고 `GitHubAPIError` 예외를 발생시킨다. `cli.py`가 두 모듈을 묶어 스킬에서 쉘 명령으로 호출할 수 있는 인터페이스를 제공한다.

**Tech Stack:** Python 3.9+, urllib (표준), unittest.mock, pytest

---

## 파일 구조

```
scripts/suh_template/
├── gh_branch.py          ← 신규
├── gh_client.py          ← 신규
├── cli.py             ← 수정 (5개 커맨드 추가)
└── __init__.py        ← 수정 (SUPPORTED_SKILL_IDS에 'github' 추가)

scripts/tests/
├── test_gh_branch.py     ← 신규
├── test_gh_client.py     ← 신규
└── test_cli_gh_client.py ← 신규

skills/
├── issue/SKILL.md     ← 수정
├── report/SKILL.md    ← 수정
└── github/SKILL.md    ← 신규

.cursor/skills/
└── github.mdc         ← 신규 (skills/github/SKILL.md 내용 동기화)
```

---

### Task 1: `gh_branch.py` — 브랜치명 계산 모듈

**Files:**
- Create: `scripts/suh_template/gh_branch.py`
- Test: `scripts/tests/test_gh_branch.py`

- [ ] **Step 1: 실패하는 테스트 작성**

`scripts/tests/test_gh_branch.py`:

```python
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from suh_template.gh_branch import normalize_title, create_branch_name, get_commit_template


def test_normalize_title_special_chars():
    assert normalize_title("hello world!") == "hello_world"


def test_normalize_title_korean():
    assert normalize_title("드롭다운 디자인 변경") == "드롭다운_디자인_변경"


def test_normalize_title_consecutive_underscores():
    assert normalize_title("foo--bar__baz") == "foo_bar_baz"


def test_normalize_title_strip_underscores():
    assert normalize_title("!hello!") == "hello"


def test_normalize_title_mixed():
    assert normalize_title("⚙️[기능추가] 새 기능") == "기능추가_새_기능"


def test_create_branch_name_format():
    result = create_branch_name("드롭다운 디자인 변경", 427, "20260115")
    assert result == "20260115_#427_드롭다운_디자인_변경"


def test_create_branch_name_length_limit():
    long_title = "가" * 200
    result = create_branch_name(long_title, 1, "20260115")
    assert len(result) <= 100
    assert not result.endswith("_")


def test_get_commit_template():
    result = get_commit_template("기능추가", "https://github.com/owner/repo/issues/1")
    assert "기능추가" in result
    assert "https://github.com/owner/repo/issues/1" in result
    assert ": feat :" in result
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
cd /path/to/project && python -m pytest scripts/tests/test_gh_branch.py -v 2>&1 | head -20
```

Expected: `ModuleNotFoundError: No module named 'suh_template.gh_branch'`

- [ ] **Step 3: `gh_branch.py` 구현**

`scripts/suh_template/gh_branch.py`:

```python
"""브랜치명 계산 모듈 — SUH-ISSUE-HELPER TypeScript 로직의 Python 포팅."""

from __future__ import annotations

import re
from datetime import date


_KEEP_PATTERN = re.compile(r"[^\uAC00-\uD7A3a-zA-Z0-9]")
_MULTI_UNDERSCORE = re.compile(r"_+")
_MAX_BRANCH_LEN = 100


def normalize_title(title: str) -> str:
    """이슈 제목을 브랜치명용 문자열로 정규화한다."""
    normalized = _KEEP_PATTERN.sub("_", title)
    normalized = _MULTI_UNDERSCORE.sub("_", normalized)
    return normalized.strip("_")


def create_branch_name(
    issue_title: str,
    issue_number: int,
    date_yyyymmdd: str | None = None,
) -> str:
    """YYYYMMDD_#이슈번호_정규화제목 형식의 브랜치명을 생성한다."""
    if date_yyyymmdd is None:
        date_yyyymmdd = date.today().strftime("%Y%m%d")
    prefix = f"{date_yyyymmdd}_#{issue_number}_"
    max_title_len = _MAX_BRANCH_LEN - len(prefix)
    normalized = normalize_title(issue_title)[:max_title_len].rstrip("_")
    return f"{prefix}{normalized}"


def get_commit_template(issue_title: str, issue_url: str) -> str:
    """커밋 메시지 템플릿을 반환한다."""
    return f"{issue_title} : feat : {{설명}} {issue_url}"
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
python -m pytest scripts/tests/test_gh_branch.py -v
```

Expected: 8 passed

- [ ] **Step 5: 커밋**

```bash
git add scripts/suh_template/gh_branch.py scripts/tests/test_gh_branch.py
git commit -m "feat: gh_branch.py 브랜치명 계산 모듈 추가 [skip ci]"
```

---

### Task 2: `gh_client.py` — GitHub REST API 클라이언트

**Files:**
- Create: `scripts/suh_template/gh_client.py`
- Test: `scripts/tests/test_gh_client.py`

- [ ] **Step 1: 실패하는 테스트 작성**

`scripts/tests/test_gh_client.py`:

```python
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


def _mock_response(data: dict, status: int = 200):
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
    mock = MagicMock()
    mock.status = 401
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
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
python -m pytest scripts/tests/test_gh_client.py -v 2>&1 | head -10
```

Expected: `ModuleNotFoundError: No module named 'suh_template.gh_client'`

- [ ] **Step 3: `gh_client.py` 구현**

`scripts/suh_template/gh_client.py`:

```python
"""GitHub REST API 클라이언트 — urllib 표준 라이브러리만 사용."""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from typing import Any


_API_BASE = "https://api.github.com"


class GitHubAPIError(Exception):
    def __init__(self, status_code: int, message: str) -> None:
        super().__init__(f"GitHub API {status_code}: {message}")
        self.status_code = status_code
        self.message = message


def _request(method: str, url: str, data: dict | None, pat: str) -> Any:
    """GitHub API 요청을 보내고 응답 JSON을 반환한다."""
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(
        url,
        data=body,
        method=method,
        headers={
            "Authorization": f"Bearer {pat}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body_bytes = e.fp.read() if e.fp else b""
        try:
            msg = json.loads(body_bytes).get("message", str(e))
        except Exception:
            msg = str(e)
        raise GitHubAPIError(e.code, msg) from e


def create_issue(
    owner: str, repo: str, title: str, body: str,
    labels: list[str], pat: str,
) -> dict:
    """이슈를 생성하고 {number, url, title}을 반환한다."""
    data = _request(
        "POST",
        f"{_API_BASE}/repos/{owner}/{repo}/issues",
        {"title": title, "body": body, "labels": labels},
        pat,
    )
    return {"number": data["number"], "url": data["html_url"], "title": data["title"]}


def add_comment(
    owner: str, repo: str, issue_number: int, body: str, pat: str,
) -> dict:
    """이슈에 댓글을 추가하고 {id, url}을 반환한다."""
    data = _request(
        "POST",
        f"{_API_BASE}/repos/{owner}/{repo}/issues/{issue_number}/comments",
        {"body": body},
        pat,
    )
    return {"id": data["id"], "url": data["html_url"]}


def get_issue(owner: str, repo: str, issue_number: int, pat: str) -> dict:
    """이슈를 조회하고 {number, title, url, state, body}를 반환한다."""
    data = _request(
        "GET",
        f"{_API_BASE}/repos/{owner}/{repo}/issues/{issue_number}",
        None,
        pat,
    )
    return {
        "number": data["number"],
        "title": data["title"],
        "url": data["html_url"],
        "state": data["state"],
        "body": data.get("body", ""),
    }


def list_issues(
    owner: str, repo: str, pat: str, state: str = "open",
) -> list[dict]:
    """이슈 목록을 조회한다."""
    items = _request(
        "GET",
        f"{_API_BASE}/repos/{owner}/{repo}/issues?state={state}&per_page=50",
        None,
        pat,
    )
    return [
        {"number": i["number"], "title": i["title"], "url": i["html_url"], "state": i["state"]}
        for i in items
    ]


def create_pull_request(
    owner: str, repo: str, title: str, body: str,
    head: str, base: str, pat: str,
) -> dict:
    """PR을 생성하고 {number, url}을 반환한다."""
    data = _request(
        "POST",
        f"{_API_BASE}/repos/{owner}/{repo}/pulls",
        {"title": title, "body": body, "head": head, "base": base},
        pat,
    )
    return {"number": data["number"], "url": data["html_url"]}
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
python -m pytest scripts/tests/test_gh_client.py -v
```

Expected: 9 passed

- [ ] **Step 5: 커밋**

```bash
git add scripts/suh_template/gh_client.py scripts/tests/test_gh_client.py
git commit -m "feat: gh_client.py GitHub REST API 클라이언트 추가 [skip ci]"
```

---

### Task 3: `cli.py` — GitHub·Branch CLI 커맨드 추가

**Files:**
- Modify: `scripts/suh_template/cli.py`
- Modify: `scripts/suh_template/__init__.py`
- Test: `scripts/tests/test_cli_gh_client.py`

- [ ] **Step 1: 실패하는 테스트 작성**

`scripts/tests/test_cli_gh_client.py`:

```python
import sys
import os
import json
import subprocess
from pathlib import Path
from unittest.mock import patch
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
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
python -m pytest scripts/tests/test_cli_gh_client.py -v 2>&1 | head -15
```

Expected: 오류 (`unknown_command` 코드로 실패)

- [ ] **Step 3: `__init__.py`에 'github' 추가**

`scripts/suh_template/__init__.py`의 `SUPPORTED_SKILL_IDS` 리스트에 `"github"` 추가:

```python
SUPPORTED_SKILL_IDS = [
    "analyze",
    "plan",
    "design-analyze",
    "refactor-analyze",
    "troubleshoot",
    "report",
    "ppt",
    "review",
    "issue",
    "github",
    "synology-expose",
]
```

- [ ] **Step 4: `cli.py`에 5개 커맨드 추가**

`scripts/suh_template/cli.py` 상단 import 블록에 추가:

```python
from suh_template import gh_branch as _branch
from suh_template import gh_client as _github
```

다음 함수들을 `cmd_init_config` 함수 아래에 추가:

```python
def cmd_create_branch_name(args: list) -> int:
    """create-branch-name <issue_title> <issue_number> [--date YYYYMMDD]"""
    if len(args) < 2:
        _err("ERROR", "create-branch-name", "issue_title과 issue_number 인수가 필요합니다.", "missing_argument")
        return 1
    issue_title = args[0]
    try:
        issue_number = int(args[1])
    except ValueError:
        _err("ERROR", "create-branch-name", "issue_number는 정수여야 합니다.", "invalid_argument")
        return 1
    date_val = None
    if "--date" in args:
        idx = args.index("--date")
        if idx + 1 < len(args):
            date_val = args[idx + 1]
    print(_branch.create_branch_name(issue_title, issue_number, date_val))
    return 0


def _get_pat() -> Optional[str]:
    """환경변수 GITHUB_PAT를 반환한다."""
    return os.environ.get("GITHUB_PAT")


def cmd_create_issue(args: list) -> int:
    """create-issue <owner> <repo> <title> <body_file> <labels_csv>"""
    if len(args) < 5:
        _err("ERROR", "create-issue", "owner, repo, title, body_file, labels_csv 인수가 필요합니다.", "missing_argument")
        return 1
    pat = _get_pat()
    if not pat:
        _err("ERROR", "create-issue", "환경변수 GITHUB_PAT가 설정되지 않았습니다.", "missing_pat")
        return 1
    owner, repo, title, body_file, labels_csv = args[0], args[1], args[2], args[3], args[4]
    body = Path(body_file).read_text(encoding="utf-8") if body_file and Path(body_file).exists() else ""
    labels = [l.strip() for l in labels_csv.split(",") if l.strip()] if labels_csv else []
    try:
        result = _github.create_issue(owner, repo, title, body, labels, pat)
        import json as _json
        print(_json.dumps(result, ensure_ascii=False))
        return 0
    except _github.GitHubAPIError as e:
        _err("ERROR", "create-issue", str(e), f"github_api_{e.status_code}")
        return 1


def cmd_add_comment(args: list) -> int:
    """add-comment <owner> <repo> <issue_number> <body_file>"""
    if len(args) < 4:
        _err("ERROR", "add-comment", "owner, repo, issue_number, body_file 인수가 필요합니다.", "missing_argument")
        return 1
    pat = _get_pat()
    if not pat:
        _err("ERROR", "add-comment", "환경변수 GITHUB_PAT가 설정되지 않았습니다.", "missing_pat")
        return 1
    owner, repo, issue_number, body_file = args[0], args[1], int(args[2]), args[3]
    body = Path(body_file).read_text(encoding="utf-8") if body_file and Path(body_file).exists() else ""
    try:
        result = _github.add_comment(owner, repo, issue_number, body, pat)
        import json as _json
        print(_json.dumps(result, ensure_ascii=False))
        return 0
    except _github.GitHubAPIError as e:
        _err("ERROR", "add-comment", str(e), f"github_api_{e.status_code}")
        return 1


def cmd_get_issue(args: list) -> int:
    """get-issue <owner> <repo> <issue_number>"""
    if len(args) < 3:
        _err("ERROR", "get-issue", "owner, repo, issue_number 인수가 필요합니다.", "missing_argument")
        return 1
    pat = _get_pat()
    if not pat:
        _err("ERROR", "get-issue", "환경변수 GITHUB_PAT가 설정되지 않았습니다.", "missing_pat")
        return 1
    owner, repo, issue_number = args[0], args[1], int(args[2])
    try:
        result = _github.get_issue(owner, repo, issue_number, pat)
        import json as _json
        print(_json.dumps(result, ensure_ascii=False))
        return 0
    except _github.GitHubAPIError as e:
        _err("ERROR", "get-issue", str(e), f"github_api_{e.status_code}")
        return 1


def cmd_create_pr(args: list) -> int:
    """create-pr <owner> <repo> <title> <body_file> <head> <base>"""
    if len(args) < 6:
        _err("ERROR", "create-pr", "owner, repo, title, body_file, head, base 인수가 필요합니다.", "missing_argument")
        return 1
    pat = _get_pat()
    if not pat:
        _err("ERROR", "create-pr", "환경변수 GITHUB_PAT가 설정되지 않았습니다.", "missing_pat")
        return 1
    owner, repo, title, body_file, head, base = args[0], args[1], args[2], args[3], args[4], args[5]
    body = Path(body_file).read_text(encoding="utf-8") if body_file and Path(body_file).exists() else ""
    try:
        result = _github.create_pull_request(owner, repo, title, body, head, base, pat)
        import json as _json
        print(_json.dumps(result, ensure_ascii=False))
        return 0
    except _github.GitHubAPIError as e:
        _err("ERROR", "create-pr", str(e), f"github_api_{e.status_code}")
        return 1
```

`_COMMANDS` 딕셔너리에 5개 항목 추가:

```python
_COMMANDS = {
    "get-output-path": cmd_get_output_path,
    "get-issue-number": cmd_get_issue_number,
    "get-next-seq": cmd_get_next_seq,
    "normalize-title": cmd_normalize_title,
    "config-get": cmd_config_get,
    "init-config": cmd_init_config,
    "create-branch-name": cmd_create_branch_name,
    "create-issue": cmd_create_issue,
    "add-comment": cmd_add_comment,
    "get-issue": cmd_get_issue,
    "create-pr": cmd_create_pr,
}
```

- [ ] **Step 5: 테스트 통과 확인**

```bash
python -m pytest scripts/tests/test_cli_gh_client.py -v
```

Expected: 5 passed

- [ ] **Step 6: 전체 테스트 스위트 통과 확인**

```bash
python -m pytest scripts/tests/ -v
```

Expected: 모든 테스트 통과 (기존 테스트 포함)

- [ ] **Step 7: 커밋**

```bash
git add scripts/suh_template/__init__.py scripts/suh_template/cli.py scripts/tests/test_cli_gh_client.py
git commit -m "feat: cli.py에 GitHub/Branch CLI 커맨드 5개 추가 [skip ci]"
```

---

### Task 4: `/issue` 스킬 SKILL.md 업데이트

**Files:**
- Modify: `skills/issue/SKILL.md`

- [ ] **Step 1: 현재 SKILL.md 읽기**

```bash
cat skills/issue/SKILL.md
```

- [ ] **Step 2: SKILL.md 전체 교체**

`skills/issue/SKILL.md` 전체를 아래 내용으로 교체:

```markdown
---
name: issue
description: "Issue Mode - GitHub 이슈 작성 전문가. 사용자의 대략적인 설명을 받아 GitHub 이슈 템플릿에 맞는 제목과 본문을 자동으로 작성하고 GitHub에 즉시 등록한다. 이슈 생성, 버그 리포트, 기능 요청, QA 요청 작성 시 사용. /issue 호출 시 사용."
---

# Issue Mode

당신은 GitHub 이슈 작성 전문가다. 사용자의 대략적인 설명을 받아 **GitHub 이슈 템플릿에 맞는 제목과 본문을 자동 작성**하고, **GitHub API로 이슈를 실제 등록**한 뒤 **즉시 브랜치명을 계산**하여 다음 작업 선택지를 제공한다.

## 시작 전

1. `references/common-rules.md`의 **절대 규칙** 적용 (Git 커밋 금지, 민감 정보 보호)

2. **Config 확인**:

   ```bash
   python3 -m suh_template.cli config-get issue github_pat
   ```

   - 값이 반환되면 → config 로드 완료. `github_repos` 목록에서 `default: true`인 repo 사용. repo가 여러 개면 번호를 매겨 선택하게 한다.
   - `config_not_found` 에러 → 대화형으로 아래 정보를 하나씩 수집한다:
     - GitHub PAT 토큰 (repo 권한 필요. 발급 방법: GitHub > Settings > Developer settings > Personal access tokens)
     - repo 목록 (owner/repo 형태, 여러 개 가능)
     - 기본 repo 선택
   - 수집 완료 후 저장 위치 선택:
     ```
     설정을 어디에 저장할까요?
     1. 이 프로젝트에만 (.suh-template/config/) — .gitignore 자동 등록
     2. 모든 프로젝트에서 사용 (~/.suh-template/config/)
     ```
   - AI가 직접 `config.save(project_root, "issue", data, scope)` 호출하여 저장.

## 허용 이모지+태그 규칙

`.github/ISSUE_TEMPLATE/` 폴더가 존재하면 파일들을 읽어 허용 조합을 파싱한다.
폴더가 없으면 아래 기본값을 사용한다.

**주요 태그** (타입 결정, 하나만 선택):

| 이모지+태그 | 용도 |
|-------------|------|
| `❗[버그]` | 버그 리포트 |
| `🎨[디자인]` | 디자인/UI 요청 |
| `🔧[기능요청]` | 기능 요청 |
| `⚙️[기능추가]` | 새 기능 추가 |
| `🚀[기능개선]` | 기존 기능 개선 |
| `🔍[시험요청]` | QA/테스트 요청 |

**수식어 태그** (선택적, 주요 태그 앞에 붙임):

| 이모지+태그 | 조건 |
|-------------|------|
| `🔥[긴급]` | 사용자가 "긴급"이라 명시할 때만 |
| `📄[문서]` | 문서 관련일 때 |
| `⌛[~월/일]` | 마감일이 있을 때 |

**규칙**: 이모지와 `[` 사이에 공백 없음. 위 목록에 없는 이모지 사용 금지.

## 절대 금지

- **채팅으로만 이슈 본문을 출력하고 파일 저장을 생략하는 것**
- 코드적인 내용 (구현 방법, 코드 예시)
- 허용 목록에 없는 이모지 사용
- `🔥[긴급]` 임의 추가 (사용자가 명시할 때만)
- 담당자 임의 채우기
- 이모지와 `[` 사이 공백

## 사용자 입력

$ARGUMENTS

## 프로세스

### 1단계: 이슈 타입 자동 판단

| 타입 | 키워드 | 템플릿 |
|------|--------|--------|
| **버그** | 안 됨, 에러, 깨짐, 오류, 크래시, 장애 | `bug_report` |
| **기능** | 추가, 만들어야, 새로, 구현, 개선, 변경, 요청 | `feature_request` |
| **디자인** | 디자인, UI, UX, 폰트, 색상, 레이아웃 | `design_request` |
| **QA** | 테스트, QA, 시험, 검증, 확인 | `qa_request` |

**기능 세분류**:
- `🔧[기능요청]`: 요청/검토 단계
- `⚙️[기능추가]`: 완전히 새로운 기능
- `🚀[기능개선]`: 기존 기능 개선

### 2단계: 이슈 제목 생성

```
[이모지+태그][카테고리] 제목 (50자 이내)
```

예시: `⚙️[기능추가][Skills] issue 스킬 GitHub API 연동`

### 3단계: 코드 탐색 및 본문 작성

1. 프로젝트의 `.github/ISSUE_TEMPLATE/` 해당 템플릿을 Read로 읽어 형식 파악
2. 관련 코드를 탐색하여 연관 파일 경로 포함
3. 템플릿 형식에 맞춰 본문 작성

### 4단계: 제목 확인

생성한 이슈 제목을 사용자에게 보여주고 수정 여부를 확인한다:

```
제목: ⚙️[기능추가][Skills] issue 스킬 GitHub API 연동
이 제목으로 이슈를 생성할까요? (수정하려면 원하는 제목을 입력하세요)
```

### 5단계: GitHub 이슈 생성

제목이 확정되면 임시 파일에 본문을 저장하고 CLI로 이슈를 생성한다:

```bash
# 본문을 임시 파일로 저장
# PAT는 환경변수로 전달
GITHUB_PAT=$(python3 -m suh_template.cli config-get issue github_pat) \
  python3 -m suh_template.cli create-issue {owner} {repo} "{제목}" /tmp/issue_body.md "{라벨}"
```

반환 JSON에서 `number`와 `url`을 추출한다.

### 6단계: 브랜치명 즉시 계산

```bash
python3 -m suh_template.cli create-branch-name "{이슈 제목}" {이슈번호}
```

### 7단계: 로컬 파일 저장

```bash
python3 -m suh_template.cli get-output-path issue
```

반환 경로 대신 `.issue/` 폴더에 파일 저장:

**파일 위치**: `.issue/[YYYYMMDD]_#[번호]_[제목].md`

파일 첫 줄에 이슈 제목을 `# ` 헤딩으로 작성한다.

### 8단계: 다음 작업 선택지 제시

```
이슈 생성 완료: #{번호} — {제목}
브랜치명: {브랜치명}
이슈 URL: {url}

다음 작업을 선택하세요:
1. 지금 worktree 생성 (../{브랜치명}/)
2. 브랜치만 생성 (현재 디렉토리에서 작업)
3. 나중에 직접 (브랜치명 복사만)
```

선택에 따라:
- **1 선택**: `git worktree add -b {브랜치명} ../{브랜치명}` 실행
- **2 선택**: `git checkout -b {브랜치명}` 실행
- **3 선택**: 브랜치명을 다시 출력하고 종료

## 산출물 저장

`.issue/` 폴더에 저장 (Step 7에서 처리). 별도로 `get-output-path`를 호출할 필요 없다.
```

- [ ] **Step 3: `.cursor/skills/issue.mdc` 동기화**

`skills/issue/SKILL.md`와 동일한 내용을 `.cursor/skills/issue.mdc`에 저장한다 (frontmatter 유지).

- [ ] **Step 4: 커밋**

```bash
git add skills/issue/SKILL.md .cursor/skills/issue.mdc
git commit -m "feat: issue 스킬 GitHub API 연동 및 브랜치 선택지 추가 [skip ci]"
```

---

### Task 5: `/report` 스킬 SKILL.md 업데이트

**Files:**
- Modify: `skills/report/SKILL.md`
- Modify: `.cursor/skills/report.mdc`

- [ ] **Step 1: 현재 SKILL.md 읽기**

```bash
cat skills/report/SKILL.md
```

- [ ] **Step 2: "산출물 저장" 섹션 뒤에 "GitHub 댓글 포스팅" 섹션 추가**

`skills/report/SKILL.md`의 마지막 `## 산출물 저장` 섹션을 아래 내용으로 교체:

```markdown
## 산출물 저장

`references/doc-output-path.md` 규칙을 따른다.

산출물 md 저장 전:
```bash
python3 -m suh_template.cli get-output-path report
```

반환된 경로에 파일을 저장한다.

## GitHub 댓글 포스팅 (선택적)

파일 저장 후, GitHub 이슈에 댓글로 보고서를 포스팅할 수 있다. PAT가 설정된 경우에만 시도한다.

### 이슈 번호 자동 감지 순서

1. 현재 작업 디렉토리 경로에서 추출 (worktree 경로 `YYYYMMDD_#숫자_제목` 패턴):
   ```bash
   python3 -m suh_template.cli get-issue-number
   ```
2. `.issue/` 폴더 파일명에서 추출 (예: `.issue/20260115_#427_제목.md` → 427)
3. git 브랜치명에서 추출
4. 위 세 방법 모두 실패 시 사용자에게 이슈 번호 질문

### 포스팅 플로우

```bash
# 1. PAT 확인
python3 -m suh_template.cli config-get issue github_pat
# config_not_found이면 로컬 저장만 하고 종료

# 2. repo 확인
python3 -m suh_template.cli config-get issue github_repos
# 또는 git remote origin에서 owner/repo 추출

# 3. 댓글 포스팅
GITHUB_PAT={pat} python3 -m suh_template.cli add-comment {owner} {repo} {이슈번호} {보고서파일경로}
```

### 완료 메시지

```
보고서 저장: docs/suh-template/report/{파일명}.md
GitHub 댓글: https://github.com/{owner}/{repo}/issues/{번호}#issuecomment-{id}
```

PAT 미설정 시:
```
보고서 저장: docs/suh-template/report/{파일명}.md
(GitHub PAT 미설정 — 로컬 저장만 완료)
```
```

- [ ] **Step 3: `.cursor/skills/report.mdc` 동기화**

`skills/report/SKILL.md`와 동일한 내용을 `.cursor/skills/report.mdc`에 저장한다.

- [ ] **Step 4: 커밋**

```bash
git add skills/report/SKILL.md .cursor/skills/report.mdc
git commit -m "feat: report 스킬 GitHub 댓글 포스팅 기능 추가 [skip ci]"
```

---

### Task 6: `/github` 스킬 신규 생성

**Files:**
- Create: `skills/github/SKILL.md`
- Create: `.cursor/skills/github.mdc`

- [ ] **Step 1: 디렉토리 생성 확인**

```bash
mkdir -p skills/github
```

- [ ] **Step 2: `skills/github/SKILL.md` 작성**

```markdown
---
name: github
description: "GitHub Mode - 독립적인 GitHub 제어 스킬. 이슈 조회, 댓글 추가, PR 생성/조회를 직접 수행한다. '/github', '이슈 확인해줘', 'PR 만들어줘', '댓글 달아줘' 등을 언급하면 이 skill을 사용한다."
---

# GitHub Mode

독립적인 GitHub 제어 스킬이다. 다른 스킬 없이 단독으로 GitHub 작업을 수행한다.

## 시작 전

**Config 확인**:

```bash
python3 -m suh_template.cli config-get issue github_pat
```

- 값이 반환되면 → PAT 준비 완료.
- `config_not_found` 에러 → issue 스킬의 Config 설정 절차를 안내한다 (`/issue` 스킬을 먼저 실행하여 PAT를 등록하면 이 스킬에서도 공유 사용된다).

**Repo 자동 감지**:

```bash
git remote get-url origin
```

`https://github.com/{owner}/{repo}.git` 또는 `git@github.com:{owner}/{repo}.git` 형식에서 `owner`와 `repo`를 추출한다. 감지 실패 시 config의 `github_repos` 목록에서 선택하게 한다.

## 사용자 입력

$ARGUMENTS

## 지원 작업

### 이슈 조회

```bash
GITHUB_PAT={pat} python3 -m suh_template.cli get-issue {owner} {repo} {이슈번호}
```

`#번호` 형식이나 "이슈 427 확인해줘"처럼 번호를 명시하면 해당 이슈를 조회한다.

출력 예시:
```
#427 — ⚙️[기능추가][Skills] 드롭다운 디자인 변경
상태: open
URL: https://github.com/owner/repo/issues/427
```

### 이슈에 댓글 추가

사용자가 댓글 내용을 주면 임시 파일에 저장 후 포스팅한다:

```bash
GITHUB_PAT={pat} python3 -m suh_template.cli add-comment {owner} {repo} {이슈번호} /tmp/comment.md
```

### PR 생성

현재 브랜치 이름을 자동 감지하여 PR을 생성한다:

```bash
git rev-parse --abbrev-ref HEAD  # head 브랜치 확인
GITHUB_PAT={pat} python3 -m suh_template.cli create-pr {owner} {repo} "{제목}" /tmp/pr_body.md {head} main
```

PR 제목은 사용자가 명시하지 않으면 현재 브랜치명의 이슈 제목을 기반으로 자동 생성한다.
브랜치명이 `YYYYMMDD_#번호_제목` 형식이면 `python3 -m suh_template.cli get-issue-number`로 이슈 번호를 추출하고 이슈 조회로 제목을 가져온다.

### PR 목록 조회

repo의 열린 PR 목록은 GitHub API를 직접 호출한다:

```bash
GITHUB_PAT={pat} python3 -c "
import sys; sys.path.insert(0, 'scripts')
from suh_template.gh_client import list_issues
# PR 목록은 pulls endpoint를 직접 사용
import urllib.request, json, os
url = 'https://api.github.com/repos/{owner}/{repo}/pulls?state=open'
req = urllib.request.Request(url, headers={
    'Authorization': f'Bearer {pat}',
    'Accept': 'application/vnd.github+json',
})
with urllib.request.urlopen(req) as r:
    prs = json.loads(r.read())
    for pr in prs:
        print(f\"#{pr['number']} — {pr['title']}\")
"
```

## 오류 처리

| 오류 코드 | 의미 | 대응 |
|-----------|------|------|
| `missing_pat` | GITHUB_PAT 미설정 | `/issue` 스킬로 PAT 등록 안내 |
| `github_api_401` | PAT 인증 실패 | PAT 갱신 안내 |
| `github_api_404` | 이슈/PR 없음 | 번호 재확인 요청 |
| `github_api_422` | 이미 PR 존재 등 | API 오류 메시지 그대로 안내 |
```

- [ ] **Step 3: `.cursor/skills/github.mdc` 작성**

`skills/github/SKILL.md`와 동일한 내용을 `.cursor/skills/github.mdc`에 저장한다.

- [ ] **Step 4: 커밋**

```bash
git add skills/github/ .cursor/skills/github.mdc
git commit -m "feat: github 스킬 신규 생성 [skip ci]"
```

---

### Task 7: CLAUDE.md Skills 테이블 업데이트

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: CLAUDE.md의 Skills 섹션 확인**

```bash
grep -n "github\|issue\|report" CLAUDE.md | head -20
```

- [ ] **Step 2: Skills 테이블에 `github` 항목 추가**

`CLAUDE.md`의 Skills 테이블에서 `issue` 행 아래에 다음 행을 추가한다:

```
| `github` | GitHub 이슈/PR 조회·댓글·PR 생성 |
```

기존 `issue` 행의 설명도 업데이트한다:

```
| `issue` | 이슈 작성 + GitHub 등록 + 브랜치 생성 |
```

기존 `report` 행의 설명도 업데이트한다:

```
| `report` | 구현 보고서 생성 + GitHub 댓글 포스팅 |
```

- [ ] **Step 3: 커밋**

```bash
git add CLAUDE.md
git commit -m "docs: CLAUDE.md Skills 테이블에 github 스킬 추가 [skip ci]"
```

---

## 자가 검토

**스펙 커버리지 확인:**

| 스펙 요구사항 | 담당 Task |
|---------------|-----------|
| `gh_branch.py` normalize_title, create_branch_name, get_commit_template | Task 1 |
| `gh_client.py` 5개 함수 + GitHubAPIError | Task 2 |
| CLI: create-branch-name, create-issue, add-comment, get-issue, create-pr | Task 3 |
| GITHUB_PAT 환경변수 | Task 3 |
| `__init__.py` SUPPORTED_SKILL_IDS에 'github' 추가 | Task 3 |
| `/issue` 스킬: 허용 이모지+태그 파싱, GitHub 생성, 브랜치 선택지 | Task 4 |
| `/report` 스킬: GitHub 댓글 포스팅 | Task 5 |
| `/github` 스킬 신규: 이슈 조회/댓글/PR 생성/PR 조회 | Task 6 |
| `.cursor/skills/` 동기화 | Task 4, 5, 6 |
| CLAUDE.md 업데이트 | Task 7 |

**타입 일관성:**
- `create_branch_name(issue_title, issue_number, date_yyyymmdd)` — Task 1 정의 → Task 3 CLI에서 동일 시그니처 사용 ✅
- `GitHubAPIError.status_code` — Task 2 정의 → Task 3 CLI에서 `e.status_code` 사용 ✅
- `create_issue` 반환 `{number, url, title}` — Task 2 정의 → Task 4 스킬에서 `number`, `url` 사용 ✅
- `add_comment` 반환 `{id, url}` — Task 2 정의 → Task 5 스킬에서 `id`, `url` 사용 ✅
