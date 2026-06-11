# suh-changelog-deploy 임시파일 위치 버그 수정 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** suh-changelog-deploy 스킬의 릴리스 노트 임시파일을 레포 내부 `scripts/`(cwd 의존, 삭제 실패로 찌꺼기 누적) 대신 홈 `~/.suh-template/tmp/{owner}__{repo}__release_notes.md`(레포별 고유, 단일 절대경로)로 옮겨 버그를 제거한다.

**Architecture:** 만들기(agent Write) · 읽기(cli) · 지우기(bash rm)가 모두 같은 절대경로를 가리키게 통일한다. 파일명에 `{owner}__{repo}` prefix를 박아 여러 에이전트·레포 동시 deploy 시 충돌을 막는다. 폴더는 `tmp/` 하나만 둔다. bash는 `$HOME`, cli는 `pathlib.Path.home()`을 써서 Windows·macOS 양쪽에서 동작한다.

**Tech Stack:** 마크다운 SKILL.md(LLM 지시문), Python 3 표준 라이브러리(`pathlib`), bash. 외부 의존성 없음.

**스펙:** `docs/superpowers/specs/2026-06-11-changelog-deploy-tmpfile-location-design.md`

---

## File Structure

| 파일 | 작업 | 책임 |
|---|---|---|
| Modify: `skills/suh-changelog-deploy/scripts/changelog_cli.py` | `_resolve_body_file` 탐색 후보에 홈 tmp 추가 + docstring·에러메시지 갱신 | cli가 받은 본문 파일 경로를 해석(읽기만) |
| Modify: `skills/suh-changelog-deploy/SKILL.md` | 5단계·6단계·fix4·fix5의 임시파일 경로를 `~/.suh-template/tmp/{OWNER}__{REPO}__release_notes.md`로 통일 | agent에게 Write 위치·bash NOTES_FILE·rm 경로를 일치시켜 지시 |

주의: cli의 `raw.is_absolute()` 분기(213-214행)와 기존 `_PROJECT_ROOT / "scripts"` 후보는 **유지**(하위호환). 파일명 생성 로직은 cli로 옮기지 않고 SKILL.md(agent) 책임으로 둔다.

검증 환경: Windows + Git Bash. Python은 `/c/Users/USER/AppData/Local/Programs/Python/Python313/python`(또는 `command -v python`). 이 레포는 외부 인터넷이 없으므로 실제 PR 생성은 하지 않고 경로 해석만 단위 검증한다.

---

### Task 1: cli `_resolve_body_file`에 홈 tmp 후보 추가 (TDD)

**Files:**
- Modify: `skills/suh-changelog-deploy/scripts/changelog_cli.py:203-218`
- Test: `scripts/tests/test_changelog_resolve_body_file.py` (신규 — 기존 `scripts/tests/` 컨벤션을 따른다)

**배경**: `_resolve_body_file`은 본문 파일 경로를 해석한다. 절대경로면 그대로, 상대경로면 `(raw, PROJECT_ROOT/scripts/raw.name, cwd/raw)` 순으로 탐색한다. 여기에 `~/.suh-template/tmp/raw.name` 후보를 추가해, 누군가 파일명만(`owner__repo__release_notes.md`) 넘겨도 홈 tmp에서 찾게 한다. 절대경로 분기는 그대로 두므로 SKILL.md가 절대경로를 넘기는 정상 흐름은 1순위로 동작한다.

- [ ] **Step 1: 실패하는 테스트 작성**

먼저 테스트 파일이 import할 수 있는지 확인하기 위해 cli 경로를 sys.path에 넣는다. 다음 전체 내용으로 신규 파일을 만든다:

```python
# scripts/tests/test_changelog_resolve_body_file.py
"""_resolve_body_file 경로 해석 단위 테스트 — 홈 tmp 후보 추가 검증."""
import importlib.util
import sys
from pathlib import Path

# 이 파일: <root>/scripts/tests/ → parents[2] == <root>
# changelog_cli.py: <root>/skills/suh-changelog-deploy/scripts/changelog_cli.py
_ROOT = Path(__file__).resolve().parents[2]
_CLI_PATH = _ROOT / "skills" / "suh-changelog-deploy" / "scripts" / "changelog_cli.py"
_spec = importlib.util.spec_from_file_location("changelog_cli", _CLI_PATH)
changelog_cli = importlib.util.module_from_spec(_spec)
sys.modules["changelog_cli"] = changelog_cli
_spec.loader.exec_module(changelog_cli)

_resolve = changelog_cli._resolve_body_file


def test_absolute_path_returned_as_is(tmp_path):
    f = tmp_path / "owner__repo__release_notes.md"
    f.write_text("note", encoding="utf-8")
    assert _resolve(str(f)) == f


def test_absolute_path_missing_returns_none(tmp_path):
    f = tmp_path / "nope.md"
    assert _resolve(str(f)) is None


def test_relative_name_found_in_home_tmp(monkeypatch, tmp_path):
    # HOME을 tmp_path로 바꿔 ~/.suh-template/tmp/ 를 격리 검증
    fake_home = tmp_path
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: fake_home))
    notes_dir = fake_home / ".suh-template" / "tmp"
    notes_dir.mkdir(parents=True)
    target = notes_dir / "owner__repo__release_notes.md"
    target.write_text("note", encoding="utf-8")
    # 상대경로(파일명만) 입력 → 홈 tmp에서 발견되어야 함
    assert _resolve("owner__repo__release_notes.md") == target


def test_none_input_returns_none():
    assert _resolve(None) is None
    assert _resolve("") is None
```

- [ ] **Step 2: 테스트 실행 — 홈 tmp 케이스 실패 확인**

Run (Git Bash):
```
PYTHON=$(command -v python); cd "D:/0-suh/project/suh-github-template" && "$PYTHON" -m pytest scripts/tests/test_changelog_resolve_body_file.py -v
```
Expected: `test_relative_name_found_in_home_tmp` FAIL (현재 후보에 홈 tmp가 없어 None 반환), 나머지 3개 PASS.

pytest가 없으면:
```
PYTHON=$(command -v python); "$PYTHON" -c "import pytest" 2>/dev/null && echo HAS_PYTEST || echo NO_PYTEST
```
NO_PYTEST면 Step 2/4에서 아래 인라인 검증 스크립트로 대체하고 그 사실을 보고한다:
```
PYTHON=$(command -v python); cd "D:/0-suh/project/suh-github-template" && "$PYTHON" - <<'PY'
import importlib.util, sys, tempfile, os
from pathlib import Path
p = Path("skills/suh-changelog-deploy/scripts/changelog_cli.py").resolve()
spec = importlib.util.spec_from_file_location("changelog_cli", p)
m = importlib.util.module_from_spec(spec); sys.modules["changelog_cli"]=m; spec.loader.exec_module(m)
import unittest.mock as mock
with tempfile.TemporaryDirectory() as d:
    home = Path(d)
    with mock.patch.object(Path, "home", classmethod(lambda cls: home)):
        nd = home/".suh-template"/"tmp"; nd.mkdir(parents=True)
        t = nd/"owner__repo__release_notes.md"; t.write_text("x", encoding="utf-8")
        got = m._resolve_body_file("owner__repo__release_notes.md")
        print("RESULT:", got, "EXPECT:", t, "PASS" if got==t else "FAIL")
PY
```
구현 전 Expected: `FAIL` (홈 tmp 후보 없음).

- [ ] **Step 3: `_resolve_body_file` 구현 수정**

`changelog_cli.py:203-218`을 다음으로 교체한다 (docstring·후보·주석 갱신):

```python
def _resolve_body_file(body_file: str | None) -> Path | None:
    """본문 파일 경로 해석 — 절대 경로면 그대로, 상대 경로면 여러 위치를 순서대로 탐색.

    SKILL.md 절차는 `~/.suh-template/tmp/{owner}__{repo}__release_notes.md`(홈, 절대경로)에
    저장하고 cli에 그 절대경로를 넘긴다. 다만 누군가 파일명만(상대경로) 넘겨도 찾을 수 있도록
    홈 tmp → PROJECT_ROOT/scripts(구버전 하위호환) → cwd 순으로 보강 탐색한다.
    찾지 못하면 None을 반환한다 (호출자가 본문 없음을 판단).
    """
    if not body_file:
        return None
    raw = Path(body_file)
    if raw.is_absolute():
        return raw if raw.exists() else None
    for candidate in (
        raw,
        Path.home() / ".suh-template" / "tmp" / raw.name,
        _PROJECT_ROOT / "scripts" / raw.name,
        Path.cwd() / raw,
    ):
        if candidate.exists():
            return candidate
    return None
```

- [ ] **Step 4: 테스트 실행 — 전부 통과 확인**

Run:
```
PYTHON=$(command -v python); cd "D:/0-suh/project/suh-github-template" && "$PYTHON" -m pytest scripts/tests/test_changelog_resolve_body_file.py -v
```
Expected: 4개 모두 PASS. (pytest 없으면 Step 2의 인라인 스크립트 재실행 → `PASS` 출력 확인)

- [ ] **Step 5: cli 에러 메시지 갱신**

`changelog_cli.py`의 `cmd_create_pr` 안 `body_file_not_found` 에러(247행 부근)를 홈 tmp 후보까지 안내하도록 교체한다. 기존:

```python
            "error": f"본문 파일을 찾을 수 없습니다: {args.body_file} (cwd={Path.cwd()}, PROJECT_ROOT={_PROJECT_ROOT})",
```

다음으로 교체:

```python
            "error": (
                f"본문 파일을 찾을 수 없습니다: {args.body_file} "
                f"(탐색: 절대경로 | ~/.suh-template/tmp/ | {_PROJECT_ROOT / 'scripts'} | cwd={Path.cwd()})"
            ),
```

- [ ] **Step 6: 문법 검증 + 커밋**

Run (문법만 빠르게 확인):
```
PYTHON=$(command -v python); cd "D:/0-suh/project/suh-github-template" && "$PYTHON" -m py_compile skills/suh-changelog-deploy/scripts/changelog_cli.py && echo OK
```
Expected: `OK`

커밋 (이 두 파일만 stage — 레포에 무관한 untracked 다수 존재, `git add -A` 금지):
```bash
cd "D:/0-suh/project/suh-github-template"
git add skills/suh-changelog-deploy/scripts/changelog_cli.py scripts/tests/test_changelog_resolve_body_file.py
git commit -m "changelog_cli _resolve_body_file에 홈 tmp 후보 추가 : fix : 릴리스 노트 임시파일을 ~/.suh-template/tmp/에서도 찾도록 탐색 경로 보강하고 docstring·에러메시지를 새 위치 기준으로 갱신, 경로 해석 단위 테스트 추가"
```

(커밋 메시지에 이모지·태그 prefix 금지, AI 관여 trailer 절대 금지 — 프로젝트 컨벤션)

---

### Task 2: SKILL.md deploy 모드 경로 통일

**Files:**
- Modify: `skills/suh-changelog-deploy/SKILL.md` (5단계 저장 안내 237행 부근, deploy 6단계 bash 블록 346-375행 부근)

**배경**: agent가 Write로 만드는 위치와 bash가 읽고 지우는 위치를 `~/.suh-template/tmp/{OWNER}__{REPO}__release_notes.md`로 일치시킨다. `{OWNER}`·`{REPO}`는 [시작 전]에서 agent가 이미 구한 값이다.

- [ ] **Step 1: 5단계 저장 위치 안내 교체**

`SKILL.md`에서 다음 줄(237행 부근)을 찾는다:

```
**Write tool로 `$PROJECT_ROOT/scripts/_release_notes.md`에 저장**:
```

다음으로 교체:

```
**Write tool로 `~/.suh-template/tmp/{OWNER}__{REPO}__release_notes.md`에 저장한다** (레포 내부가 아닌 홈 디렉토리 — config와 동일 위치라 레포 오염이 없고, 파일명의 `{OWNER}__{REPO}` prefix로 여러 레포·에이전트 동시 deploy 시 충돌이 없다). `{OWNER}`·`{REPO}`는 [시작 전]에서 구한 실제 값으로 치환한다. Windows는 `C:\Users\<사용자>\.suh-template\tmp\{OWNER}__{REPO}__release_notes.md`, macOS/Linux는 `~/.suh-template/tmp/{OWNER}__{REPO}__release_notes.md`. **tmp 폴더가 없으면 Write 전에 생성**한다. 이후 cli 호출 시 이 **절대경로**(아래 `NOTES_FILE`)를 그대로 넘긴다:
```

- [ ] **Step 2: deploy 6단계 bash 블록 교체**

`SKILL.md`의 deploy 6단계 bash 블록에서, 변수 선언 줄부터 `cd "$PROJECT_ROOT"`까지를 교체한다. 기존:

```bash
# ⚠️ Bash stateless — 이 블록 맨 앞 5개 변수를 [시작 전]에서 구한 실제 값으로 채운다.
GITHUB_PAT="..."; OWNER="..."; REPO="..."; PYTHON="..."; PROJECT_ROOT="..."

TODAY=$(date '+%Y%m%d')
TITLE="🚀 Deploy ${TODAY}"

cd "$PROJECT_ROOT/skills/suh-changelog-deploy/scripts"
DEPLOY_STATUS=$(GITHUB_PAT="$GITHUB_PAT" PYTHONIOENCODING=utf-8 "$PYTHON" changelog_cli.py \
  deploy-status "$OWNER" "$REPO" --base deploy)
EXISTING_PR=$(DEPLOY_STATUS="$DEPLOY_STATUS" "$PYTHON" -c "import os,json; d=json.loads(os.environ['DEPLOY_STATUS']); print((d.get('pr') or {}).get('number',''))")

# 기존 open deploy PR이 있으면 재사용 — 닫지 않는다 (새로 열면 워크플로우 재트리거되어 본문 초기화 위험)
if [ -n "$EXISTING_PR" ]; then
  # 재사용 케이스: 이미 PR이 존재하므로 update-pr로 릴리스 노트 본문만 갱신한다.
  PR_NUMBER=$EXISTING_PR
  echo "기존 deploy PR #$PR_NUMBER 재사용 → 본문 업데이트"
  RESULT_OUT=$(GITHUB_PAT="$GITHUB_PAT" PYTHONIOENCODING=utf-8 "$PYTHON" changelog_cli.py \
    update-pr "$OWNER" "$REPO" "$PR_NUMBER" "_release_notes.md"
  )
else
  # 신규 케이스: create-pr의 body_file에 릴리스 노트 파일 경로를 넘겨 본문 포함 PR 생성.
  # suh_command가 body_file을 읽어 본문에 채운다 (빈 경로를 넘기던 기존 동작과 달리, 노트 파일을 넘긴다).
  RESULT_OUT=$(GITHUB_PAT="$GITHUB_PAT" PYTHONIOENCODING=utf-8 "$PYTHON" changelog_cli.py \
    create-pr "$OWNER" "$REPO" "$TITLE" "_release_notes.md" "main" "deploy")
  PR_NUMBER=$(RESULT_OUT="$RESULT_OUT" "$PYTHON" -c "import os,json; print(json.loads(os.environ['RESULT_OUT']).get('number',''))")
  echo "새 deploy PR #$PR_NUMBER 생성 (릴리스 노트 본문 포함)"
fi
rm -f _release_notes.md
cd "$PROJECT_ROOT"
```

다음으로 교체:

```bash
# ⚠️ Bash stateless — 이 블록 맨 앞 5개 변수를 [시작 전]에서 구한 실제 값으로 채운다.
GITHUB_PAT="..."; OWNER="..."; REPO="..."; PYTHON="..."; PROJECT_ROOT="..."

# 릴리스 노트 임시 파일 — 5단계에서 Write한 그 절대경로와 동일해야 한다.
# 홈 디렉토리 + {OWNER}__{REPO} prefix → cwd 무관·레포별 격리. (Windows Git Bash도 $HOME 정상 동작)
NOTES_FILE="$HOME/.suh-template/tmp/${OWNER}__${REPO}__release_notes.md"

TODAY=$(date '+%Y%m%d')
TITLE="🚀 Deploy ${TODAY}"

cd "$PROJECT_ROOT/skills/suh-changelog-deploy/scripts"
DEPLOY_STATUS=$(GITHUB_PAT="$GITHUB_PAT" PYTHONIOENCODING=utf-8 "$PYTHON" changelog_cli.py \
  deploy-status "$OWNER" "$REPO" --base deploy)
EXISTING_PR=$(DEPLOY_STATUS="$DEPLOY_STATUS" "$PYTHON" -c "import os,json; d=json.loads(os.environ['DEPLOY_STATUS']); print((d.get('pr') or {}).get('number',''))")

# 기존 open deploy PR이 있으면 재사용 — 닫지 않는다 (새로 열면 워크플로우 재트리거되어 본문 초기화 위험)
if [ -n "$EXISTING_PR" ]; then
  # 재사용 케이스: 이미 PR이 존재하므로 update-pr로 릴리스 노트 본문만 갱신한다.
  PR_NUMBER=$EXISTING_PR
  echo "기존 deploy PR #$PR_NUMBER 재사용 → 본문 업데이트"
  RESULT_OUT=$(GITHUB_PAT="$GITHUB_PAT" PYTHONIOENCODING=utf-8 "$PYTHON" changelog_cli.py \
    update-pr "$OWNER" "$REPO" "$PR_NUMBER" "$NOTES_FILE"
  )
else
  # 신규 케이스: create-pr의 body_file에 릴리스 노트 파일 절대경로를 넘겨 본문 포함 PR 생성.
  # suh_command가 body_file을 읽어 본문에 채운다 (빈 경로를 넘기던 기존 동작과 달리, 노트 파일을 넘긴다).
  RESULT_OUT=$(GITHUB_PAT="$GITHUB_PAT" PYTHONIOENCODING=utf-8 "$PYTHON" changelog_cli.py \
    create-pr "$OWNER" "$REPO" "$TITLE" "$NOTES_FILE" "main" "deploy")
  PR_NUMBER=$(RESULT_OUT="$RESULT_OUT" "$PYTHON" -c "import os,json; print(json.loads(os.environ['RESULT_OUT']).get('number',''))")
  echo "새 deploy PR #$PR_NUMBER 생성 (릴리스 노트 본문 포함)"
fi
rm -f "$NOTES_FILE"
cd "$PROJECT_ROOT"
```

- [ ] **Step 3: 잔존 참조 검증**

Run:
```
cd "D:/0-suh/project/suh-github-template" && grep -n "scripts/_release_notes.md\|\"_release_notes.md\"\|rm -f _release_notes.md" skills/suh-changelog-deploy/SKILL.md
```
Expected: deploy 모드(237행·6단계) 관련 매치가 더는 없어야 한다. **fix 모드(fix4 498행, fix5 524·526행) 매치는 Task 3에서 처리하므로 이 시점엔 남아 있어도 정상** — 출력에 fix 모드 라인만 남았는지 확인한다.

- [ ] **Step 4: 커밋**

```bash
cd "D:/0-suh/project/suh-github-template"
git add skills/suh-changelog-deploy/SKILL.md
git commit -m "suh-changelog-deploy deploy 모드 임시파일 경로 통일 : fix : 릴리스 노트를 홈 ~/.suh-template/tmp/{owner}__{repo}__release_notes.md에 저장·읽기·삭제하도록 5·6단계 일치 — cwd 불일치로 삭제 실패해 레포에 찌꺼기가 쌓이던 문제 해결, 레포별 파일명으로 동시 deploy 충돌 방지"
```

---

### Task 3: SKILL.md fix 모드 경로 통일

**Files:**
- Modify: `skills/suh-changelog-deploy/SKILL.md` (fix 4단계 저장 안내 498행 부근, fix 5단계 bash 블록 514-527행 부근)

**배경**: fix 모드도 deploy 모드와 동일한 임시파일 위치를 써야 한다. Task 2와 같은 변경을 fix 4·5단계에 적용한다.

- [ ] **Step 1: fix 4단계 저장 위치 교체**

`SKILL.md`에서 다음 줄(498행 부근)을 찾는다:

```
deploy 6단계와 **동일한 고정 구조**로 릴리스 노트 파일을 작성한다 (Write tool로 `$PROJECT_ROOT/scripts/_release_notes.md`에 저장). 구조는 deploy 5단계의 고정 템플릿(`Summary by CodeRabbit` 포함)을 그대로 따른다.
```

다음으로 교체:

```
deploy 6단계와 **동일한 고정 구조**로 릴리스 노트 파일을 작성한다 (Write tool로 `~/.suh-template/tmp/{OWNER}__{REPO}__release_notes.md`에 저장 — deploy 5단계와 동일 위치·파일명 규칙, tmp 폴더 없으면 먼저 생성). 구조는 deploy 5단계의 고정 템플릿(`Summary by CodeRabbit` 포함)을 그대로 따른다.
```

- [ ] **Step 2: fix 5단계 bash 블록 교체**

`SKILL.md`의 fix 5단계 bash 블록에서 변수 선언부터 `cd "$PROJECT_ROOT"`까지 교체한다. 기존:

```bash
# ⚠️ Bash stateless — 5개 변수를 실제 값으로 채운다.
GITHUB_PAT="..."; OWNER="..."; REPO="..."; PYTHON="..."; PROJECT_ROOT="..."

TODAY=$(date '+%Y%m%d')
TITLE="🚀 Deploy ${TODAY} (재시도)"

# create-pr의 body_file에 릴리스 노트 파일 경로를 넘겨 본문 포함 PR 생성 (deploy 6단계와 동일 패턴).
cd "$PROJECT_ROOT/skills/suh-changelog-deploy/scripts"
CREATE_OUT=$(GITHUB_PAT="$GITHUB_PAT" PYTHONIOENCODING=utf-8 "$PYTHON" changelog_cli.py \
  create-pr "$OWNER" "$REPO" "$TITLE" "_release_notes.md" "main" "deploy")
PR_NUMBER=$(CREATE_OUT="$CREATE_OUT" "$PYTHON" -c "import os,json; print(json.loads(os.environ['CREATE_OUT']).get('number',''))")
rm -f _release_notes.md
cd "$PROJECT_ROOT"
```

다음으로 교체:

```bash
# ⚠️ Bash stateless — 5개 변수를 실제 값으로 채운다.
GITHUB_PAT="..."; OWNER="..."; REPO="..."; PYTHON="..."; PROJECT_ROOT="..."

# 릴리스 노트 임시 파일 — fix 4단계에서 Write한 그 절대경로와 동일해야 한다.
NOTES_FILE="$HOME/.suh-template/tmp/${OWNER}__${REPO}__release_notes.md"

TODAY=$(date '+%Y%m%d')
TITLE="🚀 Deploy ${TODAY} (재시도)"

# create-pr의 body_file에 릴리스 노트 파일 절대경로를 넘겨 본문 포함 PR 생성 (deploy 6단계와 동일 패턴).
cd "$PROJECT_ROOT/skills/suh-changelog-deploy/scripts"
CREATE_OUT=$(GITHUB_PAT="$GITHUB_PAT" PYTHONIOENCODING=utf-8 "$PYTHON" changelog_cli.py \
  create-pr "$OWNER" "$REPO" "$TITLE" "$NOTES_FILE" "main" "deploy")
PR_NUMBER=$(CREATE_OUT="$CREATE_OUT" "$PYTHON" -c "import os,json; print(json.loads(os.environ['CREATE_OUT']).get('number',''))")
rm -f "$NOTES_FILE"
cd "$PROJECT_ROOT"
```

- [ ] **Step 3: 전체 잔존 참조 최종 검증**

Run:
```
cd "D:/0-suh/project/suh-github-template" && grep -n "scripts/_release_notes.md\|\"_release_notes.md\"\|rm -f _release_notes.md\|PROJECT_ROOT/scripts/_release" skills/suh-changelog-deploy/SKILL.md skills/suh-changelog-deploy/scripts/changelog_cli.py
```
Expected: **매치 0건**. SKILL.md·cli 어디에도 옛 경로 참조가 남지 않아야 한다.

추가로 새 경로가 일관되게 들어갔는지 확인:
```
cd "D:/0-suh/project/suh-github-template" && grep -c "suh-template/tmp" skills/suh-changelog-deploy/SKILL.md
```
Expected: 4 이상 (5단계 안내, 6단계 NOTES_FILE, fix4 안내, fix5 NOTES_FILE).

- [ ] **Step 4: 커밋**

```bash
cd "D:/0-suh/project/suh-github-template"
git add skills/suh-changelog-deploy/SKILL.md
git commit -m "suh-changelog-deploy fix 모드 임시파일 경로 통일 : fix : fix 4·5단계도 deploy 모드와 동일하게 홈 ~/.suh-template/tmp/{owner}__{repo}__release_notes.md를 쓰도록 일치, 옛 scripts/ 경로 참조 완전 제거"
```

---

### Task 4: 문서 + 잔존 찌꺼기 정리

**Files:**
- Modify: `docs/superpowers/specs/2026-06-11-changelog-deploy-tmpfile-location-design.md` (이미 커밋됨 — 상태 갱신만, 선택)
- 정리 대상: `scripts/_release_notes.md` (레포에 남은 untracked 찌꺼기)

- [ ] **Step 1: 레포에 남은 찌꺼기 파일 삭제**

이번 버그로 레포에 남아있던 `scripts/_release_notes.md`를 제거한다 (untracked이므로 git에서 빠지는 게 아니라 파일만 삭제).

Run:
```
cd "D:/0-suh/project/suh-github-template" && ls -la scripts/_release_notes.md 2>/dev/null && rm -f scripts/_release_notes.md && echo "삭제됨" || echo "이미 없음"
```
Expected: `삭제됨` 또는 `이미 없음`.

- [ ] **Step 2: 최종 상태 확인 (커밋 불필요 — untracked 파일 삭제라 git 변경 없음)**

Run:
```
cd "D:/0-suh/project/suh-github-template" && git status --short | grep "_release_notes" || echo "찌꺼기 없음"
```
Expected: `찌꺼기 없음`.

이 Task는 파일 시스템 정리만 하므로 별도 커밋이 없다.

---

## Self-Review 결과

- **스펙 커버리지**: §2(홈 tmp 이동/Task 2·3), §2.0(레포별 파일명/Task 2·3 NOTES_FILE), §2.1(크로스플랫폼 `$HOME`·`pathlib`/Task 1·2), §3.1(SKILL 3지점/Task 2·3), §3.2(cli 후보·docstring·에러/Task 1), §3.3(경계: 절대경로 분기·기존 후보 유지/Task 1 코드에서 보존), §5(검증/Task 1 테스트 + Task 3 grep) — 전부 매핑됨.
- **플레이스홀더**: 코드·명령 전부 실제 내용. "비슷하게"류 없음.
- **타입/이름 일관성**: `NOTES_FILE`, `~/.suh-template/tmp/{OWNER}__{REPO}__release_notes.md`, `_resolve_body_file` 후보 순서가 Task 1~3 전체에서 동일. Write 파일명과 bash `NOTES_FILE`이 같은 규칙(`{OWNER}__{REPO}__release_notes.md`).
- **하위호환**: cli `raw.is_absolute()` 분기·`_PROJECT_ROOT/scripts` 후보 유지(Task 1 코드에 명시).
- **커밋 위생**: 모든 커밋이 해당 파일만 stage(`git add -A` 금지 명시), 이모지·태그·AI trailer 금지.
