#!/usr/bin/env python3
"""changelog provider 폴백 사다리 오케스트레이터 (#455).

version.yml options.changelog.provider 값에 따라 provider를 순서대로 시도하고,
처음 성공한 provider의 pr_body.md를 남긴다. commit은 AI 무의존 최후 보루.

  provider=commit                    → commit
  provider=github-ai                 → github-ai → (openai*) → commit
  provider=openai|gemini|claude|ollama → 해당 provider → github-ai → commit
  provider=coderabbit                → github-ai → commit
    (coderabbit 단계 자체는 워크플로우 Job 1의 요청·폴링이 담당 — 이 사다리에
     도달했다는 것은 이미 CodeRabbit이 무응답이었다는 뜻이라 재시도하지 않는다)
  * openai 단계는 MODEL_API_KEY가 있을 때만 끼운다 (없으면 무의미한 시도)

입력: CHANGELOG_PROVIDER + 각 provider의 환경변수 passthrough
출력: pr_body.md + provider_result.json({provider, attempted, failed, notice})
      + stdout `PROVIDER=<승자>` + exit 0. 전 단계 실패 시 exit 1.
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OPENAI_FAMILY = ("openai", "gemini", "claude", "ollama")


def build_rungs(provider):
    """(라벨, 스크립트, 추가 env) 목록 — 시도 순서."""
    commit = ("commit", "commit.py", {})
    github_ai = ("github-ai", "github_ai.py", {})
    if provider == "commit":
        return [commit]
    if provider in OPENAI_FAMILY:
        return [(f"openai:{provider}", "openai_compatible.py", {"PROVIDER_NAME": provider}), github_ai, commit]
    # github-ai(기본)·coderabbit(폴링 실패 후 위임)·미지의 값 → github-ai부터
    rungs = [github_ai]
    if provider == "github-ai" and os.environ.get("MODEL_API_KEY"):
        rungs.append(("openai:openai", "openai_compatible.py", {"PROVIDER_NAME": "openai"}))
    rungs.append(commit)
    return rungs


def run_rung(script, extra_env):
    env = dict(os.environ)
    env.update(extra_env)
    env.setdefault("PYTHONIOENCODING", "utf-8")
    proc = subprocess.run(
        [sys.executable, os.path.join(HERE, script)],
        env=env, capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    # rung의 로그는 그대로 통과시켜 워크플로우 로그에서 사유를 볼 수 있게 한다
    if proc.stdout.strip():
        print(proc.stdout.strip())
    if proc.stderr.strip():
        print(proc.stderr.strip(), file=sys.stderr)
    return proc.returncode == 0 and os.path.isfile("pr_body.md")


def main():
    provider = os.environ.get("CHANGELOG_PROVIDER") or "github-ai"
    rungs = build_rungs(provider)
    attempted, failed, winner = [], [], None

    for label, script, extra_env in rungs:
        attempted.append(label)
        print(f"🪜 provider 시도: {label}")
        if run_rung(script, extra_env):
            winner = label
            break
        failed.append(label)
        print(f"↩️ {label} 실패 — 다음 단계로 폴백", file=sys.stderr)

    notice = None
    if winner and failed:
        notice = f"{' → '.join(failed)} 실패 → {winner} 사용"

    with open("provider_result.json", "w", encoding="utf-8") as f:
        json.dump(
            {"provider": winner, "attempted": attempted, "failed": failed, "notice": notice},
            f, ensure_ascii=False,
        )

    if not winner:
        print("❌ 사다리 전 단계 실패 — pr_body.md 생성 불가", file=sys.stderr)
        sys.exit(1)
    print(f"PROVIDER={winner}")


if __name__ == "__main__":
    main()
