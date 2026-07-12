"""issue_helper.py 테스트 — 구 TS 액션(normalize.ts)과의 패리티 + 신규 기능."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from issue_helper import (
    DEFAULT_COMMIT_TYPE_MAP,
    create_branch_name,
    extract_issue_title,
    infer_commit_type,
    normalize_title,
    render_commit_message,
)


# ── 제목 추출 (구 extractIssueTitle 패리티) ──────────────────────────────
def test_extract_title_removes_tags():
    assert extract_issue_title("❗ [버그][로그인] 소셜 로그인 실패") == "소셜 로그인 실패"

def test_extract_title_removes_emoji():
    assert extract_issue_title("🚀 기능 개선") == "기능 개선"

def test_extract_title_fallback_when_empty():
    # 태그·이모지 제거 후 빈 문자열이면 원본 trim 반환 (구 동작 보존)
    assert extract_issue_title("  [버그]  ") == "[버그]"


# ── 정규화 (구 normalizeTitle 패리티, scripts/common/gh_branch.py와 규칙 동일) ──
def test_normalize_replaces_special_chars():
    assert normalize_title("FCM 푸시: 라우팅용 데이터!") == "FCM_푸시_라우팅용_데이터"

def test_normalize_collapses_underscores():
    assert normalize_title("a - - b") == "a_b"

def test_normalize_strips_edge_underscores():
    assert normalize_title("!한글 제목!") == "한글_제목"


# ── 브랜치명 (구 createBranchName 패리티 — base slice, prefix 제외) ─────────
def test_branch_name_core_format():
    b = create_branch_name("로그인 버그 수정", 123, "20260712")
    assert b == "20260712_#123_로그인_버그_수정"

def test_branch_name_prefix_excluded_from_limit():
    b = create_branch_name("가" * 200, 5, "20260712", branch_prefix="feat/", max_branch_length=30)
    assert b.startswith("feat/20260712_#5_")
    assert len(b) == len("feat/") + 30

def test_branch_name_contains_issue_number_token():
    # 불변 계약: 소비자 정규식 #(\d+) 이 반드시 매치해야 한다
    import re
    b = create_branch_name("제목", 42, "20260712", branch_prefix="fix/")
    assert re.search(r"#(\d+)", b).group(1) == "42"


# ── 커밋 타입 추론 (신규) ────────────────────────────────────────────────
def test_infer_type_bug():
    assert infer_commit_type("❗ [버그][로그인] 실패") == "fix"

def test_infer_type_feature_variants():
    assert infer_commit_type("[기능추가] X") == "feat"
    assert infer_commit_type("[기능개선] X") == "feat"

def test_infer_type_docs_design_test():
    assert infer_commit_type("[문서] X") == "docs"
    assert infer_commit_type("[디자인] X") == "design"
    assert infer_commit_type("[시험요청] X") == "test"

def test_infer_type_default_feat():
    assert infer_commit_type("태그 없는 제목") == "feat"

def test_infer_type_user_override():
    assert infer_commit_type("[버그] X", {"버그": "hotfix"}) == "hotfix"

def test_infer_type_unknown_tag_skipped():
    # 미등록 태그([긴급])는 건너뛰고 다음 태그로 판정
    assert infer_commit_type("[긴급][버그] X") == "fix"


# ── 커밋 템플릿 렌더링 (기존 5종 + 신규 3종 변수) ─────────────────────────
def test_render_all_variables():
    ctx = {
        "issueTitle": "로그인 수정", "issueUrl": "https://github.com/o/r/issues/9",
        "issueNumber": "9", "branchName": "20260712_#9_로그인_수정",
        "date": "20260712", "commitType": "fix", "labels": "작업전", "assignees": "Cassiiopeia",
    }
    out = render_commit_message(
        "${issueTitle} : ${commitType} : {설명} ${issueUrl} by ${assignees}", ctx)
    assert out == "로그인 수정 : fix : {설명} https://github.com/o/r/issues/9 by Cassiiopeia"

def test_render_leaves_unknown_placeholders():
    # {변경 사항에 대한 설명} 같은 사용자 안내 placeholder는 그대로 남긴다
    ctx = {"issueTitle": "t", "issueUrl": "u", "issueNumber": "1",
           "branchName": "b", "date": "d", "commitType": "feat", "labels": "", "assignees": ""}
    assert "{변경 사항에 대한 설명}" in render_commit_message(
        "${issueTitle} : feat : {변경 사항에 대한 설명}", ctx)
