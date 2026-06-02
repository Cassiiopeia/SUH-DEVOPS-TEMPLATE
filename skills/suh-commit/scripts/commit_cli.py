#!/usr/bin/env python3
"""commit_cli — suh-commit skill 전용 CLI.

브랜치명 → 이슈 번호 추출, 이슈 제목 조회, 커밋 템플릿 생성.
서브커맨드: get-issue-number, get-issue, normalize-title, get-commit-template

사용법:
    cd skills/suh-commit/scripts
    python commit_cli.py <subcommand> [args]
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

_HERE = Path(__file__).resolve()
_PROJECT_ROOT = _HERE.parents[3]
_SCRIPTS_ROOT = _PROJECT_ROOT / "scripts"
if str(_SCRIPTS_ROOT) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_ROOT))

from common.emit import emit  # noqa: E402
from common.config import get_github_pat  # noqa: E402
from common.gh_client import GitHubAPIError, get_issue  # noqa: E402
from common.cli_parser import JSONArgumentParser, run_cli  # noqa: E402


def cmd_get_issue_number(_args) -> int:
    from common.issue_number import (
        extract_from_path as in_extract_from_path,
        extract_from_branch, get_current_branch, resolve,
    )
    cwd = os.getcwd()
    wt_number = in_extract_from_path(cwd)
    branch = get_current_branch()
    br_number = extract_from_branch(branch) if branch else None
    number, mismatch = resolve(wt_number, br_number)
    return emit({
        "number": number,
        "mismatch": mismatch,
        "summary": str(number) if number else "이슈 번호 없음",
    })


def cmd_get_issue(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    try:
        issue = get_issue(args.owner, args.repo, args.number, pat)
        return emit({
            "issue": issue,
            "title": issue["title"],
            "url": issue["url"],
            "summary": f"#{issue['number']} — {issue['title']}",
        })
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


def cmd_normalize_title(args) -> int:
    from common.title import normalize
    result = normalize(" ".join(args.title))
    return emit({"normalized": result, "summary": result})


def cmd_get_commit_template(args) -> int:
    from common.gh_branch import get_commit_template
    template = get_commit_template(args.issue_title, args.issue_url)
    return emit({"template": template, "summary": template})


def build_parser() -> JSONArgumentParser:
    parser = JSONArgumentParser(prog="commit_cli", description="suh-commit skill CLI")
    sub = parser.add_subparsers(dest="command", required=True)

    p_gin = sub.add_parser("get-issue-number", help="cwd 기준 현재 이슈 번호 추출")
    p_gin.set_defaults(func=cmd_get_issue_number)

    p_gi = sub.add_parser("get-issue", help="이슈 조회")
    p_gi.add_argument("owner")
    p_gi.add_argument("repo")
    p_gi.add_argument("number", type=int)
    p_gi.set_defaults(func=cmd_get_issue)

    p_nt = sub.add_parser("normalize-title", help="제목 정규화")
    p_nt.add_argument("title", nargs="+")
    p_nt.set_defaults(func=cmd_normalize_title)

    p_gct = sub.add_parser("get-commit-template", help="커밋 메시지 템플릿")
    p_gct.add_argument("issue_title")
    p_gct.add_argument("issue_url")
    p_gct.set_defaults(func=cmd_get_commit_template)

    return parser


def main() -> int:
    return run_cli(build_parser())


if __name__ == "__main__":
    sys.exit(main())
