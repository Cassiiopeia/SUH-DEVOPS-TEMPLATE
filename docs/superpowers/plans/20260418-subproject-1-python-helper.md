# Sub-project #1: 공통 Python 헬퍼 인프라 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** skill들이 산출물 md 경로를 표준화된 규칙으로 계산할 수 있는 Python 헬퍼 패키지(`scripts/suh_template/`)를 구축한다.

**Architecture:** `scripts/suh_template/` 패키지로 기능별 모듈 분리. `cli.py`가 단일 진입점으로 모든 커맨드를 처리. 각 모듈은 독립적으로 테스트 가능하다.

**Tech Stack:** Python 3.8+, 표준 라이브러리만 (`pathlib`, `subprocess`, `json`, `re`, `datetime`, `sys`, `os`)

---

## 파일 구조

| 파일 | 역할 |
|------|------|
| `scripts/suh_template/__init__.py` | 패키지 진입점, 버전 정의 |
| `scripts/suh_template/issue_number.py` | worktree/브랜치에서 이슈 번호 추출 |
| `scripts/suh_template/title.py` | worktree/경로에서 제목 추출 및 정규화 |
| `scripts/suh_template/paths.py` | 산출물 경로 계산 (날짜+번호+제목 조합) |
| `scripts/suh_template/config.py` | `.suh-template/config/` 로딩 |
| `scripts/suh_template/manifest.py` | `.cursor/skills/MANIFEST.json` 읽기/쓰기 |
| `scripts/suh_template/cli.py` | CLI 진입점, 커맨드 라우팅, 에러 출력 |
| `scripts/tests/test_issue_number.py` | issue_number 모듈 테스트 |
| `scripts/tests/test_title.py` | title 모듈 테스트 |
| `scripts/tests/test_paths.py` | paths 모듈 테스트 |
| `scripts/tests/test_config.py` | config 모듈 테스트 |
| `scripts/tests/test_manifest.py` | manifest 모듈 테스트 |
| `scripts/tests/test_cli.py` | CLI 통합 테스트 |
| `skills/references/doc-output-path.md` | skill SKILL.md가 참조할 공통 규칙 문서 |

---

## Task 1: 패키지 골격 생성

**Files:**
- Create: `scripts/suh_template/__init__.py`
- Create: `scripts/tests/__init__.py`

- [ ] **Step 1: 패키지 디렉토리와 `__init__.py` 생성**

```python
# scripts/suh_template/__init__.py
"""suh_template: cassiiopeia skill 공통 Python 헬퍼 패키지."""

__version__ = "1.0.0"

# 지원하는 skill_id 목록 (산출물 경로 생성 대상)
SUPPORTED_SKILL_IDS = [
    "analyze",
    "plan",
    "design-analyze",
    "refactor-analyze",
    "troubleshoot",
    "report",
    "ppt",
    "review",
]
```

- [ ] **Step 2: 테스트 패키지 디렉토리 생성**

```python
# scripts/tests/__init__.py
# 빈 파일
```

- [ ] **Step 3: 골격 커밋**

```bash
git add scripts/suh_template/__init__.py scripts/tests/__init__.py
git commit -m "feat: suh_template 패키지 골격 생성"
```

---

## Task 2: `issue_number.py` — 이슈 번호 추출

**Files:**
- Create: `scripts/suh_template/issue_number.py`
- Create: `scripts/tests/test_issue_number.py`

- [ ] **Step 1: 실패하는 테스트 작성**

```python
# scripts/tests/test_issue_number.py
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from suh_template.issue_number import (
    extract_from_path,
    extract_from_branch,
    resolve,
)


def test_extract_from_path_worktree():
    # worktree 경로에서 이슈 번호 추출
    path = "/Users/dev/RomRom-FE-Worktree/20260115_427_드롭다운_디자인_변경"
    assert extract_from_path(path) == "427"


def test_extract_from_path_no_match():
    # 패턴 없으면 None
    assert extract_from_path("/Users/dev/myproject") is None


def test_extract_from_branch_feature():
    # feature/427-dropdown 형태
    assert extract_from_branch("feature/427-dropdown") == "427"


def test_extract_from_branch_plain_number():
    # 브랜치명에 숫자만 있는 경우
    assert extract_from_branch("fix/123-bug") == "123"


def test_extract_from_branch_no_match():
    assert extract_from_branch("main") is None


def test_resolve_worktree_wins():
    # worktree와 브랜치 둘 다 있으면 worktree 우선
    result, warn = resolve(worktree_number="427", branch_number="999")
    assert result == "427"
    assert warn is True  # 불일치 경고


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
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
cd scripts && python -m pytest tests/test_issue_number.py -v
```

Expected: `ModuleNotFoundError` 또는 `ImportError`

- [ ] **Step 3: `issue_number.py` 구현**

```python
# scripts/suh_template/issue_number.py
"""worktree 폴더명 또는 git 브랜치명에서 이슈 번호를 추출한다."""

import re
import subprocess
from pathlib import Path
from typing import Optional, Tuple


# YYYYMMDD_숫자_제목 패턴
_WORKTREE_PATTERN = re.compile(r"\d{8}_(\d+)_")
# 브랜치명에서 숫자 추출 (feature/427-xxx, fix/123-xxx 등)
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
        - issue_number: 결정된 번호 (없으면 None)
        - mismatch_warn: 둘 다 있고 값이 다르면 True
    """
    if worktree_number and branch_number:
        warn = worktree_number != branch_number
        return worktree_number, warn
    if worktree_number:
        return worktree_number, False
    if branch_number:
        return branch_number, False
    return None, False
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
cd scripts && python -m pytest tests/test_issue_number.py -v
```

Expected: 9개 모두 PASS

- [ ] **Step 5: 커밋**

```bash
git add scripts/suh_template/issue_number.py scripts/tests/test_issue_number.py
git commit -m "feat: 이슈 번호 추출 모듈 구현 (issue_number.py)"
```

---

## Task 3: `title.py` — 제목 추출 및 정규화

**Files:**
- Create: `scripts/suh_template/title.py`
- Create: `scripts/tests/test_title.py`

- [ ] **Step 1: 실패하는 테스트 작성**

```python
# scripts/tests/test_title.py
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
    assert normalize("fix: 버그#1 수정!") == "fix_버그1_수정"


def test_normalize_max_length():
    long_title = "가" * 60
    result = normalize(long_title)
    assert len(result) <= 50


def test_normalize_already_clean():
    assert normalize("드롭다운_디자인_변경") == "드롭다운_디자인_변경"


def test_normalize_english():
    assert normalize("dropdown design change") == "dropdown_design_change"
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
cd scripts && python -m pytest tests/test_title.py -v
```

Expected: `ImportError`

- [ ] **Step 3: `title.py` 구현**

```python
# scripts/suh_template/title.py
"""worktree 폴더명에서 제목을 추출하고 파일명 안전 형식으로 정규화한다."""

import re
from pathlib import Path
from typing import Optional


_WORKTREE_PATTERN = re.compile(r"\d{8}_\d+_(.+)$")
# 허용: 한글, 영문, 숫자, 언더스코어
_ALLOWED = re.compile(r"[^\w가-힣]", re.UNICODE)
_MULTI_UNDERSCORE = re.compile(r"_+")
MAX_LENGTH = 50


def extract_from_path(cwd: str) -> Optional[str]:
    """경로에서 worktree 패턴의 제목 부분을 추출한다."""
    for part in reversed(Path(cwd).parts):
        m = _WORKTREE_PATTERN.search(part)
        if m:
            return m.group(1)
    return None


def normalize(text: str) -> str:
    """
    제목 문자열을 파일명 안전 형식으로 정규화한다.

    - 공백 → _
    - 허용되지 않는 문자 제거 (한글/영문/숫자/_ 만 허용)
    - 연속 언더스코어 → 단일 언더스코어
    - 최대 50자
    """
    text = text.replace(" ", "_")
    text = _ALLOWED.sub("_", text)
    text = _MULTI_UNDERSCORE.sub("_", text)
    text = text.strip("_")
    return text[:MAX_LENGTH]
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
cd scripts && python -m pytest tests/test_title.py -v
```

Expected: 7개 모두 PASS

- [ ] **Step 5: 커밋**

```bash
git add scripts/suh_template/title.py scripts/tests/test_title.py
git commit -m "feat: 제목 추출 및 정규화 모듈 구현 (title.py)"
```

---

## Task 4: `paths.py` — 산출물 경로 계산

**Files:**
- Create: `scripts/suh_template/paths.py`
- Create: `scripts/tests/test_paths.py`

- [ ] **Step 1: 실패하는 테스트 작성**

```python
# scripts/tests/test_paths.py
import sys
from pathlib import Path
from datetime import date
sys.path.insert(0, str(Path(__file__).parent.parent))

from suh_template.paths import get_next_seq, build_output_path


def test_get_next_seq_empty_dir(tmp_path):
    # 폴더에 파일 없으면 001
    skill_dir = tmp_path / "plan"
    skill_dir.mkdir()
    today = date.today().strftime("%Y%m%d")
    assert get_next_seq(skill_dir, today) == "001"


def test_get_next_seq_existing_files(tmp_path):
    # 오늘 날짜 파일 2개 있으면 003
    skill_dir = tmp_path / "plan"
    skill_dir.mkdir()
    today = date.today().strftime("%Y%m%d")
    (skill_dir / f"{today}_001_test.md").touch()
    (skill_dir / f"{today}_002_test.md").touch()
    assert get_next_seq(skill_dir, today) == "003"


def test_get_next_seq_other_date_ignored(tmp_path):
    # 다른 날짜 파일은 카운트 안 함
    skill_dir = tmp_path / "plan"
    skill_dir.mkdir()
    today = date.today().strftime("%Y%m%d")
    (skill_dir / "20200101_001_old.md").touch()
    assert get_next_seq(skill_dir, today) == "001"


def test_build_output_path_with_issue(tmp_path):
    skill_dir = tmp_path / "plan"
    skill_dir.mkdir()
    today = "20260418"
    path = build_output_path(
        base_dir=tmp_path,
        skill_id="plan",
        today=today,
        number="427",
        title="드롭다운_디자인_변경",
    )
    assert str(path) == str(tmp_path / "plan" / "20260418_427_드롭다운_디자인_변경.md")


def test_build_output_path_with_seq(tmp_path):
    skill_dir = tmp_path / "plan"
    skill_dir.mkdir()
    today = "20260418"
    path = build_output_path(
        base_dir=tmp_path,
        skill_id="plan",
        today=today,
        number="001",
        title="분석_결과",
    )
    assert str(path) == str(tmp_path / "plan" / "20260418_001_분석_결과.md")
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
cd scripts && python -m pytest tests/test_paths.py -v
```

Expected: `ImportError`

- [ ] **Step 3: `paths.py` 구현**

```python
# scripts/suh_template/paths.py
"""산출물 md 파일 경로를 계산한다."""

from pathlib import Path
from typing import Union


def get_next_seq(skill_dir: Path, today: str) -> str:
    """
    skill_dir 내에서 오늘 날짜(today)로 시작하는 파일 개수 + 1을 3자리로 반환한다.

    Args:
        skill_dir: 해당 skill의 출력 디렉토리 (예: docs/suh-template/plan/)
        today: YYYYMMDD 형식의 날짜 문자열
    """
    if not skill_dir.exists():
        return "001"
    count = sum(1 for f in skill_dir.iterdir() if f.name.startswith(today))
    return f"{count + 1:03d}"


def build_output_path(
    base_dir: Union[str, Path],
    skill_id: str,
    today: str,
    number: str,
    title: str,
) -> Path:
    """
    최종 산출물 경로를 반환한다.

    Args:
        base_dir: 프로젝트 루트 또는 docs/suh-template/ 상위
        skill_id: skill 이름 (예: "plan", "analyze")
        today: YYYYMMDD 형식의 날짜
        number: 이슈번호 또는 누적순번 (예: "427", "001")
        title: 정규화된 제목 (예: "드롭다운_디자인_변경")

    Returns:
        Path: docs/suh-template/{skill_id}/{today}_{number}_{title}.md
    """
    return Path(base_dir) / skill_id / f"{today}_{number}_{title}.md"
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
cd scripts && python -m pytest tests/test_paths.py -v
```

Expected: 5개 모두 PASS

- [ ] **Step 5: 커밋**

```bash
git add scripts/suh_template/paths.py scripts/tests/test_paths.py
git commit -m "feat: 산출물 경로 계산 모듈 구현 (paths.py)"
```

---

## Task 5: `config.py` — Config 로딩

**Files:**
- Create: `scripts/suh_template/config.py`
- Create: `scripts/tests/test_config.py`

- [ ] **Step 1: 실패하는 테스트 작성**

```python
# scripts/tests/test_config.py
import sys
import json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from suh_template.config import load, get_value


def test_load_existing_config(tmp_path):
    config_dir = tmp_path / ".suh-template" / "config"
    config_dir.mkdir(parents=True)
    config_file = config_dir / "issue.config.json"
    config_file.write_text(json.dumps({"github_repo": "https://github.com/test/repo"}))

    result = load(tmp_path, "issue")
    assert result == {"github_repo": "https://github.com/test/repo"}


def test_load_missing_config(tmp_path):
    # config 파일 없으면 None
    assert load(tmp_path, "issue") is None


def test_get_value_existing_key(tmp_path):
    config_dir = tmp_path / ".suh-template" / "config"
    config_dir.mkdir(parents=True)
    (config_dir / "issue.config.json").write_text(
        json.dumps({"github_repo": "https://github.com/test/repo"})
    )
    assert get_value(tmp_path, "issue", "github_repo") == "https://github.com/test/repo"


def test_get_value_missing_key(tmp_path):
    config_dir = tmp_path / ".suh-template" / "config"
    config_dir.mkdir(parents=True)
    (config_dir / "issue.config.json").write_text(json.dumps({}))
    assert get_value(tmp_path, "issue", "nonexistent") is None


def test_get_value_no_config(tmp_path):
    assert get_value(tmp_path, "issue", "github_repo") is None
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
cd scripts && python -m pytest tests/test_config.py -v
```

Expected: `ImportError`

- [ ] **Step 3: `config.py` 구현**

```python
# scripts/suh_template/config.py
"""skill별 사용자 config를 .suh-template/config/ 에서 로딩한다."""

import json
from pathlib import Path
from typing import Any, Optional


def _config_path(project_root: Path, skill_id: str) -> Path:
    return project_root / ".suh-template" / "config" / f"{skill_id}.config.json"


def load(project_root: Any, skill_id: str) -> Optional[dict]:
    """
    .suh-template/config/{skill_id}.config.json 을 읽어 dict로 반환한다.
    파일이 없으면 None을 반환한다.
    """
    path = _config_path(Path(project_root), skill_id)
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def get_value(project_root: Any, skill_id: str, key: str) -> Optional[str]:
    """config에서 특정 키의 값을 반환한다. config 없거나 키 없으면 None."""
    data = load(project_root, skill_id)
    if data is None:
        return None
    return data.get(key)
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
cd scripts && python -m pytest tests/test_config.py -v
```

Expected: 5개 모두 PASS

- [ ] **Step 5: 커밋**

```bash
git add scripts/suh_template/config.py scripts/tests/test_config.py
git commit -m "feat: config 로딩 모듈 구현 (config.py)"
```

---

## Task 6: `manifest.py` — Cursor 매니페스트 읽기/쓰기

**Files:**
- Create: `scripts/suh_template/manifest.py`
- Create: `scripts/tests/test_manifest.py`

- [ ] **Step 1: 실패하는 테스트 작성**

```python
# scripts/tests/test_manifest.py
import sys
import json
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

from suh_template.manifest import read, write, MANIFEST_PATH


def test_read_existing_manifest(tmp_path):
    manifest_dir = tmp_path / ".cursor" / "skills"
    manifest_dir.mkdir(parents=True)
    data = {"plugin_version": "2.9.9", "skills": []}
    (manifest_dir / "MANIFEST.json").write_text(json.dumps(data))

    result = read(tmp_path)
    assert result["plugin_version"] == "2.9.9"


def test_read_missing_manifest(tmp_path):
    assert read(tmp_path) is None


def test_write_creates_manifest(tmp_path):
    manifest_dir = tmp_path / ".cursor" / "skills"
    manifest_dir.mkdir(parents=True)
    data = {"plugin_version": "3.0.0", "skills": []}
    write(tmp_path, data)

    result = json.loads((manifest_dir / "MANIFEST.json").read_text())
    assert result["plugin_version"] == "3.0.0"


def test_manifest_path_constant():
    # MANIFEST_PATH는 .cursor/skills/MANIFEST.json 이어야 함
    assert MANIFEST_PATH == Path(".cursor") / "skills" / "MANIFEST.json"
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
cd scripts && python -m pytest tests/test_manifest.py -v
```

Expected: `ImportError`

- [ ] **Step 3: `manifest.py` 구현**

```python
# scripts/suh_template/manifest.py
""".cursor/skills/MANIFEST.json 을 읽고 쓴다."""

import json
from pathlib import Path
from typing import Any, Optional

MANIFEST_PATH = Path(".cursor") / "skills" / "MANIFEST.json"


def read(project_root: Any) -> Optional[dict]:
    """MANIFEST.json을 읽어 dict로 반환한다. 없으면 None."""
    path = Path(project_root) / MANIFEST_PATH
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def write(project_root: Any, data: dict) -> None:
    """MANIFEST.json에 data를 저장한다."""
    path = Path(project_root) / MANIFEST_PATH
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
cd scripts && python -m pytest tests/test_manifest.py -v
```

Expected: 4개 모두 PASS

- [ ] **Step 5: 커밋**

```bash
git add scripts/suh_template/manifest.py scripts/tests/test_manifest.py
git commit -m "feat: cursor 매니페스트 읽기/쓰기 모듈 구현 (manifest.py)"
```

---

## Task 7: `cli.py` — CLI 진입점 구현

**Files:**
- Create: `scripts/suh_template/cli.py`
- Create: `scripts/tests/test_cli.py`

- [ ] **Step 1: 실패하는 테스트 작성**

```python
# scripts/tests/test_cli.py
import sys
import subprocess
from pathlib import Path

SCRIPTS_DIR = Path(__file__).parent.parent


def run_cli(*args, cwd=None):
    """CLI를 서브프로세스로 실행하고 (stdout, stderr, returncode) 반환."""
    result = subprocess.run(
        [sys.executable, "-m", "suh_template.cli", *args],
        capture_output=True,
        text=True,
        cwd=str(cwd or SCRIPTS_DIR),
    )
    return result.stdout.strip(), result.stderr.strip(), result.returncode


def test_normalize_title():
    stdout, stderr, code = run_cli("normalize-title", "드롭다운 디자인 변경")
    assert code == 0
    assert stdout == "드롭다운_디자인_변경"
    assert stderr == ""


def test_normalize_title_special_chars():
    stdout, stderr, code = run_cli("normalize-title", "fix: 버그#1 수정!")
    assert code == 0
    assert stdout == "fix_버그1_수정"


def test_get_issue_number_no_git(tmp_path):
    # git 없는 임시 디렉토리: 빈 문자열 반환, exit 0
    stdout, stderr, code = run_cli("get-issue-number", cwd=tmp_path)
    assert code == 0
    assert stdout == ""


def test_get_next_seq_empty(tmp_path):
    # 빈 디렉토리에서 plan: 001
    stdout, stderr, code = run_cli("get-next-seq", "plan", cwd=tmp_path)
    assert code == 0
    assert stdout == "001"


def test_invalid_command():
    stdout, stderr, code = run_cli("nonexistent-command")
    assert code == 1
    assert "ERROR" in stderr


def test_skill_id_invalid():
    stdout, stderr, code = run_cli("get-next-seq", "invalid-skill")
    assert code == 1
    assert "skill_id_invalid" in stderr
```

- [ ] **Step 2: 테스트 실패 확인**

```bash
cd scripts && python -m pytest tests/test_cli.py -v
```

Expected: `ImportError` 또는 `ModuleNotFoundError`

- [ ] **Step 3: `cli.py` 구현**

```python
# scripts/suh_template/cli.py
"""
suh_template CLI 진입점.

사용법:
    python3 -m suh_template.cli <command> [args]

커맨드:
    get-output-path <skill_id> [--title <제목>]
    get-issue-number
    get-next-seq <skill_id>
    normalize-title <제목>
    config-get <skill_id> <key>
"""

from __future__ import annotations

import os
import sys
from datetime import date
from pathlib import Path

# 패키지 루트를 sys.path에 추가 (직접 실행 시)
_HERE = Path(__file__).parent.parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from suh_template import SUPPORTED_SKILL_IDS
from suh_template import issue_number as _issue
from suh_template import title as _title
from suh_template import paths as _paths
from suh_template import config as _config


def _err(level: str, command: str, message: str, code: str) -> None:
    print(f"[{level}] {command}: {message} ({code})", file=sys.stderr)


def _get_project_root() -> Path:
    """git 루트를 찾아 반환. 없으면 cwd 반환."""
    import subprocess
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, check=True,
        )
        return Path(result.stdout.strip())
    except (subprocess.CalledProcessError, FileNotFoundError):
        return Path.cwd()


def cmd_get_output_path(args: list[str]) -> int:
    """get-output-path <skill_id> [--title <제목>]"""
    if not args:
        _err("ERROR", "get-output-path", "skill_id 인수가 필요합니다.", "missing_argument")
        return 1

    skill_id = args[0]
    if skill_id not in SUPPORTED_SKILL_IDS:
        _err("ERROR", "get-output-path",
             f"지원하지 않는 skill_id입니다. 지원: {', '.join(SUPPORTED_SKILL_IDS)}",
             "skill_id_invalid")
        return 1

    # --title 옵션 파싱
    forced_title = None
    if "--title" in args:
        idx = args.index("--title")
        if idx + 1 < len(args):
            forced_title = args[idx + 1]

    cwd = os.getcwd()
    today = date.today().strftime("%Y%m%d")

    # 이슈 번호 추출
    wt_number = _issue.extract_from_path(cwd)
    branch = _issue.get_current_branch()
    br_number = _issue.extract_from_branch(branch) if branch else None
    issue_num, mismatch = _issue.resolve(wt_number, br_number)

    if mismatch:
        _err("WARN", "get-output-path",
             f"worktree({wt_number})와 브랜치({br_number}) 이슈 번호가 다릅니다. worktree 우선 사용.",
             "issue_number_mismatch")

    # 누적순번 계산
    project_root = _get_project_root()
    output_base = project_root / "docs" / "suh-template"
    skill_dir = output_base / skill_id

    if issue_num:
        number = issue_num
    else:
        _err("WARN", "get-output-path",
             "이슈 번호를 찾을 수 없어 누적순번으로 대체합니다.",
             "issue_number_not_found")
        number = _paths.get_next_seq(skill_dir, today)

    # 제목 결정
    if forced_title:
        final_title = _title.normalize(forced_title)
    else:
        raw_title = _title.extract_from_path(cwd)
        if raw_title:
            final_title = _title.normalize(raw_title)
        else:
            _err("WARN", "get-output-path",
                 "제목을 추출할 수 없습니다. --title 옵션으로 재호출하거나 'untitled' 사용.",
                 "title_not_found")
            final_title = "untitled"

    path = _paths.build_output_path(output_base, skill_id, today, number, final_title)
    print(str(path))
    return 0


def cmd_get_issue_number(_args: list[str]) -> int:
    """get-issue-number"""
    cwd = os.getcwd()
    wt_number = _issue.extract_from_path(cwd)
    branch = _issue.get_current_branch()
    br_number = _issue.extract_from_branch(branch) if branch else None
    result, _ = _issue.resolve(wt_number, br_number)
    print(result or "")
    return 0


def cmd_get_next_seq(args: list[str]) -> int:
    """get-next-seq <skill_id>"""
    if not args:
        _err("ERROR", "get-next-seq", "skill_id 인수가 필요합니다.", "missing_argument")
        return 1
    skill_id = args[0]
    if skill_id not in SUPPORTED_SKILL_IDS:
        _err("ERROR", "get-next-seq",
             f"지원하지 않는 skill_id입니다. 지원: {', '.join(SUPPORTED_SKILL_IDS)}",
             "skill_id_invalid")
        return 1
    project_root = _get_project_root()
    skill_dir = project_root / "docs" / "suh-template" / skill_id
    today = date.today().strftime("%Y%m%d")
    print(_paths.get_next_seq(skill_dir, today))
    return 0


def cmd_normalize_title(args: list[str]) -> int:
    """normalize-title <제목>"""
    if not args:
        _err("ERROR", "normalize-title", "제목 인수가 필요합니다.", "missing_argument")
        return 1
    print(_title.normalize(" ".join(args)))
    return 0


def cmd_config_get(args: list[str]) -> int:
    """config-get <skill_id> <key>"""
    if len(args) < 2:
        _err("ERROR", "config-get", "skill_id와 key 인수가 필요합니다.", "missing_argument")
        return 1
    skill_id, key = args[0], args[1]
    project_root = _get_project_root()
    value = _config.get_value(project_root, skill_id, key)
    if value is None:
        _err("ERROR", "config-get",
             f".suh-template/config/{skill_id}.config.json 파일이 없거나 키 '{key}'가 없습니다.",
             "config_not_found")
        return 1
    print(value)
    return 0


_COMMANDS = {
    "get-output-path": cmd_get_output_path,
    "get-issue-number": cmd_get_issue_number,
    "get-next-seq": cmd_get_next_seq,
    "normalize-title": cmd_normalize_title,
    "config-get": cmd_config_get,
}


def main() -> None:
    args = sys.argv[1:]
    if not args:
        print("사용법: python3 -m suh_template.cli <command> [args]", file=sys.stderr)
        print(f"커맨드: {', '.join(_COMMANDS)}", file=sys.stderr)
        sys.exit(1)

    command = args[0]
    if command not in _COMMANDS:
        _err("ERROR", command, f"알 수 없는 커맨드입니다. 지원: {', '.join(_COMMANDS)}", "unknown_command")
        sys.exit(1)

    sys.exit(_COMMANDS[command](args[1:]))


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: 테스트 통과 확인**

```bash
cd scripts && python -m pytest tests/test_cli.py -v
```

Expected: 6개 모두 PASS

- [ ] **Step 5: 전체 테스트 통과 확인**

```bash
cd scripts && python -m pytest tests/ -v
```

Expected: 전체 PASS

- [ ] **Step 6: 커밋**

```bash
git add scripts/suh_template/cli.py scripts/tests/test_cli.py
git commit -m "feat: CLI 진입점 구현 (cli.py) — get-output-path, get-issue-number, get-next-seq, normalize-title, config-get"
```

---

## Task 8: `skills/references/doc-output-path.md` 작성

**Files:**
- Create: `skills/references/doc-output-path.md`
- Modify: `.cursor/skills/references/doc-output-path.md` (동일 내용 복사)

- [ ] **Step 1: reference 문서 작성**

```markdown
# 산출물 경로 규칙

이 reference는 `analyze`, `plan`, `design-analyze`, `refactor-analyze`, `troubleshoot`, `report`, `ppt`, `review` skill이 md 산출물을 저장할 때 반드시 따르는 규칙이다.

## 저장 전 경로 계산

산출물 md 저장 전 반드시 아래 커맨드를 실행해 경로를 받아라:

```bash
python3 -m suh_template.cli get-output-path <skill_id>
```

반환값 예시:
- `docs/suh-template/plan/20260418_427_드롭다운_디자인_변경.md`
- `docs/suh-template/analyze/20260418_001_초기_분석.md`

## 실패 시 대응

| 상황 | 대응 |
|------|------|
| `[WARN] title_not_found` (exit 0) | AI가 작업 컨텍스트로 제목 생성 후 `--title "제목"` 옵션으로 재호출 |
| `[WARN] issue_number_not_found` (exit 0) | fallback 경로 그대로 사용, 사용자에게 "이슈번호 없어서 순번 사용" 안내 |
| `[WARN] issue_number_mismatch` (exit 0) | fallback 경로 그대로 사용, 사용자에게 불일치 안내 |
| `[ERROR] git_not_found` (exit 1) | 사용자에게 "git 저장소가 아닙니다" 알리고 중단 |

## 디렉토리 자동 생성

경로를 받은 뒤 파일 쓰기 전 디렉토리를 생성한다:

**Mac/Linux:**
```bash
mkdir -p "$(dirname "<받은 경로>")"
```

**Windows (PowerShell):**
```powershell
New-Item -ItemType Directory -Force -Path (Split-Path "<받은 경로>")
```
```

- [ ] **Step 2: Cursor용 동일 파일 복사**

```bash
cp skills/references/doc-output-path.md .cursor/skills/references/doc-output-path.md
```

- [ ] **Step 3: 커밋**

```bash
git add skills/references/doc-output-path.md .cursor/skills/references/doc-output-path.md
git commit -m "docs: 산출물 경로 규칙 reference 문서 추가 (doc-output-path.md)"
```

---

## Task 9: 수동 동작 검증

- [ ] **Step 1: 실제 프로젝트 루트에서 smoke test**

```bash
cd /Users/suhsaechan/Desktop/Programming/project/SUH-DEVOPS-TEMPLATE/scripts

# normalize-title
python3 -m suh_template.cli normalize-title "드롭다운 디자인 변경"
# 기대: 드롭다운_디자인_변경

# get-issue-number (현재 브랜치: main → 빈 문자열)
python3 -m suh_template.cli get-issue-number
# 기대: (빈 문자열)

# get-next-seq
python3 -m suh_template.cli get-next-seq plan
# 기대: 001

# get-output-path
python3 -m suh_template.cli get-output-path plan
# 기대: docs/suh-template/plan/YYYYMMDD_001_untitled.md (또는 title 있으면 추출)
```

- [ ] **Step 2: worktree 경로 시뮬레이션**

```bash
# worktree 경로를 흉내내기 위해 해당 경로에서 실행
cd "/Users/suhsaechan/Desktop/Programming/project/RomRom-FE-Worktree/20260201_469_Common_Toast_디자인_변경_및_다중_토스트_알림시_겹침문제_개선_필요"

python3 /Users/suhsaechan/Desktop/Programming/project/SUH-DEVOPS-TEMPLATE/scripts/suh_template/cli.py get-issue-number
# 기대: 469

python3 /Users/suhsaechan/Desktop/Programming/project/SUH-DEVOPS-TEMPLATE/scripts/suh_template/cli.py get-output-path plan
# 기대: docs/suh-template/plan/YYYYMMDD_469_Common_Toast_디자인_변경_및_다중_토스트_알림시_겹침문제_개선_필요.md
```

- [ ] **Step 3: 최종 커밋**

```bash
git add -A
git commit -m "feat: sub-project #1 공통 Python 헬퍼 인프라 구현 완료"
```
