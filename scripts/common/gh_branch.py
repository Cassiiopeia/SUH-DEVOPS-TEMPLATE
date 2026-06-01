"""브랜치명 계산 모듈 — SUH-ISSUE-HELPER TypeScript 로직의 Python 포팅."""

from __future__ import annotations

import re
from datetime import date


# 한글(가-힣), 영문, 숫자만 유지. 나머지는 _로 치환
_KEEP_PATTERN = re.compile(r"[^\uAC00-\uD7A3a-zA-Z0-9]")

# 연속 언더스코어를 단일 언더스코어로 변환
_MULTI_UNDERSCORE = re.compile(r"_+")

# Git branch 최대 길이 제한 (GitHub의 reference 제약)
_MAX_BRANCH_LEN = 100


def normalize_title(title: str) -> str:
    """이슈 제목을 브랜치명용 문자열로 정규화한다.

    Args:
        title: 정규화할 제목 문자열

    Returns:
        정규화된 문자열 (한글/영문/숫자/언더스코어만 포함)
    """
    # 한글, 영문, 숫자 외의 문자를 언더스코어로 치환
    normalized = _KEEP_PATTERN.sub("_", title)

    # 연속 언더스코어를 단일 언더스코어로 변환
    normalized = _MULTI_UNDERSCORE.sub("_", normalized)

    # 양쪽 언더스코어 제거
    return normalized.strip("_")


def create_branch_name(
    issue_title: str,
    issue_number: int,
    date_yyyymmdd: str | None = None,
) -> str:
    """YYYYMMDD_#이슈번호_정규화제목 형식의 브랜치명을 생성한다.

    Args:
        issue_title: 이슈 제목
        issue_number: 이슈 번호
        date_yyyymmdd: 날짜 (YYYYMMDD 형식). None이면 현재 날짜 사용

    Returns:
        100자 이내의 브랜치명 (형식: YYYYMMDD_#123_제목)
    """
    if date_yyyymmdd is None:
        date_yyyymmdd = date.today().strftime("%Y%m%d")

    # prefix: "YYYYMMDD_#이슈번호_"
    prefix = f"{date_yyyymmdd}_#{issue_number}_"

    # 남은 길이에서 제목 길이 계산
    max_title_len = _MAX_BRANCH_LEN - len(prefix)

    # prefix만으로도 제한을 초과하면 prefix만 반환 (트레일 언더스코어 제거)
    if max_title_len <= 0:
        return prefix.rstrip("_")

    # 제목 정규화 및 길이 제한
    normalized = normalize_title(issue_title)[:max_title_len].rstrip("_")

    return f"{prefix}{normalized}"


def get_commit_template(issue_title: str, issue_url: str) -> str:
    """커밋 메시지 템플릿을 반환한다.

    Args:
        issue_title: 이슈 제목
        issue_url: 이슈 URL

    Returns:
        커밋 메시지 템플릿 문자열
    """
    return f"{issue_title} : feat : {{설명}} {issue_url}"
