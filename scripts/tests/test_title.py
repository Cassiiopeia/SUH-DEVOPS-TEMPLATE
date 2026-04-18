import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from suh_template.title import extract_from_path, normalize


def test_extract_from_worktree_path():
    path = "/Users/dev/RomRom-FE-Worktree/20260115_427_드롭다운_디자인_변경"
    assert extract_from_path(path) == "드롭다운_디자인_변경"


def test_extract_from_path_no_match():
    assert extract_from_path("/Users/dev/myproject") is None


def test_normalize_spaces_to_underscore():
    assert normalize("드롭다운 디자인 변경") == "드롭다운_디자인_변경"


def test_normalize_removes_special_chars():
    assert normalize("fix: 버그#1 수정!") == "fix_버그_1_수정"


def test_normalize_max_length():
    long_title = "가" * 60
    result = normalize(long_title)
    assert len(result) <= 50


def test_normalize_already_clean():
    assert normalize("드롭다운_디자인_변경") == "드롭다운_디자인_변경"


def test_normalize_english():
    assert normalize("dropdown design change") == "dropdown_design_change"
