import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from suh_template.issue_number import (
    extract_from_path,
    extract_from_branch,
    resolve,
)


def test_extract_from_path_worktree():
    path = "/Users/dev/RomRom-FE-Worktree/20260115_427_드롭다운_디자인_변경"
    assert extract_from_path(path) == "427"


def test_extract_from_path_no_match():
    assert extract_from_path("/Users/dev/myproject") is None


def test_extract_from_branch_feature():
    assert extract_from_branch("feature/427-dropdown") == "427"


def test_extract_from_branch_plain_number():
    assert extract_from_branch("fix/123-bug") == "123"


def test_extract_from_branch_no_match():
    assert extract_from_branch("main") is None


def test_resolve_worktree_wins():
    result, warn = resolve(worktree_number="427", branch_number="999")
    assert result == "427"
    assert warn is True


def test_resolve_only_worktree():
    result, warn = resolve(worktree_number="427", branch_number=None)
    assert result == "427"
    assert warn is False


def test_resolve_only_branch():
    result, warn = resolve(worktree_number=None, branch_number="427")
    assert result == "427"
    assert warn is False


def test_resolve_none():
    result, warn = resolve(worktree_number=None, branch_number=None)
    assert result is None
    assert warn is False
