# SKILL Python 실행 구조 재설계 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** suh-github-template 레포의 8개 skill을 3-layer 아키텍처(scripts/common/ + skills/<x>/scripts/<scope>_cli.py + SKILL.md)로 완전 재설계하고, 기존 `scripts/suh_template/` 단일 모듈을 제거한다.

**Architecture:** Layer 1 = `scripts/common/`에 도메인 순수 함수(GitHub HTTP, 제목 정규화, 이슈 번호 추출 등). Layer 2 = `skills/suh-<x>/scripts/<scope>_cli.py` skill 1개 = py 1개 = argparse 서브커맨드. Layer 3 = SKILL.md self-contained 5줄 Bash 호출. JSON 출력은 MCP-style 4필드(ok/code/summary/next) 일관 강제.

**Tech Stack:** Python 3.13 (Windows Git Bash MINGW64 + WSL Linux bash 5.2 호환), argparse, urllib (표준 라이브러리만 — 외부 의존성 0). PyNaCl은 `secrets set` 호출시에만 필요(이미 try-import 패턴).

**Spec:** `docs/superpowers/specs/2026-06-01-skill-py-restructure-design.md`
**Issue:** Cassiiopeia/SUH-DEVOPS-TEMPLATE#322
**Branch suggestion:** `20260601_#322_skill_py_실행_구조_MCP-style_표준화_및_OS_호환성_강건화`

---

## File Structure (Target)

```
suh-github-template/
├── scripts/
│   ├── common/                                  # NEW — Layer 1
│   │   ├── __init__.py                          # 패키지 + SUPPORTED_SKILL_IDS
│   │   ├── emit.py                              # NEW — MCP-style JSON 헬퍼 (4필드)
│   │   ├── bootstrap.py                         # NEW — sys.path 부트스트랩 헬퍼
│   │   ├── gh_client.py                         # MOVED from suh_template/
│   │   ├── gh_branch.py                         # MOVED
│   │   ├── paths.py                             # MOVED
│   │   ├── title.py                             # MOVED
│   │   ├── issue_number.py                      # MOVED
│   │   ├── config.py                            # MOVED (+ get_pat.py 통합)
│   │   └── manifest.py                          # MOVED
│   └── ssh/                                     # unchanged
│       └── ssh_connect.py
│
├── skills/
│   ├── suh-github/
│   │   ├── SKILL.md                             # MODIFIED — 표준 5줄 호출 패턴
│   │   ├── scripts/
│   │   │   └── github_cli.py                    # NEW — 10개 서브커맨드
│   │   └── tests/
│   │       └── test_github_cli.py               # NEW — 단위 테스트
│   ├── suh-issue/
│   │   ├── SKILL.md                             # MODIFIED
│   │   ├── scripts/
│   │   │   └── issue_cli.py                     # NEW
│   │   └── tests/
│   │       └── test_issue_cli.py                # NEW
│   ├── suh-commit/
│   │   ├── SKILL.md                             # MODIFIED
│   │   ├── scripts/
│   │   │   └── commit_cli.py                    # NEW
│   │   └── tests/
│   │       └── test_commit_cli.py               # NEW
│   ├── suh-report/
│   │   ├── SKILL.md                             # MODIFIED
│   │   ├── scripts/
│   │   │   └── report_cli.py                    # NEW
│   │   └── tests/
│   │       └── test_report_cli.py               # NEW
│   ├── suh-review/
│   │   ├── SKILL.md                             # MODIFIED
│   │   ├── scripts/
│   │   │   └── review_cli.py                    # NEW
│   │   └── tests/
│   │       └── test_review_cli.py               # NEW
│   ├── suh-troubleshoot/
│   │   ├── SKILL.md                             # MODIFIED
│   │   ├── scripts/
│   │   │   └── troubleshoot_cli.py              # NEW
│   │   └── tests/
│   │       └── test_troubleshoot_cli.py         # NEW
│   ├── suh-changelog-deploy/
│   │   ├── SKILL.md                             # MODIFIED
│   │   ├── scripts/
│   │   │   └── changelog_cli.py                 # NEW
│   │   └── tests/
│   │       └── test_changelog_cli.py            # NEW
│   ├── suh-skill-creator/
│   │   ├── SKILL.md                             # MODIFIED
│   │   └── templates/
│   │       └── python_cli_script.py             # MODIFIED — 새 표준 골격
│   └── references/
│       └── common-rules.md                      # MODIFIED — §3 PYTHONPATH 제거
│
└── (scripts/suh_template/ DELETED — 마지막 단계)
```

---

## Phase 분할 (8 Phase, ~50 task)

| Phase | 목표 | 의존성 | Task 수 |
|---|---|---|---|
| **Phase 1** | Layer 1 인프라 (scripts/common/ + 헬퍼) | 없음 | 8 |
| **Phase 2** | github_cli.py (reference 구현) | Phase 1 | 9 |
| **Phase 3** | 나머지 6개 _cli.py 병렬 작성 | Phase 1 | 18 (각 3) |
| **Phase 4** | SKILL.md 7개 재작성 | Phase 2-3 | 8 |
| **Phase 5** | references/common-rules.md 정정 | Phase 4 | 2 |
| **Phase 6** | suh-skill-creator templates 업데이트 | Phase 5 | 2 |
| **Phase 7** | scripts/suh_template/ 삭제 + 잔여 import 정리 | Phase 1-6 | 3 |
| **Phase 8** | OS 회귀 검증 (Windows + WSL) | Phase 7 | 4 |

---

## Phase 1: Layer 1 Infrastructure

### Task 1.1: brand-new 브랜치 + 작업 환경 준비

**Files:**
- Modify: (현재 main 브랜치) 새 브랜치 생성

- [ ] **Step 1: 새 브랜치 생성**

```bash
git checkout main
git pull --rebase origin main
git checkout -b "20260601_#322_skill_py_실행_구조_MCP-style_표준화_및_OS_호환성_강건화"
```

Expected: 브랜치 생성됨, `git branch --show-current` 가 새 브랜치 이름 출력.

- [ ] **Step 2: scripts/common 폴더 생성**

```bash
mkdir -p scripts/common
```

Expected: `ls scripts/common` = 빈 폴더.

- [ ] **Step 3: 회귀 검증용 baseline 캡처**

```bash
cd "$(git rev-parse --show-toplevel)/scripts" && \
PYTHONIOENCODING=utf-8 python -m suh_template.suh_command get-output-path troubleshoot 2>&1 | tail -3 > /tmp/baseline_get_output_path.txt
cat /tmp/baseline_get_output_path.txt
```

Expected: 기존 동작 결과 캡처 (예: `D:\...\docs\suh-template\troubleshoot\YYYYMMDD_001_untitled.md`).

이 baseline은 Phase 8 회귀 검증에서 새 구조 결과와 비교.

- [ ] **Step 4: Commit baseline doc**

```bash
git add docs/superpowers/specs/2026-06-01-skill-py-restructure-design.md docs/superpowers/plans/2026-06-01-skill-py-restructure-implementation.md
git commit -m "docs(specs): 3-layer skill py 재설계 spec + plan 추가 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

Expected: spec + plan 파일 첫 커밋.

---

### Task 1.2: scripts/common/__init__.py 작성

**Files:**
- Create: `scripts/common/__init__.py`

- [ ] **Step 1: Write the file**

```python
"""common — cassiiopeia skill 공용 인프라.

3-layer 아키텍처의 Layer 1. 각 skill의 _cli.py가 이 패키지를 import한다.
순수 함수 + 단일 책임 모듈만 둔다. skill 의존성 0.
"""

__version__ = "1.0.0"

# 산출물 경로 생성 대상 skill_id 목록 (paths.py·기타에서 사용)
SUPPORTED_SKILL_IDS = [
    "analyze",
    "plan",
    "design-analyze",
    "refactor-analyze",
    "troubleshoot",
    "report",
    "ppt",
    "review",
    "issue",
    "github",
    "synology-expose",
]
```

- [ ] **Step 2: import 검증**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
PYTHONPATH="$PROJECT_ROOT/scripts" python -c "from common import SUPPORTED_SKILL_IDS; print(SUPPORTED_SKILL_IDS)"
```

Expected: 리스트 11개 출력.

- [ ] **Step 3: Commit**

```bash
git add scripts/common/__init__.py
git commit -m "feat(common): Layer 1 __init__ + SUPPORTED_SKILL_IDS https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 1.3: scripts/common/emit.py — MCP-style JSON 헬퍼

**Files:**
- Create: `scripts/common/emit.py`
- Create: `tests/test_emit.py` (프로젝트 루트 tests/ 신설)

- [ ] **Step 1: Write the failing test**

```python
# tests/test_emit.py
import json
import sys
from io import StringIO
from pathlib import Path

# Bootstrap import
_PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(_PROJECT_ROOT / "scripts"))

from common.emit import emit


def test_emit_success_default_fields(capsys):
    rc = emit({"data": "hello"})
    out = capsys.readouterr().out
    parsed = json.loads(out)
    assert rc == 0
    assert parsed["ok"] is True
    assert parsed["code"] == "ok"
    assert parsed["summary"] is None
    assert parsed["next"] is None
    assert parsed["data"] == "hello"


def test_emit_error_returns_nonzero(capsys):
    rc = emit({"ok": False, "code": "missing_pat", "error": "no PAT"})
    out = capsys.readouterr().out
    parsed = json.loads(out)
    assert rc == 1
    assert parsed["ok"] is False
    assert parsed["code"] == "missing_pat"
    assert parsed["error"] == "no PAT"


def test_emit_preserves_custom_summary_and_next(capsys):
    emit({"summary": "PR #123 생성", "next": "deploy-status owner repo --pr 123"})
    out = capsys.readouterr().out
    parsed = json.loads(out)
    assert parsed["summary"] == "PR #123 생성"
    assert parsed["next"] == "deploy-status owner repo --pr 123"


def test_emit_handles_korean_no_ascii_escape(capsys):
    emit({"summary": "한글 메시지"})
    out = capsys.readouterr().out
    assert "한글 메시지" in out
    assert "\\u" not in out  # ensure_ascii=False 강제
```

- [ ] **Step 2: Run test, expect ImportError**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT" && python -m pytest tests/test_emit.py -v 2>&1 | tail -10
```

Expected: `ModuleNotFoundError: No module named 'common.emit'`

- [ ] **Step 3: Write minimal implementation**

```python
# scripts/common/emit.py
"""MCP-style JSON 출력 헬퍼.

모든 _cli.py 서브커맨드 출력은 이 emit() 통해 stdout으로 나간다.
4필드(ok/code/summary/next) 기본값 자동 보장.

성공: emit({"data": ...})                        → rc=0, ok=true, code="ok"
에러: emit({"ok": False, "code": "...", ...})    → rc=1
"""
import json
import sys


def emit(payload: dict) -> int:
    """JSON을 stdout에 출력하고 ok 값에 따라 rc 반환.

    payload에 ok/code/summary/next가 없으면 기본값을 채워 4필드를 강제한다.
    한글은 ensure_ascii=False로 그대로 출력.
    """
    payload.setdefault("ok", True)
    if payload["ok"] and "code" not in payload:
        payload["code"] = "ok"
    elif not payload["ok"] and "code" not in payload:
        payload["code"] = "error"
    payload.setdefault("summary", None)
    payload.setdefault("next", None)
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")
    sys.stdout.flush()
    return 0 if payload["ok"] else 1
```

- [ ] **Step 4: Run test, expect PASS**

```bash
cd "$PROJECT_ROOT" && python -m pytest tests/test_emit.py -v 2>&1 | tail -10
```

Expected: `4 passed`.

- [ ] **Step 5: Commit**

```bash
git add scripts/common/emit.py tests/test_emit.py
git commit -m "feat(common): emit() MCP-style JSON 헬퍼 + tests https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 1.4: scripts/common/bootstrap.py — sys.path 부트스트랩 헬퍼

**Files:**
- Create: `scripts/common/bootstrap.py`

- [ ] **Step 1: Write the implementation**

```python
# scripts/common/bootstrap.py
"""sys.path 부트스트랩 — _cli.py들이 common.* import 가능하게 한다.

각 _cli.py 첫 줄에서 이 모듈은 사용 안 한다 (순환 import 방지).
대신 _cli.py가 직접 다음 패턴을 사용:

    import sys
    from pathlib import Path
    _HERE = Path(__file__).resolve()
    _SCRIPTS_ROOT = _HERE.parents[3] / "scripts"
    if str(_SCRIPTS_ROOT) not in sys.path:
        sys.path.insert(0, str(_SCRIPTS_ROOT))
    from common.emit import emit

이 파일은 그 패턴을 검증할 헬퍼만 제공:
"""
from pathlib import Path
from typing import Optional


def find_scripts_root(start: Path) -> Optional[Path]:
    """start에서 위로 올라가며 'scripts/common/__init__.py'를 찾는다.

    찾으면 'scripts/' 경로 반환. 없으면 None.
    _cli.py에서 직접 쓰진 않고, 테스트·디버깅용.
    """
    cur = start.resolve()
    for _ in range(10):  # 10단계 위까지만 탐색
        candidate = cur / "scripts" / "common" / "__init__.py"
        if candidate.exists():
            return cur / "scripts"
        if cur.parent == cur:
            return None
        cur = cur.parent
    return None
```

- [ ] **Step 2: Smoke test**

```bash
cd "$(git rev-parse --show-toplevel)" && python -c "
import sys
from pathlib import Path
sys.path.insert(0, 'scripts')
from common.bootstrap import find_scripts_root
root = find_scripts_root(Path('skills/suh-github'))
print(root)
assert root is not None
assert root.name == 'scripts'
"
```

Expected: scripts 절대경로 출력.

- [ ] **Step 3: Commit**

```bash
git add scripts/common/bootstrap.py
git commit -m "feat(common): bootstrap.find_scripts_root 헬퍼 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 1.5: scripts/common/title.py·issue_number.py·gh_branch.py 이동

**Files:**
- Create: `scripts/common/title.py` (from suh_template/)
- Create: `scripts/common/issue_number.py` (from suh_template/)
- Create: `scripts/common/gh_branch.py` (from suh_template/)
- Create: `scripts/common/paths.py` (from suh_template/)

- [ ] **Step 1: 4개 파일 복사 (mv 아니라 cp — 기존 유지하여 회귀 가능)**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cp "$PROJECT_ROOT/scripts/suh_template/title.py" "$PROJECT_ROOT/scripts/common/title.py"
cp "$PROJECT_ROOT/scripts/suh_template/issue_number.py" "$PROJECT_ROOT/scripts/common/issue_number.py"
cp "$PROJECT_ROOT/scripts/suh_template/gh_branch.py" "$PROJECT_ROOT/scripts/common/gh_branch.py"
cp "$PROJECT_ROOT/scripts/suh_template/paths.py" "$PROJECT_ROOT/scripts/common/paths.py"
```

- [ ] **Step 2: paths.py 내부 import 점검**

```bash
grep -E "^from|^import" "$PROJECT_ROOT/scripts/common/paths.py"
```

만약 `from suh_template import` 또는 `from . import` 패턴 있으면 `from common import`로 교체. 표준 라이브러리만 import면 변경 불필요.

- [ ] **Step 3: title.py·issue_number.py·gh_branch.py 동일 점검**

```bash
for f in title issue_number gh_branch; do
  echo "=== $f ==="
  grep -E "^from|^import" "$PROJECT_ROOT/scripts/common/$f.py"
done
```

`from suh_template` 발견 시 `common`으로 교체. `from . import`는 패키지 내 상대 import이므로 그대로 OK (common 패키지 내부 호출).

- [ ] **Step 4: import 검증**

```bash
cd "$PROJECT_ROOT" && PYTHONPATH="scripts" python -c "
from common.title import normalize
from common.issue_number import extract_from_branch, extract_from_path, resolve, get_current_branch
from common.gh_branch import create_branch_name, get_commit_template
from common.paths import get_next_seq, build_output_path
print('OK')
"
```

Expected: `OK`.

- [ ] **Step 5: Commit**

```bash
git add scripts/common/title.py scripts/common/issue_number.py scripts/common/gh_branch.py scripts/common/paths.py
git commit -m "feat(common): title·issue_number·gh_branch·paths 모듈 이동 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 1.6: scripts/common/manifest.py 이동

**Files:**
- Create: `scripts/common/manifest.py`

- [ ] **Step 1: 복사**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cp "$PROJECT_ROOT/scripts/suh_template/manifest.py" "$PROJECT_ROOT/scripts/common/manifest.py"
```

- [ ] **Step 2: import 점검 + 정정**

```bash
grep -E "^from|^import" "$PROJECT_ROOT/scripts/common/manifest.py"
```

`from suh_template` → `from common`. `from . import`는 그대로.

- [ ] **Step 3: import 검증**

```bash
cd "$PROJECT_ROOT" && PYTHONPATH="scripts" python -c "from common import manifest; print(dir(manifest))"
```

Expected: manifest 함수 목록 출력 (None 아니어야 함).

- [ ] **Step 4: Commit**

```bash
git add scripts/common/manifest.py
git commit -m "feat(common): manifest 모듈 이동 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 1.7: scripts/common/config.py 이동 + get_pat.py 통합

**Files:**
- Create: `scripts/common/config.py` (from suh_template/config.py + get_pat.py 통합)

- [ ] **Step 1: config.py 복사**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cp "$PROJECT_ROOT/scripts/suh_template/config.py" "$PROJECT_ROOT/scripts/common/config.py"
```

- [ ] **Step 2: get_pat.py 내용 확인 후 config.py에 병합**

```bash
cat "$PROJECT_ROOT/scripts/suh_template/get_pat.py"
```

만약 get_pat.py가 `config.get_github_pat`을 노출하는 얇은 wrapper면 그대로 config.py에 함수로 합쳐도 동작 동일.

config.py 끝에 다음과 같은 함수가 이미 있으면 통합 완료(별 수정 불필요):
```python
def get_github_pat(owner: Optional[str] = None, repo: Optional[str] = None) -> Optional[str]:
    ...
```

없으면 get_pat.py 함수를 옮겨 추가.

- [ ] **Step 3: import 점검**

```bash
grep -E "^from|^import" "$PROJECT_ROOT/scripts/common/config.py"
```

`from suh_template` → `from common`. 다른 의존 없으면 변경 불필요.

- [ ] **Step 4: import 검증**

```bash
cd "$PROJECT_ROOT" && PYTHONPATH="scripts" python -c "
from common.config import config_path, load, get_section, get_github_pat
print('config_path:', config_path())
print('load() type:', type(load()).__name__)
"
```

Expected: 경로 + dict 또는 NoneType 출력. 에러 없어야 함.

- [ ] **Step 5: Commit**

```bash
git add scripts/common/config.py
git commit -m "feat(common): config 모듈 이동 + get_pat 통합 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 1.8: scripts/common/gh_client.py 이동 (가장 큰 모듈, 559줄)

**Files:**
- Create: `scripts/common/gh_client.py`

- [ ] **Step 1: 복사**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cp "$PROJECT_ROOT/scripts/suh_template/gh_client.py" "$PROJECT_ROOT/scripts/common/gh_client.py"
```

- [ ] **Step 2: import 점검 + 정정**

```bash
grep -E "^from suh_template|^from \." "$PROJECT_ROOT/scripts/common/gh_client.py"
```

`from suh_template.X` → `from common.X`. `from . import`는 패키지 내부이므로 그대로.

만약 결과 있으면:
```bash
sed -i 's|from suh_template\.|from common.|g' "$PROJECT_ROOT/scripts/common/gh_client.py"
sed -i 's|from suh_template |from common |g' "$PROJECT_ROOT/scripts/common/gh_client.py"
```

- [ ] **Step 3: smoke import**

```bash
cd "$PROJECT_ROOT" && PYTHONPATH="scripts" python -c "
from common.gh_client import GitHubAPIError, get_issue, create_issue, list_pulls, create_pull_request
print('OK')
"
```

Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add scripts/common/gh_client.py
git commit -m "feat(common): gh_client 모듈 이동 (559줄, HTTP 코어) https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

## Phase 2: github_cli.py (Reference 구현)

Phase 2는 다른 6개 _cli.py의 reference. 패턴 명확히 잡고 가야 다른 cli 작성이 쉬워짐.

### Task 2.1: github_cli.py 폴더 + 골격 작성

**Files:**
- Create: `skills/suh-github/scripts/github_cli.py`
- Create: `skills/suh-github/tests/test_github_cli.py`

- [ ] **Step 1: 폴더 생성**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
mkdir -p "$PROJECT_ROOT/skills/suh-github/scripts"
mkdir -p "$PROJECT_ROOT/skills/suh-github/tests"
```

- [ ] **Step 2: github_cli.py 골격 작성**

```python
# skills/suh-github/scripts/github_cli.py
#!/usr/bin/env python3
"""github_cli — suh-github skill 전용 CLI.

GitHub API 직접 호출 도구.
서브커맨드: get-issue, get-issues, update-issue, create-pr, list-prs,
           update-pr, search-issues, add-comment, explore, secrets

사용법:
    cd skills/suh-github/scripts
    python github_cli.py <subcommand> [args]

출력 형식: 모든 서브커맨드는 stdout으로 MCP-style JSON 출력.
    {"ok": true|false, "code": "...", "summary": "...", "next": "...", ...payload}
"""
from __future__ import annotations

import sys
import argparse
from pathlib import Path

# Bootstrap — scripts/common import 가능하게 sys.path 조작
_HERE = Path(__file__).resolve()
_PROJECT_ROOT = _HERE.parents[3]  # skills/suh-github/scripts/github_cli.py → 3 up
_SCRIPTS_ROOT = _PROJECT_ROOT / "scripts"
if str(_SCRIPTS_ROOT) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_ROOT))

from common.emit import emit  # noqa: E402
from common.config import get_github_pat  # noqa: E402
from common.gh_client import GitHubAPIError  # noqa: E402


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="github_cli",
        description="suh-github skill 전용 GitHub API CLI",
    )
    sub = parser.add_subparsers(dest="command", required=True)
    # 서브커맨드는 Task 2.2~2.10에서 추가
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    if not hasattr(args, "func"):
        parser.print_help(sys.stderr)
        return 1
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 3: bootstrap 검증 (--help)**

```bash
cd "$PROJECT_ROOT/skills/suh-github/scripts" && python github_cli.py --help 2>&1 | head -10
```

Expected: argparse `--help` 출력. ImportError 없어야 함.

- [ ] **Step 4: 다른 cwd에서 호출 검증 (cwd 무관 동작 보장)**

```bash
cd "$PROJECT_ROOT" && python skills/suh-github/scripts/github_cli.py --help 2>&1 | head -5
```

Expected: 같은 결과. bootstrap이 cwd 상관없이 common import 보장.

- [ ] **Step 5: Commit**

```bash
git add skills/suh-github/scripts/github_cli.py
git commit -m "feat(suh-github): github_cli 골격 + bootstrap https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 2.2: get-issue 서브커맨드 (TDD)

**Files:**
- Modify: `skills/suh-github/scripts/github_cli.py` (서브커맨드 추가)
- Create: `skills/suh-github/tests/test_github_cli.py`

- [ ] **Step 1: Write failing test**

```python
# skills/suh-github/tests/test_github_cli.py
"""github_cli 단위 테스트.

GitHub API 실제 호출 안 함 — emit JSON 출력 형식·argparse 라우팅만 검증.
HTTP는 monkeypatch로 mock.
"""
import json
import sys
import subprocess
from pathlib import Path

import pytest

CLI = Path(__file__).resolve().parents[1] / "scripts" / "github_cli.py"


def run_cli(*args):
    """github_cli 실행 후 stdout 반환."""
    result = subprocess.run(
        [sys.executable, str(CLI), *args],
        capture_output=True, text=True, encoding="utf-8",
    )
    return result.returncode, result.stdout, result.stderr


def test_get_issue_missing_args_returns_argparse_error():
    rc, out, err = run_cli("get-issue")
    assert rc != 0
    # argparse가 stderr로 usage 출력
    assert "owner" in err.lower() or "usage" in err.lower()


def test_get_issue_emits_mcp_style_on_missing_pat(monkeypatch, tmp_path):
    # config.json 없는 임시 HOME 시뮬레이션
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("USERPROFILE", str(tmp_path))
    monkeypatch.delenv("GITHUB_PAT", raising=False)
    rc, out, err = run_cli("get-issue", "nobody", "norepo", "1")
    parsed = json.loads(out)
    assert parsed["ok"] is False
    assert parsed["code"] == "missing_pat"
    assert "summary" in parsed and "next" in parsed  # 4필드 보장
```

- [ ] **Step 2: Run test, expect mixed (argparse pass + missing_pat fail)**

```bash
cd "$PROJECT_ROOT" && python -m pytest skills/suh-github/tests/test_github_cli.py -v 2>&1 | tail -15
```

Expected: argparse 부분은 자연스럽게 통과 가능, missing_pat 부분은 FAIL (서브커맨드 미구현).

- [ ] **Step 3: get-issue 서브커맨드 구현 추가**

`build_parser()` 함수 안 `# 서브커맨드는 Task 2.2~2.10에서 추가` 줄 바로 위에 추가:

```python
    # get-issue
    p_gi = sub.add_parser("get-issue", help="이슈 조회")
    p_gi.add_argument("owner")
    p_gi.add_argument("repo")
    p_gi.add_argument("number", type=int)
    p_gi.add_argument("--with-comments", action="store_true")
    p_gi.set_defaults(func=cmd_get_issue)
```

build_parser() 함수 위에 cmd_get_issue 함수 추가:

```python
def cmd_get_issue(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({
            "ok": False,
            "code": "missing_pat",
            "error": "GITHUB_PAT 환경변수도 config.json도 없습니다.",
        })
    try:
        from common.gh_client import get_issue, get_issue_comments
        issue = get_issue(args.owner, args.repo, args.number, pat)
        comments = get_issue_comments(args.owner, args.repo, args.number, pat) if args.with_comments else None
        return emit({
            "issue": issue,
            "comments": comments,
            "summary": f"#{issue['number']} {issue['state']} — {issue['title']}",
            # 기존 SKILL.md 호환용 top-level
            "number": issue["number"],
            "title": issue["title"],
            "url": issue["url"],
            "html_url": issue["url"],
            "state": issue["state"],
            "body": issue.get("body", ""),
        })
    except GitHubAPIError as e:
        return emit({
            "ok": False,
            "code": f"github_api_{e.status_code}",
            "error": str(e),
        })
```

- [ ] **Step 4: Run test, expect PASS**

```bash
cd "$PROJECT_ROOT" && python -m pytest skills/suh-github/tests/test_github_cli.py -v 2>&1 | tail -10
```

Expected: 2 passed.

- [ ] **Step 5: 실제 GitHub API 1회 검증 (config.json 있는 경우)**

```bash
cd "$PROJECT_ROOT/skills/suh-github/scripts" && python github_cli.py get-issue Cassiiopeia SUH-DEVOPS-TEMPLATE 322 2>&1 | python -c "import sys, json; d = json.loads(sys.stdin.read()); print('ok:', d['ok'], '/ title:', d.get('title', '')[:50])"
```

Expected: `ok: True / title: 🚀[기능개선][Skills] skill 내부 py 실행 구조...`.

- [ ] **Step 6: Commit**

```bash
git add skills/suh-github/scripts/github_cli.py skills/suh-github/tests/test_github_cli.py
git commit -m "feat(suh-github): get-issue 서브커맨드 + tests https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 2.3: get-issues 서브커맨드

**Files:**
- Modify: `skills/suh-github/scripts/github_cli.py`
- Modify: `skills/suh-github/tests/test_github_cli.py`

- [ ] **Step 1: build_parser()에 등록 추가**

```python
    # get-issues (여러 번호)
    p_gis = sub.add_parser("get-issues", help="여러 이슈 한 번에 조회")
    p_gis.add_argument("owner")
    p_gis.add_argument("repo")
    p_gis.add_argument("numbers", nargs="+")
    p_gis.set_defaults(func=cmd_get_issues)
```

- [ ] **Step 2: cmd_get_issues 함수 추가**

```python
def cmd_get_issues(args) -> int:
    from common.gh_client import get_issue
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    issues = []
    for raw in args.numbers:
        try:
            number = int(raw)
        except ValueError:
            issues.append({"number": raw, "error": "정수 아님", "code": "invalid_argument"})
            continue
        try:
            issues.append(get_issue(args.owner, args.repo, number, pat))
        except GitHubAPIError as e:
            issues.append({
                "number": number, "error": str(e),
                "code": f"github_api_{e.status_code}",
            })
    return emit({
        "count": len(issues),
        "issues": issues,
        "summary": f"{len(issues)}개 이슈 조회 완료",
    })
```

- [ ] **Step 3: smoke test 실행**

```bash
cd "$PROJECT_ROOT/skills/suh-github/scripts" && python github_cli.py get-issues Cassiiopeia SUH-DEVOPS-TEMPLATE 322 321 320 2>&1 | python -c "import sys, json; d = json.loads(sys.stdin.read()); print('count:', d.get('count'))"
```

Expected: `count: 3`.

- [ ] **Step 4: Commit**

```bash
git add skills/suh-github/scripts/github_cli.py
git commit -m "feat(suh-github): get-issues 서브커맨드 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 2.4: update-issue 서브커맨드

**Files:**
- Modify: `skills/suh-github/scripts/github_cli.py`

- [ ] **Step 1: argparse 등록 + 함수 추가**

```python
    # update-issue
    p_ui = sub.add_parser("update-issue", help="이슈 수정")
    p_ui.add_argument("owner")
    p_ui.add_argument("repo")
    p_ui.add_argument("number", type=int)
    p_ui.add_argument("--title")
    p_ui.add_argument("--state", choices=["open", "closed"])
    p_ui.add_argument("--labels", help="csv")
    p_ui.add_argument("--assignees", help="csv")
    p_ui.set_defaults(func=cmd_update_issue)
```

```python
def cmd_update_issue(args) -> int:
    from common.gh_client import update_issue
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    labels = [l.strip() for l in args.labels.split(",") if l.strip()] if args.labels else None
    assignees = [a.strip() for a in args.assignees.split(",") if a.strip()] if args.assignees else None
    try:
        result = update_issue(
            args.owner, args.repo, args.number, pat,
            title=args.title, state=args.state, labels=labels, assignees=assignees,
        )
        return emit({
            **result,
            "summary": f"#{args.number} 수정 완료",
        })
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})
```

- [ ] **Step 2: smoke test (실제 변경 없는 호출 — --assignees 본인 동일값)**

```bash
cd "$PROJECT_ROOT/skills/suh-github/scripts" && python github_cli.py update-issue Cassiiopeia SUH-DEVOPS-TEMPLATE 322 --assignees Cassiiopeia 2>&1 | python -c "import sys, json; d = json.loads(sys.stdin.read()); print('ok:', d['ok'])"
```

Expected: `ok: True`.

- [ ] **Step 3: Commit**

```bash
git add skills/suh-github/scripts/github_cli.py
git commit -m "feat(suh-github): update-issue 서브커맨드 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 2.5: add-comment + create-pr 서브커맨드

**Files:**
- Modify: `skills/suh-github/scripts/github_cli.py`

- [ ] **Step 1: add-comment 등록 + 함수**

```python
    # add-comment
    p_ac = sub.add_parser("add-comment", help="이슈 댓글 추가")
    p_ac.add_argument("owner")
    p_ac.add_argument("repo")
    p_ac.add_argument("number", type=int)
    p_ac.add_argument("body_file")
    p_ac.set_defaults(func=cmd_add_comment)
```

```python
def cmd_add_comment(args) -> int:
    from common.gh_client import add_comment
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    body_path = Path(args.body_file)
    if not body_path.exists():
        return emit({"ok": False, "code": "body_file_not_found", "error": f"{args.body_file} 없음"})
    body = body_path.read_text(encoding="utf-8")
    try:
        result = add_comment(args.owner, args.repo, args.number, body, pat)
        return emit({
            **result,
            "summary": f"#{args.number}에 댓글 추가 완료",
        })
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})
```

- [ ] **Step 2: create-pr 등록 + 함수**

```python
    # create-pr
    p_cp = sub.add_parser("create-pr", help="PR 생성")
    p_cp.add_argument("owner")
    p_cp.add_argument("repo")
    p_cp.add_argument("title")
    p_cp.add_argument("body_file")
    p_cp.add_argument("head")
    p_cp.add_argument("base")
    p_cp.set_defaults(func=cmd_create_pr)
```

```python
def cmd_create_pr(args) -> int:
    from common.gh_client import create_pull_request
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    body = Path(args.body_file).read_text(encoding="utf-8") if Path(args.body_file).exists() else ""
    try:
        result = create_pull_request(
            args.owner, args.repo, args.title, body, args.head, args.base, pat,
        )
        return emit({
            **result,
            "summary": f"PR #{result.get('number')} 생성 완료",
            "next": f"list-prs {args.owner} {args.repo}",
        })
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})
```

- [ ] **Step 3: smoke test add-comment (이슈 #322에 더미 댓글 X — 본인 이슈에 짧은 테스트 댓글 1회만)**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
echo "[test] github_cli 검증 댓글 — 무시하세요" > /tmp/test_comment.md
cd "$PROJECT_ROOT/skills/suh-github/scripts" && python github_cli.py add-comment Cassiiopeia SUH-DEVOPS-TEMPLATE 322 /tmp/test_comment.md 2>&1 | python -c "import sys, json; d = json.loads(sys.stdin.read()); print('ok:', d['ok'], '/ url:', d.get('url', ''))"
```

Expected: `ok: True / url: https://...`.

- [ ] **Step 4: Commit**

```bash
git add skills/suh-github/scripts/github_cli.py
git commit -m "feat(suh-github): add-comment + create-pr 서브커맨드 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 2.6: list-prs + update-pr + search-issues 서브커맨드

**Files:**
- Modify: `skills/suh-github/scripts/github_cli.py`

- [ ] **Step 1: list-prs 등록 + 함수**

```python
    # list-prs
    p_lp = sub.add_parser("list-prs", help="PR 목록")
    p_lp.add_argument("owner")
    p_lp.add_argument("repo")
    p_lp.add_argument("--state", choices=["open", "closed", "all"], default="open")
    p_lp.set_defaults(func=cmd_list_prs)
```

```python
def cmd_list_prs(args) -> int:
    from common.gh_client import list_pulls
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    try:
        result = list_pulls(args.owner, args.repo, pat, args.state)
        return emit({
            "count": len(result),
            "prs": result,
            "summary": f"{args.owner}/{args.repo} PR {len(result)}개 ({args.state})",
        })
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})
```

- [ ] **Step 2: update-pr 등록 + 함수**

```python
    # update-pr
    p_up = sub.add_parser("update-pr", help="PR 수정")
    p_up.add_argument("owner")
    p_up.add_argument("repo")
    p_up.add_argument("number", type=int)
    p_up.add_argument("body_file")
    p_up.add_argument("--title")
    p_up.add_argument("--state", choices=["open", "closed"])
    p_up.set_defaults(func=cmd_update_pr)
```

```python
def cmd_update_pr(args) -> int:
    from common.gh_client import update_pull_request
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    body = Path(args.body_file).read_text(encoding="utf-8") if args.body_file and Path(args.body_file).exists() else None
    try:
        result = update_pull_request(
            args.owner, args.repo, args.number, pat,
            title=args.title, body=body, state=args.state,
        )
        return emit({
            **result,
            "summary": f"PR #{args.number} 수정 완료",
        })
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})
```

- [ ] **Step 3: search-issues 등록 + 함수**

```python
    # search-issues
    p_si = sub.add_parser("search-issues", help="이슈 검색")
    p_si.add_argument("owner")
    p_si.add_argument("repo")
    p_si.add_argument("keywords", nargs="+", help="공백으로 구분된 검색 키워드")
    p_si.set_defaults(func=cmd_search_issues)
```

```python
def cmd_search_issues(args) -> int:
    from common.gh_client import search_issues
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    keyword = " ".join(args.keywords)
    try:
        result = search_issues(args.owner, args.repo, keyword, pat)
        return emit({
            "count": len(result),
            "items": result,
            "summary": f"\"{keyword}\" 검색 {len(result)}건",
        })
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})
```

- [ ] **Step 4: smoke 3종**

```bash
cd "$PROJECT_ROOT/skills/suh-github/scripts"
python github_cli.py list-prs Cassiiopeia SUH-DEVOPS-TEMPLATE --state all 2>&1 | python -c "import sys, json; d = json.loads(sys.stdin.read()); print('list-prs count:', d.get('count'))"
python github_cli.py search-issues Cassiiopeia SUH-DEVOPS-TEMPLATE "skill py 표준화" 2>&1 | python -c "import sys, json; d = json.loads(sys.stdin.read()); print('search count:', d.get('count'))"
```

Expected: 두 호출 다 정수 출력.

- [ ] **Step 5: Commit**

```bash
git add skills/suh-github/scripts/github_cli.py
git commit -m "feat(suh-github): list-prs + update-pr + search-issues 서브커맨드 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 2.7: explore 서브커맨드 (중첩)

**Files:**
- Modify: `skills/suh-github/scripts/github_cli.py`

- [ ] **Step 1: explore 등록 + 라우터 함수**

```python
    # explore (중첩 서브커맨드)
    p_ex = sub.add_parser("explore", help="레포 탐색 (list-repos|repo-detail|readme|languages|commits)")
    p_ex.add_argument("sub", choices=["list-repos", "repo-detail", "readme", "languages", "commits"])
    p_ex.add_argument("owner")
    p_ex.add_argument("repo", nargs="?")
    p_ex.add_argument("--type", choices=["user", "org", "auto"], default="auto")
    p_ex.add_argument("--limit", type=int, default=10)
    p_ex.set_defaults(func=cmd_explore)
```

```python
def cmd_explore(args) -> int:
    from common.gh_client import (
        get_user_type, list_repos, get_repo_detail,
        get_readme, get_languages, list_commits,
    )
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    try:
        if args.sub == "list-repos":
            owner_type = get_user_type(args.owner, pat) if args.type == "auto" else args.type
            repos = list_repos(args.owner, owner_type, pat)
            return emit({
                "owner": args.owner,
                "owner_type": owner_type,
                "count": len(repos),
                "repos": repos,
                "summary": f"{args.owner} {owner_type} 레포 {len(repos)}개",
                "next": f"explore repo-detail {args.owner} {repos[0]['name']}" if repos else None,
            })
        if not args.repo:
            return emit({"ok": False, "code": "missing_argument", "error": f"explore {args.sub}는 repo 인자 필요"})
        if args.sub == "repo-detail":
            detail = get_repo_detail(args.owner, args.repo, pat)
            return emit({"repo": detail, "summary": f"{args.owner}/{args.repo} 상세", "next": f"explore readme {args.owner} {args.repo}"})
        if args.sub == "readme":
            readme = get_readme(args.owner, args.repo, pat)
            return emit({"readme": readme, "summary": "README 조회", "next": f"explore languages {args.owner} {args.repo}"})
        if args.sub == "languages":
            langs = get_languages(args.owner, args.repo, pat)
            return emit({"languages": langs, "summary": f"언어 {len(langs)}개"})
        if args.sub == "commits":
            commits = list_commits(args.owner, args.repo, pat, limit=args.limit)
            return emit({"count": len(commits), "commits": commits, "summary": f"최근 커밋 {len(commits)}개"})
        return emit({"ok": False, "code": "unknown_subcommand", "error": f"알 수 없음: {args.sub}"})
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})
```

- [ ] **Step 2: smoke test**

```bash
cd "$PROJECT_ROOT/skills/suh-github/scripts" && python github_cli.py explore repo-detail Cassiiopeia SUH-DEVOPS-TEMPLATE 2>&1 | python -c "import sys, json; d = json.loads(sys.stdin.read()); print('ok:', d['ok'], '/ summary:', d.get('summary'))"
```

Expected: `ok: True / summary: Cassiiopeia/SUH-DEVOPS-TEMPLATE 상세`.

- [ ] **Step 3: Commit**

```bash
git add skills/suh-github/scripts/github_cli.py
git commit -m "feat(suh-github): explore 서브커맨드 (5종 중첩) https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 2.8: secrets 서브커맨드 (중첩)

**Files:**
- Modify: `skills/suh-github/scripts/github_cli.py`

- [ ] **Step 1: secrets 등록 + 함수**

```python
    # secrets (중첩)
    p_sc = sub.add_parser("secrets", help="Actions Secret 관리")
    p_sc.add_argument("sub", choices=["list", "set"])
    p_sc.add_argument("owner")
    p_sc.add_argument("repo")
    p_sc.add_argument("name", nargs="?")
    p_sc.set_defaults(func=cmd_secrets)
```

```python
def cmd_secrets(args) -> int:
    import os
    from common.gh_client import list_secrets, set_secret, PyNaClMissingError
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    try:
        if args.sub == "list":
            secrets = list_secrets(args.owner, args.repo, pat)
            return emit({
                "count": len(secrets), "secrets": secrets,
                "summary": f"{args.owner}/{args.repo} secret {len(secrets)}개",
            })
        if args.sub == "set":
            if not args.name:
                return emit({"ok": False, "code": "missing_argument", "error": "name 필요"})
            value = os.environ.get("SECRET_VALUE")
            if value is None:
                return emit({
                    "ok": False, "code": "missing_secret_value",
                    "error": "SECRET_VALUE 환경변수에 값을 담아 호출하세요.",
                })
            result = set_secret(args.owner, args.repo, args.name, value, pat)
            return emit({
                **result,
                "summary": f"secret {args.name} 갱신 완료",
            })
    except PyNaClMissingError as e:
        return emit({"ok": False, "code": e.code, "error": str(e), "hint": "pip install PyNaCl"})
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})
```

- [ ] **Step 2: smoke test (list만 — set은 실제 값 변경되므로 skip)**

```bash
cd "$PROJECT_ROOT/skills/suh-github/scripts" && python github_cli.py secrets list Cassiiopeia SUH-DEVOPS-TEMPLATE 2>&1 | python -c "import sys, json; d = json.loads(sys.stdin.read()); print('ok:', d['ok'], '/ count:', d.get('count'))"
```

Expected: `ok: True / count: N`.

- [ ] **Step 3: Commit**

```bash
git add skills/suh-github/scripts/github_cli.py
git commit -m "feat(suh-github): secrets 서브커맨드 (list/set) https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 2.9: github_cli 회귀 검증 (WSL 동작)

**Files:**
- Test: WSL 환경에서 dry-run

- [ ] **Step 1: WSL에서 같은 명령 실행**

```powershell
wsl bash -c "cd /mnt/d/0-suh/project/suh-github-template/skills/suh-github/scripts && python3 github_cli.py --help | head -5"
```

Expected: argparse `--help` 출력.

- [ ] **Step 2: WSL에서 실제 호출**

```powershell
wsl bash -c "cd /mnt/d/0-suh/project/suh-github-template/skills/suh-github/scripts && python3 github_cli.py search-issues Cassiiopeia SUH-DEVOPS-TEMPLATE 'skill py' 2>&1 | tail -1" | python -c "import sys, json; d = json.loads(sys.stdin.read()); print('WSL ok:', d['ok'])"
```

Expected: `WSL ok: True`.

- [ ] **Step 3: WSL 검증 결과 메모**

```bash
echo "Phase 2 WSL 검증 완료 — github_cli.py 모든 서브커맨드 Windows Git Bash + WSL Linux 양쪽 동작 확인" >> /tmp/phase2_wsl_log.txt
```

- [ ] **Step 4: Commit (코드 변경 없음, 단순 진행 마커)**

(이번 step은 commit 안 함. Phase 2 회귀 검증 통과만 의미)

---

## Phase 3: 나머지 6개 _cli.py 작성

각 skill = 1개 task (3 step). github_cli 패턴 그대로 적용.

### Task 3.1: issue_cli.py 작성

**Files:**
- Create: `skills/suh-issue/scripts/issue_cli.py`

- [ ] **Step 1: github_cli.py를 issue_cli.py로 복사 후 서브커맨드 교체**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
mkdir -p "$PROJECT_ROOT/skills/suh-issue/scripts"
cp "$PROJECT_ROOT/skills/suh-github/scripts/github_cli.py" "$PROJECT_ROOT/skills/suh-issue/scripts/issue_cli.py"
```

issue_cli.py에서 prog 이름 + 서브커맨드 차이만 수정:

기존 github_cli의 build_parser() 안 서브커맨드 등록 부분을 모두 지우고 다음으로 교체:

```python
    # create-issue
    p_ci = sub.add_parser("create-issue", help="이슈 생성")
    p_ci.add_argument("owner")
    p_ci.add_argument("repo")
    p_ci.add_argument("title")
    p_ci.add_argument("body_file")
    p_ci.add_argument("labels", help="csv")
    p_ci.set_defaults(func=cmd_create_issue)

    # search-issues
    p_si = sub.add_parser("search-issues", help="중복 검사용 이슈 검색")
    p_si.add_argument("owner")
    p_si.add_argument("repo")
    p_si.add_argument("keywords", nargs="+")
    p_si.set_defaults(func=cmd_search_issues)

    # get-next-seq
    p_gns = sub.add_parser("get-next-seq", help="다음 시퀀스 번호")
    p_gns.add_argument("skill_id")
    p_gns.set_defaults(func=cmd_get_next_seq)

    # normalize-title
    p_nt = sub.add_parser("normalize-title", help="제목 정규화")
    p_nt.add_argument("title", nargs="+")
    p_nt.set_defaults(func=cmd_normalize_title)

    # create-branch-name
    p_cbn = sub.add_parser("create-branch-name", help="브랜치명 생성")
    p_cbn.add_argument("issue_title")
    p_cbn.add_argument("issue_number", type=int)
    p_cbn.add_argument("--date", help="YYYYMMDD")
    p_cbn.set_defaults(func=cmd_create_branch_name)

    # get-commit-template
    p_gct = sub.add_parser("get-commit-template", help="커밋 메시지 템플릿")
    p_gct.add_argument("issue_title")
    p_gct.add_argument("issue_url")
    p_gct.set_defaults(func=cmd_get_commit_template)
```

cmd 함수들은 github_cli의 기존 패턴 그대로 + common.gh_client 호출. 다음 핵심 함수 추가:

```python
def cmd_create_issue(args) -> int:
    from common.gh_client import create_issue
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    body = Path(args.body_file).read_text(encoding="utf-8") if Path(args.body_file).exists() else ""
    labels = [l.strip() for l in args.labels.split(",") if l.strip()] if args.labels else []
    try:
        result = create_issue(args.owner, args.repo, args.title, body, labels, pat, [])
        return emit({
            **result,
            "summary": f"이슈 #{result.get('number')} 생성 완료",
        })
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


def cmd_search_issues(args) -> int:
    from common.gh_client import search_issues
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    keyword = " ".join(args.keywords)
    try:
        result = search_issues(args.owner, args.repo, keyword, pat)
        return emit({"count": len(result), "items": result, "summary": f"\"{keyword}\" 검색 {len(result)}건"})
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


def cmd_get_next_seq(args) -> int:
    from common.paths import get_next_seq
    from datetime import date
    import subprocess
    try:
        root_str = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=True).stdout.strip()
    except subprocess.CalledProcessError:
        return emit({"ok": False, "code": "git_not_found", "error": "git 저장소 아님"})
    skill_dir = Path(root_str) / "docs" / "suh-template" / args.skill_id
    today = date.today().strftime("%Y%m%d")
    seq = get_next_seq(skill_dir, today)
    return emit({"seq": seq, "summary": f"{args.skill_id} 다음 seq: {seq}"})


def cmd_normalize_title(args) -> int:
    from common.title import normalize
    result = normalize(" ".join(args.title))
    return emit({"normalized": result, "summary": result})


def cmd_create_branch_name(args) -> int:
    from common.gh_branch import create_branch_name
    name = create_branch_name(args.issue_title, args.issue_number, args.date)
    return emit({"branch": name, "summary": name})


def cmd_get_commit_template(args) -> int:
    from common.gh_branch import get_commit_template
    template = get_commit_template(args.issue_title, args.issue_url)
    return emit({"template": template, "summary": template})
```

prog 이름도 issue_cli로 교체:
```python
parser = argparse.ArgumentParser(prog="issue_cli", description="suh-issue skill CLI")
```

- [ ] **Step 2: smoke test 6개 서브커맨드**

```bash
cd "$PROJECT_ROOT/skills/suh-issue/scripts"
python issue_cli.py normalize-title "🚀[기능] 테스트 제목" 2>&1 | python -c "import sys, json; print(json.loads(sys.stdin.read())['normalized'])"
python issue_cli.py create-branch-name "테스트 제목" 322 --date 20260601 2>&1 | python -c "import sys, json; print(json.loads(sys.stdin.read())['branch'])"
python issue_cli.py get-commit-template "테스트 제목" "https://github.com/foo/bar/issues/322" 2>&1 | python -c "import sys, json; print(json.loads(sys.stdin.read())['template'])"
python issue_cli.py get-next-seq issue 2>&1 | python -c "import sys, json; print(json.loads(sys.stdin.read())['seq'])"
python issue_cli.py search-issues Cassiiopeia SUH-DEVOPS-TEMPLATE "skill py" 2>&1 | python -c "import sys, json; d = json.loads(sys.stdin.read()); print('count:', d.get('count'))"
```

Expected: 5개 모두 정상 출력 (브랜치명·템플릿·count 등).

- [ ] **Step 3: Commit**

```bash
git add skills/suh-issue/scripts/issue_cli.py
git commit -m "feat(suh-issue): issue_cli.py 6개 서브커맨드 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 3.2: commit_cli.py 작성

**Files:**
- Create: `skills/suh-commit/scripts/commit_cli.py`

- [ ] **Step 1: 골격 복사 + 서브커맨드 교체**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
mkdir -p "$PROJECT_ROOT/skills/suh-commit/scripts"
cp "$PROJECT_ROOT/skills/suh-github/scripts/github_cli.py" "$PROJECT_ROOT/skills/suh-commit/scripts/commit_cli.py"
```

build_parser() 안 서브커맨드 등록을 다음으로 교체:

```python
    # get-issue-number
    p_gin = sub.add_parser("get-issue-number", help="cwd 기준 현재 이슈 번호 추출")
    p_gin.set_defaults(func=cmd_get_issue_number)

    # get-issue (커밋시 이슈 제목 조회용 — github_cli와 동일)
    p_gi = sub.add_parser("get-issue", help="이슈 조회")
    p_gi.add_argument("owner")
    p_gi.add_argument("repo")
    p_gi.add_argument("number", type=int)
    p_gi.set_defaults(func=cmd_get_issue)

    # normalize-title
    p_nt = sub.add_parser("normalize-title", help="제목 정규화")
    p_nt.add_argument("title", nargs="+")
    p_nt.set_defaults(func=cmd_normalize_title)

    # get-commit-template
    p_gct = sub.add_parser("get-commit-template", help="커밋 메시지 템플릿")
    p_gct.add_argument("issue_title")
    p_gct.add_argument("issue_url")
    p_gct.set_defaults(func=cmd_get_commit_template)
```

cmd 함수 추가:

```python
def cmd_get_issue_number(_args) -> int:
    from common.issue_number import extract_from_path, extract_from_branch, get_current_branch, resolve
    import os
    cwd = os.getcwd()
    wt_number = extract_from_path(cwd)
    branch = get_current_branch()
    br_number = extract_from_branch(branch) if branch else None
    number, mismatch = resolve(wt_number, br_number)
    return emit({
        "number": number,
        "mismatch": mismatch,
        "summary": str(number) if number else "이슈 번호 없음",
    })


def cmd_get_issue(args) -> int:
    from common.gh_client import get_issue
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    try:
        issue = get_issue(args.owner, args.repo, args.number, pat)
        return emit({
            "issue": issue,
            "title": issue["title"],
            "url": issue["url"],
            "summary": f"#{issue['number']} — {issue['title']}",
        })
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


def cmd_normalize_title(args) -> int:
    from common.title import normalize
    result = normalize(" ".join(args.title))
    return emit({"normalized": result, "summary": result})


def cmd_get_commit_template(args) -> int:
    from common.gh_branch import get_commit_template
    template = get_commit_template(args.issue_title, args.issue_url)
    return emit({"template": template, "summary": template})
```

prog 교체:
```python
parser = argparse.ArgumentParser(prog="commit_cli", description="suh-commit skill CLI")
```

- [ ] **Step 2: smoke test**

```bash
cd "$PROJECT_ROOT/skills/suh-commit/scripts"
python commit_cli.py get-issue-number 2>&1 | python -c "import sys, json; d = json.loads(sys.stdin.read()); print('issue number:', d.get('number'))"
python commit_cli.py normalize-title "🔧 테스트" 2>&1 | python -c "import sys, json; print(json.loads(sys.stdin.read())['normalized'])"
```

Expected: 두 호출 모두 정상 JSON.

- [ ] **Step 3: Commit**

```bash
git add skills/suh-commit/scripts/commit_cli.py
git commit -m "feat(suh-commit): commit_cli.py 4개 서브커맨드 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 3.3: report_cli.py 작성

**Files:**
- Create: `skills/suh-report/scripts/report_cli.py`

- [ ] **Step 1: 골격 복사 + 서브커맨드 교체**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
mkdir -p "$PROJECT_ROOT/skills/suh-report/scripts"
cp "$PROJECT_ROOT/skills/suh-github/scripts/github_cli.py" "$PROJECT_ROOT/skills/suh-report/scripts/report_cli.py"
```

build_parser() 안:

```python
    # get-output-path
    p_gop = sub.add_parser("get-output-path", help="보고서 출력 경로")
    p_gop.add_argument("skill_id", nargs="?", default="report")
    p_gop.add_argument("--title")
    p_gop.set_defaults(func=cmd_get_output_path)

    # add-comment
    p_ac = sub.add_parser("add-comment", help="이슈 댓글 추가 (보고서 포스팅)")
    p_ac.add_argument("owner")
    p_ac.add_argument("repo")
    p_ac.add_argument("number", type=int)
    p_ac.add_argument("body_file")
    p_ac.set_defaults(func=cmd_add_comment)
```

cmd 함수 추가:

```python
def cmd_get_output_path(args) -> int:
    """get-output-path — paths·title·issue_number 사용해 출력 경로 계산."""
    from common.issue_number import extract_from_path, extract_from_branch, get_current_branch, resolve
    from common.title import normalize, extract_from_path as extract_title_from_path
    from common.paths import get_next_seq, build_output_path
    from datetime import date
    import os
    import subprocess

    cwd = os.getcwd()
    today = date.today().strftime("%Y%m%d")

    # 이슈 번호
    wt_number = extract_from_path(cwd)
    branch = get_current_branch()
    br_number = extract_from_branch(branch) if branch else None
    issue_num, mismatch = resolve(wt_number, br_number)

    # 프로젝트 루트
    try:
        root_str = subprocess.run(["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=True).stdout.strip()
    except subprocess.CalledProcessError:
        return emit({"ok": False, "code": "git_not_found", "error": "git 저장소 아님"})

    project_root = Path(root_str)
    output_base = project_root / "docs" / "suh-template"
    skill_dir = output_base / args.skill_id

    number = issue_num if issue_num else get_next_seq(skill_dir, today)

    # 제목
    if args.title:
        final_title = normalize(args.title)
    else:
        raw = extract_title_from_path(cwd)
        final_title = normalize(raw) if raw else "untitled"

    path = build_output_path(output_base, args.skill_id, today, number, final_title)
    return emit({
        "path": str(path),
        "summary": str(path),
    })


def cmd_add_comment(args) -> int:
    from common.gh_client import add_comment
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    body = Path(args.body_file).read_text(encoding="utf-8")
    try:
        result = add_comment(args.owner, args.repo, args.number, body, pat)
        return emit({**result, "summary": f"#{args.number}에 댓글 추가"})
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})
```

prog 교체:
```python
parser = argparse.ArgumentParser(prog="report_cli", description="suh-report skill CLI")
```

- [ ] **Step 2: smoke test**

```bash
cd "$PROJECT_ROOT/skills/suh-report/scripts" && python report_cli.py get-output-path report 2>&1 | python -c "import sys, json; print(json.loads(sys.stdin.read())['path'])"
```

Expected: `D:\...\docs\suh-template\report\YYYYMMDD_NNN_untitled.md`.

- [ ] **Step 3: Commit**

```bash
git add skills/suh-report/scripts/report_cli.py
git commit -m "feat(suh-report): report_cli.py 2개 서브커맨드 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 3.4: review_cli.py 작성

**Files:**
- Create: `skills/suh-review/scripts/review_cli.py`

- [ ] **Step 1: report_cli 복사 후 skill_id 기본값만 review로**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
mkdir -p "$PROJECT_ROOT/skills/suh-review/scripts"
cp "$PROJECT_ROOT/skills/suh-report/scripts/report_cli.py" "$PROJECT_ROOT/skills/suh-review/scripts/review_cli.py"
```

review_cli.py에서 add-comment 부분 삭제 (review는 보고서 포스팅 안 함). build_parser() 안 다음만 남김:

```python
    p_gop = sub.add_parser("get-output-path", help="리뷰 결과 출력 경로")
    p_gop.add_argument("skill_id", nargs="?", default="review")
    p_gop.add_argument("--title")
    p_gop.set_defaults(func=cmd_get_output_path)
```

cmd_add_comment 함수도 삭제. prog 교체:
```python
parser = argparse.ArgumentParser(prog="review_cli", description="suh-review skill CLI")
```

- [ ] **Step 2: smoke test**

```bash
cd "$PROJECT_ROOT/skills/suh-review/scripts" && python review_cli.py get-output-path review 2>&1 | python -c "import sys, json; print(json.loads(sys.stdin.read())['path'])"
```

Expected: `D:\...\docs\suh-template\review\YYYYMMDD_NNN_untitled.md`.

- [ ] **Step 3: Commit**

```bash
git add skills/suh-review/scripts/review_cli.py
git commit -m "feat(suh-review): review_cli.py get-output-path https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 3.5: troubleshoot_cli.py 작성

**Files:**
- Create: `skills/suh-troubleshoot/scripts/troubleshoot_cli.py`

- [ ] **Step 1: review_cli 복사 후 skill_id 기본값만 troubleshoot로**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
mkdir -p "$PROJECT_ROOT/skills/suh-troubleshoot/scripts"
cp "$PROJECT_ROOT/skills/suh-review/scripts/review_cli.py" "$PROJECT_ROOT/skills/suh-troubleshoot/scripts/troubleshoot_cli.py"
```

build_parser() 안 default 변경:
```python
    p_gop.add_argument("skill_id", nargs="?", default="troubleshoot")
```

prog 교체:
```python
parser = argparse.ArgumentParser(prog="troubleshoot_cli", description="suh-troubleshoot skill CLI")
```

- [ ] **Step 2: smoke test**

```bash
cd "$PROJECT_ROOT/skills/suh-troubleshoot/scripts" && python troubleshoot_cli.py get-output-path troubleshoot 2>&1 | python -c "import sys, json; print(json.loads(sys.stdin.read())['path'])"
```

Expected: `D:\...\docs\suh-template\troubleshoot\YYYYMMDD_NNN_untitled.md`.

이 시점에서 **Phase 1.1에서 캡처한 baseline과 비교**:
```bash
diff <(echo $path_new) /tmp/baseline_get_output_path.txt
```

경로 정합성 확인 (NNN 부분은 다를 수 있음 — seq 진행됐을 수 있음).

- [ ] **Step 3: Commit**

```bash
git add skills/suh-troubleshoot/scripts/troubleshoot_cli.py
git commit -m "feat(suh-troubleshoot): troubleshoot_cli.py get-output-path https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 3.6: changelog_cli.py 작성 (가장 큰 cli)

**Files:**
- Create: `skills/suh-changelog-deploy/scripts/changelog_cli.py`

- [ ] **Step 1: 골격 복사**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
mkdir -p "$PROJECT_ROOT/skills/suh-changelog-deploy/scripts"
cp "$PROJECT_ROOT/skills/suh-github/scripts/github_cli.py" "$PROJECT_ROOT/skills/suh-changelog-deploy/scripts/changelog_cli.py"
```

build_parser() 안 서브커맨드 교체:

```python
    # actions (중첩)
    p_a = sub.add_parser("actions", help="GitHub Actions run/job/log 조회")
    p_a.add_argument("sub", choices=["show-run", "joblog", "list-failed", "resolve-pr", "resolve-branch"])
    p_a.add_argument("owner")
    p_a.add_argument("repo")
    p_a.add_argument("arg", nargs="?", help="RUN_ID·JOB_ID·PR_NUM·BRANCH")
    p_a.add_argument("--limit", type=int, default=10)
    p_a.add_argument("--grep", default="error")
    p_a.add_argument("--tail", type=int, default=30)
    p_a.set_defaults(func=cmd_actions)

    # deploy-status
    p_ds = sub.add_parser("deploy-status", help="deploy PR 상태 종합 판정")
    p_ds.add_argument("owner")
    p_ds.add_argument("repo")
    p_ds.add_argument("--pr", type=int)
    p_ds.add_argument("--base", default="deploy")
    p_ds.set_defaults(func=cmd_deploy_status)

    # list-prs
    p_lp = sub.add_parser("list-prs", help="PR 목록")
    p_lp.add_argument("owner")
    p_lp.add_argument("repo")
    p_lp.add_argument("--state", choices=["open", "closed", "all"], default="open")
    p_lp.set_defaults(func=cmd_list_prs)

    # update-pr
    p_up = sub.add_parser("update-pr", help="PR 본문/상태 수정")
    p_up.add_argument("owner")
    p_up.add_argument("repo")
    p_up.add_argument("number", type=int)
    p_up.add_argument("body_file")
    p_up.add_argument("--title")
    p_up.add_argument("--state", choices=["open", "closed"])
    p_up.set_defaults(func=cmd_update_pr)

    # create-pr
    p_cp = sub.add_parser("create-pr", help="deploy PR 재트리거용 생성")
    p_cp.add_argument("owner")
    p_cp.add_argument("repo")
    p_cp.add_argument("title")
    p_cp.add_argument("body_file")
    p_cp.add_argument("head")
    p_cp.add_argument("base")
    p_cp.set_defaults(func=cmd_create_pr)
```

cmd 함수 — github_cli의 list-prs·update-pr·create-pr는 그대로 복사. actions·deploy-status는 추가:

```python
def cmd_actions(args) -> int:
    from common.gh_client import (
        get_run, get_job_log, list_failed_runs,
        resolve_pr_runs, resolve_branch_runs,
    )
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    try:
        if args.sub == "show-run":
            data = get_run(args.owner, args.repo, int(args.arg), pat)
            data["next"] = f"actions joblog {args.owner} {args.repo} {data['failed_job_ids'][0]}" if data.get("failed_job_ids") else None
            return emit(data)
        if args.sub == "joblog":
            data = get_job_log(args.owner, args.repo, int(args.arg), pat, grep=args.grep, tail=args.tail)
            return emit(data)
        if args.sub == "list-failed":
            runs = list_failed_runs(args.owner, args.repo, pat, limit=args.limit)
            nxt = f"actions show-run {args.owner} {args.repo} {runs[0]['run_id']}" if runs else None
            return emit({"count": len(runs), "runs": runs, "next": nxt})
        if args.sub == "resolve-pr":
            data = resolve_pr_runs(args.owner, args.repo, int(args.arg), pat)
            failed = [r for r in data["runs"] if r["conclusion"] == "failure"]
            data["next"] = f"actions show-run {args.owner} {args.repo} {failed[0]['run_id']}" if failed else None
            return emit(data)
        if args.sub == "resolve-branch":
            runs = resolve_branch_runs(args.owner, args.repo, args.arg, pat, limit=args.limit)
            failed = [r for r in runs if r["conclusion"] == "failure"]
            nxt = f"actions show-run {args.owner} {args.repo} {failed[0]['run_id']}" if failed else None
            return emit({"branch": args.arg, "count": len(runs), "runs": runs, "next": nxt})
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})
    except ValueError as e:
        return emit({"ok": False, "code": "invalid_argument", "error": str(e)})


def cmd_deploy_status(args) -> int:
    from common.gh_client import (
        get_pull_detail, find_open_pr_by_base, get_branch_head, resolve_pr_runs,
    )
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    try:
        pr = get_pull_detail(args.owner, args.repo, args.pr, pat) if args.pr else find_open_pr_by_base(args.owner, args.repo, args.base, pat)
        branch_head = get_branch_head(args.owner, args.repo, args.base, pat)
        deploy_branch = {"name": args.base, "head_sha": branch_head}
        if pr is None:
            return emit({
                "pr": None, "workflow": None, "deploy_branch": deploy_branch,
                "verdict": "no_pr",
                "summary": f"base={args.base}로 들어오는 open PR 없음",
            })
        # workflow 조회
        workflow = None
        try:
            run_data = resolve_pr_runs(args.owner, args.repo, pr["number"], pat)
            for r in run_data.get("runs", []):
                if "AUTO-CHANGELOG-CONTROL" in (r.get("name") or ""):
                    workflow = {"name": r["name"], "status": r["status"], "conclusion": r["conclusion"], "run_url": r.get("url")}
                    break
        except GitHubAPIError:
            workflow = None
        has_summary = "Summary by CodeRabbit" in pr.get("body", "")
        pr_out = {
            "number": pr["number"], "state": pr["state"], "merged": pr["merged"],
            "mergeable_state": pr["mergeable_state"], "has_coderabbit_summary": has_summary,
            "head_sha": pr["head_sha"], "url": pr["url"],
        }
        # verdict
        next_hint = f"deploy-status {args.owner} {args.repo} --pr {pr['number']}"
        if pr["merged"]:
            verdict, summary, next_hint = "merged", f"PR #{pr['number']} automerge 완료", None
        elif pr["mergeable_state"] in ("dirty", "blocked", "behind"):
            verdict, summary = "conflict", f"PR #{pr['number']} {pr['mergeable_state']} — 충돌"
        elif workflow and workflow["conclusion"] == "failure":
            verdict, summary = "workflow_failed", "AUTO-CHANGELOG-CONTROL 실패"
        elif not has_summary:
            verdict, summary = "missing_coderabbit_summary", f"PR #{pr['number']} CodeRabbit Summary 없음"
        else:
            verdict, summary = "waiting_for_automerge", f"PR #{pr['number']} automerge 대기 중"
        return emit({
            "pr": pr_out, "workflow": workflow, "deploy_branch": deploy_branch,
            "verdict": verdict, "summary": summary, "next": next_hint,
        })
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})
```

list-prs·update-pr·create-pr 함수는 github_cli에서 그대로 복사. prog 교체:
```python
parser = argparse.ArgumentParser(prog="changelog_cli", description="suh-changelog-deploy skill CLI")
```

- [ ] **Step 2: smoke test**

```bash
cd "$PROJECT_ROOT/skills/suh-changelog-deploy/scripts"
python changelog_cli.py list-prs Cassiiopeia SUH-DEVOPS-TEMPLATE --state all 2>&1 | python -c "import sys, json; d = json.loads(sys.stdin.read()); print('list-prs count:', d.get('count'))"
python changelog_cli.py deploy-status Cassiiopeia SUH-DEVOPS-TEMPLATE 2>&1 | python -c "import sys, json; d = json.loads(sys.stdin.read()); print('verdict:', d.get('verdict'))"
```

Expected: PR count + verdict 문자열 출력.

- [ ] **Step 3: Commit**

```bash
git add skills/suh-changelog-deploy/scripts/changelog_cli.py
git commit -m "feat(suh-changelog-deploy): changelog_cli.py 5개 서브커맨드 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

## Phase 4: SKILL.md 7개 재작성

각 SKILL.md의 Python 호출 코드블록을 표준 self-contained 5줄 패턴으로 일괄 교체.

### Task 4.1: suh-github SKILL.md 재작성

**Files:**
- Modify: `skills/suh-github/SKILL.md`

- [ ] **Step 1: 모든 코드블록 찾기**

```bash
grep -n "suh_template.suh_command" skills/suh-github/SKILL.md
```

Expected: 8개 이상 매치.

- [ ] **Step 2: 호출 패턴 일괄 교체**

각 블록을 다음 표준 패턴으로 교체:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
cd "$PROJECT_ROOT/skills/suh-github/scripts" || exit 1
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py <subcommand> [args]
```

기존 `python -m suh_template.suh_command <subcmd>` → `python github_cli.py <subcmd>` 로 명령 부분만 매핑:

| 기존 | 새 |
|---|---|
| `python -m suh_template.suh_command get-issue ...` | `python github_cli.py get-issue ...` |
| `python -m suh_template.suh_command create-pr ...` | `python github_cli.py create-pr ...` |
| (기타 8개) | 동일 패턴 |

- [ ] **Step 3: 변경 확인**

```bash
grep -c "github_cli.py" skills/suh-github/SKILL.md
grep -c "suh_template.suh_command" skills/suh-github/SKILL.md
```

Expected: github_cli.py = 8+, suh_template = 0.

- [ ] **Step 4: 직접 SKILL 호출 실측**

각 코드블록을 그대로 복사해 Bash에 붙여넣어 실행 — 1번이라도 ModuleNotFoundError 나면 안 됨.

- [ ] **Step 5: Commit**

```bash
git add skills/suh-github/SKILL.md
git commit -m "docs(suh-github): SKILL.md 표준 5줄 호출 패턴 적용 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 4.2: suh-issue SKILL.md 재작성

**Files:**
- Modify: `skills/suh-issue/SKILL.md`

- [ ] **Step 1: 코드블록 위치 파악**

```bash
grep -n "suh_template.suh_command" skills/suh-issue/SKILL.md
```

- [ ] **Step 2: 표준 5줄 패턴으로 교체**

각 호출의 cwd = `$PROJECT_ROOT/skills/suh-issue/scripts`, 명령 = `python issue_cli.py <subcmd>`.

기존 `create-issue`, `search-issues`, `update-issue` 호출 → issue_cli.py로 매핑.

단 `update-issue` (담당자 지정용) 은 suh-issue에서 호출하므로 issue_cli.py에도 추가 필요 — 또는 github_cli.py로 위임 가능. 이 경우 SKILL.md 일부 블록은 cwd가 `suh-github/scripts`가 될 수 있음. **간결성 위해 issue_cli.py에 update-issue 추가 권장.** Task 3.1 시점에 빠진 거 보강:

```bash
# issue_cli.py에 update-issue 추가 (Task 3.1 보강)
```

build_parser() 안:
```python
    p_ui = sub.add_parser("update-issue", help="이슈 수정 (담당자 지정 등)")
    p_ui.add_argument("owner")
    p_ui.add_argument("repo")
    p_ui.add_argument("number", type=int)
    p_ui.add_argument("--title")
    p_ui.add_argument("--state", choices=["open", "closed"])
    p_ui.add_argument("--labels")
    p_ui.add_argument("--assignees")
    p_ui.set_defaults(func=cmd_update_issue)
```

cmd_update_issue 함수는 github_cli의 것과 동일 — 복사 후 import 보장.

- [ ] **Step 3: SKILL.md 코드블록 7개 모두 표준 5줄로 교체**

- [ ] **Step 4: 검증**

각 블록 dry-run + 1개 실제 search-issues 호출 (이슈 생성은 회피).

- [ ] **Step 5: Commit**

```bash
git add skills/suh-issue/SKILL.md skills/suh-issue/scripts/issue_cli.py
git commit -m "docs(suh-issue): SKILL.md 표준 5줄 패턴 + update-issue 추가 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 4.3: suh-commit SKILL.md 재작성

**Files:**
- Modify: `skills/suh-commit/SKILL.md`

- [ ] **Step 1: 코드블록 위치 파악**

```bash
grep -n "suh_template.suh_command" skills/suh-commit/SKILL.md
```

- [ ] **Step 2: 표준 5줄 패턴 + cwd = suh-commit/scripts**

명령: `python commit_cli.py get-issue ...`, `python commit_cli.py get-issue-number`, `python commit_cli.py normalize-title ...`, `python commit_cli.py get-commit-template ...`

- [ ] **Step 3: 검증**

각 블록 dry-run.

- [ ] **Step 4: Commit**

```bash
git add skills/suh-commit/SKILL.md
git commit -m "docs(suh-commit): SKILL.md 표준 5줄 패턴 적용 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 4.4: suh-report SKILL.md 재작성

**Files:**
- Modify: `skills/suh-report/SKILL.md`

- [ ] **Step 1: 패턴 교체**

cwd = `$PROJECT_ROOT/skills/suh-report/scripts`, 명령 = `python report_cli.py add-comment ...` / `python report_cli.py get-output-path ...`

- [ ] **Step 2: 검증**

```bash
cd "$(git rev-parse --show-toplevel)/skills/suh-report/scripts" && python report_cli.py get-output-path report 2>&1 | python -c "import sys, json; print(json.loads(sys.stdin.read())['path'])"
```

Expected: 경로 출력.

- [ ] **Step 3: Commit**

```bash
git add skills/suh-report/SKILL.md
git commit -m "docs(suh-report): SKILL.md 표준 5줄 패턴 적용 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 4.5: suh-review SKILL.md 재작성

**Files:**
- Modify: `skills/suh-review/SKILL.md`

- [ ] **Step 1: 깨진 호출 패턴 정정**

기존 `PYTHONPATH="$SCRIPTS_PATH" $PYTHON -m suh_template.suh_command get-output-path review` (변수 미정의 = 실측 깨짐) → 표준 5줄로 완전 교체:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
cd "$PROJECT_ROOT/skills/suh-review/scripts" || exit 1
PYTHONIOENCODING=utf-8 "$PYTHON" review_cli.py get-output-path review
```

- [ ] **Step 2: 실측 검증 (이전에 100% 깨졌던 것 — 이제 동작해야 함)**

```bash
cd "$(git rev-parse --show-toplevel)/skills/suh-review/scripts" && python review_cli.py get-output-path review 2>&1 | python -c "import sys, json; print(json.loads(sys.stdin.read())['path'])"
```

Expected: 경로 정상 출력 (이전엔 Exit 127).

- [ ] **Step 3: Commit**

```bash
git add skills/suh-review/SKILL.md
git commit -m "docs(suh-review): SKILL.md 깨진 호출 정정 (변수 미정의 → 표준 5줄) https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 4.6: suh-troubleshoot SKILL.md 재작성

**Files:**
- Modify: `skills/suh-troubleshoot/SKILL.md`

- [ ] **Step 1: 깨진 호출 정정 (review와 동일 패턴)**

표준 5줄로 교체:
```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
cd "$PROJECT_ROOT/skills/suh-troubleshoot/scripts" || exit 1
PYTHONIOENCODING=utf-8 "$PYTHON" troubleshoot_cli.py get-output-path troubleshoot
```

- [ ] **Step 2: 실측 검증**

```bash
cd "$(git rev-parse --show-toplevel)/skills/suh-troubleshoot/scripts" && python troubleshoot_cli.py get-output-path troubleshoot 2>&1 | python -c "import sys, json; print(json.loads(sys.stdin.read())['path'])"
```

Expected: 경로 정상 출력. baseline (/tmp/baseline_get_output_path.txt)와 패턴 일치 확인.

- [ ] **Step 3: Commit**

```bash
git add skills/suh-troubleshoot/SKILL.md
git commit -m "docs(suh-troubleshoot): SKILL.md 깨진 호출 정정 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 4.7: suh-changelog-deploy SKILL.md 재작성

**Files:**
- Modify: `skills/suh-changelog-deploy/SKILL.md`

- [ ] **Step 1: 코드블록 위치**

```bash
grep -n "suh_template.suh_command" skills/suh-changelog-deploy/SKILL.md
```

Expected: 약 8-10개.

- [ ] **Step 2: 모두 표준 5줄 + changelog_cli.py 패턴으로 교체**

cwd = `$PROJECT_ROOT/skills/suh-changelog-deploy/scripts`, 명령 = `python changelog_cli.py <subcmd>`

- [ ] **Step 3: 검증**

```bash
cd "$(git rev-parse --show-toplevel)/skills/suh-changelog-deploy/scripts" && python changelog_cli.py deploy-status Cassiiopeia SUH-DEVOPS-TEMPLATE 2>&1 | python -c "import sys, json; print('verdict:', json.loads(sys.stdin.read()).get('verdict'))"
```

Expected: verdict 문자열 출력.

- [ ] **Step 4: Commit**

```bash
git add skills/suh-changelog-deploy/SKILL.md
git commit -m "docs(suh-changelog-deploy): SKILL.md 표준 5줄 패턴 + changelog_cli https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 4.8: Phase 4 검증 + WSL 회귀

**Files:**
- Test: 변경된 7개 SKILL.md의 모든 코드블록 dry-run

- [ ] **Step 1: grep으로 잔여 검증**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
grep -rn "suh_template.suh_command" "$PROJECT_ROOT/skills/" 2>&1 | head -20
```

Expected: 0건 (모든 SKILL.md에서 기존 패턴 제거됨).

- [ ] **Step 2: WSL에서 1개 대표 호출**

```powershell
wsl bash -c "cd /mnt/d/0-suh/project/suh-github-template/skills/suh-troubleshoot/scripts && python3 troubleshoot_cli.py get-output-path troubleshoot 2>&1 | tail -1"
```

Expected: 정상 경로 출력.

- [ ] **Step 3: Phase 4 마커**

(코드 변경 없음)

---

## Phase 5: references/common-rules.md 정정

### Task 5.1: §3 PYTHONPATH 제거 + 새 표준 명시

**Files:**
- Modify: `skills/references/common-rules.md`

- [ ] **Step 1: 기존 §3 "PYTHONPATH 설정" 섹션 제거**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
# 해당 섹션 line range 확인
grep -n "### 3. PYTHONPATH" "$PROJECT_ROOT/skills/references/common-rules.md"
grep -n "## GitHub 작업 원칙" "$PROJECT_ROOT/skills/references/common-rules.md"
```

§3 시작 ~ "## GitHub 작업 원칙" 이전까지 삭제.

- [ ] **Step 2: §"대표 호출" 자리에 새 표준 명시**

다음 텍스트로 대체/삽입:

```markdown
### 3. skill별 py 분산 호출 (표준)

3-layer 아키텍처(spec: 2026-06-01-skill-py-restructure-design.md):
- Layer 1: `scripts/common/` 공유 인프라
- Layer 2: `skills/<skill>/scripts/<scope>_cli.py` skill 전용 CLI
- Layer 3: SKILL.md self-contained 5줄 Bash 호출

표준 호출 패턴 (모든 Bash 블록 = self-contained):

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
cd "$PROJECT_ROOT/skills/<skill>/scripts" || exit 1
PYTHONIOENCODING=utf-8 "$PYTHON" <scope>_cli.py <subcommand> [args]
```

OS 호환성 (실측 검증 완료):
- Windows Git Bash MINGW64 ⭕
- WSL Linux bash 5.2 ⭕
- macOS bash/zsh ⭕ (POSIX 호환)
- PowerShell 미지원 (Claude Code Bash tool = bash 강제)

### 4. MCP-style JSON 출력 표준

모든 `_cli.py` 서브커맨드 출력 = JSON. 4필드 강제:

| 필드 | 의미 | 예시 |
|---|---|---|
| `ok` | 성공 여부 | true / false |
| `code` | 식별자 | "ok", "missing_pat", "github_api_404" |
| `summary` | 사람 친화 한 줄 | "PR #123 생성 완료" |
| `next` | 다음 행동 힌트 | "deploy-status owner repo --pr 123" 또는 null |

`scripts/common/emit.py`의 `emit()` 헬퍼가 4필드 자동 보장.
```

- [ ] **Step 3: 잔여 PYTHONPATH 참조 검증**

```bash
grep -n "PYTHONPATH" "$PROJECT_ROOT/skills/references/common-rules.md"
```

Expected: 0건 또는 표준 패턴 일부로만 등장.

- [ ] **Step 4: Commit**

```bash
git add skills/references/common-rules.md
git commit -m "docs(references): §3 PYTHONPATH 제거 + 새 표준(self-contained + MCP-style) 명시 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 5.2: 기타 references 점검

**Files:**
- Modify: `skills/references/mcp-subcommand-rules.md` (필요 시)

- [ ] **Step 1: 기존 mcp-subcommand-rules.md 점검**

```bash
grep -c "suh_template" "$PROJECT_ROOT/skills/references/mcp-subcommand-rules.md"
```

`suh_template` 언급 있으면 → `common` 또는 `<scope>_cli.py`로 교체.

- [ ] **Step 2: 4필드 표준 (ok/code/summary/next) 일관 명시**

mcp-subcommand-rules.md 안에 4필드 정의 강조 — 새 표준에 맞게 보강.

- [ ] **Step 3: Commit**

```bash
git add skills/references/mcp-subcommand-rules.md
git commit -m "docs(references): mcp-subcommand-rules.md 새 표준 반영 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

## Phase 6: suh-skill-creator templates 업데이트

### Task 6.1: python_cli_script.py 새 표준 골격으로 교체

**Files:**
- Modify: `skills/suh-skill-creator/templates/python_cli_script.py`

- [ ] **Step 1: 새 골격 작성**

```python
# skills/suh-skill-creator/templates/python_cli_script.py
#!/usr/bin/env python3
"""<scope>_cli — <skill name> 전용 CLI.

이 파일은 신규 skill 생성 시 복사하는 표준 골격이다.
3-layer 아키텍처 Layer 2.

사용법:
    cd skills/<skill>/scripts
    python <scope>_cli.py <subcommand> [args]

출력: 모든 서브커맨드는 stdout으로 MCP-style JSON 출력.
    {"ok": true|false, "code": "...", "summary": "...", "next": "...", ...}
"""
from __future__ import annotations

import sys
import argparse
from pathlib import Path

# Bootstrap — scripts/common import 가능하게 sys.path 조작 (cwd 무관 동작)
_HERE = Path(__file__).resolve()
_PROJECT_ROOT = _HERE.parents[3]  # skills/<x>/scripts/<x>_cli.py → 3 up
_SCRIPTS_ROOT = _PROJECT_ROOT / "scripts"
if str(_SCRIPTS_ROOT) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_ROOT))

from common.emit import emit  # noqa: E402


def cmd_example(args) -> int:
    """예시 서브커맨드 — 인자 그대로 echo."""
    return emit({
        "input": args.text,
        "summary": f"입력: {args.text}",
    })


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="<scope>_cli",
        description="<skill name> skill CLI",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    p_ex = sub.add_parser("example", help="예시 서브커맨드")
    p_ex.add_argument("text")
    p_ex.set_defaults(func=cmd_example)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    if not hasattr(args, "func"):
        parser.print_help(sys.stderr)
        return 1
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: 템플릿 자체 검증 — 위 코드 그대로 임시 skill로 복사 후 실행**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
mkdir -p /tmp/test_skill/scripts
cp "$PROJECT_ROOT/skills/suh-skill-creator/templates/python_cli_script.py" /tmp/test_skill/scripts/test_cli.py
# bootstrap은 _HERE.parents[3] 의존이므로 임시 skill을 실제 skills/ 아래에 둬야 함
mkdir -p "$PROJECT_ROOT/skills/_test_skill_template/scripts"
cp "$PROJECT_ROOT/skills/suh-skill-creator/templates/python_cli_script.py" "$PROJECT_ROOT/skills/_test_skill_template/scripts/test_cli.py"
cd "$PROJECT_ROOT/skills/_test_skill_template/scripts" && python test_cli.py example "hello world"
rm -rf "$PROJECT_ROOT/skills/_test_skill_template"
```

Expected: `{"ok": true, "code": "ok", "summary": "입력: hello world", ..., "input": "hello world"}` 같은 JSON.

- [ ] **Step 3: Commit**

```bash
git add skills/suh-skill-creator/templates/python_cli_script.py
git commit -m "feat(suh-skill-creator): templates/python_cli_script.py 새 표준 골격 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 6.2: suh-skill-creator SKILL.md 새 표준 반영

**Files:**
- Modify: `skills/suh-skill-creator/SKILL.md`

- [ ] **Step 1: 새 표준 안내 섹션 추가**

SKILL.md 어느 적절한 위치(예: "신규 skill 작성 시 py 필요한 경우" 섹션)에 다음 추가:

```markdown
## 신규 skill에 Python 호출이 필요한 경우

`templates/python_cli_script.py` 골격을 그대로 복사하여 `skills/suh-<new>/scripts/<scope>_cli.py`로 둔다.

다음 절차:

1. `cp templates/python_cli_script.py skills/suh-<new>/scripts/<scope>_cli.py`
2. `prog` 이름 + 서브커맨드 부분만 교체
3. `from common.<module> import ...` 형태로 Layer 1 import (공유 코드 재작성 금지)
4. SKILL.md 호출 코드블록은 표준 5줄 패턴 (`references/common-rules.md` §3 참조)

이 골격은:
- cwd 무관 동작 (`__file__` 기준 sys.path 자동 조작)
- argparse 자동 `--help`
- emit() 헬퍼로 MCP-style 4필드 JSON 자동 보장
- Windows Git Bash + macOS/WSL 양쪽 동작
```

- [ ] **Step 2: 8대 원칙 + 새 표준 충돌 확인**

```bash
grep -n "PYTHONPATH\|suh_template.suh_command" "$PROJECT_ROOT/skills/suh-skill-creator/SKILL.md"
```

Expected: 0건. 기존 표준 잔재 없어야 함.

- [ ] **Step 3: Commit**

```bash
git add skills/suh-skill-creator/SKILL.md
git commit -m "docs(suh-skill-creator): SKILL.md 새 표준 안내 추가 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

## Phase 7: scripts/suh_template/ 삭제 + 잔여 import 정리

### Task 7.1: 잔여 import 점검

**Files:**
- Inspect: 전체 레포

- [ ] **Step 1: 전체 grep**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
grep -rn "suh_template" "$PROJECT_ROOT" --include="*.py" --include="*.md" --include="*.yaml" --include="*.yml" 2>&1 | grep -v "docs/superpowers" | head -30
```

Expected: skills/<x>/scripts/*_cli.py 안에는 없어야 함. 잔존 출현 시 → common.* 로 교체.

- [ ] **Step 2: .github/workflows/ 점검**

```bash
grep -rn "suh_template" "$PROJECT_ROOT/.github/workflows/" 2>&1
```

CI 워크플로우에서 직접 호출하면 → `python skills/<x>/scripts/<x>_cli.py <subcmd>` 형태로 교체. 또는 호출 0건이면 그대로 진행.

- [ ] **Step 3: Commit (정리 있으면)**

```bash
git add .
git commit -m "refactor: suh_template 잔여 import 제거 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 7.2: scripts/suh_template/ 삭제

**Files:**
- Delete: `scripts/suh_template/` 전체

- [ ] **Step 1: 삭제 직전 회귀 검증 (마지막 안전망)**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT/skills/suh-troubleshoot/scripts" && python troubleshoot_cli.py get-output-path troubleshoot 2>&1 | tail -1
cd "$PROJECT_ROOT/skills/suh-github/scripts" && python github_cli.py get-issue Cassiiopeia SUH-DEVOPS-TEMPLATE 322 2>&1 | python -c "import sys, json; print('github ok:', json.loads(sys.stdin.read())['ok'])"
```

Expected: 두 호출 모두 정상.

- [ ] **Step 2: 삭제**

```bash
cd "$PROJECT_ROOT"
git rm -r scripts/suh_template/
```

- [ ] **Step 3: 삭제 후 회귀 검증**

```bash
cd "$PROJECT_ROOT/skills/suh-troubleshoot/scripts" && python troubleshoot_cli.py get-output-path troubleshoot 2>&1 | tail -1
cd "$PROJECT_ROOT/skills/suh-github/scripts" && python github_cli.py get-issue Cassiiopeia SUH-DEVOPS-TEMPLATE 322 2>&1 | python -c "import sys, json; print('github ok:', json.loads(sys.stdin.read())['ok'])"
```

Expected: 동일 결과. suh_template 삭제 후에도 새 구조가 자급자족.

- [ ] **Step 4: Commit**

```bash
git commit -m "refactor: scripts/suh_template/ 완전 제거 (3-layer 마이그레이션 완료) https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/322"
```

---

### Task 7.3: 최종 디렉토리 구조 검증

**Files:**
- Inspect: 전체

- [ ] **Step 1: 구조 확인**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
ls "$PROJECT_ROOT/scripts/" 2>&1
echo "---"
ls "$PROJECT_ROOT/scripts/common/" 2>&1
echo "---"
for skill in suh-github suh-issue suh-commit suh-report suh-review suh-troubleshoot suh-changelog-deploy; do
  echo "=== $skill ==="
  ls "$PROJECT_ROOT/skills/$skill/scripts/" 2>&1
done
```

Expected:
- `scripts/` = common/, ssh/, (suh_template 없음)
- `scripts/common/` = __init__.py + 9개 모듈
- 각 skill = scripts/<scope>_cli.py 존재

- [ ] **Step 2: Commit (정리 결과 마커)**

(코드 변경 없음 — Phase 7 마무리)

---

## Phase 8: OS 회귀 검증

### Task 8.1: Windows Git Bash 전체 회귀

**Files:**
- Test: 7개 SKILL의 모든 코드블록 + smoke

- [ ] **Step 1: 7개 SKILL 핵심 호출 일괄 dry-run**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)

# suh-github
cd "$PROJECT_ROOT/skills/suh-github/scripts" && python github_cli.py get-issue Cassiiopeia SUH-DEVOPS-TEMPLATE 322 2>&1 | python -c "import sys, json; print('github get-issue:', json.loads(sys.stdin.read())['ok'])"

# suh-issue
cd "$PROJECT_ROOT/skills/suh-issue/scripts" && python issue_cli.py search-issues Cassiiopeia SUH-DEVOPS-TEMPLATE "skill" 2>&1 | python -c "import sys, json; print('issue search:', json.loads(sys.stdin.read())['ok'])"

# suh-commit
cd "$PROJECT_ROOT/skills/suh-commit/scripts" && python commit_cli.py get-issue-number 2>&1 | python -c "import sys, json; print('commit get-issue-number:', json.loads(sys.stdin.read())['ok'])"

# suh-report
cd "$PROJECT_ROOT/skills/suh-report/scripts" && python report_cli.py get-output-path report 2>&1 | python -c "import sys, json; print('report get-output-path:', json.loads(sys.stdin.read())['ok'])"

# suh-review
cd "$PROJECT_ROOT/skills/suh-review/scripts" && python review_cli.py get-output-path review 2>&1 | python -c "import sys, json; print('review get-output-path:', json.loads(sys.stdin.read())['ok'])"

# suh-troubleshoot
cd "$PROJECT_ROOT/skills/suh-troubleshoot/scripts" && python troubleshoot_cli.py get-output-path troubleshoot 2>&1 | python -c "import sys, json; print('troubleshoot get-output-path:', json.loads(sys.stdin.read())['ok'])"

# suh-changelog-deploy
cd "$PROJECT_ROOT/skills/suh-changelog-deploy/scripts" && python changelog_cli.py deploy-status Cassiiopeia SUH-DEVOPS-TEMPLATE 2>&1 | python -c "import sys, json; print('changelog deploy-status:', json.loads(sys.stdin.read())['ok'])"
```

Expected: 7개 모두 `True` 출력.

- [ ] **Step 2: Phase 1.1 baseline 비교**

```bash
cat /tmp/baseline_get_output_path.txt
cd "$PROJECT_ROOT/skills/suh-troubleshoot/scripts" && python troubleshoot_cli.py get-output-path troubleshoot 2>&1 | python -c "import sys, json; print(json.loads(sys.stdin.read())['path'])"
```

경로 패턴 일치 확인 (NNN seq 번호만 차이 가능).

---

### Task 8.2: WSL Linux 회귀

**Files:**
- Test: 7개 SKILL을 WSL에서 dry-run

- [ ] **Step 1: WSL에서 동일 호출 전부**

```powershell
$skills = @(
  "suh-github::github_cli.py::get-issue::Cassiiopeia SUH-DEVOPS-TEMPLATE 322",
  "suh-issue::issue_cli.py::search-issues::Cassiiopeia SUH-DEVOPS-TEMPLATE 'skill'",
  "suh-commit::commit_cli.py::get-issue-number::",
  "suh-report::report_cli.py::get-output-path::report",
  "suh-review::review_cli.py::get-output-path::review",
  "suh-troubleshoot::troubleshoot_cli.py::get-output-path::troubleshoot",
  "suh-changelog-deploy::changelog_cli.py::deploy-status::Cassiiopeia SUH-DEVOPS-TEMPLATE"
)
foreach ($s in $skills) {
  $parts = $s -split "::"
  $skill, $cli, $cmd, $args = $parts[0], $parts[1], $parts[2], $parts[3]
  $result = wsl bash -c "cd /mnt/d/0-suh/project/suh-github-template/skills/$skill/scripts && python3 $cli $cmd $args 2>&1 | tail -1"
  Write-Host "$skill : $result"
}
```

Expected: 7개 모두 JSON 출력 (ok:true 포함).

- [ ] **Step 2: WSL 결과 자료화**

```bash
echo "Phase 8 WSL 회귀 검증 완료 — 7개 skill 양 OS 동작 보장" > /tmp/phase8_validation.txt
```

---

### Task 8.3: Push + PR 생성

**Files:**
- Push: 원격 브랜치
- Create: PR (Cassiiopeia/SUH-DEVOPS-TEMPLATE)

- [ ] **Step 1: Push**

```bash
git push -u origin "20260601_#322_skill_py_실행_구조_MCP-style_표준화_및_OS_호환성_강건화"
```

Expected: remote 브랜치 생성됨.

- [ ] **Step 2: PR 본문 작성**

PR body 파일 작성 (`/tmp/pr_322_body.md`):

```markdown
## 개요
skill 내부 Python 실행 구조를 3-layer 아키텍처로 완전 재설계.

## 변경
- Layer 1: `scripts/common/` 신설 (gh_client, gh_branch, paths, title, issue_number, config, manifest, emit, bootstrap)
- Layer 2: 7개 skill에 자체 `scripts/<scope>_cli.py` 추가 (github_cli, issue_cli, commit_cli, report_cli, review_cli, troubleshoot_cli, changelog_cli)
- Layer 3: 7개 SKILL.md 호출 패턴을 self-contained 5줄로 통일
- 기존 `scripts/suh_template/` 완전 제거
- `references/common-rules.md` §3 PYTHONPATH 제거 + 새 표준 명시
- `suh-skill-creator/templates/python_cli_script.py` 새 표준 골격
- MCP-style JSON 4필드 (ok/code/summary/next) emit() 헬퍼로 강제

## 검증
- Windows Git Bash MINGW64 ⭕
- WSL Linux bash 5.2 ⭕ (macOS POSIX 프록시)
- 깨졌던 suh-troubleshoot·suh-review `get-output-path` 호출 정상 동작 복구

## 이슈
- Closes #322
```

- [ ] **Step 3: PR 생성 (github_cli로)**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cd "$PROJECT_ROOT/skills/suh-github/scripts" && python github_cli.py create-pr Cassiiopeia SUH-DEVOPS-TEMPLATE "🚀[기능개선][Skills] skill 내부 py 실행 구조 MCP-style 표준화 및 OS 호환성 강건화" /tmp/pr_322_body.md "Cassiiopeia:20260601_#322_skill_py_실행_구조_MCP-style_표준화_및_OS_호환성_강건화" main 2>&1 | python -c "import sys, json; d = json.loads(sys.stdin.read()); print('PR URL:', d.get('url'))"
```

Expected: PR URL 출력.

- [ ] **Step 4: 완료 (PR review 대기)**

Phase 8 마무리. 사용자에게 PR URL 보고.

---

### Task 8.4: 회귀 검증 회고 + 이슈 댓글

**Files:**
- Comment: 이슈 #322

- [ ] **Step 1: 검증 결과 요약 댓글**

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
cat > /tmp/issue_322_completion.md << 'EOF'
## 작업 완료 보고

**브랜치**: `20260601_#322_skill_py_실행_구조_MCP-style_표준화_및_OS_호환성_강건화`
**PR**: (위 PR 링크)

### 핵심 변경
- 3-layer 아키텍처 도입 (common / cli / SKILL)
- 7개 skill 각자 자체 cli.py 보유
- `scripts/suh_template/` 완전 제거
- self-contained 5줄 Bash 호출 패턴
- MCP-style JSON 4필드 강제

### 검증
- Windows Git Bash MINGW64 ⭕
- WSL Linux bash 5.2 ⭕

### 깨졌던 호출 복구
- `suh-troubleshoot/SKILL.md` L99-102: `$SCRIPTS_PATH`·`$PYTHON` 미정의 → 표준 5줄로 정상화
- `suh-review/SKILL.md` L88-91: 동일 정상화
EOF

cd "$PROJECT_ROOT/skills/suh-github/scripts" && python github_cli.py add-comment Cassiiopeia SUH-DEVOPS-TEMPLATE 322 /tmp/issue_322_completion.md 2>&1 | python -c "import sys, json; print('comment URL:', json.loads(sys.stdin.read()).get('url'))"
```

Expected: 댓글 URL 출력.

- [ ] **Step 2: 작업 종료**

브랜치 push 끝, PR 생성됨, 이슈 댓글 작성됨. Phase 8 + 전체 plan 종료.

---

## Self-Review

### 1. Spec coverage

| Spec 섹션 | 구현 Task |
|---|---|
| §3 3-layer 아키텍처 | Phase 1-3 전체 |
| §4 파일 구조 | Phase 1-3, 7 |
| §5 표준 호출 패턴 (5.1 Bash + 5.2 Python bootstrap) | Phase 2-4 |
| §6 MCP-style JSON 4필드 | Task 1.3 emit() + 모든 cmd 함수 |
| §7 서브커맨드 매핑 | Phase 2-3 |
| §8 의존 모듈 마이그레이션 | Phase 1 (Task 1.5-1.8) |
| §9 references 정정 | Phase 5 |
| §10 OS 호환성 | Phase 2 Task 2.9 + Phase 8 |
| §11 검증 방식 | Phase 2-3 각 task의 smoke + Phase 8 |
| §12 구현 단계 | Phase 1-8 그대로 |
| §13.5 확장성 (신규 skill·서브커맨드·common·외부 시스템·multi-profile·OS·출력 포맷·테스트) | Phase 6 templates + 3-layer 자체가 확장성 보장 |
| §14 롤백 전략 | Phase 7 Task 7.2가 마지막 — 그 전엔 신구 병존 |

빈틈 없음.

### 2. Placeholder scan

- "TBD" 없음
- "implement later" 없음
- 모든 step에 실제 코드/명령 + Expected
- "Similar to Task N" 없음 — 각 cli별 핵심 함수 직접 명시

### 3. Type consistency

- `emit(payload: dict) -> int` 일관
- `cmd_<name>(args) -> int` 패턴 일관
- `pat = get_github_pat(owner, repo)` 일관
- `GitHubAPIError` import 일관
- JSON 출력 = `emit({...})` 일관

OK. 빈틈 없음.

---

## 실행 옵션

Plan 저장 완료: `docs/superpowers/plans/2026-06-01-skill-py-restructure-implementation.md`

두 실행 옵션:

**1. Subagent-Driven (recommended)** — 각 task를 fresh subagent가 처리. 메인 컨텍스트가 두꺼워지지 않고, 매 task 사이에 main이 review 가능.

**2. Inline Execution** — 본 세션에서 직접 실행. 체크포인트마다 사용자 확인.

어느 쪽으로?
