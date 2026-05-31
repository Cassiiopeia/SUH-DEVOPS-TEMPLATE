"""
suh_command — cassiiopeia 스킬들이 공유하는 공통 명령 진입점.

이 파일이 하는 일:
    suh-issue / suh-github / suh-report / suh-review / suh-changelog-deploy /
    suh-troubleshoot 등 여러 스킬이 GitHub API 호출(이슈·PR·Actions)과
    문자열 유틸(제목 정규화·브랜치명·출력 경로)을 직접 인라인 Python으로
    짜지 않고, 이 한 파일의 서브커맨드로 호출한다.
    실제 로직은 gh_client.py(GitHub API) / gh_branch.py / paths.py 등에 있고,
    이 파일은 "명령을 받아 알맞은 모듈로 넘기는 라우터" 역할만 한다.

PAT(GitHub 토큰)는 직접 넘기지 않아도 된다:
    GITHUB_PAT 환경변수가 있으면 그것을, 없으면 config.json에서 자동으로 읽는다
    (_get_pat 참조). 따라서 호출 측에서 GITHUB_PAT= 를 빼먹어도 동작한다.

사용법:
    python3 -m suh_template.suh_command <command> [args]

커맨드:
    get-output-path <skill_id> [--title <제목>]
    get-issue-number
    get-next-seq <skill_id>
    normalize-title <제목>
    create-branch-name <issue_title> <issue_number> [--date YYYYMMDD]
    get-commit-template <issue_title> <issue_url>
    create-issue <owner> <repo> <title> <body_file> <labels_csv>
    add-comment <owner> <repo> <issue_number> <body_file>
    get-issue <owner> <repo> <issue_number> [--with-comments]
    get-issues <owner> <repo> <issue_number...>
    update-issue <owner> <repo> <issue_number> [옵션]
    create-pr <owner> <repo> <title> <body_file> <head> <base>
    list-prs <owner> <repo> [--state open|closed|all]
    search-issues <owner> <repo> <keyword...>
    update-pr <owner> <repo> <pr_number> <body_file> [옵션]
    actions <show-run|joblog|list-failed|resolve-pr|resolve-branch> <owner> <repo> [인자]
    explore <list-repos|repo-detail|readme|languages|commits> <owner> [repo] [인자]
    secrets <list|set> <owner> <repo> [인자]
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


def _get_pat(owner: Optional[str] = None, repo: Optional[str] = None) -> Optional[str]:
    """
    GitHub PAT를 반환한다.

    1. GITHUB_PAT 환경변수가 있으면 그것을 사용 (명시적 전달 우선)
    2. 없으면 config.json에서 자동 로드
       - owner/repo가 일치하는 repos[].pat(non-null) 우선, 없으면 global_pat

    환경변수를 안 붙여도 config만 있으면 동작하므로, 호출 측(스킬)에서
    GITHUB_PAT= 전달을 빼먹어도 missing_pat이 나지 않는다.
    """
    pat = os.environ.get("GITHUB_PAT")
    if pat:
        return pat
    try:
        return _config.get_github_pat(owner, repo)
    except Exception:
        return None


def cmd_create_issue(args: list) -> int:
    """create-issue <owner> <repo> <title> <body_file> <labels_csv>"""
    if len(args) < 5:
        _err("ERROR", "create-issue", "owner, repo, title, body_file, labels_csv 인수가 필요합니다.", "missing_argument")
        return 1
    owner, repo, title, body_file, labels_csv = args[0], args[1], args[2], args[3], args[4]
    pat = _get_pat(owner, repo)
    if not pat:
        _err("ERROR", "create-issue", "GITHUB_PAT 환경변수도 config.json도 없습니다.", "missing_pat")
        return 1
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
    owner, repo, issue_number, body_file = args[0], args[1], int(args[2]), args[3]
    pat = _get_pat(owner, repo)
    if not pat:
        _err("ERROR", "add-comment", "GITHUB_PAT 환경변수도 config.json도 없습니다.", "missing_pat")
        return 1
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
    owner, repo, issue_number = args[0], args[1], int(args[2])
    pat = _get_pat(owner, repo)
    if not pat:
        _err("ERROR", "update-issue", "GITHUB_PAT 환경변수도 config.json도 없습니다.", "missing_pat")
        return 1
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
    """get-issue <owner> <repo> <issue_number> [--with-comments]"""
    if len(args) < 3:
        return _emit({"ok": False, "error": "사용법: get-issue <owner> <repo> <issue_number> [--with-comments]"})
    owner, repo = args[0], args[1]
    try:
        issue_number = int(args[2])
    except ValueError:
        return _emit({"ok": False, "error": "issue_number는 정수여야 합니다.", "code": "invalid_argument"})
    with_comments = "--with-comments" in args[3:]
    pat = _get_pat(owner, repo)
    if not pat:
        return _emit({"ok": False, "error": "GITHUB_PAT 환경변수도 config.json도 없음", "code": "missing_pat"})
    try:
        issue = _github.get_issue(owner, repo, issue_number, pat)
        payload = {
            "ok": True,
            "issue": issue,
            "comments": _github.get_issue_comments(owner, repo, issue_number, pat) if with_comments else None,
            "summary": f"#{issue['number']} {issue['state']} — {issue['title']}",
            "next": None,
            # 기존 get-issue 소비자가 top-level title/url을 읽어도 동작하도록 유지한다.
            "number": issue["number"],
            "title": issue["title"],
            "url": issue["url"],
            "html_url": issue["url"],
            "state": issue["state"],
            "body": issue.get("body", ""),
        }
        return _emit(payload)
    except _github.GitHubAPIError as e:
        return _emit({"ok": False, "error": str(e), "code": f"github_api_{e.status_code}"})


def cmd_get_issues(args: list) -> int:
    """get-issues <owner> <repo> <issue_number...>"""
    if len(args) < 3:
        return _emit({"ok": False, "error": "사용법: get-issues <owner> <repo> <issue_number...>"})
    owner, repo = args[0], args[1]
    pat = _get_pat(owner, repo)
    if not pat:
        return _emit({"ok": False, "error": "GITHUB_PAT 환경변수도 config.json도 없음", "code": "missing_pat"})

    issues = []
    for raw_number in args[2:]:
        try:
            number = int(raw_number)
        except ValueError:
            issues.append({"number": raw_number, "error": "issue_number는 정수여야 합니다.", "code": "invalid_argument"})
            continue
        try:
            issues.append(_github.get_issue(owner, repo, number, pat))
        except _github.GitHubAPIError as e:
            issues.append({"number": number, "error": str(e), "code": f"github_api_{e.status_code}"})

    return _emit({
        "ok": True,
        "count": len(issues),
        "issues": issues,
        "summary": f"{len(issues)}개 이슈 조회 완료",
        "next": None,
    })


def cmd_create_pr(args: list) -> int:
    """create-pr <owner> <repo> <title> <body_file> <head> <base>"""
    if len(args) < 6:
        _err("ERROR", "create-pr", "owner, repo, title, body_file, head, base 인수가 필요합니다.", "missing_argument")
        return 1
    owner, repo, title, body_file, head, base = args[0], args[1], args[2], args[3], args[4], args[5]
    pat = _get_pat(owner, repo)
    if not pat:
        _err("ERROR", "create-pr", "GITHUB_PAT 환경변수도 config.json도 없습니다.", "missing_pat")
        return 1
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
    owner, repo = args[0], args[1]
    pat = _get_pat(owner, repo)
    if not pat:
        _err("ERROR", "list-prs", "GITHUB_PAT 환경변수도 config.json도 없습니다.", "missing_pat")
        return 1
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


def cmd_search_issues(args: list) -> int:
    """search-issues <owner> <repo> <keyword...>"""
    if len(args) < 3:
        _err("ERROR", "search-issues", "owner, repo, keyword 인수가 필요합니다.", "missing_argument")
        return 1
    owner, repo = args[0], args[1]
    pat = _get_pat(owner, repo)
    if not pat:
        _err("ERROR", "search-issues", "GITHUB_PAT 환경변수도 config.json도 없습니다.", "missing_pat")
        return 1
    keyword = " ".join(args[2:])
    try:
        result = _github.search_issues(owner, repo, keyword, pat)
        import json as _json
        print(_json.dumps({"count": len(result), "items": result}, ensure_ascii=False))
        return 0
    except _github.GitHubAPIError as e:
        _err("ERROR", "search-issues", str(e), f"github_api_{e.status_code}")
        return 1


def cmd_update_pr(args: list) -> int:
    """update-pr <owner> <repo> <pr_number> <body_file> [--title <제목>] [--state open|closed]"""
    if len(args) < 4:
        _err("ERROR", "update-pr", "owner, repo, pr_number, body_file 인수가 필요합니다.", "missing_argument")
        return 1
    owner, repo, pr_number, body_file = args[0], args[1], int(args[2]), args[3]
    pat = _get_pat(owner, repo)
    if not pat:
        _err("ERROR", "update-pr", "GITHUB_PAT 환경변수도 config.json도 없습니다.", "missing_pat")
        return 1
    rest = args[4:]
    body = Path(body_file).read_text(encoding="utf-8") if body_file and Path(body_file).exists() else None

    def _opt(key: str) -> Optional[str]:
        if key in rest:
            idx = rest.index(key)
            return rest[idx + 1] if idx + 1 < len(rest) else None
        return None

    title = _opt("--title")
    state = _opt("--state")
    try:
        result = _github.update_pull_request(owner, repo, pr_number, pat,
                                             title=title, body=body, state=state)
        import json as _json
        print(_json.dumps(result, ensure_ascii=False))
        return 0
    except _github.GitHubAPIError as e:
        _err("ERROR", "update-pr", str(e), f"github_api_{e.status_code}")
        return 1


def _emit(payload: dict) -> int:
    """JSON을 stdout에 출력하고 0을 반환한다."""
    import json as _json
    print(_json.dumps(payload, ensure_ascii=False))
    return 0


def cmd_actions(args: list) -> int:
    """actions <show-run|joblog|list-failed|resolve-pr|resolve-branch> <owner> <repo> [인자]

    출력은 언제나 JSON. 성공 시 {"ok": true, ...데이터..., "next": "다음 서브커맨드 힌트"}.
    입력 해석(URL→ID, PR→run 추적)은 호출자(agent) 책임. 여기서는 명확한 인자만 받는다.
    """
    if len(args) < 3:
        return _emit({
            "ok": False,
            "error": "사용법: actions <sub> <owner> <repo> [인자]",
            "subcommands": ["show-run RUN_ID", "joblog JOB_ID", "list-failed [--limit N]",
                            "resolve-pr PR_NUM", "resolve-branch BRANCH [--limit N]"],
        })

    sub, owner, repo = args[0], args[1], args[2]
    rest = args[3:]

    pat = _get_pat(owner, repo)
    if not pat:
        return _emit({"ok": False, "error": "GITHUB_PAT 환경변수도 config.json도 없음", "code": "missing_pat"})

    def _opt_int(key: str, default: int) -> int:
        if key in rest:
            idx = rest.index(key)
            if idx + 1 < len(rest):
                try:
                    return int(rest[idx + 1])
                except ValueError:
                    pass
        return default

    try:
        if sub == "show-run":
            if not rest:
                return _emit({"ok": False, "error": "RUN_ID 필요"})
            run_id = int(rest[0])
            data = _github.get_run(owner, repo, run_id, pat)
            data["ok"] = True
            if data.get("failed_job_ids"):
                data["next"] = f"actions joblog {owner} {repo} {data['failed_job_ids'][0]}"
            else:
                data["next"] = None
            return _emit(data)

        if sub == "joblog":
            if not rest:
                return _emit({"ok": False, "error": "JOB_ID 필요"})
            job_id = int(rest[0])
            grep = rest[rest.index("--grep") + 1] if "--grep" in rest and rest.index("--grep") + 1 < len(rest) else "error"
            tail = _opt_int("--tail", 30)
            data = _github.get_job_log(owner, repo, job_id, pat, grep=grep, tail=tail)
            data["ok"] = True
            data["next"] = None
            return _emit(data)

        if sub == "list-failed":
            limit = _opt_int("--limit", 10)
            runs = _github.list_failed_runs(owner, repo, pat, limit=limit)
            nxt = f"actions show-run {owner} {repo} {runs[0]['run_id']}" if runs else None
            return _emit({"ok": True, "count": len(runs), "runs": runs, "next": nxt})

        if sub == "resolve-pr":
            if not rest:
                return _emit({"ok": False, "error": "PR_NUM 필요"})
            pr_number = int(rest[0])
            data = _github.resolve_pr_runs(owner, repo, pr_number, pat)
            data["ok"] = True
            failed = [r for r in data["runs"] if r["conclusion"] == "failure"]
            data["next"] = f"actions show-run {owner} {repo} {failed[0]['run_id']}" if failed else None
            return _emit(data)

        if sub == "resolve-branch":
            if not rest:
                return _emit({"ok": False, "error": "BRANCH 필요"})
            branch = rest[0]
            limit = _opt_int("--limit", 10)
            runs = _github.resolve_branch_runs(owner, repo, branch, pat, limit=limit)
            failed = [r for r in runs if r["conclusion"] == "failure"]
            nxt = f"actions show-run {owner} {repo} {failed[0]['run_id']}" if failed else None
            return _emit({"ok": True, "branch": branch, "count": len(runs), "runs": runs, "next": nxt})

        return _emit({"ok": False, "error": f"알 수 없는 actions 서브커맨드: {sub}"})

    except _github.GitHubAPIError as e:
        return _emit({"ok": False, "error": str(e), "code": f"github_api_{e.status_code}"})
    except ValueError as e:
        return _emit({"ok": False, "error": f"인자 형식 오류: {e}"})


def cmd_deploy_status(args: list) -> int:
    """deploy-status <owner> <repo> [--pr N] [--base deploy]

    deploy PR의 머지/CodeRabbit 본문/워크플로우/브랜치 상태를 한 번에 조회하고
    verdict로 판정해 종합 JSON을 반환한다. 출력은 언제나 JSON.
    """
    if len(args) < 2:
        return _emit({"ok": False, "error": "사용법: deploy-status <owner> <repo> [--pr N] [--base deploy]"})

    owner, repo = args[0], args[1]
    rest = args[2:]

    base = "deploy"
    if "--base" in rest:
        i = rest.index("--base")
        if i + 1 < len(rest):
            base = rest[i + 1]

    pr_number = None
    if "--pr" in rest:
        i = rest.index("--pr")
        if i + 1 < len(rest):
            try:
                pr_number = int(rest[i + 1])
            except ValueError:
                return _emit({"ok": False, "error": "--pr 값이 정수가 아님"})

    pat = _get_pat(owner, repo)
    if not pat:
        return _emit({"ok": False, "error": "GITHUB_PAT 환경변수도 config.json도 없음", "code": "missing_pat"})

    try:
        # 1) PR 상세 — --pr 있으면 직접, 없으면 base로 open PR 탐색
        if pr_number is not None:
            pr = _github.get_pull_detail(owner, repo, pr_number, pat)
        else:
            pr = _github.find_open_pr_by_base(owner, repo, base, pat)

        branch_head = _github.get_branch_head(owner, repo, base, pat)
        deploy_branch = {"name": base, "head_sha": branch_head}

        # PR이 없으면 no_pr — deploy 브랜치 head만 단서로 제공
        if pr is None:
            return _emit({
                "ok": True,
                "pr": None,
                "workflow": None,
                "deploy_branch": deploy_branch,
                "verdict": "no_pr",
                "summary": f"base={base}로 들어오는 open PR이 없습니다. 이미 머지됐거나 아직 생성 전입니다.",
                "next": None,
            })

        # 2) 워크플로우 run — PR head_sha에 연결된 AUTO-CHANGELOG-CONTROL run 식별
        workflow = None
        try:
            run_data = _github.resolve_pr_runs(owner, repo, pr["number"], pat)
            for r in run_data.get("runs", []):
                if "AUTO-CHANGELOG-CONTROL" in (r.get("name") or ""):
                    workflow = {
                        "name": r.get("name"),
                        "status": r.get("status"),
                        "conclusion": r.get("conclusion"),
                        "run_url": r.get("url"),
                    }
                    break
        except _github.GitHubAPIError:
            workflow = None  # run 조회 실패는 치명적이지 않음 — workflow=null로 둔다

        has_summary = "Summary by CodeRabbit" in pr.get("body", "")
        pr_out = {
            "number": pr["number"],
            "state": pr["state"],
            "merged": pr["merged"],
            "mergeable_state": pr["mergeable_state"],
            "has_coderabbit_summary": has_summary,
            "head_sha": pr["head_sha"],
            "url": pr["url"],
        }

        # 3) verdict 판정 (우선순위: merged → conflict → workflow_failed → missing_summary → waiting)
        next_hint = f"deploy-status {owner} {repo} --pr {pr['number']}"
        if pr["merged"]:
            verdict = "merged"
            summary = f"PR #{pr['number']} automerge 완료. 배포가 진행됩니다."
            next_hint = None
        elif pr["mergeable_state"] in ("dirty", "blocked", "behind"):
            verdict = "conflict"
            summary = f"PR #{pr['number']} mergeable_state={pr['mergeable_state']} — 충돌/차단 상태입니다. 수동 확인이 필요합니다."
        elif workflow and workflow["conclusion"] == "failure":
            verdict = "workflow_failed"
            summary = "AUTO-CHANGELOG-CONTROL 워크플로우가 실패했습니다. run을 확인하고 fix 모드로 재시도하세요."
        elif not has_summary:
            verdict = "missing_coderabbit_summary"
            summary = f"PR #{pr['number']} 본문에 'Summary by CodeRabbit'이 없습니다. 본문이 초기화된 것으로 보입니다 — fix 모드로 재작성하세요."
        else:
            verdict = "waiting_for_automerge"
            summary = f"PR #{pr['number']} open·{pr['mergeable_state']}, CodeRabbit 본문 있음 — automerge 대기 중. 약 60초 후 재확인하세요 (보통 60초 안에 머지 완료)."

        return _emit({
            "ok": True,
            "pr": pr_out,
            "workflow": workflow,
            "deploy_branch": deploy_branch,
            "verdict": verdict,
            "summary": summary,
            "next": next_hint,
        })

    except _github.GitHubAPIError as e:
        return _emit({"ok": False, "error": str(e), "code": f"github_api_{e.status_code}"})


def cmd_explore(args: list) -> int:
    """explore <list-repos|repo-detail|readme|languages|commits> <owner> [repo] [인자]

    레포 탐색 계열 커맨드. 출력은 언제나 JSON이며 다음 탐색 힌트를 next에 담는다.
    """
    if len(args) < 2:
        return _emit({
            "ok": False,
            "error": "사용법: explore <sub> <owner> [repo] [인자]",
            "subcommands": [
                "list-repos OWNER [--type user|org|auto]",
                "repo-detail OWNER REPO",
                "readme OWNER REPO",
                "languages OWNER REPO",
                "commits OWNER REPO [--limit N]",
            ],
        })

    sub = args[0]

    def _opt_int(rest: list, key: str, default: int) -> int:
        if key in rest:
            idx = rest.index(key)
            if idx + 1 < len(rest):
                try:
                    return int(rest[idx + 1])
                except ValueError:
                    pass
        return default

    try:
        if sub == "list-repos":
            owner = args[1]
            rest = args[2:]
            repo_type = "auto"
            if "--type" in rest:
                idx = rest.index("--type")
                if idx + 1 < len(rest):
                    repo_type = rest[idx + 1]
            if repo_type not in ("user", "org", "auto"):
                return _emit({"ok": False, "error": "--type은 user|org|auto 중 하나여야 합니다.", "code": "invalid_argument"})
            pat = _get_pat(owner, None)
            if not pat:
                return _emit({"ok": False, "error": "GITHUB_PAT 환경변수도 config.json도 없음", "code": "missing_pat"})
            owner_type = _github.get_user_type(owner, pat) if repo_type == "auto" else repo_type
            repos = _github.list_repos(owner, owner_type, pat)
            next_hint = f"explore repo-detail {owner} {repos[0]['name']}" if repos else None
            return _emit({
                "ok": True,
                "owner": owner,
                "owner_type": owner_type,
                "count": len(repos),
                "repos": repos,
                "summary": f"{owner} {owner_type} 레포 {len(repos)}개 조회",
                "next": next_hint,
            })

        if len(args) < 3:
            return _emit({"ok": False, "error": f"사용법: explore {sub} <owner> <repo>"})
        owner, repo = args[1], args[2]
        rest = args[3:]
        pat = _get_pat(owner, repo)
        if not pat:
            return _emit({"ok": False, "error": "GITHUB_PAT 환경변수도 config.json도 없음", "code": "missing_pat"})

        if sub == "repo-detail":
            repo_detail = _github.get_repo_detail(owner, repo, pat)
            return _emit({
                "ok": True,
                "repo": repo_detail,
                "summary": f"{owner}/{repo} 상세 조회 완료",
                "next": f"explore readme {owner} {repo}",
            })

        if sub == "readme":
            readme = _github.get_readme(owner, repo, pat)
            return _emit({
                "ok": True,
                "readme": readme,
                "summary": "README 조회 완료" if readme.get("content") is not None else "README가 없습니다.",
                "next": f"explore languages {owner} {repo}",
            })

        if sub == "languages":
            languages = _github.get_languages(owner, repo, pat)
            return _emit({
                "ok": True,
                "languages": languages,
                "summary": f"{owner}/{repo} 언어 {len(languages)}개 조회",
                "next": None,
            })

        if sub == "commits":
            limit = _opt_int(rest, "--limit", 10)
            commits = _github.list_commits(owner, repo, pat, limit=limit)
            return _emit({
                "ok": True,
                "count": len(commits),
                "commits": commits,
                "summary": f"{owner}/{repo} 최근 커밋 {len(commits)}개 조회",
                "next": None,
            })

        return _emit({"ok": False, "error": f"알 수 없는 explore 서브커맨드: {sub}"})

    except _github.GitHubAPIError as e:
        return _emit({"ok": False, "error": str(e), "code": f"github_api_{e.status_code}"})
    except ValueError as e:
        return _emit({"ok": False, "error": f"인자 형식 오류: {e}"})


def cmd_secrets(args: list) -> int:
    """secrets <list|set> <owner> <repo> [name]

    Actions Secret 목록 조회 및 등록/갱신. set 값은 SECRET_VALUE 환경변수로 받는다.
    """
    if len(args) < 3:
        return _emit({
            "ok": False,
            "error": "사용법: secrets <list|set> <owner> <repo> [name]",
            "subcommands": ["list OWNER REPO", "set OWNER REPO NAME (SECRET_VALUE 환경변수 사용)"],
        })

    sub, owner, repo = args[0], args[1], args[2]
    pat = _get_pat(owner, repo)
    if not pat:
        return _emit({"ok": False, "error": "GITHUB_PAT 환경변수도 config.json도 없음", "code": "missing_pat"})

    try:
        if sub == "list":
            secrets = _github.list_secrets(owner, repo, pat)
            return _emit({
                "ok": True,
                "count": len(secrets),
                "secrets": secrets,
                "summary": f"{owner}/{repo} Actions Secret {len(secrets)}개 조회",
                "next": f"secrets set {owner} {repo} <NAME> (SECRET_VALUE 환경변수 사용)",
            })

        if sub == "set":
            if len(args) < 4:
                return _emit({"ok": False, "error": "secret name이 필요합니다.", "code": "missing_argument"})
            name = args[3]
            value = os.environ.get("SECRET_VALUE")
            if value is None and len(args) >= 5:
                value = args[4]
            if value is None:
                return _emit({
                    "ok": False,
                    "error": "SECRET_VALUE 환경변수에 secret 값을 담아 호출하세요.",
                    "code": "missing_secret_value",
                })
            result = _github.set_secret(owner, repo, name, value, pat)
            return _emit({
                "ok": True,
                **result,
                "summary": f"{owner}/{repo} secret {name} 갱신 완료",
                "next": None,
            })

        return _emit({"ok": False, "error": f"알 수 없는 secrets 서브커맨드: {sub}"})

    except _github.PyNaClMissingError as e:
        return _emit({"ok": False, "error": str(e), "code": e.code, "hint": "수동 설치: pip install PyNaCl"})
    except _github.GitHubAPIError as e:
        return _emit({"ok": False, "error": str(e), "code": f"github_api_{e.status_code}"})


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
    "get-issues": cmd_get_issues,
    "update-issue": cmd_update_issue,
    "create-pr": cmd_create_pr,
    "list-prs": cmd_list_prs,
    "search-issues": cmd_search_issues,
    "update-pr": cmd_update_pr,
    "actions": cmd_actions,
    "deploy-status": cmd_deploy_status,
    "explore": cmd_explore,
    "secrets": cmd_secrets,
}


def main() -> None:
    """CLI 진입점 — 커맨드를 파싱하고 해당 핸들러를 실행한다."""
    args = sys.argv[1:]
    if not args:
        print("사용법: python3 -m suh_template.suh_command <command> [args]", file=sys.stderr)
        print(f"커맨드: {', '.join(_COMMANDS)}", file=sys.stderr)
        sys.exit(1)

    command = args[0]
    if command not in _COMMANDS:
        _err("ERROR", command, f"알 수 없는 커맨드입니다. 지원: {', '.join(_COMMANDS)}", "unknown_command")
        sys.exit(1)

    sys.exit(_COMMANDS[command](args[1:]))


if __name__ == "__main__":
    main()
