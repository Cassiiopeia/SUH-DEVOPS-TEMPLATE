"""GitHub REST API 클라이언트 — urllib 표준 라이브러리만 사용."""

from __future__ import annotations

import json
import urllib.error
import urllib.parse
import urllib.request
from typing import Any


_API_BASE = "https://api.github.com"


class GitHubAPIError(Exception):
    """GitHub API 요청 중 발생하는 에러."""
    def __init__(self, status_code: int, message: str) -> None:
        super().__init__(f"GitHub API {status_code}: {message}")
        self.status_code = status_code
        self.message = message


class _StripAuthRedirect(urllib.request.HTTPRedirectHandler):
    """redirect 시 Authorization 헤더를 제거한다.

    GitHub job logs 등 일부 엔드포인트는 Azure Blob(SAS URL)로 302 redirect되는데,
    urllib 기본 동작은 Authorization 헤더를 redirect 대상까지 전달한다.
    Azure는 이를 거부하고 403 AuthenticationFailed를 반환하므로 헤더를 제거해야 한다.
    """
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        new = super().redirect_request(req, fp, code, msg, headers, newurl)
        if new is not None:
            new.headers.pop("Authorization", None)
            new.unredirected_hdrs.pop("Authorization", None)
        return new


_opener = urllib.request.build_opener(_StripAuthRedirect)


def _request(method: str, url: str, data: dict | None, pat: str, raw: bool = False) -> Any:
    """GitHub API 요청을 보내고 응답을 반환한다.

    raw=False: 응답 본문을 JSON으로 파싱해 반환.
    raw=True: 디코딩한 텍스트(str)를 그대로 반환 (로그 등 비 JSON 응답용).
    """
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
            "User-Agent": "suh-template",
        },
    )
    try:
        with _opener.open(req) as resp:
            content = resp.read()
            if raw:
                return content.decode("utf-8", "replace")
            return json.loads(content.decode())
    except urllib.error.HTTPError as e:
        body_bytes = e.fp.read() if e.fp else b""
        try:
            msg = json.loads(body_bytes).get("message", str(e))
        except Exception:
            msg = body_bytes.decode("utf-8", "replace")[:200] or str(e)
        raise GitHubAPIError(e.code, msg) from e


def list_labels(owner: str, repo: str, pat: str) -> list[str]:
    """레포의 라벨 이름 목록을 반환한다."""
    items = _request("GET", f"{_API_BASE}/repos/{owner}/{repo}/labels?per_page=100", None, pat)
    return [item["name"] for item in items]


def create_issue(
    owner: str, repo: str, title: str, body: str,
    labels: list[str], pat: str, assignees: list[str] | None = None,
) -> dict:
    """이슈를 생성하고 {number, url, title}을 반환한다."""
    # 존재하지 않는 라벨은 422를 유발하므로 사전에 필터링
    if labels:
        existing = list_labels(owner, repo, pat)
        labels = [l for l in labels if l in existing]
    payload: dict = {"title": title, "body": body, "labels": labels}
    if assignees:
        payload["assignees"] = assignees
    data = _request("POST", f"{_API_BASE}/repos/{owner}/{repo}/issues", payload, pat)
    return {"number": data["number"], "url": data["html_url"], "title": data["title"]}


def update_issue(
    owner: str, repo: str, issue_number: int, pat: str,
    title: str | None = None, body: str | None = None,
    state: str | None = None, labels: list[str] | None = None,
    assignees: list[str] | None = None,
) -> dict:
    """이슈를 수정하고 {number, url, title}을 반환한다."""
    payload: dict = {}
    if title is not None:
        payload["title"] = title
    if body is not None:
        payload["body"] = body
    if state is not None:
        payload["state"] = state
    if labels is not None:
        payload["labels"] = labels
    if assignees is not None:
        payload["assignees"] = assignees
    data = _request("PATCH", f"{_API_BASE}/repos/{owner}/{repo}/issues/{issue_number}", payload, pat)
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


def list_pulls(
    owner: str, repo: str, pat: str, state: str = "open",
) -> list[dict]:
    """PR 목록을 조회한다."""
    items = _request(
        "GET",
        f"{_API_BASE}/repos/{owner}/{repo}/pulls?state={state}&per_page=50",
        None,
        pat,
    )
    return [
        {"number": i["number"], "title": i["title"], "url": i["html_url"], "state": i["state"]}
        for i in items
    ]


def search_issues(
    owner: str, repo: str, keyword: str, pat: str, per_page: int = 5,
) -> list[dict]:
    """레포 내 제목에 keyword가 포함된 이슈를 검색한다 (중복 이슈 판단용)."""
    q = urllib.parse.quote(f"is:issue repo:{owner}/{repo} in:title {keyword}", safe="")
    data = _request(
        "GET", f"{_API_BASE}/search/issues?q={q}&per_page={per_page}", None, pat
    )
    items = data.get("items", []) if isinstance(data, dict) else []
    return [
        {
            "number": i["number"],
            "title": i["title"],
            "url": i["html_url"],
            "state": i["state"],
        }
        for i in items
    ]


def update_pull_request(
    owner: str, repo: str, pr_number: int, pat: str,
    title: str | None = None, body: str | None = None,
    state: str | None = None, base: str | None = None,
) -> dict:
    """PR을 수정하고 {number, url}을 반환한다. PR 본문(릴리스 노트) 업데이트 등에 사용."""
    payload: dict = {}
    if title is not None:
        payload["title"] = title
    if body is not None:
        payload["body"] = body
    if state is not None:
        payload["state"] = state
    if base is not None:
        payload["base"] = base
    data = _request(
        "PATCH", f"{_API_BASE}/repos/{owner}/{repo}/pulls/{pr_number}", payload, pat
    )
    return {"number": data["number"], "url": data["html_url"]}


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


# --- GitHub Actions ---

def _run_summary(run: dict) -> dict:
    """workflow run 객체에서 요약 필드만 추출한다."""
    return {
        "run_id": run["id"],
        "name": run.get("name"),
        "branch": run.get("head_branch"),
        "event": run.get("event"),
        "status": run.get("status"),
        "conclusion": run.get("conclusion"),
        "created_at": (run.get("created_at") or "")[:16],
        "url": run.get("html_url"),
    }


def get_run(owner: str, repo: str, run_id: int, pat: str) -> dict:
    """단일 run 메타 + job 목록(실패 step 포함)을 반환한다."""
    run = _request("GET", f"{_API_BASE}/repos/{owner}/{repo}/actions/runs/{run_id}", None, pat)
    result = _run_summary(run)
    jobs_data = _request(
        "GET", f"{_API_BASE}/repos/{owner}/{repo}/actions/runs/{run_id}/jobs?per_page=100", None, pat
    )
    jobs = []
    failed_job_ids = []
    for j in jobs_data.get("jobs", []):
        failed_steps = [
            s["name"] for s in (j.get("steps") or []) if s.get("conclusion") == "failure"
        ]
        jobs.append({
            "job_id": j["id"],
            "name": j["name"],
            "conclusion": j.get("conclusion"),
            "failed_steps": failed_steps,
        })
        if j.get("conclusion") == "failure":
            failed_job_ids.append(j["id"])
    result["jobs"] = jobs
    result["failed_job_ids"] = failed_job_ids
    return result


def get_job_log(
    owner: str, repo: str, job_id: int, pat: str,
    grep: str = "error", tail: int = 30,
) -> dict:
    """job 로그를 받아 grep 매칭 라인의 끝 tail개를 반환한다.

    job logs 엔드포인트는 Azure로 redirect되므로 _request의 strip 핸들러가 필수.
    """
    text = _request(
        "GET", f"{_API_BASE}/repos/{owner}/{repo}/actions/jobs/{job_id}/logs", None, pat, raw=True
    )
    all_lines = text.splitlines()
    needle = grep.lower()
    matched = [l for l in all_lines if needle in l.lower()]
    return {
        "job_id": job_id,
        "total_lines": len(all_lines),
        "matched_count": len(matched),
        "grep": grep,
        "lines": [l[:300] for l in matched[-tail:]],
    }


def list_failed_runs(owner: str, repo: str, pat: str, limit: int = 10) -> list[dict]:
    """최근 실패(conclusion=failure) run 목록을 반환한다."""
    data = _request(
        "GET",
        f"{_API_BASE}/repos/{owner}/{repo}/actions/runs?status=failure&per_page={limit}",
        None, pat,
    )
    return [_run_summary(r) for r in data.get("workflow_runs", [])]


def resolve_pr_runs(owner: str, repo: str, pr_number: int, pat: str) -> dict:
    """PR 번호 → head SHA → 연결된 run 목록을 반환한다."""
    pr = _request("GET", f"{_API_BASE}/repos/{owner}/{repo}/pulls/{pr_number}", None, pat)
    head_sha = pr["head"]["sha"]
    head_ref = pr["head"]["ref"]
    runs = _request(
        "GET",
        f"{_API_BASE}/repos/{owner}/{repo}/actions/runs?head_sha={head_sha}&per_page=30",
        None, pat,
    )
    return {
        "pr_number": pr_number,
        "head_sha": head_sha,
        "head_ref": head_ref,
        "runs": [_run_summary(r) for r in runs.get("workflow_runs", [])],
    }


def resolve_branch_runs(owner: str, repo: str, branch: str, pat: str, limit: int = 10) -> list[dict]:
    """브랜치명 → 해당 브랜치의 최근 run 목록을 반환한다."""
    enc = urllib.parse.quote(branch, safe="")
    data = _request(
        "GET",
        f"{_API_BASE}/repos/{owner}/{repo}/actions/runs?branch={enc}&per_page={limit}",
        None, pat,
    )
    return [_run_summary(r) for r in data.get("workflow_runs", [])]
