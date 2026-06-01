#!/usr/bin/env python3
"""issue_cli — suh-issue skill 전용 CLI.

이슈 작성 워크플로우 헬퍼.
서브커맨드: create-issue, search-issues, get-next-seq, normalize-title,
           create-branch-name, get-commit-template, update-issue

사용법:
    cd skills/suh-issue/scripts
    python issue_cli.py <subcommand> [args]
"""
from __future__ import annotations

import sys
import argparse
import subprocess
from datetime import date
from pathlib import Path

_HERE = Path(__file__).resolve()
_PROJECT_ROOT = _HERE.parents[3]
_SCRIPTS_ROOT = _PROJECT_ROOT / "scripts"
if str(_SCRIPTS_ROOT) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_ROOT))

from common.emit import emit  # noqa: E402
from common.config import get_github_pat  # noqa: E402
from common.gh_client import GitHubAPIError, create_issue, search_issues, update_issue  # noqa: E402


def cmd_create_issue(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    body = Path(args.body_file).read_text(encoding="utf-8") if Path(args.body_file).exists() else ""
    labels = [l.strip() for l in args.labels.split(",") if l.strip()] if args.labels else []
    try:
        result = create_issue(args.owner, args.repo, args.title, body, labels, pat, [])
        return emit({**result, "summary": f"이슈 #{result.get('number')} 생성 완료"})
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


def cmd_search_issues(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    keyword = " ".join(args.keywords)
    try:
        result = search_issues(args.owner, args.repo, keyword, pat)
        return emit({"count": len(result), "items": result, "summary": f"\"{keyword}\" 검색 {len(result)}건"})
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


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


def cmd_get_next_seq(args) -> int:
    from common.paths import get_next_seq
    try:
        root_str = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except subprocess.CalledProcessError:
        return emit({"ok": False, "code": "git_not_found", "error": "git 저장소 아님"})
    skill_dir = Path(root_str) / "docs" / "suh-template" / args.skill_id
    today = date.today().strftime("%Y%m%d")
    seq = get_next_seq(skill_dir, today)
    return emit({"seq": seq, "summary": f"{args.skill_id} 다음 seq: {seq}"})


def cmd_normalize_title(args) -> int:
    from common.title import normalize
    result = normalize(" ".join(args.title))
    return emit({"normalized": result, "summary": result})


def cmd_create_branch_name(args) -> int:
    from common.gh_branch import create_branch_name
    name = create_branch_name(args.issue_title, args.issue_number, args.date)
    return emit({"branch": name, "summary": name})


def cmd_get_commit_template(args) -> int:
    from common.gh_branch import get_commit_template
    template = get_commit_template(args.issue_title, args.issue_url)
    return emit({"template": template, "summary": template})


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="issue_cli", description="suh-issue skill CLI")
    sub = parser.add_subparsers(dest="command", required=True)

    p_ci = sub.add_parser("create-issue", help="이슈 생성")
    p_ci.add_argument("owner")
    p_ci.add_argument("repo")
    p_ci.add_argument("title")
    p_ci.add_argument("body_file")
    p_ci.add_argument("labels", help="csv")
    p_ci.set_defaults(func=cmd_create_issue)

    p_si = sub.add_parser("search-issues", help="중복 검사용 이슈 검색")
    p_si.add_argument("owner")
    p_si.add_argument("repo")
    p_si.add_argument("keywords", nargs="+")
    p_si.set_defaults(func=cmd_search_issues)

    p_ui = sub.add_parser("update-issue", help="이슈 수정 (담당자 지정 등)")
    p_ui.add_argument("owner")
    p_ui.add_argument("repo")
    p_ui.add_argument("number", type=int)
    p_ui.add_argument("--title")
    p_ui.add_argument("--state", choices=["open", "closed"])
    p_ui.add_argument("--labels")
    p_ui.add_argument("--assignees")
    p_ui.set_defaults(func=cmd_update_issue)

    p_gns = sub.add_parser("get-next-seq", help="다음 시퀀스 번호")
    p_gns.add_argument("skill_id")
    p_gns.set_defaults(func=cmd_get_next_seq)

    p_nt = sub.add_parser("normalize-title", help="제목 정규화")
    p_nt.add_argument("title", nargs="+")
    p_nt.set_defaults(func=cmd_normalize_title)

    p_cbn = sub.add_parser("create-branch-name", help="브랜치명 생성")
    p_cbn.add_argument("issue_title")
    p_cbn.add_argument("issue_number", type=int)
    p_cbn.add_argument("--date", help="YYYYMMDD")
    p_cbn.set_defaults(func=cmd_create_branch_name)

    p_gct = sub.add_parser("get-commit-template", help="커밋 메시지 템플릿")
    p_gct.add_argument("issue_title")
    p_gct.add_argument("issue_url")
    p_gct.set_defaults(func=cmd_get_commit_template)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    if not hasattr(args, "func"):
        parser.print_help(sys.stderr)
        return 1
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
