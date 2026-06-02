#!/usr/bin/env python3
"""review_cli — suh-review skill 전용 CLI.

코드 리뷰 결과 출력 경로 계산.
서브커맨드: get-output-path
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
from common.cli_parser import JSONArgumentParser, run_cli  # noqa: E402


def cmd_get_output_path(args) -> int:
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
        return emit({"ok": False, "code": "git_not_found", "error": "git 저장소 아님"})

    project_root = Path(root_str)
    output_base = project_root / "docs" / "suh-template"
    skill_dir = output_base / args.skill_id

    number = issue_num if issue_num else get_next_seq(skill_dir, today)

    if args.title:
        final_title = normalize(args.title)
    else:
        raw = title_extract_from_path(cwd)
        final_title = normalize(raw) if raw else "untitled"

    path = build_output_path(output_base, args.skill_id, today, number, final_title)
    return emit({"path": str(path), "summary": str(path), "mismatch": mismatch})


def build_parser() -> JSONArgumentParser:
    parser = JSONArgumentParser(prog="review_cli", description="suh-review skill CLI")
    sub = parser.add_subparsers(dest="command", required=True)

    p_gop = sub.add_parser("get-output-path", help="리뷰 결과 출력 경로")
    p_gop.add_argument("skill_id", nargs="?", default="review")
    p_gop.add_argument("--title")
    p_gop.set_defaults(func=cmd_get_output_path)

    return parser


def main() -> int:
    return run_cli(build_parser())


if __name__ == "__main__":
    sys.exit(main())
