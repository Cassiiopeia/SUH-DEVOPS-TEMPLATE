#!/usr/bin/env python3
"""github_cli — suh-github skill 전용 CLI.

GitHub API 직접 호출 도구.
서브커맨드: get-issue, get-issues, update-issue, create-pr, list-prs,
           update-pr, search-issues, add-comment, explore, secrets

사용법:
    cd skills/suh-github/scripts
    python github_cli.py <subcommand> [args]

출력 형식: 모든 서브커맨드는 stdout으로 MCP-style JSON 출력.
    {"ok": true|false, "code": "...", "summary": "...", "next": "...", ...payload}
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

# Bootstrap — scripts/common import 가능하게 sys.path 조작 (cwd 무관 동작)
_HERE = Path(__file__).resolve()
_PROJECT_ROOT = _HERE.parents[3]
_SCRIPTS_ROOT = _PROJECT_ROOT / "scripts"
if str(_SCRIPTS_ROOT) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_ROOT))

from common.emit import emit  # noqa: E402
from common.config import get_github_pat  # noqa: E402
from common.cli_parser import JSONArgumentParser, run_cli  # noqa: E402
from common.gh_client import (  # noqa: E402
    GitHubAPIError, PyNaClMissingError,
    get_issue, get_issue_comments, update_issue, create_issue,
    add_comment, list_pulls, update_pull_request, create_pull_request,
    search_issues, list_labels,
    get_user_type, list_repos, get_repo_detail, get_readme, get_languages, list_commits,
    list_secrets, set_secret,
)


# =========================================================================
# Subcommand handlers
# =========================================================================

def cmd_get_issue(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    try:
        issue = get_issue(args.owner, args.repo, args.number, pat)
        comments = get_issue_comments(args.owner, args.repo, args.number, pat) if args.with_comments else None
        return emit({
            "issue": issue,
            "comments": comments,
            "summary": f"#{issue['number']} {issue['state']} — {issue['title']}",
            "number": issue["number"],
            "title": issue["title"],
            "url": issue["url"],
            "html_url": issue["url"],
            "state": issue["state"],
            "body": issue.get("body", ""),
        })
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


def cmd_get_issues(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    issues = []
    for raw in args.numbers:
        try:
            number = int(raw)
        except ValueError:
            issues.append({"number": raw, "error": "정수 아님", "code": "invalid_argument"})
            continue
        try:
            issues.append(get_issue(args.owner, args.repo, number, pat))
        except GitHubAPIError as e:
            issues.append({"number": number, "error": str(e), "code": f"github_api_{e.status_code}"})
    return emit({
        "count": len(issues),
        "issues": issues,
        "summary": f"{len(issues)}개 이슈 조회 완료",
    })


def cmd_update_issue(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    labels = [l.strip() for l in args.labels.split(",") if l.strip()] if args.labels else None
    assignees = [a.strip() for a in args.assignees.split(",") if a.strip()] if args.assignees else None
    try:
        result = update_issue(
            args.owner, args.repo, args.number, pat,
            title=args.title, state=args.state, labels=labels, assignees=assignees,
        )
        return emit({**result, "summary": f"#{args.number} 수정 완료"})
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


def cmd_add_comment(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    body_path = Path(args.body_file)
    if not body_path.exists():
        return emit({"ok": False, "code": "body_file_not_found", "error": f"{args.body_file} 없음"})
    body = body_path.read_text(encoding="utf-8")
    try:
        result = add_comment(args.owner, args.repo, args.number, body, pat)
        return emit({**result, "summary": f"#{args.number}에 댓글 추가 완료"})
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


def cmd_create_pr(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    body_path = Path(args.body_file)
    body = body_path.read_text(encoding="utf-8") if body_path.exists() else ""
    try:
        result = create_pull_request(args.owner, args.repo, args.title, body, args.head, args.base, pat)
        return emit({
            **result,
            "summary": f"PR #{result.get('number')} 생성 완료",
            "next": f"list-prs {args.owner} {args.repo}",
        })
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


def cmd_list_prs(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    try:
        result = list_pulls(args.owner, args.repo, pat, args.state)
        return emit({
            "count": len(result),
            "prs": result,
            "summary": f"{args.owner}/{args.repo} PR {len(result)}개 ({args.state})",
        })
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


def cmd_update_pr(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    body = None
    if args.body_file:
        body_path = Path(args.body_file)
        body = body_path.read_text(encoding="utf-8") if body_path.exists() else None
    try:
        result = update_pull_request(
            args.owner, args.repo, args.number, pat,
            title=args.title, body=body, state=args.state,
        )
        return emit({**result, "summary": f"PR #{args.number} 수정 완료"})
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


def cmd_search_issues(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    keyword = " ".join(args.keywords)
    try:
        result = search_issues(args.owner, args.repo, keyword, pat)
        return emit({
            "count": len(result),
            "items": result,
            "summary": f"\"{keyword}\" 검색 {len(result)}건",
        })
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


def cmd_explore(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    try:
        if args.sub == "list-repos":
            owner_type = get_user_type(args.owner, pat) if args.type == "auto" else args.type
            repos = list_repos(args.owner, owner_type, pat)
            return emit({
                "owner": args.owner,
                "owner_type": owner_type,
                "count": len(repos),
                "repos": repos,
                "summary": f"{args.owner} {owner_type} 레포 {len(repos)}개",
                "next": f"explore repo-detail {args.owner} {repos[0]['name']}" if repos else None,
            })
        if not args.repo:
            return emit({"ok": False, "code": "missing_argument", "error": f"explore {args.sub}는 repo 인자 필요"})
        if args.sub == "repo-detail":
            detail = get_repo_detail(args.owner, args.repo, pat)
            return emit({
                "repo": detail,
                "summary": f"{args.owner}/{args.repo} 상세",
                "next": f"explore readme {args.owner} {args.repo}",
            })
        if args.sub == "readme":
            readme = get_readme(args.owner, args.repo, pat)
            return emit({
                "readme": readme,
                "summary": "README 조회",
                "next": f"explore languages {args.owner} {args.repo}",
            })
        if args.sub == "languages":
            langs = get_languages(args.owner, args.repo, pat)
            return emit({"languages": langs, "summary": f"언어 {len(langs)}개"})
        if args.sub == "commits":
            commits = list_commits(args.owner, args.repo, pat, limit=args.limit)
            return emit({
                "count": len(commits),
                "commits": commits,
                "summary": f"최근 커밋 {len(commits)}개",
            })
        return emit({"ok": False, "code": "unknown_subcommand", "error": f"알 수 없음: {args.sub}"})
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


def cmd_secrets(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    try:
        if args.sub == "list":
            secrets = list_secrets(args.owner, args.repo, pat)
            return emit({
                "count": len(secrets),
                "secrets": secrets,
                "summary": f"{args.owner}/{args.repo} secret {len(secrets)}개",
            })
        if args.sub == "set":
            if not args.name:
                return emit({"ok": False, "code": "missing_argument", "error": "name 필요"})
            value = os.environ.get("SECRET_VALUE")
            if value is None:
                return emit({
                    "ok": False, "code": "missing_secret_value",
                    "error": "SECRET_VALUE 환경변수에 값을 담아 호출하세요.",
                })
            result = set_secret(args.owner, args.repo, args.name, value, pat)
            return emit({**result, "summary": f"secret {args.name} 갱신 완료"})
        return emit({"ok": False, "code": "unknown_subcommand", "error": f"알 수 없음: {args.sub}"})
    except PyNaClMissingError as e:
        return emit({"ok": False, "code": e.code, "error": str(e), "hint": "pip install PyNaCl"})
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


# =========================================================================
# argparse setup
# =========================================================================

def build_parser() -> JSONArgumentParser:
    parser = JSONArgumentParser(
        prog="github_cli",
        description="suh-github skill 전용 GitHub API CLI",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_gi = sub.add_parser("get-issue", help="이슈 조회")
    p_gi.add_argument("owner")
    p_gi.add_argument("repo")
    p_gi.add_argument("number", type=int)
    p_gi.add_argument("--with-comments", action="store_true")
    p_gi.set_defaults(func=cmd_get_issue)

    p_gis = sub.add_parser("get-issues", help="여러 이슈 한 번에 조회")
    p_gis.add_argument("owner")
    p_gis.add_argument("repo")
    p_gis.add_argument("numbers", nargs="+")
    p_gis.set_defaults(func=cmd_get_issues)

    p_ui = sub.add_parser("update-issue", help="이슈 수정")
    p_ui.add_argument("owner")
    p_ui.add_argument("repo")
    p_ui.add_argument("number", type=int)
    p_ui.add_argument("--title")
    p_ui.add_argument("--state", choices=["open", "closed"])
    p_ui.add_argument("--labels", help="csv")
    p_ui.add_argument("--assignees", help="csv")
    p_ui.set_defaults(func=cmd_update_issue)

    p_ac = sub.add_parser("add-comment", help="이슈 댓글 추가")
    p_ac.add_argument("owner")
    p_ac.add_argument("repo")
    p_ac.add_argument("number", type=int)
    p_ac.add_argument("body_file")
    p_ac.set_defaults(func=cmd_add_comment)

    p_cp = sub.add_parser("create-pr", help="PR 생성")
    p_cp.add_argument("owner")
    p_cp.add_argument("repo")
    p_cp.add_argument("title")
    p_cp.add_argument("body_file")
    p_cp.add_argument("head")
    p_cp.add_argument("base")
    p_cp.set_defaults(func=cmd_create_pr)

    p_lp = sub.add_parser("list-prs", help="PR 목록")
    p_lp.add_argument("owner")
    p_lp.add_argument("repo")
    p_lp.add_argument("--state", choices=["open", "closed", "all"], default="open")
    p_lp.set_defaults(func=cmd_list_prs)

    p_up = sub.add_parser("update-pr", help="PR 수정")
    p_up.add_argument("owner")
    p_up.add_argument("repo")
    p_up.add_argument("number", type=int)
    p_up.add_argument("body_file", nargs="?")
    p_up.add_argument("--title")
    p_up.add_argument("--state", choices=["open", "closed"])
    p_up.set_defaults(func=cmd_update_pr)

    p_si = sub.add_parser("search-issues", help="이슈 검색")
    p_si.add_argument("owner")
    p_si.add_argument("repo")
    p_si.add_argument("keywords", nargs="+")
    p_si.set_defaults(func=cmd_search_issues)

    p_ex = sub.add_parser("explore", help="레포 탐색 (list-repos|repo-detail|readme|languages|commits)")
    p_ex.add_argument("sub", choices=["list-repos", "repo-detail", "readme", "languages", "commits"])
    p_ex.add_argument("owner")
    p_ex.add_argument("repo", nargs="?")
    p_ex.add_argument("--type", choices=["user", "org", "auto"], default="auto")
    p_ex.add_argument("--limit", type=int, default=10)
    p_ex.set_defaults(func=cmd_explore)

    p_sc = sub.add_parser("secrets", help="Actions Secret 관리 (list|set)")
    p_sc.add_argument("sub", choices=["list", "set"])
    p_sc.add_argument("owner")
    p_sc.add_argument("repo")
    p_sc.add_argument("name", nargs="?")
    p_sc.set_defaults(func=cmd_secrets)

    return parser


def main() -> int:
    return run_cli(build_parser())


if __name__ == "__main__":
    sys.exit(main())
