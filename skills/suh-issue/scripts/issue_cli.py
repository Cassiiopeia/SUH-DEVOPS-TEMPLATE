#!/usr/bin/env python3
"""issue_cli — suh-issue skill 전용 CLI.

이슈 작성 워크플로우 헬퍼.
서브커맨드: create-issue, search-issues, normalize-title,
           create-branch-name, get-commit-template, update-issue

사용법:
    cd skills/suh-issue/scripts
    python issue_cli.py <subcommand> [args]
"""
from __future__ import annotations

import sys
from pathlib import Path

_HERE = Path(__file__).resolve()
_PROJECT_ROOT = _HERE.parents[3]
_SCRIPTS_ROOT = _PROJECT_ROOT / "scripts"
if str(_SCRIPTS_ROOT) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_ROOT))

from common.emit import emit  # noqa: E402
from common.config import get_github_pat  # noqa: E402
from common.gh_client import GitHubAPIError, create_issue, search_issues, update_issue  # noqa: E402
from common.cli_parser import JSONArgumentParser, run_cli  # noqa: E402


def cmd_create_issue(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    body = Path(args.body_file).read_text(encoding="utf-8") if Path(args.body_file).exists() else ""
    labels = [l.strip() for l in args.labels.split(",") if l.strip()] if args.labels else []
    # 담당자는 csv로 받는다. agent가 config의 assignee(레포별 → default_assignee 우선순위)를
    # 해석해 넘긴다. 비면 담당자 없이 생성 (기존 동작과 호환).
    assignees = [a.strip() for a in args.assignees.split(",") if a.strip()] if args.assignees else []
    try:
        result = create_issue(args.owner, args.repo, args.title, body, labels, pat, assignees)
        # 요청한 담당자 중 실제로 반영되지 않은 사람을 경고로 surface (이슈 자체는 성공).
        # 유효하지 않은 담당자는 GitHub이 조용히 누락시키므로 여기서 비교해 알린다.
        applied = result.get("assignees", [])
        missing = [a for a in assignees if a not in applied]
        out = {**result, "summary": f"이슈 #{result.get('number')} 생성 완료"}
        if missing:
            out["assignee_warning"] = (
                f"담당자 지정 일부 실패: {', '.join(missing)} (레포 협업자/권한 확인 필요). 이슈는 정상 생성됨."
            )
        return emit(out)
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


def build_parser() -> JSONArgumentParser:
    parser = JSONArgumentParser(prog="issue_cli", description="suh-issue skill CLI")
    sub = parser.add_subparsers(dest="command", required=True)

    p_ci = sub.add_parser("create-issue", help="이슈 생성")
    p_ci.add_argument("owner")
    p_ci.add_argument("repo")
    p_ci.add_argument("title")
    p_ci.add_argument("body_file")
    p_ci.add_argument("labels", help="csv")
    p_ci.add_argument("--assignees", help="담당자 csv (config의 assignee를 agent가 해석해 전달)")
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

    # get-next-seq 제거됨 (이슈 #329) — paths.get_next_seq는 다른 CLI가 내부 사용

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
    return run_cli(build_parser())


if __name__ == "__main__":
    sys.exit(main())
