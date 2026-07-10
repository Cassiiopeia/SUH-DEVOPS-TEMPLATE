#!/usr/bin/env python3
"""report_cli — report skill 전용 CLI.

구현 보고서 출력 경로 계산 + PR 댓글 포스팅.
서브커맨드: get-output-path, add-comment

사용법:
    cd skills/pro-report/scripts
    python report_cli.py <subcommand> [args]
"""
from __future__ import annotations

import os
import sys
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
from common.gh_client import GitHubAPIError, add_comment  # noqa: E402
from common.cli_parser import JSONArgumentParser, run_cli  # noqa: E402


def _resolve_output_path(skill_id: str, forced_title: str | None) -> dict:
    """get-output-path 공통 로직 — issue_number + paths + title 조합."""
    from common.issue_number import (
        extract_from_path as in_extract_from_path,
        extract_from_branch, get_current_branch, resolve,
    )
    from common.title import normalize, extract_from_path as title_extract_from_path
    from common.paths import get_next_seq, build_output_path

    cwd = os.getcwd()
    today = date.today().strftime("%Y%m%d")

    wt_number = in_extract_from_path(cwd)
    branch = get_current_branch()
    br_number = extract_from_branch(branch) if branch else None
    issue_num, mismatch = resolve(wt_number, br_number)

    try:
        root_str = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
    except subprocess.CalledProcessError:
        return {"ok": False, "code": "git_not_found", "error": "git 저장소 아님"}

    project_root = Path(root_str)
    output_base = project_root / "docs" / "projectops"
    skill_dir = output_base / skill_id

    number = issue_num if issue_num else get_next_seq(skill_dir, today)

    if forced_title:
        final_title = normalize(forced_title)
    else:
        raw = title_extract_from_path(cwd)
        final_title = normalize(raw) if raw else "untitled"

    path = build_output_path(output_base, skill_id, today, number, final_title)
    return {"path": str(path), "summary": str(path), "mismatch": mismatch}


def cmd_get_output_path(args) -> int:
    result = _resolve_output_path(args.skill_id, args.title)
    return emit(result)


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
        return emit({**result, "summary": f"#{args.number}에 댓글 추가"})
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


def build_parser() -> JSONArgumentParser:
    parser = JSONArgumentParser(prog="report_cli", description="report skill CLI")
    sub = parser.add_subparsers(dest="command", required=True)

    p_gop = sub.add_parser("get-output-path", help="보고서 출력 경로")
    p_gop.add_argument("skill_id", nargs="?", default="report")
    p_gop.add_argument("--title")
    p_gop.set_defaults(func=cmd_get_output_path)

    p_ac = sub.add_parser("add-comment", help="이슈 댓글 추가 (보고서 포스팅)")
    p_ac.add_argument("owner")
    p_ac.add_argument("repo")
    p_ac.add_argument("number", type=int)
    p_ac.add_argument("body_file")
    p_ac.set_defaults(func=cmd_add_comment)

    return parser


def main() -> int:
    return run_cli(build_parser())


if __name__ == "__main__":
    sys.exit(main())
