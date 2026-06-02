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
import argparse
from pathlib import Path

_HERE = Path(__file__).resolve()
_PROJECT_ROOT = _HERE.parents[3]
_SCRIPTS_ROOT = _PROJECT_ROOT / "scripts"
if str(_SCRIPTS_ROOT) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_ROOT))

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

        workflow = None
        try:
            run_data = resolve_pr_runs(args.owner, args.repo, pr["number"], pat)
            for r in run_data.get("runs", []):
                if "AUTO-CHANGELOG-CONTROL" in (r.get("name") or ""):
                    workflow = {
                        "name": r.get("name"),
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
        }

        workflow_status = (workflow or {}).get("status")
        workflow_conclusion = (workflow or {}).get("conclusion")
        workflow_running = workflow_status in ("in_progress", "queued", "waiting", "requested")

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
        elif not has_summary:
            # 워크플로우가 진행 중이 아닐 때만 진짜 body 초기화 사고로 판정
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
            "next": f"deploy-status {args.owner} {args.repo} --pr {result.get('number')}",
        })
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="changelog_cli", description="suh-changelog-deploy skill CLI")
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
    parser = build_parser()
    args = parser.parse_args()
    if not hasattr(args, "func"):
        parser.print_help(sys.stderr)
        return 1
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
