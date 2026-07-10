#!/usr/bin/env python3
"""changelog provider 공통 헬퍼 (#455) — stdlib 전용.

모든 provider는 같은 계약을 따른다:
  입력: 환경변수 (COMMIT_RANGE 등)
  출력: 성공 시 cwd에 pr_body.md(Summary by CodeRabbit 고정 구조) + stdout `PROVIDER=<name>` + exit 0
        실패 시 stderr 사유 + exit 1 (ladder가 다음 단계로 폴백)
"""
import re
import subprocess
import sys

HEADER = "<!-- This is an auto-generated comment: release notes by coderabbit.ai -->"
FOOTER = "<!-- end of auto-generated comment: release notes by coderabbit.ai -->"

# 커밋 제목 prefix → 릴리스 노트 섹션
SECTION_ORDER = [
    ("feat", "새 기능"),
    ("fix", "버그 수정"),
    ("improve", "개선"),
    ("docs", "문서"),
    ("etc", "기타"),
]
_PREFIX_RE = re.compile(r"^(feat|fix|refactor|docs|chore|style|test|perf|ci|build|revert)(\([^)]*\))?:")
_PREFIX_TO_SECTION = {
    "feat": "feat", "fix": "fix",
    "refactor": "improve", "style": "improve", "perf": "improve",
    "docs": "docs",
}


def collect_commits(range_expr, limit=60, fallback_count=30):
    """지정 range의 커밋 제목 수집([skip ci] 제외). 비면 최근 커밋으로 폴백."""
    def _log(args):
        try:
            out = subprocess.run(
                ["git", "log", *args, "--pretty=format:%s"],
                capture_output=True, text=True, encoding="utf-8", errors="replace",
            )
            if out.returncode != 0:
                return []
            return [s for s in out.stdout.splitlines() if s.strip() and "[skip ci]" not in s]
        except OSError:
            return []

    commits = _log([range_expr])[:limit]
    if not commits:
        commits = _log([f"-{fallback_count}"])
    return commits


def clean_message(line):
    """prefix·이슈번호(#123)·URL 제거, 공백 정리."""
    msg = _PREFIX_RE.sub("", line)
    msg = re.sub(r"#[0-9]+", "", msg)
    msg = re.sub(r"https?://\S+", "", msg)
    msg = re.sub(r" {2,}", " ", msg).strip()
    return msg or line.strip()


def classify(commits):
    """커밋 제목들을 섹션별로 분류해 {섹션key: [메시지…]} 반환."""
    sections = {key: [] for key, _ in SECTION_ORDER}
    for line in commits:
        m = _PREFIX_RE.match(line)
        key = _PREFIX_TO_SECTION.get(m.group(1), "etc") if m else "etc"
        sections[key].append(clean_message(line))
    return sections


def sections_to_markdown(sections):
    parts = []
    for key, title in SECTION_ORDER:
        items = sections.get(key) or []
        if not items:
            continue
        parts.append(f"* **{title}**")
        parts.extend(f"  * {msg}" for msg in items)
        parts.append("")
    return "\n".join(parts).rstrip("\n")


def write_pr_body(content, path="pr_body.md"):
    """Summary by CodeRabbit 고정 구조로 감싸 pr_body.md 저장 — changelog_manager.py 파싱 계약."""
    body = "\n".join([
        HEADER, "",
        "## Summary by CodeRabbit", "",
        "## 릴리스 노트", "",
        content, "",
        FOOTER, "",
    ])
    with open(path, "w", encoding="utf-8") as f:
        f.write(body)


def fail(reason):
    print(reason, file=sys.stderr)
    sys.exit(1)
