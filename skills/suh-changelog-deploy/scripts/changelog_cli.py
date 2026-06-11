#!/usr/bin/env python3
"""changelog_cli — suh-changelog-deploy skill 전용 CLI.

deploy PR 자동화 + Actions/CodeRabbit 상태 종합.
서브커맨드: actions, deploy-status, list-prs, update-pr, create-pr

사용법:
    cd skills/suh-changelog-deploy/scripts
    python changelog_cli.py <subcommand> [args]
"""
from __future__ import annotations

import sys
from pathlib import Path

_HERE = Path(__file__).resolve()
_PROJECT_ROOT = _HERE.parents[3]
_SCRIPTS_ROOT = _PROJECT_ROOT / "scripts"
if str(_SCRIPTS_ROOT) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_ROOT))

from common.cli_parser import JSONArgumentParser, run_cli  # noqa: E402
from common.emit import emit  # noqa: E402
from common.config import get_github_pat  # noqa: E402
from common.gh_client import (  # noqa: E402
    GitHubAPIError,
    list_pulls, update_pull_request, create_pull_request,
    get_run, get_job_log, list_failed_runs, resolve_pr_runs, resolve_branch_runs,
    get_pull_detail, find_open_pr_by_base, get_branch_head,
)


def cmd_actions(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    try:
        if args.sub == "show-run":
            if args.arg is None:
                return emit({"ok": False, "code": "missing_argument", "error": "RUN_ID 필요"})
            data = get_run(args.owner, args.repo, int(args.arg), pat)
            if data.get("failed_job_ids"):
                data["next"] = f"actions joblog {args.owner} {args.repo} {data['failed_job_ids'][0]}"
            return emit(data)
        if args.sub == "joblog":
            if args.arg is None:
                return emit({"ok": False, "code": "missing_argument", "error": "JOB_ID 필요"})
            data = get_job_log(args.owner, args.repo, int(args.arg), pat, grep=args.grep, tail=args.tail)
            return emit(data)
        if args.sub == "list-failed":
            runs = list_failed_runs(args.owner, args.repo, pat, limit=args.limit)
            nxt = f"actions show-run {args.owner} {args.repo} {runs[0]['run_id']}" if runs else None
            return emit({"count": len(runs), "runs": runs, "next": nxt})
        if args.sub == "resolve-pr":
            if args.arg is None:
                return emit({"ok": False, "code": "missing_argument", "error": "PR_NUM 필요"})
            data = resolve_pr_runs(args.owner, args.repo, int(args.arg), pat)
            failed = [r for r in data["runs"] if r["conclusion"] == "failure"]
            data["next"] = f"actions show-run {args.owner} {args.repo} {failed[0]['run_id']}" if failed else None
            return emit(data)
        if args.sub == "resolve-branch":
            if args.arg is None:
                return emit({"ok": False, "code": "missing_argument", "error": "BRANCH 필요"})
            runs = resolve_branch_runs(args.owner, args.repo, args.arg, pat, limit=args.limit)
            failed = [r for r in runs if r["conclusion"] == "failure"]
            nxt = f"actions show-run {args.owner} {args.repo} {failed[0]['run_id']}" if failed else None
            return emit({"branch": args.arg, "count": len(runs), "runs": runs, "next": nxt})
        return emit({"ok": False, "code": "unknown_subcommand", "error": f"알 수 없음: {args.sub}"})
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})
    except ValueError as e:
        return emit({"ok": False, "code": "invalid_argument", "error": str(e)})


def cmd_deploy_status(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    try:
        if args.pr:
            pr = get_pull_detail(args.owner, args.repo, args.pr, pat)
        else:
            pr = find_open_pr_by_base(args.owner, args.repo, args.base, pat)
        branch_head = get_branch_head(args.owner, args.repo, args.base, pat)
        deploy_branch = {"name": args.base, "head_sha": branch_head}

        if pr is None:
            return emit({
                "pr": None,
                "workflow": None,
                "deploy_branch": deploy_branch,
                "verdict": "no_pr",
                "summary": f"base={args.base}로 들어오는 open PR 없음",
            })

        # 워크플로우 매칭 — name이 아니라 path로 매칭한다.
        # name 필드는 사람이 보는 라벨(예: "AUTO UPDATE PROJECT CHANGELOG")이라 언제든 바뀌고,
        # 실제 파일 path(`.github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml`)가 식별자다.
        # 과거: `"AUTO-CHANGELOG-CONTROL" in name` → name은 "AUTO UPDATE PROJECT CHANGELOG"라 영원히 매칭 실패.
        workflow = None
        try:
            run_data = resolve_pr_runs(args.owner, args.repo, pr["number"], pat)
            for r in run_data.get("runs", []):
                path = (r.get("path") or "").lower()
                name = (r.get("name") or "").upper()
                # 1순위: 파일 path. 2순위(legacy fallback): name에 키워드.
                if path.endswith("project-common-auto-changelog-control.yaml") \
                        or ("CHANGELOG" in name and ("AUTO" in name or "DEPLOY" in name)):
                    workflow = {
                        "name": r.get("name"),
                        "path": r.get("path"),
                        "status": r.get("status"),
                        "conclusion": r.get("conclusion"),
                        "run_url": r.get("url"),
                    }
                    break
        except GitHubAPIError:
            workflow = None

        body = pr.get("body") or ""
        has_summary = "Summary by CodeRabbit" in body
        pr_out = {
            "number": pr["number"],
            "state": pr["state"],
            "merged": pr["merged"],
            "mergeable_state": pr["mergeable_state"],
            "has_coderabbit_summary": has_summary,
            "head_sha": pr["head_sha"],
            "url": pr["url"],
            "created_at": pr.get("created_at"),
        }

        workflow_status = (workflow or {}).get("status")
        workflow_conclusion = (workflow or {}).get("conclusion")
        workflow_running = workflow_status in ("in_progress", "queued", "waiting", "requested")

        # PR 생성 후 얼마 안 지났으면(120초 이내) 워크플로우가 막 trigger되어 아직 API에
        # 반영되지 않았을 가능성을 가드한다. workflow=null이라도 PR이 갓 만들어진 상태면
        # missing 판정 대신 waiting으로 양보한다.
        import datetime as _dt
        pr_age_sec = None
        if pr.get("created_at"):
            try:
                created = _dt.datetime.fromisoformat(pr["created_at"].replace("Z", "+00:00"))
                now = _dt.datetime.now(_dt.timezone.utc)
                pr_age_sec = (now - created).total_seconds()
            except Exception:
                pr_age_sec = None
        pr_young = (pr_age_sec is not None and pr_age_sec < 120)

        next_hint = f"deploy-status {args.owner} {args.repo} --pr {pr['number']}"
        if pr["merged"]:
            verdict, summary, next_hint = "merged", f"PR #{pr['number']} automerge 완료", None
        elif pr["mergeable_state"] in ("dirty", "blocked", "behind"):
            verdict = "conflict"
            summary = f"PR #{pr['number']} mergeable_state={pr['mergeable_state']} — 충돌/차단"
        elif workflow and workflow_conclusion == "failure":
            verdict = "workflow_failed"
            summary = "AUTO-CHANGELOG-CONTROL 워크플로우 실패"
        elif workflow_running:
            # 워크플로우 진행 중이면 body·has_summary가 일시적으로 비어 보여도 정상 대기로 본다 (race 가드)
            verdict = "waiting_for_automerge"
            summary = f"PR #{pr['number']} 워크플로우 진행 중({workflow_status}), automerge 대기"
        elif workflow is None and pr_young:
            # 워크플로우 매칭 못 했지만 PR이 갓 만들어진 상태 — API 반영 lag 가능, race 가드
            verdict = "waiting_for_automerge"
            summary = f"PR #{pr['number']} 생성 직후({int(pr_age_sec)}s), 워크플로우 trigger 대기"
        elif not has_summary:
            # 워크플로우가 진행 중이 아니고 PR도 갓 생성된 게 아니면 진짜 body 초기화 사고로 판정
            verdict = "missing_coderabbit_summary"
            summary = f"PR #{pr['number']} 본문에 'Summary by CodeRabbit' 없음 — fix 모드로 재작성"
        else:
            verdict = "waiting_for_automerge"
            summary = f"PR #{pr['number']} open·{pr['mergeable_state']}, automerge 대기"

        return emit({
            "pr": pr_out,
            "workflow": workflow,
            "deploy_branch": deploy_branch,
            "verdict": verdict,
            "summary": summary,
            "next": next_hint,
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


def _resolve_body_file(body_file: str | None) -> Path | None:
    """본문 파일 경로 해석 — 절대 경로면 그대로, 상대 경로면 여러 위치를 순서대로 탐색.

    SKILL.md 절차는 `~/.suh-template/tmp/{owner}__{repo}__release_notes.md`(홈, 절대경로)에
    저장하고 cli에 그 절대경로를 넘긴다. 다만 누군가 파일명만(상대경로) 넘겨도 찾을 수 있도록
    홈 tmp → PROJECT_ROOT/scripts(구버전 하위호환) → cwd 순으로 보강 탐색한다.
    찾지 못하면 None을 반환한다 (호출자가 본문 없음을 판단).
    """
    if not body_file:
        return None
    raw = Path(body_file)
    if raw.is_absolute():
        return raw if raw.exists() else None
    for candidate in (
        raw,
        Path.home() / ".suh-template" / "tmp" / raw.name,
        _PROJECT_ROOT / "scripts" / raw.name,
        Path.cwd() / raw,
    ):
        if candidate.exists():
            return candidate
    return None


def cmd_update_pr(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    body = None
    if args.body_file:
        body_path = _resolve_body_file(args.body_file)
        body = body_path.read_text(encoding="utf-8") if body_path else None
    try:
        result = update_pull_request(
            args.owner, args.repo, args.number, pat,
            title=args.title, body=body, state=args.state,
        )
        return emit({**result, "summary": f"PR #{args.number} 수정 완료"})
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


def cmd_create_pr(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    body_path = _resolve_body_file(args.body_file)
    if args.body_file and not body_path:
        return emit({
            "ok": False, "code": "body_file_not_found",
            "error": (
                f"본문 파일을 찾을 수 없습니다: {args.body_file} "
                f"(탐색: 절대경로 | ~/.suh-template/tmp/ | {_PROJECT_ROOT / 'scripts'} | cwd={Path.cwd()})"
            ),
        })
    body = body_path.read_text(encoding="utf-8") if body_path else ""
    try:
        result = create_pull_request(args.owner, args.repo, args.title, body, args.head, args.base, pat)
        pr_number = result.get("number")

        # PR 생성 직후엔 AUTO-CHANGELOG-CONTROL 워크플로우 step 2가 본문을 초기화할 수 있다.
        # step 2는 PR opened 후 보통 3~10초 안에 실행되므로, 워크플로우 본문 초기화가 끝난 뒤
        # (대기 후) 본문을 다시 확인해 비어 있으면 update-pr로 재주입한다. 이렇게 하면 step 8
        # (CodeRabbit Summary 폴링)이 첫 attempt(5초 간격)에서 즉시 본문을 잡고 빠르게 머지된다.
        # 본문이 비어 있지 않으면(워크플로우가 보존했거나 CodeRabbit이 자기 Summary 작성한 경우) skip.
        guard_summary = None
        if pr_number and body:
            import time
            time.sleep(15)
            try:
                detail = get_pull_detail(args.owner, args.repo, pr_number, pat)
                cur_body = detail.get("body") or ""
                if "Summary by CodeRabbit" not in cur_body:
                    update_pull_request(args.owner, args.repo, pr_number, pat, body=body)
                    guard_summary = "본문 재주입 (워크플로우 step 2 race 회복)"
                else:
                    guard_summary = "본문 보존 확인 — 재주입 불필요"
            except GitHubAPIError:
                guard_summary = "본문 재확인 실패 — 무시하고 진행"

        out = {
            **result,
            "summary": f"PR #{pr_number} 생성 완료" + (f" / {guard_summary}" if guard_summary else ""),
            "next": f"deploy-status {args.owner} {args.repo} --pr {pr_number}",
        }
        if guard_summary:
            out["body_guard"] = guard_summary
        return emit(out)
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


def build_parser() -> JSONArgumentParser:
    parser = JSONArgumentParser(prog="changelog_cli", description="suh-changelog-deploy skill CLI")
    sub = parser.add_subparsers(dest="command", required=True)

    p_a = sub.add_parser("actions", help="GitHub Actions run/job/log 조회")
    p_a.add_argument("sub", choices=["show-run", "joblog", "list-failed", "resolve-pr", "resolve-branch"])
    p_a.add_argument("owner")
    p_a.add_argument("repo")
    p_a.add_argument("arg", nargs="?")
    p_a.add_argument("--limit", type=int, default=10)
    p_a.add_argument("--grep", default="error")
    p_a.add_argument("--tail", type=int, default=30)
    p_a.set_defaults(func=cmd_actions)

    p_ds = sub.add_parser("deploy-status", help="deploy PR 상태 종합 판정")
    p_ds.add_argument("owner")
    p_ds.add_argument("repo")
    p_ds.add_argument("--pr", type=int)
    p_ds.add_argument("--base", default="deploy")
    p_ds.set_defaults(func=cmd_deploy_status)

    p_lp = sub.add_parser("list-prs", help="PR 목록")
    p_lp.add_argument("owner")
    p_lp.add_argument("repo")
    p_lp.add_argument("--state", choices=["open", "closed", "all"], default="open")
    p_lp.set_defaults(func=cmd_list_prs)

    p_up = sub.add_parser("update-pr", help="PR 본문/상태 수정")
    p_up.add_argument("owner")
    p_up.add_argument("repo")
    p_up.add_argument("number", type=int)
    p_up.add_argument("body_file", nargs="?")
    p_up.add_argument("--title")
    p_up.add_argument("--state", choices=["open", "closed"])
    p_up.set_defaults(func=cmd_update_pr)

    p_cp = sub.add_parser("create-pr", help="deploy PR 재트리거용 생성")
    p_cp.add_argument("owner")
    p_cp.add_argument("repo")
    p_cp.add_argument("title")
    p_cp.add_argument("body_file")
    p_cp.add_argument("head")
    p_cp.add_argument("base")
    p_cp.set_defaults(func=cmd_create_pr)

    return parser


def main() -> int:
    return run_cli(build_parser())


if __name__ == "__main__":
    sys.exit(main())
