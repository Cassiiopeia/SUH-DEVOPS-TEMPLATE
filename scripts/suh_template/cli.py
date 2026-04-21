"""
suh_template CLI 진입점.

사용법:
    python3 -m suh_template.cli <command> [args]

커맨드:
    get-output-path <skill_id> [--title <제목>]
    get-issue-number
    get-next-seq <skill_id>
    normalize-title <제목>
    create-branch-name <issue_title> <issue_number> [--date YYYYMMDD]
    get-commit-template <issue_title> <issue_url>
    create-issue <owner> <repo> <title> <body_file> <labels_csv>
    add-comment <owner> <repo> <issue_number> <body_file>
    get-issue <owner> <repo> <issue_number>
    update-issue <owner> <repo> <issue_number> [옵션]
    create-pr <owner> <repo> <title> <body_file> <head> <base>
    list-prs <owner> <repo> [--state open|closed|all]
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
from suh_template import gh_branch as _branch
from suh_template import gh_client as _github


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



def cmd_create_branch_name(args: list) -> int:
    """create-branch-name <issue_title> <issue_number> [--date YYYYMMDD]"""
    if len(args) < 2:
        _err("ERROR", "create-branch-name", "issue_title과 issue_number 인수가 필요합니다.", "missing_argument")
        return 1
    issue_title = args[0]
    try:
        issue_number = int(args[1])
    except ValueError:
        _err("ERROR", "create-branch-name", "issue_number는 정수여야 합니다.", "invalid_argument")
        return 1
    # --date 옵션 파싱
    date_val = None
    if "--date" in args:
        idx = args.index("--date")
        if idx + 1 < len(args):
            date_val = args[idx + 1]
    print(_branch.create_branch_name(issue_title, issue_number, date_val))
    return 0


def cmd_get_commit_template(args: list) -> int:
    """get-commit-template <issue_title> <issue_url>"""
    if len(args) < 2:
        _err("ERROR", "get-commit-template", "issue_title과 issue_url 인수가 필요합니다.", "missing_argument")
        return 1
    issue_title, issue_url = args[0], args[1]
    print(_branch.get_commit_template(issue_title, issue_url))
    return 0


def _get_pat() -> Optional[str]:
    """GITHUB_PAT를 반환한다. 환경변수 우선, 없으면 config 파일에서 자동 로드."""
    pat = os.environ.get("GITHUB_PAT")
    if pat:
        return pat
    # 환경변수에 없으면 config 파일에서 폴백 로드
    project_root = _get_project_root()
    try:
        return _config.get_value(project_root, "issue", "github_pat")
    except Exception:
        return None


def cmd_create_issue(args: list) -> int:
    """create-issue <owner> <repo> <title> <body_file> <labels_csv>"""
    if len(args) < 5:
        _err("ERROR", "create-issue", "owner, repo, title, body_file, labels_csv 인수가 필요합니다.", "missing_argument")
        return 1
    pat = _get_pat()
    if not pat:
        _err("ERROR", "create-issue", "환경변수 GITHUB_PAT가 설정되지 않았습니다.", "missing_pat")
        return 1
    owner, repo, title, body_file, labels_csv = args[0], args[1], args[2], args[3], args[4]
    body = Path(body_file).read_text(encoding="utf-8") if body_file and Path(body_file).exists() else ""
    labels = [l.strip() for l in labels_csv.split(",") if l.strip()] if labels_csv else []
    assignees = []
    try:
        result = _github.create_issue(owner, repo, title, body, labels, pat, assignees)
        import json as _json
        print(_json.dumps(result, ensure_ascii=False))
        return 0
    except _github.GitHubAPIError as e:
        _err("ERROR", "create-issue", str(e), f"github_api_{e.status_code}")
        return 1


def cmd_add_comment(args: list) -> int:
    """add-comment <owner> <repo> <issue_number> <body_file>"""
    if len(args) < 4:
        _err("ERROR", "add-comment", "owner, repo, issue_number, body_file 인수가 필요합니다.", "missing_argument")
        return 1
    pat = _get_pat()
    if not pat:
        _err("ERROR", "add-comment", "환경변수 GITHUB_PAT가 설정되지 않았습니다.", "missing_pat")
        return 1
    owner, repo, issue_number, body_file = args[0], args[1], int(args[2]), args[3]
    body = Path(body_file).read_text(encoding="utf-8") if body_file and Path(body_file).exists() else ""
    try:
        result = _github.add_comment(owner, repo, issue_number, body, pat)
        import json as _json
        print(_json.dumps(result, ensure_ascii=False))
        return 0
    except _github.GitHubAPIError as e:
        _err("ERROR", "add-comment", str(e), f"github_api_{e.status_code}")
        return 1


def cmd_update_issue(args: list) -> int:
    """update-issue <owner> <repo> <issue_number> [--title <제목>] [--state open|closed] [--labels <csv>] [--assignees <csv>]"""
    if len(args) < 3:
        _err("ERROR", "update-issue", "owner, repo, issue_number 인수가 필요합니다.", "missing_argument")
        return 1
    pat = _get_pat()
    if not pat:
        _err("ERROR", "update-issue", "환경변수 GITHUB_PAT가 설정되지 않았습니다.", "missing_pat")
        return 1
    owner, repo, issue_number = args[0], args[1], int(args[2])
    rest = args[3:]

    def _opt(key: str) -> Optional[str]:
        if key in rest:
            idx = rest.index(key)
            return rest[idx + 1] if idx + 1 < len(rest) else None
        return None

    title = _opt("--title")
    state = _opt("--state")
    labels_csv = _opt("--labels")
    assignees_csv = _opt("--assignees")
    labels = [l.strip() for l in labels_csv.split(",") if l.strip()] if labels_csv else None
    assignees = [a.strip() for a in assignees_csv.split(",") if a.strip()] if assignees_csv else None
    try:
        result = _github.update_issue(owner, repo, issue_number, pat,
                                      title=title, state=state, labels=labels, assignees=assignees)
        import json as _json
        print(_json.dumps(result, ensure_ascii=False))
        return 0
    except _github.GitHubAPIError as e:
        _err("ERROR", "update-issue", str(e), f"github_api_{e.status_code}")
        return 1


def cmd_get_issue(args: list) -> int:
    """get-issue <owner> <repo> <issue_number>"""
    if len(args) < 3:
        _err("ERROR", "get-issue", "owner, repo, issue_number 인수가 필요합니다.", "missing_argument")
        return 1
    pat = _get_pat()
    if not pat:
        _err("ERROR", "get-issue", "환경변수 GITHUB_PAT가 설정되지 않았습니다.", "missing_pat")
        return 1
    owner, repo, issue_number = args[0], args[1], int(args[2])
    try:
        result = _github.get_issue(owner, repo, issue_number, pat)
        import json as _json
        print(_json.dumps(result, ensure_ascii=False))
        return 0
    except _github.GitHubAPIError as e:
        _err("ERROR", "get-issue", str(e), f"github_api_{e.status_code}")
        return 1


def cmd_create_pr(args: list) -> int:
    """create-pr <owner> <repo> <title> <body_file> <head> <base>"""
    if len(args) < 6:
        _err("ERROR", "create-pr", "owner, repo, title, body_file, head, base 인수가 필요합니다.", "missing_argument")
        return 1
    pat = _get_pat()
    if not pat:
        _err("ERROR", "create-pr", "환경변수 GITHUB_PAT가 설정되지 않았습니다.", "missing_pat")
        return 1
    owner, repo, title, body_file, head, base = args[0], args[1], args[2], args[3], args[4], args[5]
    body = Path(body_file).read_text(encoding="utf-8") if body_file and Path(body_file).exists() else ""
    try:
        result = _github.create_pull_request(owner, repo, title, body, head, base, pat)
        import json as _json
        print(_json.dumps(result, ensure_ascii=False))
        return 0
    except _github.GitHubAPIError as e:
        _err("ERROR", "create-pr", str(e), f"github_api_{e.status_code}")
        return 1


def cmd_list_prs(args: list) -> int:
    """list-prs <owner> <repo> [--state open|closed|all]"""
    if len(args) < 2:
        _err("ERROR", "list-prs", "owner, repo 인수가 필요합니다.", "missing_argument")
        return 1
    pat = _get_pat()
    if not pat:
        _err("ERROR", "list-prs", "환경변수 GITHUB_PAT가 설정되지 않았습니다.", "missing_pat")
        return 1
    owner, repo = args[0], args[1]
    state = "open"
    if "--state" in args:
        idx = args.index("--state")
        if idx + 1 < len(args):
            state = args[idx + 1]
    try:
        result = _github.list_pulls(owner, repo, pat, state)
        import json as _json
        print(_json.dumps(result, ensure_ascii=False))
        return 0
    except _github.GitHubAPIError as e:
        _err("ERROR", "list-prs", str(e), f"github_api_{e.status_code}")
        return 1


# 커맨드 → 핸들러 함수 매핑
_COMMANDS = {
    "get-output-path": cmd_get_output_path,
    "get-issue-number": cmd_get_issue_number,
    "get-next-seq": cmd_get_next_seq,
    "normalize-title": cmd_normalize_title,
    "create-branch-name": cmd_create_branch_name,
    "get-commit-template": cmd_get_commit_template,
    "create-issue": cmd_create_issue,
    "add-comment": cmd_add_comment,
    "get-issue": cmd_get_issue,
    "update-issue": cmd_update_issue,
    "create-pr": cmd_create_pr,
    "list-prs": cmd_list_prs,
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
