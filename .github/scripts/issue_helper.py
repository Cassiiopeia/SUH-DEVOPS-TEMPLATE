#!/usr/bin/env python3
"""SUH-ISSUE-HELPER — 이슈 생성/제목수정 시 브랜치명·커밋 메시지 댓글 생성 (내재화 버전).

구 외부 액션(Cassiiopeia/github-issue-helper@deploy)을 대체한다. stdlib 전용.

⚠️ 불변 계약 — 아래 형식을 기계 파싱하는 소비자가 있으므로 절대 깨지 마라:
  1. 브랜치명 `{prefix}YYYYMMDD_#이슈번호_정규화제목`
     - PROJECT-FLUTTER-ANDROID-TEST-APK.yaml      : sed 's/.*#\\([0-9]*\\).*/\\1/p'
     - PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml   : 동일
     - PROJECT-FLUTTER-PROJECTOPS-APP-BUILD-TRIGGER.yaml : /#(\\d+)/
     - scripts/common/issue_number.py             : \\d{8}_(\\d+)_ (worktree)
  2. 댓글 본문의 `Guide by SUH-LAB` 문구 + `### 브랜치` 제목 + 코드블록
     - PROJECT-FLUTTER-PROJECTOPS-APP-BUILD-TRIGGER.yaml
       : /### 브랜치\\s*```\\s*([\\s\\S]*?)\\s*```/ (구버전이 사용자 레포에서 계속 실행됨)

설정: version.yml metadata.template.options.issue_helper (없으면 전부 기본값).
"""
from __future__ import annotations

import json
import os
import re
import sys
import unicodedata
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

# ── 기본 설정 (version.yml에 issue_helper 섹션이 없을 때) ─────────────────
DEFAULT_CONFIG = {
    "branch_prefix": "",
    "max_branch_length": 100,
    "timezone": "Asia/Seoul",
    "commit_template": "${issueTitle} : ${commitType} : {변경 사항에 대한 설명} ${issueUrl}",
    "commit_type_map": {},
    "comment_marker": "<!-- SUH-ISSUE-HELPER -->",
    "show_guide": True,
}

# 제목 태그 → 커밋 타입 (이슈 템플릿 4종의 제목 태그 기준). 설정 commit_type_map이 병합됨.
DEFAULT_COMMIT_TYPE_MAP = {
    "버그": "fix",
    "기능요청": "feat",
    "기능추가": "feat",
    "기능개선": "feat",
    "문서": "docs",
    "디자인": "design",
    "시험요청": "test",
}

_TAG = re.compile(r"\[([^\]]*)\]")
_KEEP = re.compile(r"[^가-힣a-zA-Z0-9]")   # 한글/영문/숫자 외 → _
_MULTI_UNDERSCORE = re.compile(r"_+")


def _strip_emoji(text: str) -> str:
    """이모지(So)·제어문자(C*)·변형선택자 제거 — 구 TS \\p{So}|\\p{C}|\\uFE0F|\\u200D 패리티."""
    out = []
    for ch in text:
        if ch in ("️", "‍"):
            continue
        cat = unicodedata.category(ch)
        if cat == "So" or cat.startswith("C"):
            continue
        out.append(ch)
    return "".join(out)


def extract_issue_title(raw_title: str) -> str:
    """[태그]·이모지 제거. 결과가 비면 원본 trim 반환 (구 동작 보존)."""
    title = _TAG.sub("", raw_title).strip()
    title = _strip_emoji(title).strip()
    return title if title else raw_title.strip()


def normalize_title(title: str) -> str:
    normalized = _KEEP.sub("_", title)
    normalized = _MULTI_UNDERSCORE.sub("_", normalized)
    return normalized.strip("_")


def infer_commit_type(raw_title: str, type_map: dict | None = None) -> str:
    """원본 제목의 [태그]들을 순서대로 매핑 조회. 미매치 시 feat."""
    merged = dict(DEFAULT_COMMIT_TYPE_MAP)
    if type_map:
        merged.update(type_map)
    for tag in _TAG.findall(raw_title):
        commit_type = merged.get(tag.strip())
        if commit_type:
            return commit_type
    return "feat"


def create_branch_name(
    title: str,
    issue_number: int | str,
    date_yyyymmdd: str,
    branch_prefix: str = "",
    max_branch_length: int = 100,
) -> str:
    """불변 계약 1: 코어 `YYYYMMDD_#번호_제목` 고정. 길이 제한은 코어부에만 적용(구 TS 패리티)."""
    base = f"{date_yyyymmdd}_#{issue_number}_{normalize_title(title)}"
    if max_branch_length > 0:
        base = base[:max_branch_length]
    return f"{branch_prefix}{base}"


def render_commit_message(template: str, ctx: dict) -> str:
    """${변수} 치환 — 기존 5종 + commitType/labels/assignees. 미지 변수는 그대로 둔다."""
    out = template
    for key in ("issueTitle", "issueUrl", "issueNumber", "branchName",
                "date", "commitType", "labels", "assignees"):
        out = out.replace("${" + key + "}", str(ctx.get(key, "")))
    return out.strip()
