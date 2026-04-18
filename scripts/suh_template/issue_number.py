"""worktree 폴더명 또는 git 브랜치명에서 이슈 번호를 추출한다."""

import re
import subprocess
from pathlib import Path
from typing import Optional, Tuple


_WORKTREE_PATTERN = re.compile(r"\d{8}_(\d+)_")
_BRANCH_PATTERN = re.compile(r"(?:^|[/_-])(\d+)(?:[/_-]|$)")


def extract_from_path(cwd: str) -> Optional[str]:
    """경로 문자열에서 worktree 패턴(YYYYMMDD_숫자_제목)의 숫자를 추출한다."""
    for part in Path(cwd).parts:
        m = _WORKTREE_PATTERN.search(part)
        if m:
            return m.group(1)
    return None


def extract_from_branch(branch: str) -> Optional[str]:
    """git 브랜치명에서 이슈 번호로 보이는 숫자를 추출한다."""
    m = _BRANCH_PATTERN.search(branch)
    return m.group(1) if m else None


def get_current_branch() -> Optional[str]:
    """현재 git 브랜치명을 반환한다. git 저장소가 아니면 None."""
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True,
            text=True,
            check=True,
        )
        return result.stdout.strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def resolve(
    worktree_number: Optional[str],
    branch_number: Optional[str],
) -> Tuple[Optional[str], bool]:
    """
    worktree 번호와 브랜치 번호를 받아 최종 이슈 번호와 경고 여부를 반환한다.

    Returns:
        (issue_number, mismatch_warn)
    """
    if worktree_number and branch_number:
        warn = worktree_number != branch_number
        return worktree_number, warn
    if worktree_number:
        return worktree_number, False
    if branch_number:
        return branch_number, False
    return None, False
