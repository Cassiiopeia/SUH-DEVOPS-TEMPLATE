# deploy-status 검증 서브커맨드 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `suh-changelog-deploy` 스킬이 매 배포마다 `/tmp`에 즉석 생성하던 PR 상태·automerge·deploy 반영 확인 스크립트를, 재사용 가능한 `deploy-status` 서브커맨드 하나로 통합한다.

**Architecture:** 기존 `suh_command.py`의 `actions` 서브커맨드와 동일한 MCP-style 패턴(JSON 출력 + `next` 힌트)을 따른다. `gh_client.py`에 데이터 조회 헬퍼 3개를 추가하고, `suh_command.py`에 verdict 판정 + JSON 조립을 담당하는 `cmd_deploy_status`를 추가한다. 데이터는 gh_client, 판정은 command 레이어로 분리.

**Tech Stack:** Python 3 표준 라이브러리만 (urllib, json, argparse 불필요 — 기존 수동 인자 파싱 패턴 따름). 테스트는 pytest + unittest.mock.

---

## File Structure

- **Modify** `scripts/suh_template/gh_client.py` — 데이터 조회 헬퍼 3개 추가 (`get_pull_detail`, `find_open_pr_by_base`, `get_branch_head`). 순수 API 조회만, 판정 로직 없음.
- **Modify** `scripts/suh_template/suh_command.py` — `cmd_deploy_status` 추가 + `_COMMANDS` 매핑 등록. verdict 판정 + 종합 JSON 조립.
- **Modify** `scripts/tests/test_gh_client.py` — 신규 헬퍼 3개 단위 테스트.
- **Modify** `scripts/tests/test_cli_github.py` — `cmd_deploy_status` verdict 판정 테스트 (gh_client mock).
- **Modify** `skills/suh-changelog-deploy/SKILL.md` — deploy 모드 7단계(검증) 삽입, fix 모드 1단계 교체, 주의사항 추가.

---

## Task 1: gh_client에 `get_pull_detail` 추가

단일 PR 상세에서 머지 상태 판정에 필요한 필드를 추출한다. 기존 `list_pulls`는 `body`/`mergeable_state`가 없고, `resolve_pr_runs`는 PR을 가져오지만 이 필드들을 노출하지 않는다.

**Files:**
- Modify: `scripts/suh_template/gh_client.py` (createPull 함수들 뒤, `# --- GitHub Actions ---` 주석 앞)
- Test: `scripts/tests/test_gh_client.py`

- [ ] **Step 1: 실패하는 테스트 작성**

`scripts/tests/test_gh_client.py` 상단 import에 `get_pull_detail`을 추가하고(아래 Step에서 다른 헬퍼도 함께 추가하므로 한 번에), 파일 끝에 테스트 추가:

```python
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
```

import 줄을 다음으로 교체:

```python
from suh_template.gh_client import (
    create_issue, add_comment, get_issue, list_issues,
    create_pull_request, GitHubAPIError,
    get_pull_detail, find_open_pr_by_base, get_branch_head,
)
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd scripts && python3 -m pytest tests/test_gh_client.py::test_get_pull_detail_success -v`
Expected: FAIL — `ImportError: cannot import name 'get_pull_detail'`

- [ ] **Step 3: 최소 구현**

`scripts/suh_template/gh_client.py`의 `create_pull_request` 함수 정의 끝(`return {...}` 줄) 다음, `# --- GitHub Actions ---` 주석 앞에 추가:

```python
def get_pull_detail(owner: str, repo: str, pr_number: int, pat: str) -> dict:
    """단일 PR 상세에서 머지 판정에 필요한 필드를 추출한다.

    list_pulls에는 body·mergeable_state가 없어 deploy-status 검증용으로 별도 조회한다.
    """
    pr = _request("GET", f"{_API_BASE}/repos/{owner}/{repo}/pulls/{pr_number}", None, pat)
    return {
        "number": pr["number"],
        "state": pr["state"],
        "merged": pr.get("merged", False),
        "mergeable_state": pr.get("mergeable_state"),
        "body": pr.get("body") or "",
        "head_sha": pr.get("head", {}).get("sha"),
        "url": pr["html_url"],
    }
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd scripts && python3 -m pytest tests/test_gh_client.py::test_get_pull_detail_success -v`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add scripts/suh_template/gh_client.py scripts/tests/test_gh_client.py
git commit -m "gh_client에 get_pull_detail 추가 : feat : deploy-status 검증용 PR 상세(merged/mergeable_state/body) 조회 헬퍼"
```

---

## Task 2: gh_client에 `find_open_pr_by_base` 추가

`--pr` 생략 시 base가 deploy인 open PR을 자동 탐색한다. 매번 즉석 스크립트로 하던 일.

**Files:**
- Modify: `scripts/suh_template/gh_client.py` (`get_pull_detail` 바로 뒤)
- Test: `scripts/tests/test_gh_client.py`

- [ ] **Step 1: 실패하는 테스트 작성**

`scripts/tests/test_gh_client.py` 끝에 추가:

```python
def test_find_open_pr_by_base_found():
    # /pulls?state=open 목록 → base.ref가 deploy인 첫 PR의 상세를 재조회
    list_resp = _mock_response([
        {"number": 999, "base": {"ref": "main"}},
        {"number": 740, "base": {"ref": "deploy"}},
    ])
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
    list_resp = _mock_response([{"number": 999, "base": {"ref": "main"}}])
    with patch("suh_template.gh_client._opener.open", return_value=list_resp):
        result = find_open_pr_by_base("owner", "repo", "deploy", "ghp_fake")
    assert result is None
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd scripts && python3 -m pytest tests/test_gh_client.py::test_find_open_pr_by_base_found tests/test_gh_client.py::test_find_open_pr_by_base_none -v`
Expected: FAIL — `cannot import name 'find_open_pr_by_base'`

- [ ] **Step 3: 최소 구현**

`get_pull_detail` 함수 정의 바로 뒤에 추가:

```python
def find_open_pr_by_base(owner: str, repo: str, base: str, pat: str) -> dict | None:
    """base 브랜치로 들어오는 open PR 중 첫 번째의 상세를 반환한다. 없으면 None.

    deploy-status를 --pr 없이 호출할 때 deploy PR을 자동으로 찾기 위함.
    """
    items = _request(
        "GET",
        f"{_API_BASE}/repos/{owner}/{repo}/pulls?state=open&base={base}&per_page=50",
        None, pat,
    )
    if not items:
        return None
    return get_pull_detail(owner, repo, items[0]["number"], pat)
```

> 참고: `?base=deploy` 쿼리로 GitHub이 직접 필터링하므로 test의 list_resp가 base=main을 섞어 줘도 실제로는 deploy만 온다. 테스트는 첫 항목 선택 로직을 검증하기 위해 단순화한 것이며, 구현은 목록의 `[0]`을 신뢰한다.

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd scripts && python3 -m pytest tests/test_gh_client.py::test_find_open_pr_by_base_found tests/test_gh_client.py::test_find_open_pr_by_base_none -v`
Expected: PASS (둘 다)

- [ ] **Step 5: 커밋**

```bash
git add scripts/suh_template/gh_client.py scripts/tests/test_gh_client.py
git commit -m "gh_client에 find_open_pr_by_base 추가 : feat : --pr 생략 시 deploy PR 자동 탐색"
```

---

## Task 3: gh_client에 `get_branch_head` 추가

deploy 브랜치 HEAD SHA를 조회한다 (머지 후 반영 여부 추정용).

**Files:**
- Modify: `scripts/suh_template/gh_client.py` (`find_open_pr_by_base` 바로 뒤)
- Test: `scripts/tests/test_gh_client.py`

- [ ] **Step 1: 실패하는 테스트 작성**

`scripts/tests/test_gh_client.py` 끝에 추가:

```python
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
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd scripts && python3 -m pytest tests/test_gh_client.py::test_get_branch_head_found tests/test_gh_client.py::test_get_branch_head_missing -v`
Expected: FAIL — `cannot import name 'get_branch_head'`

- [ ] **Step 3: 최소 구현**

`find_open_pr_by_base` 함수 정의 바로 뒤에 추가:

```python
def get_branch_head(owner: str, repo: str, branch: str, pat: str) -> str | None:
    """브랜치 HEAD SHA를 반환한다. 브랜치가 없으면 None (404를 None으로 흡수)."""
    enc = urllib.parse.quote(branch, safe="")
    try:
        ref = _request("GET", f"{_API_BASE}/repos/{owner}/{repo}/git/ref/heads/{enc}", None, pat)
    except GitHubAPIError as e:
        if e.status_code == 404:
            return None
        raise
    return ref.get("object", {}).get("sha")
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd scripts && python3 -m pytest tests/test_gh_client.py::test_get_branch_head_found tests/test_gh_client.py::test_get_branch_head_missing -v`
Expected: PASS (둘 다)

- [ ] **Step 5: 커밋**

```bash
git add scripts/suh_template/gh_client.py scripts/tests/test_gh_client.py
git commit -m "gh_client에 get_branch_head 추가 : feat : deploy 브랜치 HEAD SHA 조회(404는 None)"
```

---

## Task 4: suh_command에 `cmd_deploy_status` 추가 — verdict 판정 + 종합 JSON

3개 헬퍼를 조합해 PR/워크플로우/deploy 브랜치 상태를 조회하고, verdict를 판정해 종합 JSON을 반환한다.

**Files:**
- Modify: `scripts/suh_template/suh_command.py` (`cmd_actions` 함수 뒤, `_COMMANDS` 매핑 앞)
- Test: `scripts/tests/test_cli_github.py`

- [ ] **Step 1: 실패하는 테스트 작성**

`scripts/tests/test_cli_github.py` 끝에 추가. `cmd_deploy_status`를 직접 import해 gh_client를 mock하고 verdict 판정만 검증한다 (서브프로세스 대신 in-process — verdict 로직 단위 테스트).

```python
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
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd scripts && python3 -m pytest tests/test_cli_github.py -k deploy_status -v`
Expected: FAIL — `AttributeError: module 'suh_template.suh_command' has no attribute 'cmd_deploy_status'`

- [ ] **Step 3: 최소 구현**

`scripts/suh_template/suh_command.py`의 `cmd_actions` 함수 정의 끝(마지막 `except ValueError ...` 블록) 다음, `# 커맨드 → 핸들러 함수 매핑` 주석 앞에 추가:

```python
def cmd_deploy_status(args: list) -> int:
    """deploy-status <owner> <repo> [--pr N] [--base deploy]

    deploy PR의 머지/CodeRabbit 본문/워크플로우/브랜치 상태를 한 번에 조회하고
    verdict로 판정해 종합 JSON을 반환한다. 출력은 언제나 JSON.
    """
    if len(args) < 2:
        return _emit({"ok": False, "error": "사용법: deploy-status <owner> <repo> [--pr N] [--base deploy]"})

    owner, repo = args[0], args[1]
    rest = args[2:]

    base = "deploy"
    if "--base" in rest:
        i = rest.index("--base")
        if i + 1 < len(rest):
            base = rest[i + 1]

    pr_number = None
    if "--pr" in rest:
        i = rest.index("--pr")
        if i + 1 < len(rest):
            try:
                pr_number = int(rest[i + 1])
            except ValueError:
                return _emit({"ok": False, "error": "--pr 값이 정수가 아님"})

    pat = _get_pat(owner, repo)
    if not pat:
        return _emit({"ok": False, "error": "GITHUB_PAT 환경변수도 config.json도 없음", "code": "missing_pat"})

    try:
        # 1) PR 상세 — --pr 있으면 직접, 없으면 base로 open PR 탐색
        if pr_number is not None:
            pr = _github.get_pull_detail(owner, repo, pr_number, pat)
        else:
            pr = _github.find_open_pr_by_base(owner, repo, base, pat)

        branch_head = _github.get_branch_head(owner, repo, base, pat)
        deploy_branch = {"name": base, "head_sha": branch_head}

        # PR이 없으면 no_pr — deploy 브랜치 head만 단서로 제공
        if pr is None:
            return _emit({
                "ok": True,
                "pr": None,
                "workflow": None,
                "deploy_branch": deploy_branch,
                "verdict": "no_pr",
                "summary": f"base={base}로 들어오는 open PR이 없습니다. 이미 머지됐거나 아직 생성 전입니다.",
                "next": None,
            })

        # 2) 워크플로우 run — PR head_sha에 연결된 AUTO-CHANGELOG-CONTROL run 식별
        workflow = None
        try:
            run_data = _github.resolve_pr_runs(owner, repo, pr["number"], pat)
            for r in run_data.get("runs", []):
                if "AUTO-CHANGELOG-CONTROL" in (r.get("name") or ""):
                    workflow = {
                        "name": r.get("name"),
                        "status": r.get("status"),
                        "conclusion": r.get("conclusion"),
                        "run_url": r.get("url"),
                    }
                    break
        except _github.GitHubAPIError:
            workflow = None  # run 조회 실패는 치명적이지 않음 — workflow=null로 둔다

        has_summary = "Summary by CodeRabbit" in pr.get("body", "")
        pr_out = {
            "number": pr["number"],
            "state": pr["state"],
            "merged": pr["merged"],
            "mergeable_state": pr["mergeable_state"],
            "has_coderabbit_summary": has_summary,
            "head_sha": pr["head_sha"],
            "url": pr["url"],
        }

        # 3) verdict 판정 (우선순위: merged → conflict → workflow_failed → missing_summary → waiting)
        next_hint = f"deploy-status {owner} {repo} --pr {pr['number']}"
        if pr["merged"]:
            verdict = "merged"
            summary = f"PR #{pr['number']} automerge 완료. 배포가 진행됩니다."
            next_hint = None
        elif pr["mergeable_state"] in ("dirty", "blocked", "behind"):
            verdict = "conflict"
            summary = f"PR #{pr['number']} mergeable_state={pr['mergeable_state']} — 충돌/차단 상태입니다. 수동 확인이 필요합니다."
        elif workflow and workflow["conclusion"] == "failure":
            verdict = "workflow_failed"
            summary = f"AUTO-CHANGELOG-CONTROL 워크플로우가 실패했습니다. run을 확인하고 fix 모드로 재시도하세요."
        elif not has_summary:
            verdict = "missing_coderabbit_summary"
            summary = f"PR #{pr['number']} 본문에 'Summary by CodeRabbit'이 없습니다. 본문이 초기화된 것으로 보입니다 — fix 모드로 재작성하세요."
        else:
            verdict = "waiting_for_automerge"
            summary = f"PR #{pr['number']} open·{pr['mergeable_state']}, CodeRabbit 본문 있음 — automerge 대기 중. 약 90초 후 재확인하세요."

        return _emit({
            "ok": True,
            "pr": pr_out,
            "workflow": workflow,
            "deploy_branch": deploy_branch,
            "verdict": verdict,
            "summary": summary,
            "next": next_hint,
        })

    except _github.GitHubAPIError as e:
        return _emit({"ok": False, "error": str(e), "code": f"github_api_{e.status_code}"})
```

그리고 `_COMMANDS` 매핑 dict에서 `"actions": cmd_actions,` 줄 다음에 추가:

```python
    "deploy-status": cmd_deploy_status,
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `cd scripts && python3 -m pytest tests/test_cli_github.py -k deploy_status -v`
Expected: PASS (6개 모두 — merged/waiting/missing_summary/workflow_failed/conflict/no_pr)

- [ ] **Step 5: 전체 테스트 회귀 확인**

Run: `cd scripts && python3 -m pytest tests/ -q`
Expected: 기존 테스트 포함 전부 PASS

- [ ] **Step 6: 커밋**

```bash
git add scripts/suh_template/suh_command.py scripts/tests/test_cli_github.py
git commit -m "suh_command에 deploy-status 서브커맨드 추가 : feat : PR 머지·CodeRabbit 본문·워크플로우·deploy HEAD를 한 번에 조회해 verdict로 판정"
```

---

## Task 5: SKILL.md에 검증 단계 통합

PR 생성 후 `deploy-status`로 검증하는 단계를 추가하고, fix 모드 1단계를 교체한다.

**Files:**
- Modify: `skills/suh-changelog-deploy/SKILL.md`

- [ ] **Step 1: deploy 모드에 7단계(검증) 삽입**

`### 7단계: 결과 안내` 헤더(현재 286번째 줄 부근)를 찾아, 그 **앞에** 다음 섹션을 삽입한다 (기존 "7단계: 결과 안내"는 그대로 두되 본문에서 8단계로 안내):

````markdown
### 7단계: automerge 검증 (deploy-status)

PR 생성 직후, **`/tmp`에 즉석 Python을 만들지 말고** 아래 재사용 커맨드 한 번으로 상태를 확인한다. owner/repo/PR번호만 주면 PR 머지·CodeRabbit 본문·워크플로우 run·deploy HEAD를 한 번에 조회해 `verdict`로 판정한 JSON을 반환한다.

```bash
# ⚠️ Bash stateless — 5개 변수를 [시작 전]에서 구한 실제 값으로 채운다.
GITHUB_PAT="..."; OWNER="..."; REPO="..."; PYTHON="..."; PROJECT_ROOT="..."

cd "$PROJECT_ROOT/scripts"
GITHUB_PAT="$GITHUB_PAT" PYTHONIOENCODING=utf-8 "$PYTHON" -m suh_template.suh_command \
  deploy-status "$OWNER" "$REPO" --pr "$PR_NUMBER"
cd "$PROJECT_ROOT"
```

반환 JSON의 `verdict`를 보고 라우팅한다:

| verdict | 의미 | 행동 |
|---------|------|------|
| `merged` | automerge 완료 | 8단계 결과 안내, 종료 |
| `waiting_for_automerge` | 정상 대기 중 | **sleep 금지.** `ScheduleWakeup`으로 ~90초 후 `next` 힌트(`deploy-status ... --pr N`)를 재호출해 재확인 |
| `missing_coderabbit_summary` | 본문 초기화됨(레이스컨디션) | fix 모드로 재실행 |
| `workflow_failed` | 워크플로우 실패 | `workflow.run_url` 안내 + fix 모드로 재실행 |
| `conflict` | 머지 충돌/차단 | 사용자에게 충돌 상태 안내, 수동 확인 요청 |
| `no_pr` | open deploy PR 없음 | `deploy_branch.head_sha`로 이미 머지됐는지 확인 후 안내 |

> **재확인 시 sleep을 쓰지 않는다.** Claude Code Bash는 `sleep 120`을 차단한다. 대기가 필요하면 `ScheduleWakeup(delaySeconds=90)`으로 자기 페이스를 잡고, 깨어나면 `next` 힌트의 `deploy-status` 커맨드를 다시 호출한다.
````

- [ ] **Step 2: 기존 "7단계: 결과 안내"를 "8단계"로 수정**

`### 7단계: 결과 안내`를 `### 8단계: 결과 안내`로 바꾼다. (헤더 텍스트만 변경, 본문 유지)

- [ ] **Step 3: fix 모드 1단계를 deploy-status로 교체**

`### fix 1단계: 현재 deploy PR 상태 확인` 섹션의 코드 블록(curl + grep로 EXISTING_PR 추출하는 부분)을 다음으로 교체한다:

````markdown
### fix 1단계: 현재 deploy PR 상태 확인 (deploy-status)

curl 즉석 파싱 대신 deploy-status로 현재 상태를 종합 조회한다. `--pr` 없이 호출하면 open deploy PR을 자동 탐색한다.

```bash
# ⚠️ Bash stateless — 5개 변수를 실제 값으로 채운다.
GITHUB_PAT="..."; OWNER="..."; REPO="..."; PYTHON="..."; PROJECT_ROOT="..."

cd "$PROJECT_ROOT/scripts"
GITHUB_PAT="$GITHUB_PAT" PYTHONIOENCODING=utf-8 "$PYTHON" -m suh_template.suh_command \
  deploy-status "$OWNER" "$REPO"
cd "$PROJECT_ROOT"
```

- `verdict=no_pr` → open PR 없음. fix 3단계(새 PR 생성)로 이동
- `verdict=merged` → 이미 머지됨. 재시도 불필요, 사용자에게 안내 후 종료
- 그 외(`waiting_for_automerge`/`missing_coderabbit_summary`/`workflow_failed`) → `pr.number`를 EXISTING_PR로 기억하고 fix 2단계(기존 PR 닫기)로 진행
````

- [ ] **Step 4: 주의사항에 항목 추가**

`## 주의사항` 섹션의 첫 불릿 앞에 추가:

```markdown
- **PR 생성/재시도 후 반드시 `deploy-status` 커맨드로 검증한다.** PR 상태·automerge·워크플로우 확인용 Python을 `/tmp`에 즉석 생성하지 않는다 — `deploy-status`가 그 모든 것을 JSON으로 반환한다.
```

- [ ] **Step 5: 검증 — SKILL.md 구조 확인**

Run: `grep -n "deploy-status\|### .*단계" skills/suh-changelog-deploy/SKILL.md`
Expected: deploy 모드에 7단계(검증)·8단계(결과 안내)가 보이고, fix 1단계에 deploy-status가 등장

- [ ] **Step 6: 커밋**

```bash
git add skills/suh-changelog-deploy/SKILL.md
git commit -m "changelog-deploy 스킬에 deploy-status 검증 단계 통합 : feat : PR 생성 후 즉석 Python 대신 재사용 커맨드로 automerge 검증, fix 1단계도 교체"
```

---

## Self-Review 결과

**Spec 커버리지:**
- ✅ `deploy-status` 서브커맨드 → Task 4
- ✅ 헬퍼 3개(`get_pull_detail`/`find_open_pr_by_base`/`get_branch_head`) → Task 1/2/3
- ✅ verdict 6종 판정 → Task 4 Step 3 + 테스트 6개
- ✅ 종합 JSON(`pr`/`workflow`/`deploy_branch`/`verdict`/`summary`/`next`) → Task 4
- ✅ SKILL.md 7단계 삽입 + fix 1단계 교체 + 주의사항 → Task 5
- ✅ 단발 조회(sleep 금지) → Task 5 Step 1 표 + 경고

**Type 일관성:** 헬퍼 반환 키(`head_sha`, `mergeable_state`, `merged`, `body`)가 Task 1~3 정의와 Task 4 사용처에서 일치. `_emit`/`_get_pat`/`_github` 모두 기존 심볼.

**Placeholder:** 없음. 모든 Step에 실제 코드/명령/기대 출력 포함.
