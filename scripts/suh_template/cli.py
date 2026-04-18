"""
suh_template CLI 진입점.

사용법:
    python3 -m suh_template.cli <command> [args]

커맨드:
    get-output-path <skill_id> [--title <제목>]
    get-issue-number
    get-next-seq <skill_id>
    normalize-title <제목>
    config-get <skill_id> <key>
    init-config <skill_id>
"""

from __future__ import annotations

import os
import sys
from datetime import date
from pathlib import Path
from typing import Optional

# 패키지 루트를 sys.path에 추가 (직접 실행 시)
_HERE = Path(__file__).parent.parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from suh_template import SUPPORTED_SKILL_IDS
from suh_template import issue_number as _issue
from suh_template import title as _title
from suh_template import paths as _paths
from suh_template import config as _config


def _err(level: str, command: str, message: str, code: str) -> None:
    """표준화된 형식으로 stderr에 메시지를 출력한다."""
    print(f"[{level}] {command}: {message} ({code})", file=sys.stderr)


def _get_project_root() -> Optional[Path]:
    """git 루트를 찾아 반환. git 저장소가 아니면 None."""
    import subprocess
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        )
        return Path(result.stdout.strip())
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def cmd_get_output_path(args: list) -> int:
    """get-output-path <skill_id> [--title <제목>]"""
    if not args:
        _err("ERROR", "get-output-path", "skill_id 인수가 필요합니다.", "missing_argument")
        return 1

    skill_id = args[0]
    if skill_id not in SUPPORTED_SKILL_IDS:
        _err("ERROR", "get-output-path",
             f"지원하지 않는 skill_id입니다. 지원: {', '.join(SUPPORTED_SKILL_IDS)}",
             "skill_id_invalid")
        return 1

    # --title 옵션 파싱
    forced_title = None
    if "--title" in args:
        idx = args.index("--title")
        if idx + 1 < len(args):
            forced_title = args[idx + 1]

    cwd = os.getcwd()
    today = date.today().strftime("%Y%m%d")

    # 이슈 번호 결정 (worktree 경로 → 브랜치 순서)
    wt_number = _issue.extract_from_path(cwd)
    branch = _issue.get_current_branch()
    br_number = _issue.extract_from_branch(branch) if branch else None
    issue_num, mismatch = _issue.resolve(wt_number, br_number)

    if mismatch:
        _err("WARN", "get-output-path",
             f"worktree({wt_number})와 브랜치({br_number}) 이슈 번호가 다릅니다. worktree 우선 사용.",
             "issue_number_mismatch")

    project_root = _get_project_root()
    if project_root is None:
        _err("ERROR", "get-output-path", "git 저장소가 아닙니다.", "git_not_found")
        return 1
    output_base = project_root / "docs" / "suh-template"
    skill_dir = output_base / skill_id

    if issue_num:
        number = issue_num
    else:
        _err("WARN", "get-output-path",
             "이슈 번호를 찾을 수 없어 누적순번으로 대체합니다.",
             "issue_number_not_found")
        number = _paths.get_next_seq(skill_dir, today)

    # 제목 결정 (--title 옵션 → 경로 추출 → untitled)
    if forced_title:
        final_title = _title.normalize(forced_title)
    else:
        raw_title = _title.extract_from_path(cwd)
        if raw_title:
            final_title = _title.normalize(raw_title)
        else:
            _err("WARN", "get-output-path",
                 "제목을 추출할 수 없습니다. --title 옵션으로 재호출하거나 'untitled' 사용.",
                 "title_not_found")
            final_title = "untitled"

    path = _paths.build_output_path(output_base, skill_id, today, number, final_title)
    print(str(path))
    return 0


def cmd_get_issue_number(_args: list) -> int:
    """get-issue-number"""
    cwd = os.getcwd()
    wt_number = _issue.extract_from_path(cwd)
    branch = _issue.get_current_branch()
    br_number = _issue.extract_from_branch(branch) if branch else None
    result, _ = _issue.resolve(wt_number, br_number)
    print(result or "")
    return 0


def cmd_get_next_seq(args: list) -> int:
    """get-next-seq <skill_id>"""
    if not args:
        _err("ERROR", "get-next-seq", "skill_id 인수가 필요합니다.", "missing_argument")
        return 1
    skill_id = args[0]
    if skill_id not in SUPPORTED_SKILL_IDS:
        _err("ERROR", "get-next-seq",
             f"지원하지 않는 skill_id입니다. 지원: {', '.join(SUPPORTED_SKILL_IDS)}",
             "skill_id_invalid")
        return 1
    project_root = _get_project_root()
    if project_root is None:
        _err("ERROR", "get-next-seq", "git 저장소가 아닙니다.", "git_not_found")
        return 1
    skill_dir = project_root / "docs" / "suh-template" / skill_id
    today = date.today().strftime("%Y%m%d")
    print(_paths.get_next_seq(skill_dir, today))
    return 0


def cmd_normalize_title(args: list) -> int:
    """normalize-title <제목>"""
    if not args:
        _err("ERROR", "normalize-title", "제목 인수가 필요합니다.", "missing_argument")
        return 1
    print(_title.normalize(" ".join(args)))
    return 0


def cmd_config_get(args: list) -> int:
    """config-get <skill_id> <key>"""
    if len(args) < 2:
        _err("ERROR", "config-get", "skill_id와 key 인수가 필요합니다.", "missing_argument")
        return 1
    skill_id, key = args[0], args[1]
    project_root = _get_project_root()
    value = _config.get_value(project_root, skill_id, key)
    if value is None:
        _err("ERROR", "config-get",
             f".suh-template/config/{skill_id}.config.json 파일이 없거나 키 '{key}'가 없습니다.",
             "config_not_found")
        return 1
    print(value)
    return 0


def cmd_init_config(args: list) -> int:
    """init-config <skill_id>

    .suh-template.example/config/{skill_id}.config.example.json 경로를 stdout에 출력한다.
    AI(skill)가 이 파일을 읽어 스키마를 파악하고 대화형 수집 후 config.save()를 호출한다.
    """
    if not args:
        _err("ERROR", "init-config", "skill_id 인수가 필요합니다.", "missing_argument")
        return 1

    skill_id = args[0]
    if skill_id not in SUPPORTED_SKILL_IDS:
        _err("ERROR", "init-config",
             f"지원하지 않는 skill_id입니다. 지원: {', '.join(SUPPORTED_SKILL_IDS)}",
             "skill_id_invalid")
        return 1

    project_root = _get_project_root()
    if project_root is None:
        _err("ERROR", "init-config", "git 저장소가 아닙니다.", "git_not_found")
        return 1

    example_path = (
        project_root / ".suh-template.example" / "config"
        / f"{skill_id}.config.example.json"
    )
    if not example_path.exists():
        _err("ERROR", "init-config",
             f".suh-template.example/config/{skill_id}.config.example.json 파일이 없습니다.",
             "example_not_found")
        return 1

    print(str(example_path))
    return 0


# 커맨드 → 핸들러 함수 매핑
_COMMANDS = {
    "get-output-path": cmd_get_output_path,
    "get-issue-number": cmd_get_issue_number,
    "get-next-seq": cmd_get_next_seq,
    "normalize-title": cmd_normalize_title,
    "config-get": cmd_config_get,
    "init-config": cmd_init_config,
}


def main() -> None:
    """CLI 진입점 — 커맨드를 파싱하고 해당 핸들러를 실행한다."""
    args = sys.argv[1:]
    if not args:
        print("사용법: python3 -m suh_template.cli <command> [args]", file=sys.stderr)
        print(f"커맨드: {', '.join(_COMMANDS)}", file=sys.stderr)
        sys.exit(1)

    command = args[0]
    if command not in _COMMANDS:
        _err("ERROR", command, f"알 수 없는 커맨드입니다. 지원: {', '.join(_COMMANDS)}", "unknown_command")
        sys.exit(1)

    sys.exit(_COMMANDS[command](args[1:]))


if __name__ == "__main__":
    main()
