"""브랜치명 계산 모듈 테스트 — gh_branch.py"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from suh_template.gh_branch import normalize_title, create_branch_name, get_commit_template


def test_normalize_title_special_chars():
    """특수 문자 제거 테스트."""
    assert normalize_title("hello world!") == "hello_world"


def test_normalize_title_korean():
    """한글 처리 테스트."""
    assert normalize_title("드롭다운 디자인 변경") == "드롭다운_디자인_변경"


def test_normalize_title_consecutive_underscores():
    """연속 언더스코어 제거 테스트."""
    assert normalize_title("foo--bar__baz") == "foo_bar_baz"


def test_normalize_title_strip_underscores():
    """양쪽 언더스코어 제거 테스트."""
    assert normalize_title("!hello!") == "hello"


def test_normalize_title_mixed():
    """이모지 + 한글 + 영문 혼합 테스트."""
    assert normalize_title("⚙️[기능추가] 새 기능") == "기능추가_새_기능"


def test_create_branch_name_format():
    """브랜치명 형식 테스트."""
    result = create_branch_name("드롭다운 디자인 변경", 427, "20260115")
    assert result == "20260115_#427_드롭다운_디자인_변경"


def test_create_branch_name_length_limit():
    """브랜치명 길이 제한 테스트."""
    long_title = "가" * 200
    result = create_branch_name(long_title, 1, "20260115")
    assert len(result) <= 100
    assert not result.endswith("_")


def test_get_commit_template():
    """커밋 메시지 템플릿 테스트."""
    result = get_commit_template("기능추가", "https://github.com/owner/repo/issues/1")
    assert "기능추가" in result
    assert "https://github.com/owner/repo/issues/1" in result
    assert ": feat :" in result


def test_create_branch_name_extreme_number():
    """이슈 번호가 매우 커서 prefix가 100자에 근접해도 크래시 없이 동작해야 한다."""
    result = create_branch_name("제목", 10**15, "20260115")
    assert len(result) <= 100
    assert not result.endswith("_")


def test_normalize_title_empty_string():
    """빈 문자열 정규화 테스트."""
    assert normalize_title("") == ""


def test_normalize_title_all_special():
    """특수문자만 있는 문자열 정규화 테스트."""
    assert normalize_title("!@#$%") == ""
