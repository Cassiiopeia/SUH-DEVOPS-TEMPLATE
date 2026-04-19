"""GitHub REST API 클라이언트 — urllib 표준 라이브러리만 사용."""

from __future__ import annotations

import json
import urllib.error
import urllib.request
from typing import Any


_API_BASE = "https://api.github.com"


class GitHubAPIError(Exception):
    """GitHub API 요청 중 발생하는 에러."""
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
