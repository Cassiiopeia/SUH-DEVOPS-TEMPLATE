# SUH-ISSUE-HELPER 내재화 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 외부 GitHub 액션(`Cassiiopeia/github-issue-helper@deploy`) 의존을 제거하고 이슈 브랜치명/커밋 메시지 댓글 생성을 내부 Python 스크립트로 내재화한다.

**Architecture:** `.github/scripts/issue_helper.py`(stdlib 전용)가 GitHub Actions `issues` 이벤트에서 실행되어 제목 정규화 → 브랜치명/커밋 메시지 생성 → 댓글 upsert를 수행한다. 설정은 `version.yml`의 `metadata.template.options.issue_helper`(SSOT), 구 워크플로우의 커스텀 설정은 마이그레이션 엔진(#470)의 신규 `settingsExtractor` 훅이 자동 이관한다.

**Tech Stack:** Python 3 stdlib (`urllib`/`re`/`json`/`unicodedata`/`zoneinfo`), Node.js ESM (마법사 `src/`), node:test, pytest.

**Spec:** `docs/superpowers/specs/2026-07-12-issue-helper-internalization-design.md`

## Global Constraints

- **Python은 stdlib 전용** — pip/yq/jq/pyyaml 금지 (`version_manager.py` 표준과 동일)
- **불변 계약 1 (브랜치)**: `{prefix}YYYYMMDD_#{이슈번호}_{정규화제목}` — 코어 순서·`#` 고정. 소비자: `PROJECT-FLUTTER-ANDROID-TEST-APK.yaml:223`(`sed 's/.*#\([0-9]*\).*/\1/p'`), `PROJECT-FLUTTER-PROJECTOPS-APP-BUILD-TRIGGER.yaml:167`(`/#(\d+)/`), `scripts/common/issue_number.py:9`(`\d{8}_(\d+)_`)
- **불변 계약 2 (댓글)**: 본문에 `Guide by SUH-LAB` 문구 + `### 브랜치` 제목 + 코드블록. 소비자: `PROJECT-FLUTTER-PROJECTOPS-APP-BUILD-TRIGGER.yaml:206-220`의 정규식 `/### 브랜치\s*```\s*([\s\S]*?)\s*```/` — **구버전 파서가 사용자 레포에서 계속 돌므로 하위호환 필수**
- **공통 워크플로우는 두 곳 동일 유지**: `.github/workflows/` 루트 + `.github/workflows/project-types/common/`
- **커밋 컨벤션**: `제목 : type : 설명` — 이모지/태그 접두 금지, Co-Authored-By 금지
- **동시 작업 주의**: 다른 에이전트가 develop에서 `src/commands/interactive.js`·`src/core/copy/workflows.js`·`src/core/version-yml.js` 등을 수정 중 — **registry.js 수정은 추가(additive)로만**, 각 커밋 전 `git status`로 남의 미커밋 변경을 스테이징하지 않는지 확인, **남의 파일은 절대 git add 금지** (git add는 항상 파일 명시, `git add -A` 금지)
- Flutter 워크플로우 3종 수정은 **헤더 주석만** — `run:`/`uses:`/`with:`/`steps:` 실행 로직 무손상을 `git diff`로 자가검증

## File Structure

| 작업 | 파일 | 책임 |
|---|---|---|
| 신규 | `.github/scripts/issue_helper.py` | 이벤트 처리·정규화·브랜치/커밋 생성·동적 가이드·댓글 upsert (단일 파일, MCP-style 아님 — 워크플로우 전용 실행 스크립트) |
| 신규 | `.github/scripts/test/test_issue_helper.py` | pytest — 정규화 패리티·커밋타입·템플릿·계약·설정 파싱 |
| 신규 | `.github/workflows/PROJECT-COMMON-SUH-ISSUE-HELPER.yaml` + `project-types/common/` 동일본 | 이벤트 트리거 + py 실행 |
| 삭제 | `project-types/common/PROJECT-COMMON-SUH-ISSUE-HELPER-API.yaml` | deprecated |
| 삭제 | `PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE.yml` (루트+common 두 곳) | 외부 액션 호출본 |
| 수정 | `src/core/migrations/registry.js` | 구 파일 2건 등록 + replacedBy 2건 갱신 |
| 신규 | `src/core/migrations/rules/settings-extractors.js` | 구 `with:` → version.yml 이관 |
| 수정 | `src/core/migrations/rules/obsolete-workflows.js` | apply 전 추출기 실행 훅 |
| 수정 | `src/core/copy/simple.js` | `issue_helper.py` 복사 목록 추가 |
| 수정 | `test/migrations.test.js` | 설정 이관 테스트 추가 |
| 수정 | Flutter 워크플로우 3종 | 헤더 주석에 브랜치 규칙 의존 블록 |
| 신규 | `docs/BRANCH-CONVENTION.md` | 브랜치 규칙 중앙 문서 |
| 수정 | `CLAUDE.md`, `docs/ISSUE-AUTOMATION.md`, `docs/WORKFLOW-COMMENT-GUIDELINES.md` | 명칭/설명 갱신 |

---

### Task 1: `issue_helper.py` 코어 로직 (정규화·커밋타입·브랜치·템플릿)

**Files:**
- Create: `.github/scripts/issue_helper.py`
- Test: `.github/scripts/test/test_issue_helper.py`

**Interfaces (Produces):**
- `extract_issue_title(raw_title: str) -> str` — `[태그]`·이모지 제거
- `normalize_title(title: str) -> str` — 한글/영문/숫자 외 `_` 치환
- `infer_commit_type(raw_title: str, type_map: dict | None = None) -> str`
- `create_branch_name(title, issue_number, date_yyyymmdd, branch_prefix="", max_branch_length=100) -> str`
- `render_commit_message(template: str, ctx: dict) -> str` — ctx 키: `issueTitle, issueUrl, issueNumber, branchName, date, commitType, labels, assignees`
- `DEFAULT_COMMIT_TYPE_MAP: dict`

- [ ] **Step 1: 실패하는 테스트 작성**

`.github/scripts/test/test_issue_helper.py` 생성:

```python
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
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd /Users/suhsaechan/Desktop/Programming/project/SUH-DEVOPS-TEMPLATE && python3 -m pytest .github/scripts/test/test_issue_helper.py -v`
Expected: FAIL — `ModuleNotFoundError: No module named 'issue_helper'`

- [ ] **Step 3: 최소 구현 작성**

`.github/scripts/issue_helper.py` 생성:

```python
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
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `python3 -m pytest .github/scripts/test/test_issue_helper.py -v`
Expected: PASS (15개 전부)

- [ ] **Step 5: 커밋**

```bash
git add .github/scripts/issue_helper.py .github/scripts/test/test_issue_helper.py
git commit -m "이슈 헬퍼 내재화 코어 로직 : feat : 정규화·브랜치명·커밋타입 추론·템플릿 렌더링 (구 TS 액션 패리티)"
```

---

### Task 2: 설정 로드 + 동적 가이드 + 댓글 본문 (계약 테스트)

**Files:**
- Modify: `.github/scripts/issue_helper.py` (함수 추가)
- Test: `.github/scripts/test/test_issue_helper.py` (테스트 추가)

**Interfaces:**
- Consumes: Task 1의 전 함수
- Produces:
  - `load_config(repo_root: str = ".") -> dict` — DEFAULT_CONFIG 병합 결과
  - `build_guide(workflows_dir: Path) -> str` — 파일 실존 기반 접이식 가이드 (빈 문자열 가능)
  - `build_comment_body(cfg: dict, branch_name: str, commit_message: str, guide: str) -> str`
  - `GUIDE_LINES: list[tuple[str, str]]`

- [ ] **Step 1: 실패하는 테스트 추가**

`test_issue_helper.py`에 추가:

```python
import re as _re

from issue_helper import (
    DEFAULT_CONFIG,
    GUIDE_LINES,
    build_comment_body,
    build_guide,
    load_config,
)


# ── 설정 로드 ────────────────────────────────────────────────────────────
def test_load_config_defaults_when_no_file(tmp_path):
    cfg = load_config(str(tmp_path))
    assert cfg == DEFAULT_CONFIG

def test_load_config_defaults_when_no_section(tmp_path):
    (tmp_path / "version.yml").write_text('version: "1.0.0"\nmetadata:\n  last_updated: "x"\n', encoding="utf-8")
    assert load_config(str(tmp_path)) == DEFAULT_CONFIG

def test_load_config_reads_section(tmp_path):
    (tmp_path / "version.yml").write_text(
        'version: "1.0.0"\n'
        "metadata:\n"
        "  template:\n"
        "    options:\n"
        "      issue_helper:\n"
        '        branch_prefix: "feat/"\n'
        "        max_branch_length: 80\n"
        '        commit_template: "${issueTitle} : ${commitType} : ${issueUrl}"\n'
        "        show_guide: false\n"
        "        commit_type_map:\n"
        '          "버그": "hotfix"\n'
        '          "디자인": "style"\n',
        encoding="utf-8",
    )
    cfg = load_config(str(tmp_path))
    assert cfg["branch_prefix"] == "feat/"
    assert cfg["max_branch_length"] == 80
    assert cfg["show_guide"] is False
    assert cfg["commit_type_map"] == {"버그": "hotfix", "디자인": "style"}
    assert cfg["timezone"] == "Asia/Seoul"  # 미지정 키는 기본값 유지


# ── 동적 가이드 (파일 실존 기반 — 마법사 setting에서 타입 변경 시 자동 추종) ──
def test_guide_lists_only_existing_workflows(tmp_path):
    wf = tmp_path / ".github" / "workflows"
    wf.mkdir(parents=True)
    (wf / "PROJECT-FLUTTER-PROJECTOPS-APP-BUILD-TRIGGER.yaml").write_text("name: x\n", encoding="utf-8")
    guide = build_guide(wf)
    assert "@projectops app build" in guide
    assert "테스트 APK 빌드" not in guide  # 파일 없으면 안내 안 함 (거짓 안내 차단)

def test_guide_always_mentions_skills(tmp_path):
    wf = tmp_path / ".github" / "workflows"
    wf.mkdir(parents=True)
    guide = build_guide(wf)
    # 스킬 연동은 레포 구성 무관 — 항상 포함
    assert "이슈 번호를 자동 추출" in guide


# ── 댓글 본문 — 불변 계약 2 (BUILD-TRIGGER 파서 하위호환) ───────────────────
def _body(tmp_path, show_guide=True):
    cfg = dict(DEFAULT_CONFIG, show_guide=show_guide)
    return build_comment_body(cfg, "20260712_#9_제목", "제목 : fix : {설명} url", "가이드텍스트")

def test_comment_contract_guide_by_suh_lab(tmp_path):
    assert "Guide by SUH-LAB" in _body(tmp_path)

def test_comment_contract_branch_block_parseable(tmp_path):
    # BUILD-TRIGGER.yaml:220 의 JS 정규식과 동일 패턴으로 파싱 가능해야 한다
    m = _re.search(r"### 브랜치\s*```\s*([\s\S]*?)\s*```", _body(tmp_path))
    assert m and m.group(1).strip() == "20260712_#9_제목"

def test_comment_contains_marker_twice(tmp_path):
    body = _body(tmp_path)
    assert body.count(DEFAULT_CONFIG["comment_marker"]) == 2  # 구 액션과 동일: 상단+하단

def test_comment_guide_hidden_when_disabled(tmp_path):
    assert "가이드텍스트" not in _body(tmp_path, show_guide=False)
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `python3 -m pytest .github/scripts/test/test_issue_helper.py -v`
Expected: FAIL — `ImportError: cannot import name 'load_config'`

- [ ] **Step 3: 구현 추가**

`issue_helper.py`에 추가 (기존 코드 아래):

```python
# ── 설정 로드 (version.yml — pyyaml 없이 이 섹션만 파싱) ────────────────────
def _unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in ("'", '"'):
        return value[1:-1]
    return value


def load_config(repo_root: str = ".") -> dict:
    """version.yml의 issue_helper 블록을 파싱해 DEFAULT_CONFIG에 병합한다.

    파일/섹션이 없으면 기본값 그대로 — 기존 통합 레포의 무설정 동작을 보존한다.
    향후 마법사 '설정 중앙관리' 메뉴가 이 섹션을 읽고 쓴다 (플랫 스칼라 + 얕은 맵 1개 유지).
    """
    cfg = dict(DEFAULT_CONFIG)
    cfg["commit_type_map"] = dict(DEFAULT_CONFIG["commit_type_map"])
    path = Path(repo_root) / "version.yml"
    if not path.exists():
        return cfg

    lines = path.read_text(encoding="utf-8").splitlines()
    section_indent = None
    in_type_map = False
    type_map_indent = 0
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())

        if section_indent is None:
            if re.match(r"^issue_helper:\s*(#.*)?$", stripped):
                section_indent = indent
            continue

        if indent <= section_indent:  # 섹션 종료
            break

        m = re.match(r"""^["']?([^"':]+)["']?\s*:\s*(.*?)\s*$""", stripped)
        if not m:
            continue
        key, raw = m.group(1).strip(), re.sub(r"\s+#.*$", "", m.group(2))

        if in_type_map and indent > type_map_indent:
            cfg["commit_type_map"][key] = _unquote(raw)
            continue
        in_type_map = False

        if key == "commit_type_map":
            in_type_map = True
            type_map_indent = indent
        elif key == "max_branch_length":
            try:
                cfg[key] = int(_unquote(raw))
            except ValueError:
                pass  # 잘못된 값은 기본값 유지
        elif key == "show_guide":
            cfg[key] = _unquote(raw).lower() != "false"
        elif key in ("branch_prefix", "timezone", "commit_template", "comment_marker"):
            cfg[key] = _unquote(raw)
    return cfg


# ── 동적 가이드 — 레포에 실존하는 워크플로우만 안내 (거짓 안내 원천 차단) ────
# ⚠️ 확장 규칙: 새 워크플로우가 브랜치 규칙(YYYYMMDD_#번호_)에 의존하게 되면 여기 한 줄 추가.
#    파일 실존 기반이므로 마법사 setting에서 타입 변경 시 자동 추종된다.
GUIDE_LINES = [
    ("PROJECT-FLUTTER-PROJECTOPS-APP-BUILD-TRIGGER.yaml",
     "`@projectops app build` 댓글 빌드 — 이 댓글의 브랜치를 자동 인식해서 빌드"),
    ("PROJECT-FLUTTER-ANDROID-TEST-APK.yaml",
     "테스트 APK 빌드 — 브랜치의 `#이슈번호`로 이슈 정보를 빌드 노트에 자동 포함"),
    ("PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml",
     "테스트 TestFlight 빌드 — 브랜치의 `#이슈번호`로 이슈 정보를 자동 연동"),
]

_GUIDE_ALWAYS = [
    "커밋/보고서/리뷰 스킬 — 브랜치·worktree 폴더명에서 이슈 번호를 자동 추출해 커밋 메시지·보고서 완성",
]


def build_guide(workflows_dir: Path) -> str:
    """접이식(details) 안내 본문. 레포에 의존 기능이 있으면 그 목록을, 없으면 권장 한 줄만."""
    active = [text for fname, text in GUIDE_LINES if (workflows_dir / fname).exists()]
    items = "\n".join(f"- {t}" for t in active + _GUIDE_ALWAYS)
    return (
        "<details>\n"
        "<summary>💡 왜 이 브랜치명을 써야 하나요?</summary>\n\n"
        "이 브랜치명 형식(`YYYYMMDD_#이슈번호_제목`)을 쓰면 아래 기능이 자동으로 연동됩니다:\n"
        f"{items}\n\n"
        "다른 형식의 브랜치명을 쓰면 위 자동화가 동작하지 않습니다.\n"
        "</details>"
    )


def build_comment_body(cfg: dict, branch_name: str, commit_message: str, guide: str) -> str:
    """불변 계약 2: Guide by SUH-LAB + ### 브랜치 코드블록 구조 유지 (구 파서 하위호환)."""
    marker = cfg["comment_marker"]
    guide_block = f"\n{guide}\n" if (cfg.get("show_guide", True) and guide) else ""
    return (
        f"{marker}\n\n"
        "Guide by SUH-LAB\n"
        "---\n\n"
        "### 브랜치\n"
        f"```\n{branch_name}\n```\n\n"
        "### 커밋 메시지\n"
        f"```\n{commit_message}\n```\n"
        f"{guide_block}\n"
        f"{marker}"
    )
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `python3 -m pytest .github/scripts/test/test_issue_helper.py -v`
Expected: PASS 전부

- [ ] **Step 5: 커밋**

```bash
git add .github/scripts/issue_helper.py .github/scripts/test/test_issue_helper.py
git commit -m "이슈 헬퍼 설정·가이드·댓글 본문 : feat : version.yml 설정 파싱, 파일 실존 기반 동적 가이드, BUILD-TRIGGER 파서 계약 테스트"
```

---

### Task 3: 이벤트 처리 + GitHub API 댓글 upsert + main()

**Files:**
- Modify: `.github/scripts/issue_helper.py`
- Test: `.github/scripts/test/test_issue_helper.py`

**Interfaces:**
- Consumes: Task 1·2의 전 함수
- Produces:
  - `should_process(payload: dict) -> bool` — opened / edited+title만 True
  - `prepare_comment(payload: dict, cfg: dict, workflows_dir: Path, date_yyyymmdd: str) -> tuple[str, str, str]` — (branch, commit_msg, body)
  - `find_existing_comment(comments: list[dict], marker: str) -> dict | None` — 신형 마커 → 구형 마커 순 매칭
  - `today_yyyymmdd(tz_name: str) -> str`
  - `main() -> int`

- [ ] **Step 1: 실패하는 테스트 추가**

```python
from issue_helper import (
    LEGACY_MARKER_HINTS,
    find_existing_comment,
    prepare_comment,
    should_process,
    today_yyyymmdd,
)


def _payload(action="opened", title="[버그] 로그인 실패", changes=None):
    p = {
        "action": action,
        "issue": {
            "number": 7,
            "title": title,
            "html_url": "https://github.com/o/r/issues/7",
            "labels": [{"name": "작업전"}],
            "assignees": [{"login": "Cassiiopeia"}],
        },
        "repository": {"name": "r", "owner": {"login": "o"}},
    }
    if changes is not None:
        p["changes"] = changes
    return p


# ── 이벤트 필터링 ────────────────────────────────────────────────────────
def test_process_opened():
    assert should_process(_payload("opened")) is True

def test_process_edited_with_title_change():
    assert should_process(_payload("edited", changes={"title": {"from": "old"}})) is True

def test_skip_edited_body_only():
    assert should_process(_payload("edited", changes={"body": {"from": "old"}})) is False

def test_skip_other_actions():
    assert should_process(_payload("closed")) is False


# ── 종단 조립 ────────────────────────────────────────────────────────────
def test_prepare_comment_end_to_end(tmp_path):
    wf = tmp_path / ".github" / "workflows"
    wf.mkdir(parents=True)
    branch, commit, body = prepare_comment(_payload(), dict(DEFAULT_CONFIG), wf, "20260712")
    assert branch == "20260712_#7_로그인_실패"
    assert commit.startswith("로그인 실패 : fix : ")           # [버그] → fix 추론
    assert "https://github.com/o/r/issues/7" in commit
    m = _re.search(r"### 브랜치\s*```\s*([\s\S]*?)\s*```", body)  # 계약 재확인
    assert m.group(1).strip() == branch


# ── upsert 매칭 (구 액션 댓글 하위호환) ──────────────────────────────────────
def test_find_comment_by_new_marker():
    comments = [{"id": 1, "body": "무관"}, {"id": 2, "body": "x <!-- SUH-ISSUE-HELPER --> y"}]
    assert find_existing_comment(comments, "<!-- SUH-ISSUE-HELPER -->")["id"] == 2

def test_find_comment_by_legacy_marker():
    # 구 액션 기본 마커 — github-issue-helper URL 포함
    legacy = ("<!-- 이 댓글은 SUH-ISSUE-HELPER 에 의해 자동으로 생성되었습니다."
              " - https://github.com/Cassiiopeia/github-issue-helper -->")
    comments = [{"id": 3, "body": f"{legacy}\nGuide by SUH-LAB"}]
    assert find_existing_comment(comments, "<!-- SUH-ISSUE-HELPER -->")["id"] == 3

def test_find_comment_none():
    assert find_existing_comment([{"id": 1, "body": "그냥 댓글"}], "<!-- SUH-ISSUE-HELPER -->") is None


# ── 날짜 (KST 개선 — 구 액션은 UTC 러너 시각) ────────────────────────────────
def test_today_is_8_digits():
    assert _re.fullmatch(r"\d{8}", today_yyyymmdd("Asia/Seoul"))

def test_today_invalid_tz_falls_back():
    assert _re.fullmatch(r"\d{8}", today_yyyymmdd("No/Such_Zone"))
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `python3 -m pytest .github/scripts/test/test_issue_helper.py -v`
Expected: FAIL — ImportError

- [ ] **Step 3: 구현 추가**

`issue_helper.py`에 추가:

```python
# ── 이벤트 처리 ──────────────────────────────────────────────────────────
def should_process(payload: dict) -> bool:
    """opened 또는 edited(제목 변경)만 처리 — 구 워크플로우 if 조건과 동일."""
    action = payload.get("action")
    if action == "opened":
        return True
    return action == "edited" and bool(payload.get("changes", {}).get("title"))


def today_yyyymmdd(tz_name: str) -> str:
    """설정 타임존 기준 오늘 날짜. 구 액션의 UTC 러너 시각 오차(한국 새벽 -9h)를 개선."""
    try:
        from zoneinfo import ZoneInfo
        return datetime.now(ZoneInfo(tz_name)).strftime("%Y%m%d")
    except Exception:
        return datetime.now(timezone.utc).strftime("%Y%m%d")


def prepare_comment(payload: dict, cfg: dict, workflows_dir: Path, date_yyyymmdd: str):
    """페이로드 → (브랜치명, 커밋 메시지, 댓글 본문). 네트워크 무의존 — 테스트 가능 단위."""
    issue = payload["issue"]
    raw_title = issue["title"]
    title = extract_issue_title(raw_title)
    issue_number = str(issue["number"])

    branch = create_branch_name(
        title, issue_number, date_yyyymmdd,
        branch_prefix=cfg["branch_prefix"], max_branch_length=cfg["max_branch_length"])

    ctx = {
        "issueTitle": title,
        "issueUrl": issue["html_url"],
        "issueNumber": issue_number,
        "branchName": branch,
        "date": date_yyyymmdd,
        "commitType": infer_commit_type(raw_title, cfg["commit_type_map"]),
        "labels": ", ".join(l["name"] for l in issue.get("labels", [])),
        "assignees": ", ".join(a["login"] for a in issue.get("assignees", [])),
    }
    commit_message = render_commit_message(cfg["commit_template"], ctx)
    body = build_comment_body(cfg, branch, commit_message, build_guide(workflows_dir))
    return branch, commit_message, body


# ── GitHub API (urllib — 같은 레포 이슈 댓글이라 redirect 없음) ──────────────
_API = "https://api.github.com"

# 구 액션이 남긴 댓글도 upsert 대상으로 매칭 (중복 댓글 방지 — 하위호환)
LEGACY_MARKER_HINTS = ("github-issue-helper", "SUH-ISSUE-HELPER 에 의해 자동으로")


def _request(method: str, url: str, token: str, data: dict | None = None):
    req = urllib.request.Request(url, method=method)
    req.add_header("Authorization", f"token {token}")
    req.add_header("Accept", "application/vnd.github+json")
    payload = None
    if data is not None:
        payload = json.dumps(data).encode("utf-8")
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, payload) as res:
        return json.loads(res.read().decode("utf-8"))


def find_existing_comment(comments: list, marker: str):
    """신형 마커 우선, 없으면 구 액션 마커 힌트로 매칭."""
    for c in comments:
        if marker in (c.get("body") or ""):
            return c
    for c in comments:
        body = c.get("body") or ""
        if any(hint in body for hint in LEGACY_MARKER_HINTS):
            return c
    return None


def upsert_comment(owner: str, repo: str, issue_number: int, marker: str, body: str, token: str):
    comments = []
    page = 1
    while True:
        batch = _request(
            "GET",
            f"{_API}/repos/{owner}/{repo}/issues/{issue_number}/comments?per_page=100&page={page}",
            token)
        comments.extend(batch)
        if len(batch) < 100:
            break
        page += 1

    existing = find_existing_comment(comments, marker)
    if existing:
        _request("PATCH", f"{_API}/repos/{owner}/{repo}/issues/comments/{existing['id']}",
                 token, {"body": body})
        return "updated"
    _request("POST", f"{_API}/repos/{owner}/{repo}/issues/{issue_number}/comments",
             token, {"body": body})
    return "created"


def main() -> int:
    event_path = os.environ.get("GITHUB_EVENT_PATH", "")
    token = os.environ.get("GITHUB_TOKEN", "")
    if not event_path or not Path(event_path).exists():
        print("❌ GITHUB_EVENT_PATH가 없습니다 (Actions 환경 전용)", file=sys.stderr)
        return 1
    if not token:
        print("❌ GITHUB_TOKEN이 없습니다", file=sys.stderr)
        return 1

    payload = json.loads(Path(event_path).read_text(encoding="utf-8"))
    if not should_process(payload):
        print("ℹ️ 처리 대상 이벤트가 아님 (opened/제목 edited만) → 종료", file=sys.stderr)
        return 0

    cfg = load_config(".")
    branch, commit_message, body = prepare_comment(
        payload, cfg, Path(".github") / "workflows", today_yyyymmdd(cfg["timezone"]))

    owner = payload["repository"]["owner"]["login"]
    repo = payload["repository"]["name"]
    result = upsert_comment(
        owner, repo, payload["issue"]["number"], cfg["comment_marker"], body, token)
    print(f"✅ 댓글 {result}: {branch}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: 테스트 + 문법 검증**

Run: `python3 -m pytest .github/scripts/test/test_issue_helper.py -v && python3 -m py_compile .github/scripts/issue_helper.py`
Expected: PASS 전부 + py_compile 무출력

- [ ] **Step 5: 커밋**

```bash
git add .github/scripts/issue_helper.py .github/scripts/test/test_issue_helper.py
git commit -m "이슈 헬퍼 이벤트 처리·댓글 upsert : feat : opened/제목수정 필터, 구 마커 하위호환 매칭, KST 날짜"
```

---

### Task 4: 워크플로우 교체 (API 삭제·MODULE 삭제·신규 생성)

**Files:**
- Delete: `.github/workflows/project-types/common/PROJECT-COMMON-SUH-ISSUE-HELPER-API.yaml`
- Delete: `.github/workflows/PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE.yml`
- Delete: `.github/workflows/project-types/common/PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE.yml`
- Create: `.github/workflows/PROJECT-COMMON-SUH-ISSUE-HELPER.yaml`
- Create: `.github/workflows/project-types/common/PROJECT-COMMON-SUH-ISSUE-HELPER.yaml` (동일 내용)

**Interfaces:**
- Consumes: Task 3의 `main()` (`python3 .github/scripts/issue_helper.py`)
- Produces: 워크플로우 파일명 `PROJECT-COMMON-SUH-ISSUE-HELPER.yaml` (Task 5 registry의 `replacedBy` 값)

- [ ] **Step 1: 구 파일 삭제**

```bash
git rm .github/workflows/project-types/common/PROJECT-COMMON-SUH-ISSUE-HELPER-API.yaml
git rm .github/workflows/PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE.yml
git rm .github/workflows/project-types/common/PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE.yml
```

- [ ] **Step 2: 신규 워크플로우 작성**

`.github/workflows/PROJECT-COMMON-SUH-ISSUE-HELPER.yaml` 생성:

```yaml
# ===================================================
# PROJECT-COMMON-SUH-ISSUE-HELPER
# ===================================================
#
# GitHub Issue 생성/제목 수정 시 브랜치명과 커밋 메시지 템플릿을 자동으로 댓글 생성합니다.
# 로직: .github/scripts/issue_helper.py (외부 액션 의존 없음 — v4.3.0에서 내재화)
#
# ⚙️ 커스터마이징: version.yml → metadata.template.options.issue_helper
#   branch_prefix / max_branch_length / timezone / commit_template
#   / commit_type_map / comment_marker / show_guide
#   (섹션이 없으면 전부 기본값으로 동작)
#
# 🔑 토큰: Public 레포는 GITHUB_TOKEN 자동 사용.
#   Private 레포에서 다른 워크플로우 연쇄 트리거가 필요하면 _GITHUB_PAT_TOKEN 시크릿 등록.
#
# ⚠️ 이 댓글을 기계 파싱하는 소비자가 있습니다 (형식 변경 금지):
#   - PROJECT-FLUTTER-PROJECTOPS-APP-BUILD-TRIGGER.yaml
#     : "Guide by SUH-LAB" 댓글에서 "### 브랜치" 코드블록을 추출해 빌드 대상 결정
#   상세: docs/BRANCH-CONVENTION.md (템플릿 레포)
#
# ===================================================

name: PROJECT-COMMON-SUH-ISSUE-HELPER

on:
  issues:
    types: [opened, edited]

permissions:
  issues: write
  contents: read

jobs:
  generate-comment:
    if: github.event.action == 'opened' || (github.event.action == 'edited' && github.event.changes.title)
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v5

      - name: Generate branch & commit comment
        env:
          GITHUB_TOKEN: ${{ secrets._GITHUB_PAT_TOKEN || secrets.GITHUB_TOKEN }}
        run: python3 .github/scripts/issue_helper.py
```

- [ ] **Step 3: common 복사본 생성 (두 곳 동일 유지 규칙)**

```bash
cp .github/workflows/PROJECT-COMMON-SUH-ISSUE-HELPER.yaml \
   .github/workflows/project-types/common/PROJECT-COMMON-SUH-ISSUE-HELPER.yaml
diff .github/workflows/PROJECT-COMMON-SUH-ISSUE-HELPER.yaml \
     .github/workflows/project-types/common/PROJECT-COMMON-SUH-ISSUE-HELPER.yaml
```
Expected: diff 무출력 (동일)

- [ ] **Step 4: 커밋**

```bash
git add .github/workflows/PROJECT-COMMON-SUH-ISSUE-HELPER.yaml \
        .github/workflows/project-types/common/PROJECT-COMMON-SUH-ISSUE-HELPER.yaml
git commit -m "이슈 헬퍼 워크플로우 내재화 교체 : feat : 외부 액션 제거, API 버전 삭제, MODULE을 SUH-ISSUE-HELPER로 리네임해 내부 py 실행"
```

---

### Task 5: 마이그레이션 — registry 등록 + 설정 자동 이관 (settingsExtractor)

**Files:**
- Modify: `src/core/migrations/registry.js` (36행·39행 replacedBy 갱신 + 신규 2건 — **추가만, 남의 변경 건드리지 않기**)
- Create: `src/core/migrations/rules/settings-extractors.js`
- Modify: `src/core/migrations/rules/obsolete-workflows.js`
- Test: `test/migrations.test.js`

**Interfaces:**
- Consumes: registry 스키마(`id/category/tier/file/replacedBy/since/reason`), `obsolete-workflows.js`의 `apply(targetRoot, entry)`
- Produces:
  - registry 선택 필드 `settingsExtractor: string`
  - `EXTRACTORS: { "suh-issue-helper-module": (targetRoot, entry) => { carried: string[] } }`
  - apply 반환에 `carried?: string[]` 필드 추가

- [ ] **Step 1: 실패하는 테스트 추가**

`test/migrations.test.js` 끝에 추가:

```js
// ── 설정 이관 (settingsExtractor, 이슈 헬퍼 내재화) ─────────────────────────

const OLD_MODULE = "PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE.yml";

function writeOldModule(root, withBlock) {
  writeFileSync(join(wfDir(root), OLD_MODULE), [
    "name: PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE",
    "jobs:",
    "  generate-comment:",
    "    steps:",
    "      - uses: Cassiiopeia/github-issue-helper@deploy",
    "        with:",
    ...withBlock.map((l) => `          ${l}`),
    "",
  ].join("\n"));
}

test("carryover: 커스텀 with 값이 version.yml issue_helper로 이관된다", () => {
  const root = fresh();
  try {
    writeOldModule(root, ['branch_prefix: "feat/"', "max_branch_length: 100",
      'commit_template: "${issueTitle} : feat : {변경 사항에 대한 설명} ${issueUrl}"']);
    writeFileSync(join(root, "version.yml"),
      'version: "1.0.0"\nmetadata:\n  last_updated: "x"\n');
    const { safe } = detectMigrations(root);
    const entry = safe.find((e) => e.file === OLD_MODULE);
    const [r] = applySafeMigrations(root, [entry]);
    assert.deepEqual(r.carried, ["branch_prefix"]); // 기본값과 다른 것만 이관
    const vy = readFileSync(join(root, "version.yml"), "utf8");
    assert.match(vy, /issue_helper:/);
    assert.match(vy, /branch_prefix: "feat\/"/);
    assert.ok(existsSync(join(wfDir(root), `${OLD_MODULE}.bak`))); // 무해화도 수행됨
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("carryover: 전부 기본값이면 version.yml을 건드리지 않는다", () => {
  const root = fresh();
  try {
    writeOldModule(root, ['branch_prefix: ""', "max_branch_length: 100"]);
    const before = 'version: "1.0.0"\nmetadata:\n  last_updated: "x"\n';
    writeFileSync(join(root, "version.yml"), before);
    const { safe } = detectMigrations(root);
    applySafeMigrations(root, [safe.find((e) => e.file === OLD_MODULE)]);
    assert.equal(readFileSync(join(root, "version.yml"), "utf8"), before);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("carryover: issue_helper 섹션이 이미 있으면 덮어쓰지 않는다 (신형 설정 우선·멱등)", () => {
  const root = fresh();
  try {
    writeOldModule(root, ['branch_prefix: "old/"']);
    const before = [
      'version: "1.0.0"', "metadata:", "  template:", "    options:",
      "      issue_helper:", '        branch_prefix: "new/"', "",
    ].join("\n");
    writeFileSync(join(root, "version.yml"), before);
    const { safe } = detectMigrations(root);
    applySafeMigrations(root, [safe.find((e) => e.file === OLD_MODULE)]);
    assert.equal(readFileSync(join(root, "version.yml"), "utf8"), before);
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("carryover: version.yml이 없으면 조용히 건너뛰고 무해화는 진행한다", () => {
  const root = fresh();
  try {
    writeOldModule(root, ['branch_prefix: "feat/"']);
    const { safe } = detectMigrations(root);
    const [r] = applySafeMigrations(root, [safe.find((e) => e.file === OLD_MODULE)]);
    assert.equal(r.action, "bak");
    assert.ok(!existsSync(join(root, "version.yml")));
  } finally { rmSync(root, { recursive: true, force: true }); }
});

test("registry: 이슈 헬퍼 구 파일 2종이 safe로 등록되어 있다", () => {
  const api = MIGRATIONS.find((m) => m.file === "PROJECT-COMMON-SUH-ISSUE-HELPER-API.yaml");
  const mod = MIGRATIONS.find((m) => m.file === OLD_MODULE);
  assert.equal(api?.tier, "safe");
  assert.equal(mod?.tier, "safe");
  assert.equal(mod?.settingsExtractor, "suh-issue-helper-module");
  assert.equal(api?.replacedBy, "PROJECT-COMMON-SUH-ISSUE-HELPER.yaml");
  assert.equal(mod?.replacedBy, "PROJECT-COMMON-SUH-ISSUE-HELPER.yaml");
});
```

`readFileSync`가 import에 없으면 상단 import에 추가한다 (기존: `mkdtempSync, mkdirSync, writeFileSync, existsSync, rmSync, readdirSync` → `readFileSync` 추가).

- [ ] **Step 2: 테스트 실패 확인**

Run: `cd /Users/suhsaechan/Desktop/Programming/project/SUH-DEVOPS-TEMPLATE && node --test test/migrations.test.js`
Expected: FAIL — registry에 항목 없음 + carried undefined

- [ ] **Step 3: registry.js 갱신**

36행 `wf-issue-comment-v1`과 39행 `wf-issue-comment-v2`의 `replacedBy`를 `"PROJECT-COMMON-SUH-ISSUE-HELPER.yaml"`로 변경하고, safe 구역 끝(70행 `wf-flutter-android-pr-ci` 뒤)에 추가:

```js
  { id: "wf-issue-helper-api", category: "workflow", tier: "safe",
    file: "PROJECT-COMMON-SUH-ISSUE-HELPER-API.yaml", replacedBy: "PROJECT-COMMON-SUH-ISSUE-HELPER.yaml",
    since: "4.3.0", reason: "이슈 헬퍼 API 버전 폐기 (dispatch 전용 비활성 잔재)" },
  { id: "wf-issue-helper-module", category: "workflow", tier: "safe",
    file: "PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE.yml", replacedBy: "PROJECT-COMMON-SUH-ISSUE-HELPER.yaml",
    since: "4.3.0", reason: "외부 액션 내재화 — 공존 시 이슈 댓글 중복",
    settingsExtractor: "suh-issue-helper-module" }, // 무해화 전 with: 커스텀 값을 version.yml로 이관
```

registry.js 상단 스키마 주석에 한 줄 추가:

```js
//   settingsExtractor - (선택) 무해화 직전 실행할 설정 이관기 이름
//                       (rules/settings-extractors.js의 EXTRACTORS 키)
```

- [ ] **Step 4: settings-extractors.js 작성**

`src/core/migrations/rules/settings-extractors.js` 생성:

```js
// 설정 이관기 (#470 확장) — 구 워크플로우의 커스텀 설정을 무해화 전에 version.yml로 이관.
// 원칙: 기본값과 다른 값만 이관 / issue_helper 섹션이 이미 있으면 불변(신형 우선·멱등)
//       / version.yml 없으면 skip / 실패해도 무해화를 막지 않는다(호출부에서 try-catch).
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

// 구 MODULE 워크플로우 배포본의 with: 기본값 — 이 값 그대로면 사용자 커스텀이 아니다
const OLD_DEFAULTS = {
  branch_prefix: "",
  max_branch_length: "100",
  commit_template: "${issueTitle} : feat : {변경 사항에 대한 설명} ${issueUrl}",
  comment_marker: "<!-- 이 댓글은 SUH-ISSUE-HELPER 에 의해 자동으로 생성되었습니다. - https://github.com/Cassiiopeia/github-issue-helper -->",
};

const KEYS = Object.keys(OLD_DEFAULTS);

function unquote(v) { return v.trim().replace(/^["']|["']$/g, ""); }

function parseWithValues(content) {
  const out = {};
  for (const key of KEYS) {
    const m = content.match(new RegExp(`^\\s*${key}:\\s*(.+)$`, "m"));
    if (m) out[key] = unquote(m[1].replace(/\s+#.*$/, ""));
  }
  return out;
}

// version.yml에 issue_helper 블록 삽입. 계층(metadata/template/options)이 없으면 만든다.
function insertIssueHelperBlock(vyText, carried) {
  const lines = Object.entries(carried)
    .map(([k, v]) => `        ${k}: "${v.replace(/"/g, '\\"')}"`);
  const block = ["      issue_helper:", ...lines].join("\n");

  if (/^\s{4}options:\s*$/m.test(vyText))
    return vyText.replace(/^(\s{4}options:\s*)$/m, `$1\n${block}`);
  if (/^\s{2}template:\s*$/m.test(vyText))
    return vyText.replace(/^(\s{2}template:\s*)$/m, `$1\n    options:\n${block}`);
  if (/^metadata:\s*$/m.test(vyText))
    return vyText.replace(/^(metadata:\s*)$/m, `$1\n  template:\n    options:\n${block}`);
  return `${vyText.replace(/\n*$/, "\n")}metadata:\n  template:\n    options:\n${block}\n`;
}

// 구 SUH-ISSUE-HELPER-MODULE의 with: → options.issue_helper 이관. 반환: { carried: [키...] }
export function extractIssueHelperModule(targetRoot, entry) {
  const wf = join(targetRoot, ".github", "workflows", entry.file);
  const vy = join(targetRoot, "version.yml");
  if (!existsSync(wf) || !existsSync(vy)) return { carried: [] };

  const vyText = readFileSync(vy, "utf8");
  if (/^\s*issue_helper:/m.test(vyText)) return { carried: [] }; // 신형 설정 우선

  const vals = parseWithValues(readFileSync(wf, "utf8"));
  const carried = {};
  for (const [k, v] of Object.entries(vals)) {
    if (v !== OLD_DEFAULTS[k]) carried[k] = v; // 기본값과 다른 것만
  }
  if (Object.keys(carried).length === 0) return { carried: [] };

  writeFileSync(vy, insertIssueHelperBlock(vyText, carried));
  return { carried: Object.keys(carried) };
}

export const EXTRACTORS = {
  "suh-issue-helper-module": extractIssueHelperModule,
};
```

- [ ] **Step 5: obsolete-workflows.js에 훅 배선**

`src/core/migrations/rules/obsolete-workflows.js`의 `apply`를 수정:

```js
import { EXTRACTORS } from "./settings-extractors.js";

export function apply(targetRoot, entry) {
  // 무해화 전 설정 이관 (실패해도 무해화는 진행 — 부분 실패 허용 원칙)
  let carried = [];
  if (entry.settingsExtractor && EXTRACTORS[entry.settingsExtractor]) {
    try { carried = EXTRACTORS[entry.settingsExtractor](targetRoot, entry).carried; }
    catch { carried = []; }
  }
  const src = target(targetRoot, entry);
  const bak = `${src}.bak`;
  if (existsSync(bak)) rmSync(bak, { force: true }); // Windows rename은 대상 존재 시 실패
  renameSync(src, bak);
  const result = { action: "bak", from: entry.file, to: `${entry.file}.bak` };
  if (carried.length > 0) result.carried = carried;
  return result;
}
```

- [ ] **Step 6: 테스트 통과 확인**

Run: `node --test test/migrations.test.js`
Expected: PASS 전부 (기존 테스트 포함 — 특히 "registry: 현행 배포 세트와 파일명이 절대 겹치지 않는다"가 Task 4의 삭제 덕에 통과)

- [ ] **Step 7: 커밋 (남의 미커밋 파일 확인 후)**

```bash
git status --short   # 다른 에이전트의 src/ 변경이 staged 되지 않는지 확인
git add src/core/migrations/registry.js src/core/migrations/rules/settings-extractors.js \
        src/core/migrations/rules/obsolete-workflows.js test/migrations.test.js
git commit -m "이슈 헬퍼 자동 마이그레이션 : feat : 구 워크플로우 2종 registry 등록, settingsExtractor 훅으로 with 커스텀 값 version.yml 자동 이관"
```

---

### Task 6: 복사 엔진 배선 + 전체 테스트

**Files:**
- Modify: `src/core/copy/simple.js:13-20` (scripts 배열)

**Interfaces:**
- Consumes: Task 1의 `.github/scripts/issue_helper.py` 존재
- Produces: npx 통합/업데이트 시 사용자 프로젝트에 `issue_helper.py` 복사됨

- [ ] **Step 1: scripts 배열에 추가**

`src/core/copy/simple.js`의 `copyScripts` 내 배열에 항목 추가:

```js
  const scripts = [
    "version_manager.sh", "version_manager.py",
    "changelog_manager.py",
    "truncate_release_notes.sh", "truncate_release_notes.py",
    "issue_helper.py",   // SUH-ISSUE-HELPER 내재화 (#이번이슈) — 워크플로우가 호출
    "changelog_providers/_common.py", "changelog_providers/ladder.py",
    "changelog_providers/commit.py", "changelog_providers/github_ai.py",
    "changelog_providers/openai_compatible.py",
  ];
```

파일 상단 주석(8-11행)에 한 줄 추가: `// issue_helper.py는 SUH-ISSUE-HELPER 워크플로우가 호출 — 함께 복사 필수.`

- [ ] **Step 2: 제외 목록 무변경 확인**

`issue_helper.py`는 사용자 프로젝트에 **가야 하는** 공통 자산이므로 `src/core/exclusions.js`·`template_initializer.py`에는 넣지 않는다. 확인:

```bash
grep -n "issue_helper" src/core/exclusions.js .github/scripts/template_initializer.py
```
Expected: 무출력 (없어야 정상)

- [ ] **Step 3: 전체 테스트**

Run: `npm test 2>&1 | tail -20 && python3 -m pytest .github/scripts/test/test_issue_helper.py -q`
Expected: node 테스트 전부 PASS + pytest 전부 PASS
(주의: 다른 에이전트의 미커밋 변경으로 무관한 테스트가 깨질 수 있음 — 깨진 테스트가 이번 변경 파일과 무관하면 그대로 두고 보고만 한다)

- [ ] **Step 4: 커밋**

```bash
git add src/core/copy/simple.js
git commit -m "이슈 헬퍼 복사 배선 : feat : npx 통합 시 issue_helper.py를 사용자 프로젝트에 복사"
```

---

### Task 7: Flutter 워크플로우 3종 — 브랜치 규칙 의존 헤더 주석

**Files:**
- Modify: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-ANDROID-TEST-APK.yaml` (헤더 주석)
- Modify: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml` (헤더 주석)
- Modify: `.github/workflows/project-types/flutter/PROJECT-FLUTTER-PROJECTOPS-APP-BUILD-TRIGGER.yaml` (헤더 주석)

**Interfaces:** 없음 (주석 전용 — 실행 로직 무손상)

- [ ] **Step 1: 표준 의존성 블록 삽입**

각 파일 헤더 주석부(파일 최상단 `# ===...` 블록 안, 기존 "브랜치명에서 이슈 번호 자동 추출" 줄 근처)에 아래 블록을 추가한다. 기존 주석 줄은 삭제하지 않는다:

```yaml
#
# ⚠️ 브랜치 규칙 의존:
# 이 워크플로우는 브랜치명 `YYYYMMDD_#이슈번호_제목` 형식에서 이슈 번호를 추출합니다.
# 이슈 생성 시 SUH-ISSUE-HELPER 댓글이 제안하는 브랜치명을 그대로 사용하세요.
# 형식이 다르면: 이슈 연동 빌드 정보가 누락됩니다 (빌드 자체는 진행).
# 상세: docs/BRANCH-CONVENTION.md (템플릿 레포)
#
```

BUILD-TRIGGER에는 마지막 두 줄 대신 아래를 사용 (댓글 계약도 명시):

```yaml
# 형식이 다르면: 이슈 댓글 빌드에서 브랜치를 찾지 못합니다.
# 또한 이슈의 "Guide by SUH-LAB" 댓글(### 브랜치 코드블록)을 파싱하므로
# SUH-ISSUE-HELPER 워크플로우가 활성화되어 있어야 이슈 댓글 빌드가 동작합니다.
# 상세: docs/BRANCH-CONVENTION.md (템플릿 레포)
```

- [ ] **Step 2: 실행 로직 무손상 자가검증**

```bash
git diff .github/workflows/project-types/flutter/ | grep "^[+-]" | grep -v "^[+-][+-]" | grep -v "^[+-]#"
```
Expected: 무출력 (주석 외 변경 0줄 — CLAUDE.md YAML 검증 규칙)

- [ ] **Step 3: 커밋**

```bash
git add .github/workflows/project-types/flutter/
git commit -m "플러터 워크플로우 브랜치 규칙 명시 : docs : 이슈번호 추출 의존성을 헤더 주석으로 표준화 (실행 로직 무변경)"
```

---

### Task 8: 문서 — BRANCH-CONVENTION.md + 기존 문서 갱신

**Files:**
- Create: `docs/BRANCH-CONVENTION.md`
- Modify: `CLAUDE.md:104` (워크플로우 표) + Skills 개발 가이드 근처에 GUIDE_LINES 확장 규칙
- Modify: `docs/ISSUE-AUTOMATION.md:63,208` (파일명·동작 설명)
- Modify: `docs/WORKFLOW-COMMENT-GUIDELINES.md:355` (표의 SUH-ISSUE-HELPER-API 행)

- [ ] **Step 1: BRANCH-CONVENTION.md 작성**

`docs/BRANCH-CONVENTION.md` 생성:

```markdown
# 브랜치 네이밍 규칙 (BRANCH CONVENTION)

> 이 문서는 템플릿 유지보수자용이다. 최종 사용자 안내는
> ① 이슈 헬퍼 댓글의 접이식 안내(사용 시점) ② 의존 워크플로우 헤더 주석(사용자 레포로 복사됨)이 담당한다.

## 형식

```
{prefix}YYYYMMDD_#이슈번호_정규화제목
예: 20260712_#427_드롭다운_디자인_변경
```

- 생성: `.github/scripts/issue_helper.py` (이슈 생성 시 댓글 제안) / `scripts/common/gh_branch.py` (pro-github 스킬) — **두 구현의 결과가 일치해야 한다**
- prefix(예: `feat/`)는 선택 — `version.yml`의 `options.issue_helper.branch_prefix`
- 코어부(`YYYYMMDD_#번호_제목`)는 고정 — 아래 소비자들이 기계 파싱한다

## 소비자 (이 형식을 깨면 죽는 것들)

| 소비자 | 파싱 방식 | 깨질 때 증상 |
|---|---|---|
| `PROJECT-FLUTTER-ANDROID-TEST-APK.yaml` | `sed 's/.*#\([0-9]*\).*/\1/p'` | 빌드 노트에 이슈 정보 누락 |
| `PROJECT-FLUTTER-IOS-TEST-TESTFLIGHT.yaml` | 동일 | 동일 |
| `PROJECT-FLUTTER-PROJECTOPS-APP-BUILD-TRIGGER.yaml` | `/#(\d+)/` + `Guide by SUH-LAB` 댓글의 `### 브랜치` 코드블록 | 이슈 댓글 빌드가 브랜치를 못 찾음 |
| `scripts/common/issue_number.py` (pro-commit/report/review) | worktree `\d{8}_(\d+)_` / 브랜치 숫자 패턴 | 커밋 메시지·보고서에서 이슈 번호 미인식 |

## 댓글 계약 (이슈 헬퍼가 생성하는 댓글)

`Guide by SUH-LAB` 문구와 `### 브랜치` 제목 + 코드블록 구조는 불변이다.
구버전 BUILD-TRIGGER가 사용자 레포에서 계속 실행되므로 하위호환이 필수다.

## 확장 규칙 (agent 필독)

- 새 워크플로우가 이 브랜치 규칙에 의존하게 되면:
  1. `issue_helper.py`의 `GUIDE_LINES`에 (파일명, 안내 문구) 한 줄 추가 — 파일 실존 기반이라
     해당 워크플로우가 없는 레포에는 안내가 표시되지 않는다 (거짓 안내 차단)
  2. 그 워크플로우 헤더에 "⚠️ 브랜치 규칙 의존" 표준 주석 블록 추가
  3. 이 문서의 소비자 표에 행 추가
```

- [ ] **Step 2: CLAUDE.md 갱신**

1. 104행의 표 행 교체:
   - 변경 전: `| `PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE` | 이슈 생성 | 브랜치명/커밋 제안 |`
   - 변경 후: `| `PROJECT-COMMON-SUH-ISSUE-HELPER` | 이슈 생성 | 브랜치명/커밋 제안 (내부 py — `issue_helper.py`) |`
2. "⚠️ 워크플로우를 리네임/삭제할 때" 절 바로 뒤에 추가:

```markdown
> **⚠️ 브랜치 규칙(`YYYYMMDD_#번호_제목`)에 의존하는 워크플로우를 추가할 때 (agent 필독)**:
> `.github/scripts/issue_helper.py`의 `GUIDE_LINES`에 (파일명, 안내 문구)를 추가하고,
> 워크플로우 헤더에 "⚠️ 브랜치 규칙 의존" 주석 블록을 넣는다. 상세: `docs/BRANCH-CONVENTION.md`
```

3. 핵심 스크립트 절에 추가:

```markdown
### issue_helper.py (이슈 브랜치/커밋 댓글 — #이번이슈에서 내재화)
이슈 생성/제목 수정 시 `PROJECT-COMMON-SUH-ISSUE-HELPER.yaml`이 실행. 외부 액션 의존 없음.
설정: `version.yml` `metadata.template.options.issue_helper` (branch_prefix/commit_template/commit_type_map 등 — 없으면 기본값).
구 MODULE 워크플로우의 커스텀 설정은 마이그레이션이 자동 이관한다 (`rules/settings-extractors.js`).
```

- [ ] **Step 3: ISSUE-AUTOMATION.md·WORKFLOW-COMMENT-GUIDELINES.md 갱신**

```bash
grep -n "SUH-ISSUE-HELPER" docs/ISSUE-AUTOMATION.md docs/WORKFLOW-COMMENT-GUIDELINES.md
```

- `docs/ISSUE-AUTOMATION.md:63`: `**파일**: \`PROJECT-COMMON-SUH-ISSUE-HELPER-MODULE.yaml\`` → `**파일**: \`PROJECT-COMMON-SUH-ISSUE-HELPER.yaml\` (로직: \`.github/scripts/issue_helper.py\` — v4.3.0 내재화)`
- `docs/ISSUE-AUTOMATION.md:208`: 같은 파일명 교체
- 같은 파일 "동작 방식" 절에 외부 모듈(`Cassiiopeia/github-issue-helper`) 언급이 있으면 내부 스크립트 설명으로 교체
- `docs/WORKFLOW-COMMENT-GUIDELINES.md:355`: `| SUH-ISSUE-HELPER-API | B | ✅ |` 행을 `| SUH-ISSUE-HELPER | B | ✅ |`로 교체 (API 버전은 삭제됨)

- [ ] **Step 4: 커밋**

```bash
git add docs/BRANCH-CONVENTION.md CLAUDE.md docs/ISSUE-AUTOMATION.md docs/WORKFLOW-COMMENT-GUIDELINES.md
git commit -m "브랜치 규칙 중앙 문서화 : docs : BRANCH-CONVENTION 신설, 이슈 헬퍼 내재화 반영 (CLAUDE.md·ISSUE-AUTOMATION 갱신)"
```

---

### Task 9: 최종 검증

- [ ] **Step 1: 전체 테스트 일괄 실행**

```bash
npm test 2>&1 | tail -5
python3 -m pytest .github/scripts/test/ -q
python3 -m py_compile .github/scripts/issue_helper.py
```
Expected: 전부 PASS

- [ ] **Step 2: 외부 의존 잔재 0건 확인**

```bash
grep -rn "github-issue-helper@\|Cassiiopeia/github-issue-helper@" .github/ src/ skills/ docs/ CLAUDE.md
```
Expected: 무출력 (uses: 참조 완전 제거 — 문서 내 역사 서술·하위호환 마커 문자열은 허용이므로 `@` 포함 패턴으로 검사)

- [ ] **Step 3: 두 곳 동일 유지 재확인**

```bash
diff .github/workflows/PROJECT-COMMON-SUH-ISSUE-HELPER.yaml \
     .github/workflows/project-types/common/PROJECT-COMMON-SUH-ISSUE-HELPER.yaml
```
Expected: 무출력

- [ ] **Step 4: 이슈 참조 커밋 정리 보고**

작업 완료 후 사용자에게 보고: 변경 요약 + `git log --oneline develop -9`. **push는 사용자가 명시 요청할 때만.**

---

## Self-Review 결과

- **Spec coverage**: 스펙 §1(API 삭제)→Task 4·5, §2(py)→Task 1~3, §3(워크플로우)→Task 4, §4(설정)→Task 2, §4.5(설정 이관)→Task 5, §5(배선·테스트)→Task 5·6, §6(가이드 3층)→Task 2·7·8, §7(문서)→Task 8. 누락 없음.
- **Placeholder scan**: 통과 — 전 코드 스텝에 실제 코드 포함.
- **Type consistency**: `prepare_comment` 반환 튜플, `EXTRACTORS` 키 `"suh-issue-helper-module"`, registry `replacedBy` = `PROJECT-COMMON-SUH-ISSUE-HELPER.yaml` — Task 간 일치 확인.
