# `_cli.py` 서브커맨드 시그니처·JSON·문서화 표준 강화 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 모든 skill `_cli.py`의 argparse 실패가 JSON contract로 통일되고, SKILL.md ↔ CLI 노출 표준이 강제되어 agent가 잘못된 서브커맨드 호출 시 즉시 self-correct할 수 있게 한다.

**Architecture:**
1. `scripts/common/cli_parser.py` 신규 — `JSONArgumentParser`(argparse `error`/`exit` override) + `run_cli(parser)` 헬퍼.
2. 모든 `_cli.py` (`issue/commit/report/review/troubleshoot/github/changelog`)가 `JSONArgumentParser`로 교체 + `run_cli`로 main 단순화.
3. `paths.get_next_seq`에 `strict` 모드 추가, CLI 레이어에서 skill_dir 미존재 명시적 실패.
4. `issue_cli`의 `get-next-seq` 서브커맨드 제거 (사용처 0건 + SKILL.md `TMP1` 절차와 충돌).
5. `mcp-subcommand-rules.md` §7에 "SKILL.md 호출예 필수" 절 + §8 "argparse 실패도 JSON" 절 추가.
6. `test_skill_docs.py`에 회귀 테스트: argparse 실패 JSON 강제, SKILL.md ↔ CLI 서브커맨드 매칭 검증.

**Tech Stack:** Python 3 표준 라이브러리 (`argparse`, `json`, `sys`), pytest, 기존 `scripts/common/emit.py` 재사용.

**Reference issue:** https://github.com/Cassiiopeia/projectops/issues/329

---

## File Structure

**Create:**
- `scripts/common/cli_parser.py` — `JSONArgumentParser` 클래스 + `run_cli()` 헬퍼.
- `scripts/tests/test_cli_parser.py` — `JSONArgumentParser` 단위 테스트.
- `scripts/tests/test_cli_signatures_doc_sync.py` — SKILL.md ↔ CLI 서브커맨드 매칭 회귀 테스트.

**Modify:**
- `scripts/common/paths.py` — `get_next_seq`에 `strict` 인자 추가.
- `scripts/tests/test_skill_docs.py` — argparse 에러 JSON 강제 / get-next-seq 부재 회귀 추가.
- `skills/references/mcp-subcommand-rules.md` — §7 "SKILL.md 호출예 필수", §8 "argparse 실패도 JSON" 절 추가.
- `skills/issue/scripts/issue_cli.py` — `JSONArgumentParser`로 교체, `get-next-seq` 서브커맨드 제거, 누락 서브커맨드 docstring 정비.
- `skills/commit/scripts/commit_cli.py` — `JSONArgumentParser`로 교체.
- `skills/report/scripts/report_cli.py` — `JSONArgumentParser`로 교체.
- `skills/review/scripts/review_cli.py` — `JSONArgumentParser`로 교체.
- `skills/troubleshoot/scripts/troubleshoot_cli.py` — `JSONArgumentParser`로 교체.
- `skills/github/scripts/github_cli.py` — `JSONArgumentParser`로 교체.
- `skills/changelog-deploy/scripts/changelog_cli.py` — `JSONArgumentParser`로 교체.
- `skills/issue/SKILL.md` — 4단계 `TMP1` 절차에 `get-next-seq` 미사용 명시.
- `skills/plan/SKILL.md` — 107행 `get-next-seq` 언급 정정 (issue_cli에서 제거됨).

**Out of scope (별도 작업):** SKILL.md 누락 호출예 전체 보강은 본 plan에서 다루지 않음. 회귀 테스트만 추가하여 향후 SKILL.md 추가 시 매칭 강제. 누락 호출예는 후속 issue로 분리.

---

### Task 1: `JSONArgumentParser` 추가 — 실패 시 stdout JSON

**Files:**
- Create: `scripts/common/cli_parser.py`
- Test: `scripts/tests/test_cli_parser.py`

argparse 기본 동작은 잘못된 인자 받으면 stderr에 `usage: ...` 텍스트를 출력하고 `SystemExit(2)`로 종료한다. agent는 JSON만 파싱하므로 이 출력을 해석할 수 없다. `JSONArgumentParser`는 `error()`/`exit()`를 override해서 모든 실패를 `emit({"ok": False, "code": "bad_args", ...})` 형태 JSON으로 stdout에 출력한다.

- [ ] **Step 1: 실패 케이스 단위 테스트 작성**

```python
# scripts/tests/test_cli_parser.py
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT / "scripts") not in sys.path:
    sys.path.insert(0, str(ROOT / "scripts"))

from common.cli_parser import JSONArgumentParser, run_cli  # noqa: E402


def _build_sample_parser():
    parser = JSONArgumentParser(prog="sample_cli")
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("do-thing")
    p.add_argument("arg1")
    p.set_defaults(func=lambda args: 0)
    return parser


def test_unrecognized_arguments_emits_json(capsys):
    parser = _build_sample_parser()
    rc = run_cli(parser, ["do-thing", "x", "extra1", "extra2"])
    assert rc == 1
    out = json.loads(capsys.readouterr().out.strip())
    assert out["ok"] is False
    assert out["code"] == "bad_args"
    assert "unrecognized" in out["error"].lower() or "extra" in out["error"].lower()
    assert "hint" in out
    assert "do-thing" in out["hint"]


def test_missing_required_argument_emits_json(capsys):
    parser = _build_sample_parser()
    rc = run_cli(parser, ["do-thing"])
    assert rc == 1
    out = json.loads(capsys.readouterr().out.strip())
    assert out["ok"] is False
    assert out["code"] == "bad_args"
    assert "arg1" in out["error"]


def test_unknown_subcommand_emits_json(capsys):
    parser = _build_sample_parser()
    rc = run_cli(parser, ["nonexistent-sub"])
    assert rc == 1
    out = json.loads(capsys.readouterr().out.strip())
    assert out["ok"] is False
    assert out["code"] == "bad_args"


def test_no_subcommand_emits_json(capsys):
    parser = _build_sample_parser()
    rc = run_cli(parser, [])
    assert rc == 1
    out = json.loads(capsys.readouterr().out.strip())
    assert out["ok"] is False
    assert out["code"] == "bad_args"
    assert "available_subcommands" in out
    assert "do-thing" in out["available_subcommands"]


def test_help_flag_does_not_emit_failure_json(capsys):
    parser = _build_sample_parser()
    try:
        run_cli(parser, ["--help"])
    except SystemExit:
        pass
    captured = capsys.readouterr()
    assert "usage" in (captured.out + captured.err).lower()


def test_success_path_unaffected(capsys):
    parser = _build_sample_parser()
    rc = run_cli(parser, ["do-thing", "value"])
    assert rc == 0
```

- [ ] **Step 2: 테스트 실행 — 모두 실패해야 한다**

Run:
```bash
cd "D:/0-suh/project/suh-github-template"
python -m pytest scripts/tests/test_cli_parser.py -v
```
Expected: 모든 테스트 `ImportError: cannot import name 'JSONArgumentParser' from 'common.cli_parser'`로 실패.

- [ ] **Step 3: `cli_parser.py` 구현**

```python
# scripts/common/cli_parser.py
"""JSON-friendly argparse wrapper.

argparse 기본 동작은 인자 오류 시 stderr text + SystemExit(2)를 던진다.
agent는 stdout JSON만 파싱하므로, 이 출력을 self-correct에 활용할 수 없다.

`JSONArgumentParser`는 `error()`/`exit()`를 override하여 실패도
`emit({"ok": False, "code": "bad_args", ...})`로 stdout JSON에 출력한다.

`--help`는 그대로 SystemExit(0)으로 둬서 사람이 직접 실행할 때 도움말이 보인다.
"""
from __future__ import annotations

import argparse
import sys
from typing import Optional, Sequence

from common.emit import emit


class _BadArgsExit(SystemExit):
    """run_cli가 잡아서 JSON으로 변환하는 sentinel."""
    def __init__(self, message: str, parser: "JSONArgumentParser"):
        super().__init__(2)
        self.message = message
        self.parser = parser


class JSONArgumentParser(argparse.ArgumentParser):
    """argparse 실패를 JSON으로 변환하기 위한 sentinel 예외만 던진다."""

    def error(self, message: str) -> None:
        raise _BadArgsExit(message, self)

    def exit(self, status: int = 0, message: Optional[str] = None) -> None:
        if status == 0:
            super().exit(status, message)
            return
        raise _BadArgsExit(message or "exit", self)


def _list_subcommands(parser: argparse.ArgumentParser) -> list:
    subs = []
    for action in parser._actions:
        if isinstance(action, argparse._SubParsersAction):
            subs.extend(sorted(action.choices.keys()))
    return subs


def _make_hint(parser: argparse.ArgumentParser) -> str:
    subs = _list_subcommands(parser)
    if subs:
        return f"{parser.prog} <subcommand> — available: {', '.join(subs)}. 사용법은 `{parser.prog} <subcommand> --help`로 확인."
    return f"{parser.prog} --help"


def run_cli(parser: JSONArgumentParser, argv: Optional[Sequence[str]] = None) -> int:
    """argparse 실행 + JSON 변환 래퍼.

    성공: parsed.func(args) 반환값 (보통 0/1)
    실패: stdout에 JSON emit 후 1 반환.
    --help: argparse 기본 동작 그대로 (SystemExit 0).
    """
    try:
        args = parser.parse_args(argv)
    except _BadArgsExit as e:
        return emit({
            "ok": False,
            "code": "bad_args",
            "error": e.message,
            "hint": _make_hint(e.parser),
            "available_subcommands": _list_subcommands(e.parser),
        })
    if not hasattr(args, "func"):
        return emit({
            "ok": False,
            "code": "bad_args",
            "error": "서브커맨드가 지정되지 않았습니다.",
            "hint": _make_hint(parser),
            "available_subcommands": _list_subcommands(parser),
        })
    return args.func(args)
```

- [ ] **Step 4: 테스트 재실행 — 모두 통과 확인**

Run:
```bash
cd "D:/0-suh/project/suh-github-template"
python -m pytest scripts/tests/test_cli_parser.py -v
```
Expected: 모든 테스트 PASS.

- [ ] **Step 5: 커밋**

```bash
git add scripts/common/cli_parser.py scripts/tests/test_cli_parser.py
git commit -m "$(cat <<'EOF'
_cli.py argparse 실패 JSON 출력용 JSONArgumentParser 추가 : feat : CLI 표준 강화 #329

argparse 기본 stderr text + SystemExit(2) 대신 stdout JSON으로
실패를 emit하는 JSONArgumentParser와 run_cli 헬퍼 추가.
agent가 인자 mismatch 시 즉시 self-correct할 수 있도록 hint와
available_subcommands 필드를 함께 출력한다.

https://github.com/Cassiiopeia/projectops/issues/329

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `paths.get_next_seq`에 strict 모드 추가

**Files:**
- Modify: `scripts/common/paths.py`
- Test: `scripts/tests/test_paths.py` (없으면 신규)

`get_next_seq`는 현재 `skill_dir.exists()`가 False일 때 침묵 `001`을 반환한다. 잘못된 skill_id를 넘겨도 알 수 없다. CLI 레이어가 명시적으로 에러를 띄울 수 있게 `strict` 인자 추가.

- [ ] **Step 1: 단위 테스트 작성**

```python
# scripts/tests/test_paths.py
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT / "scripts") not in sys.path:
    sys.path.insert(0, str(ROOT / "scripts"))

import pytest  # noqa: E402
from common.paths import get_next_seq  # noqa: E402


def test_get_next_seq_nonexistent_dir_lenient_returns_001(tmp_path):
    missing = tmp_path / "does-not-exist"
    assert get_next_seq(missing, "20260602") == "001"


def test_get_next_seq_nonexistent_dir_strict_raises(tmp_path):
    missing = tmp_path / "does-not-exist"
    with pytest.raises(FileNotFoundError):
        get_next_seq(missing, "20260602", strict=True)


def test_get_next_seq_counts_files_for_today(tmp_path):
    skill_dir = tmp_path / "issue"
    skill_dir.mkdir()
    (skill_dir / "20260602_001_x.md").write_text("", encoding="utf-8")
    (skill_dir / "20260602_002_y.md").write_text("", encoding="utf-8")
    (skill_dir / "20260601_001_z.md").write_text("", encoding="utf-8")
    assert get_next_seq(skill_dir, "20260602") == "003"
```

- [ ] **Step 2: 테스트 실행 — strict 테스트가 실패해야 한다**

Run:
```bash
cd "D:/0-suh/project/suh-github-template"
python -m pytest scripts/tests/test_paths.py -v
```
Expected: `test_get_next_seq_nonexistent_dir_strict_raises` FAIL — `strict` 파라미터 미지원.

- [ ] **Step 3: `paths.py` 수정**

`scripts/common/paths.py`의 `get_next_seq` 함수를 다음으로 교체:

```python
def get_next_seq(skill_dir: Path, today: str, strict: bool = False) -> str:
    """
    skill_dir 내에서 오늘 날짜(today)로 시작하는 파일 개수 + 1을 3자리로 반환한다.

    strict=True이면 skill_dir이 존재하지 않을 때 FileNotFoundError를 던진다.
    CLI 레이어가 잘못된 skill_id를 명시적으로 거부할 때 사용한다.
    """
    if not skill_dir.exists():
        if strict:
            raise FileNotFoundError(f"skill_dir does not exist: {skill_dir}")
        return "001"
    count = sum(1 for f in skill_dir.iterdir() if f.name.startswith(today))
    return f"{count + 1:03d}"
```

- [ ] **Step 4: 테스트 재실행 — 통과 확인**

Run:
```bash
cd "D:/0-suh/project/suh-github-template"
python -m pytest scripts/tests/test_paths.py -v
```
Expected: 모든 테스트 PASS.

- [ ] **Step 5: 커밋**

```bash
git add scripts/common/paths.py scripts/tests/test_paths.py
git commit -m "$(cat <<'EOF'
get_next_seq에 strict 모드 추가, skill_dir 미존재 시 명시적 실패 : feat : CLI 표준 강화 #329

CLI 레이어가 잘못된 skill_id를 침묵 처리하는 대신 FileNotFoundError로
명시적 실패를 일으킬 수 있게 strict 인자 추가. 기본값은 기존 동작 유지.

https://github.com/Cassiiopeia/projectops/issues/329

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: `issue_cli.py`에서 `get-next-seq` 제거 + `JSONArgumentParser` 적용

**Files:**
- Modify: `skills/issue/scripts/issue_cli.py`

`get-next-seq`는 사용처 0건이고 `issue/SKILL.md` 4단계 절차 (`TMP1, TMP2` 직접 사용)와 충돌한다. CLI 표면에서 제거하면 agent가 잘못 호출할 표면 자체가 사라진다. 함수 `paths.get_next_seq`는 다른 CLI(report/review/troubleshoot)가 내부적으로 쓰므로 유지.

- [ ] **Step 1: 회귀 테스트 작성 — `get-next-seq` 부재 + bad_args JSON 출력**

`scripts/tests/test_skill_docs.py`에 함수 추가:

```python
def test_issue_cli_does_not_expose_get_next_seq():
    """get-next-seq는 issue_cli.py CLI 표면에서 제거되어야 한다 (이슈 #329).

    SKILL.md 4단계는 TMP1 직접 사용 절차이므로 CLI 노출은 agent 오추론을 유도한다.
    """
    cli_path = ROOT / "skills" / "issue" / "scripts" / "issue_cli.py"
    text = cli_path.read_text(encoding="utf-8")
    assert "add_parser(\"get-next-seq\"" not in text, \
        "issue_cli.py에 get-next-seq 서브커맨드가 남아있다 (이슈 #329)"
    assert "\"get-next-seq\"" not in text or "removed" in text.lower(), \
        "get-next-seq 참조가 코드에 남아있다"


def test_issue_cli_bad_args_emits_json(tmp_path):
    """issue_cli.py가 잘못된 인자를 받아도 stdout에 JSON을 emit해야 한다."""
    import subprocess
    cli_path = ROOT / "skills" / "issue" / "scripts" / "issue_cli.py"
    proc = subprocess.run(
        [sys.executable, str(cli_path), "nonexistent-sub"],
        capture_output=True, text=True, encoding="utf-8",
    )
    import json
    assert proc.stdout.strip(), f"stdout empty, stderr={proc.stderr}"
    out = json.loads(proc.stdout.strip().splitlines()[-1])
    assert out["ok"] is False
    assert out["code"] == "bad_args"
```

상단에 `import sys` 추가.

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run:
```bash
cd "D:/0-suh/project/suh-github-template"
python -m pytest scripts/tests/test_skill_docs.py::test_issue_cli_does_not_expose_get_next_seq scripts/tests/test_skill_docs.py::test_issue_cli_bad_args_emits_json -v
```
Expected: 두 테스트 모두 FAIL — `get-next-seq` 아직 존재 + argparse stderr 출력.

- [ ] **Step 3: `issue_cli.py` 수정 — `get-next-seq` 제거 + `JSONArgumentParser` 적용**

다음 변경 사항을 적용:

1. 모듈 docstring 5–6행 수정:
   ```python
   서브커맨드: create-issue, search-issues, normalize-title,
              create-branch-name, get-commit-template, update-issue
   ```

2. import 블록에 추가:
   ```python
   from common.cli_parser import JSONArgumentParser, run_cli  # noqa: E402
   ```

3. `cmd_get_next_seq` 함수 전체(72–84행) 삭제.

4. `build_parser` 시그니처와 본문에서 `get-next-seq` 부분(133–135행) 삭제, `argparse.ArgumentParser` → `JSONArgumentParser`:
   ```python
   def build_parser() -> JSONArgumentParser:
       parser = JSONArgumentParser(prog="issue_cli", description="issue skill CLI")
       sub = parser.add_subparsers(dest="command", required=True)

       p_ci = sub.add_parser("create-issue", help="이슈 생성")
       # ... (기존 코드 유지)

       p_si = sub.add_parser("search-issues", help="중복 검사용 이슈 검색")
       # ... (기존 코드 유지)

       p_ui = sub.add_parser("update-issue", help="이슈 수정 (담당자 지정 등)")
       # ... (기존 코드 유지)

       # get-next-seq 제거됨 (이슈 #329) — paths.get_next_seq는 다른 CLI가 내부 사용

       p_nt = sub.add_parser("normalize-title", help="제목 정규화")
       # ... (기존 코드 유지)

       p_cbn = sub.add_parser("create-branch-name", help="브랜치명 생성")
       # ... (기존 코드 유지)

       p_gct = sub.add_parser("get-commit-template", help="커밋 메시지 템플릿")
       # ... (기존 코드 유지)

       return parser
   ```

5. `main()` 함수를 `run_cli`로 단순화:
   ```python
   def main() -> int:
       return run_cli(build_parser())
   ```

6. `from datetime import date` import는 더 이상 필요 없으면 제거 (argparse 사용 중인지 확인 — `paths` import도 제거 가능).

- [ ] **Step 4: 테스트 재실행 — 통과 확인**

Run:
```bash
cd "D:/0-suh/project/suh-github-template"
python -m pytest scripts/tests/test_skill_docs.py::test_issue_cli_does_not_expose_get_next_seq scripts/tests/test_skill_docs.py::test_issue_cli_bad_args_emits_json -v
```
Expected: PASS.

기존 issue_cli 동작 회귀 확인 — 정상 호출이 깨지지 않았는지:

```bash
cd "D:/0-suh/project/suh-github-template/skills/issue/scripts"
PYTHONIOENCODING=utf-8 python issue_cli.py --help
```
Expected: 도움말 정상 출력. `get-next-seq` 항목 사라짐.

- [ ] **Step 5: 커밋**

```bash
git add skills/issue/scripts/issue_cli.py scripts/tests/test_skill_docs.py
git commit -m "$(cat <<'EOF'
issue_cli get-next-seq 제거 + JSONArgumentParser 적용 : feat : CLI 표준 강화 #329

SKILL.md 4단계는 TMP1 임시번호 직접 사용 절차인데 CLI에 get-next-seq가
노출되어 있어 agent가 오추론 호출 → unrecognized arguments 실패를
재현하던 케이스. CLI 표면에서 제거하여 오추론 표면 자체를 차단.
JSONArgumentParser로 향후 argparse 실패도 JSON으로 출력하게 통일.

https://github.com/Cassiiopeia/projectops/issues/329

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: `commit_cli.py`에 `JSONArgumentParser` 적용

**Files:**
- Modify: `skills/commit/scripts/commit_cli.py`

- [ ] **Step 1: 회귀 테스트 추가**

`scripts/tests/test_skill_docs.py`에 함수 추가:

```python
def test_commit_cli_bad_args_emits_json():
    import subprocess, json
    cli_path = ROOT / "skills" / "commit" / "scripts" / "commit_cli.py"
    proc = subprocess.run(
        [sys.executable, str(cli_path), "nonexistent-sub"],
        capture_output=True, text=True, encoding="utf-8",
    )
    assert proc.stdout.strip(), f"stdout empty, stderr={proc.stderr}"
    out = json.loads(proc.stdout.strip().splitlines()[-1])
    assert out["ok"] is False
    assert out["code"] == "bad_args"
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run:
```bash
python -m pytest scripts/tests/test_skill_docs.py::test_commit_cli_bad_args_emits_json -v
```
Expected: FAIL.

- [ ] **Step 3: `commit_cli.py` 수정**

1. import 추가:
   ```python
   from common.cli_parser import JSONArgumentParser, run_cli  # noqa: E402
   ```

2. `build_parser`의 `argparse.ArgumentParser(...)` → `JSONArgumentParser(...)` 교체.
3. `build_parser` 반환 타입 어노테이션 `JSONArgumentParser`로 교체.
4. `main()`을 다음으로 교체:
   ```python
   def main() -> int:
       return run_cli(build_parser())
   ```

기존 서브커맨드는 모두 유지.

- [ ] **Step 4: 테스트 재실행 + 회귀 확인**

Run:
```bash
python -m pytest scripts/tests/test_skill_docs.py::test_commit_cli_bad_args_emits_json -v
cd "D:/0-suh/project/suh-github-template/skills/commit/scripts"
PYTHONIOENCODING=utf-8 python commit_cli.py --help
```
Expected: 테스트 PASS, `--help` 정상 출력.

- [ ] **Step 5: 커밋**

```bash
git add skills/commit/scripts/commit_cli.py scripts/tests/test_skill_docs.py
git commit -m "$(cat <<'EOF'
commit_cli JSONArgumentParser 적용 : feat : CLI 표준 강화 #329

argparse 실패도 stdout JSON으로 출력하도록 변경.

https://github.com/Cassiiopeia/projectops/issues/329

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `report_cli.py`에 `JSONArgumentParser` 적용

**Files:**
- Modify: `skills/report/scripts/report_cli.py`

- [ ] **Step 1: 회귀 테스트 추가**

```python
def test_report_cli_bad_args_emits_json():
    import subprocess, json
    cli_path = ROOT / "skills" / "report" / "scripts" / "report_cli.py"
    proc = subprocess.run(
        [sys.executable, str(cli_path), "nonexistent-sub"],
        capture_output=True, text=True, encoding="utf-8",
    )
    assert proc.stdout.strip(), f"stdout empty, stderr={proc.stderr}"
    out = json.loads(proc.stdout.strip().splitlines()[-1])
    assert out["ok"] is False
    assert out["code"] == "bad_args"
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run:
```bash
python -m pytest scripts/tests/test_skill_docs.py::test_report_cli_bad_args_emits_json -v
```
Expected: FAIL.

- [ ] **Step 3: `report_cli.py` 수정**

1. import 추가:
   ```python
   from common.cli_parser import JSONArgumentParser, run_cli  # noqa: E402
   ```

2. `build_parser`의 `argparse.ArgumentParser(...)` → `JSONArgumentParser(...)`.
3. 반환 타입 어노테이션 `JSONArgumentParser`로 교체.
4. `main()`을 다음으로 교체:
   ```python
   def main() -> int:
       return run_cli(build_parser())
   ```

- [ ] **Step 4: 테스트 재실행 + `--help` 회귀 확인**

Run:
```bash
python -m pytest scripts/tests/test_skill_docs.py::test_report_cli_bad_args_emits_json -v
cd "D:/0-suh/project/suh-github-template/skills/report/scripts"
PYTHONIOENCODING=utf-8 python report_cli.py --help
```
Expected: PASS, `--help` 정상.

- [ ] **Step 5: 커밋**

```bash
git add skills/report/scripts/report_cli.py scripts/tests/test_skill_docs.py
git commit -m "$(cat <<'EOF'
report_cli JSONArgumentParser 적용 : feat : CLI 표준 강화 #329

argparse 실패도 stdout JSON으로 출력하도록 변경.

https://github.com/Cassiiopeia/projectops/issues/329

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: `review_cli.py`에 `JSONArgumentParser` 적용

**Files:**
- Modify: `skills/review/scripts/review_cli.py`

- [ ] **Step 1: 회귀 테스트 추가**

```python
def test_review_cli_bad_args_emits_json():
    import subprocess, json
    cli_path = ROOT / "skills" / "review" / "scripts" / "review_cli.py"
    proc = subprocess.run(
        [sys.executable, str(cli_path), "nonexistent-sub"],
        capture_output=True, text=True, encoding="utf-8",
    )
    assert proc.stdout.strip(), f"stdout empty, stderr={proc.stderr}"
    out = json.loads(proc.stdout.strip().splitlines()[-1])
    assert out["ok"] is False
    assert out["code"] == "bad_args"
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run:
```bash
python -m pytest scripts/tests/test_skill_docs.py::test_review_cli_bad_args_emits_json -v
```
Expected: FAIL.

- [ ] **Step 3: `review_cli.py` 수정**

`commit_cli` Task 4 Step 3과 동일 패턴 적용 — `JSONArgumentParser` import, `build_parser` 클래스 교체, `main()` 단순화.

- [ ] **Step 4: 테스트 재실행 + `--help` 회귀 확인**

Run:
```bash
python -m pytest scripts/tests/test_skill_docs.py::test_review_cli_bad_args_emits_json -v
cd "D:/0-suh/project/suh-github-template/skills/review/scripts"
PYTHONIOENCODING=utf-8 python review_cli.py --help
```
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add skills/review/scripts/review_cli.py scripts/tests/test_skill_docs.py
git commit -m "$(cat <<'EOF'
review_cli JSONArgumentParser 적용 : feat : CLI 표준 강화 #329

https://github.com/Cassiiopeia/projectops/issues/329

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: `troubleshoot_cli.py`에 `JSONArgumentParser` 적용

**Files:**
- Modify: `skills/troubleshoot/scripts/troubleshoot_cli.py`

- [ ] **Step 1: 회귀 테스트 추가**

```python
def test_troubleshoot_cli_bad_args_emits_json():
    import subprocess, json
    cli_path = ROOT / "skills" / "troubleshoot" / "scripts" / "troubleshoot_cli.py"
    proc = subprocess.run(
        [sys.executable, str(cli_path), "nonexistent-sub"],
        capture_output=True, text=True, encoding="utf-8",
    )
    assert proc.stdout.strip(), f"stdout empty, stderr={proc.stderr}"
    out = json.loads(proc.stdout.strip().splitlines()[-1])
    assert out["ok"] is False
    assert out["code"] == "bad_args"
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run:
```bash
python -m pytest scripts/tests/test_skill_docs.py::test_troubleshoot_cli_bad_args_emits_json -v
```
Expected: FAIL.

- [ ] **Step 3: `troubleshoot_cli.py` 수정**

Task 4 Step 3과 동일 패턴 적용.

- [ ] **Step 4: 테스트 재실행 + `--help` 회귀 확인**

Run:
```bash
python -m pytest scripts/tests/test_skill_docs.py::test_troubleshoot_cli_bad_args_emits_json -v
cd "D:/0-suh/project/suh-github-template/skills/troubleshoot/scripts"
PYTHONIOENCODING=utf-8 python troubleshoot_cli.py --help
```
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add skills/troubleshoot/scripts/troubleshoot_cli.py scripts/tests/test_skill_docs.py
git commit -m "$(cat <<'EOF'
troubleshoot_cli JSONArgumentParser 적용 : feat : CLI 표준 강화 #329

https://github.com/Cassiiopeia/projectops/issues/329

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: `github_cli.py`에 `JSONArgumentParser` 적용

**Files:**
- Modify: `skills/github/scripts/github_cli.py`

- [ ] **Step 1: 회귀 테스트 추가**

```python
def test_github_cli_bad_args_emits_json():
    import subprocess, json
    cli_path = ROOT / "skills" / "github" / "scripts" / "github_cli.py"
    proc = subprocess.run(
        [sys.executable, str(cli_path), "nonexistent-sub"],
        capture_output=True, text=True, encoding="utf-8",
    )
    assert proc.stdout.strip(), f"stdout empty, stderr={proc.stderr}"
    out = json.loads(proc.stdout.strip().splitlines()[-1])
    assert out["ok"] is False
    assert out["code"] == "bad_args"
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run:
```bash
python -m pytest scripts/tests/test_skill_docs.py::test_github_cli_bad_args_emits_json -v
```
Expected: FAIL.

- [ ] **Step 3: `github_cli.py` 수정**

Task 4 Step 3과 동일 패턴 적용.

- [ ] **Step 4: 테스트 재실행 + `--help` 회귀 확인**

Run:
```bash
python -m pytest scripts/tests/test_skill_docs.py::test_github_cli_bad_args_emits_json -v
cd "D:/0-suh/project/suh-github-template/skills/github/scripts"
PYTHONIOENCODING=utf-8 python github_cli.py --help
```
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add skills/github/scripts/github_cli.py scripts/tests/test_skill_docs.py
git commit -m "$(cat <<'EOF'
github_cli JSONArgumentParser 적용 : feat : CLI 표준 강화 #329

https://github.com/Cassiiopeia/projectops/issues/329

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: `changelog_cli.py`에 `JSONArgumentParser` 적용

**Files:**
- Modify: `skills/changelog-deploy/scripts/changelog_cli.py`

- [ ] **Step 1: 회귀 테스트 추가**

```python
def test_changelog_cli_bad_args_emits_json():
    import subprocess, json
    cli_path = ROOT / "skills" / "changelog-deploy" / "scripts" / "changelog_cli.py"
    proc = subprocess.run(
        [sys.executable, str(cli_path), "nonexistent-sub"],
        capture_output=True, text=True, encoding="utf-8",
    )
    assert proc.stdout.strip(), f"stdout empty, stderr={proc.stderr}"
    out = json.loads(proc.stdout.strip().splitlines()[-1])
    assert out["ok"] is False
    assert out["code"] == "bad_args"
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run:
```bash
python -m pytest scripts/tests/test_skill_docs.py::test_changelog_cli_bad_args_emits_json -v
```
Expected: FAIL.

- [ ] **Step 3: `changelog_cli.py` 수정**

Task 4 Step 3과 동일 패턴 적용.

- [ ] **Step 4: 테스트 재실행 + `--help` 회귀 확인**

Run:
```bash
python -m pytest scripts/tests/test_skill_docs.py::test_changelog_cli_bad_args_emits_json -v
cd "D:/0-suh/project/suh-github-template/skills/changelog-deploy/scripts"
PYTHONIOENCODING=utf-8 python changelog_cli.py --help
```
Expected: PASS.

- [ ] **Step 5: 커밋**

```bash
git add skills/changelog-deploy/scripts/changelog_cli.py scripts/tests/test_skill_docs.py
git commit -m "$(cat <<'EOF'
changelog_cli JSONArgumentParser 적용 : feat : CLI 표준 강화 #329

https://github.com/Cassiiopeia/projectops/issues/329

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: SKILL.md ↔ CLI 서브커맨드 매칭 회귀 테스트

**Files:**
- Create: `scripts/tests/test_cli_signatures_doc_sync.py`

각 `_cli.py`에 정의된 서브커맨드가 해당 SKILL.md(또는 references 문서)에 호출 예시로 등장하는지 점검한다. 누락 시 fail. 향후 신규 서브커맨드 추가 시 SKILL.md 문서화 누락을 자동 차단한다.

본 plan에서는 **현재 누락 케이스를 expected_missing 셋으로 화이트리스트** 처리하여 회귀 테스트만 도입한다. 누락 케이스는 후속 작업으로 SKILL.md 호출예 추가 시 화이트리스트에서 제거한다.

- [ ] **Step 1: 회귀 테스트 작성**

```python
# scripts/tests/test_cli_signatures_doc_sync.py
"""각 _cli.py 서브커맨드가 SKILL.md에 호출 예시로 등장하는지 점검 (이슈 #329)."""
from __future__ import annotations

import ast
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


CLI_TO_SKILL = {
    "issue/scripts/issue_cli.py": ["issue/SKILL.md"],
    "commit/scripts/commit_cli.py": ["commit/SKILL.md"],
    "report/scripts/report_cli.py": ["report/SKILL.md"],
    "review/scripts/review_cli.py": ["review/SKILL.md"],
    "troubleshoot/scripts/troubleshoot_cli.py": ["troubleshoot/SKILL.md"],
    "github/scripts/github_cli.py": ["github/SKILL.md"],
    "changelog-deploy/scripts/changelog_cli.py": ["changelog-deploy/SKILL.md"],
}


# 현재 SKILL.md에 호출예가 없는 서브커맨드 — 후속 작업으로 보강 시 셋에서 제거한다.
EXPECTED_MISSING = {
    # ("issue/scripts/issue_cli.py", "normalize-title"),  # 예: 보강 전까지 화이트리스트
}


def _extract_subcommands(cli_path: Path) -> list:
    """add_parser("subname", ...) 호출에서 첫 인자(서브커맨드명)를 모두 수집."""
    tree = ast.parse(cli_path.read_text(encoding="utf-8"))
    names = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        func = node.func
        if isinstance(func, ast.Attribute) and func.attr == "add_parser" and node.args:
            first = node.args[0]
            if isinstance(first, ast.Constant) and isinstance(first.value, str):
                names.append(first.value)
    return names


def test_each_cli_subcommand_is_documented():
    """각 _cli.py 서브커맨드는 해당 SKILL.md에 정확한 이름으로 등장해야 한다."""
    failures = []
    for cli_rel, skill_rels in CLI_TO_SKILL.items():
        cli_path = ROOT / "skills" / cli_rel
        if not cli_path.exists():
            continue
        names = _extract_subcommands(cli_path)
        docs_text = "\n".join(
            (ROOT / "skills" / s).read_text(encoding="utf-8")
            for s in skill_rels if (ROOT / "skills" / s).exists()
        )
        for name in names:
            if (cli_rel, name) in EXPECTED_MISSING:
                continue
            # 정확한 이름 매칭 (코드 백틱 또는 단어 경계)
            if re.search(rf"\b{re.escape(name)}\b", docs_text):
                continue
            failures.append(f"{cli_rel}: {name!r} 호출예가 SKILL.md에 없음")
    if failures:
        failures.append("\nSKILL.md에 호출 예시 추가하거나 EXPECTED_MISSING 셋에 임시 등록 후 #329 후속 이슈로 보강.")
    assert failures == [], "\n".join(failures)
```

- [ ] **Step 2: 테스트 실행 — 누락 케이스가 모두 드러난다**

Run:
```bash
python -m pytest scripts/tests/test_cli_signatures_doc_sync.py -v
```
Expected: FAIL — 어떤 서브커맨드 호출예가 누락됐는지 모두 출력. 출력 내용을 캡쳐.

- [ ] **Step 3: 누락된 서브커맨드를 `EXPECTED_MISSING` 화이트리스트에 등록**

Step 2 출력에서 누락된 모든 `(cli_rel, name)` 쌍을 `EXPECTED_MISSING` 셋에 추가:

```python
EXPECTED_MISSING = {
    ("issue/scripts/issue_cli.py", "normalize-title"),
    ("issue/scripts/issue_cli.py", "create-branch-name"),
    ("issue/scripts/issue_cli.py", "get-commit-template"),
    # ... Step 2 출력에서 본 모든 항목 등록
}
```

각 항목 위에 `# TODO #329 후속: SKILL.md에 호출예 추가 후 제거` 주석.

- [ ] **Step 4: 테스트 재실행 — 통과 확인**

Run:
```bash
python -m pytest scripts/tests/test_cli_signatures_doc_sync.py -v
```
Expected: PASS (모든 케이스가 화이트리스트로 처리됨).

이렇게 하면 **신규** 서브커맨드를 추가할 때 SKILL.md에 호출예가 없으면 자동으로 fail — 회귀 방어 효과만 확보.

- [ ] **Step 5: 커밋**

```bash
git add scripts/tests/test_cli_signatures_doc_sync.py
git commit -m "$(cat <<'EOF'
SKILL.md ↔ CLI 서브커맨드 매칭 회귀 테스트 추가 : test : CLI 표준 강화 #329

각 _cli.py 서브커맨드가 SKILL.md에 호출 예시로 등장하는지 점검.
신규 서브커맨드를 추가할 때 SKILL.md 문서화 누락을 자동 차단한다.
현재 누락된 케이스는 EXPECTED_MISSING 화이트리스트로 보호하고,
후속 이슈로 SKILL.md 호출예 추가 시 셋에서 제거한다.

https://github.com/Cassiiopeia/projectops/issues/329

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: SKILL.md / references 문서 정정

**Files:**
- Modify: `skills/issue/SKILL.md`
- Modify: `skills/plan/SKILL.md`
- Modify: `skills/references/mcp-subcommand-rules.md`

- [ ] **Step 1: `issue/SKILL.md` 4단계 정정**

기존 4단계의 임시 번호 사용 부분을 다음 한 줄로 강화 (190행 근처, `이슈 번호는 GitHub 등록 전이므로 임시로 \`TMP1\`, \`TMP2\`...` 행에 이어서):

기존:
```
- 이슈 번호는 GitHub 등록 전이므로 임시로 `TMP1`, `TMP2`… 를 사용한다 (GitHub 등록 후 실제 번호로 rename)
```

추가:
```
- 이슈 번호는 GitHub 등록 전이므로 임시로 `TMP1`, `TMP2`… 를 사용한다 (GitHub 등록 후 실제 번호로 rename)
- **`issue_cli.py`의 `get-next-seq` 서브커맨드를 호출하지 않는다.** 이슈 #329로 CLI에서 제거됨 — 임시 번호는 agent가 직접 생성한다.
```

- [ ] **Step 2: `plan/SKILL.md` 107행 정정**

기존:
```
- 3-layer 아키텍처: skill별 `_cli.py`에서 `get-output-path` · `get-issue-number` · `get-next-seq` · `normalize-title` 호출. `issue_cli.py` 가 `get-next-seq`·`normalize-title` 보유, `commit_cli.py` 가 `get-issue-number`·`normalize-title` 보유. 참조: `references/common-rules.md` §"skill별 py 분산 호출"
```

다음으로 교체:
```
- 3-layer 아키텍처: skill별 `_cli.py`에서 `get-output-path` · `get-issue-number` · `normalize-title` 호출. `commit_cli.py`가 `get-issue-number`·`normalize-title` 보유, `issue_cli.py`가 `normalize-title`·`create-branch-name`·`get-commit-template` 보유. 참조: `references/common-rules.md` §"skill별 py 분산 호출". 다음 시퀀스 번호 계산은 `report_cli`/`review_cli`/`troubleshoot_cli`의 `get-output-path`가 내부에서 처리하므로 agent가 별도 호출하지 않는다.
```

- [ ] **Step 3: `mcp-subcommand-rules.md`에 §7 강화 + §8 신규 추가**

`§7 SKILL.md 작성 규칙` 끝에 다음 추가:

```markdown
- **CLI에 정의된 모든 서브커맨드는 해당 skill SKILL.md(또는 명시적으로 참조하는 다른 SKILL.md)에 호출 예시가 있어야 한다.** 호출 예시 없는 서브커맨드는 agent가 시그니처를 추측해 호출하다 실패한다 (이슈 #329). 호출예를 추가할 수 없다면 CLI 표면에서 제거하거나 내부 함수로 옮긴다.
- 호출 예시에는 다음 3가지를 반드시 포함한다: ①정확한 인자 순서를 포함한 `bash` 실행 라인, ②기대 JSON 출력 한 줄, ③agent가 결과를 어떻게 사용해야 하는지 한 줄 설명.
- `scripts/tests/test_cli_signatures_doc_sync.py`가 이 매칭을 강제한다. 신규 서브커맨드 추가 시 테스트가 통과하도록 SKILL.md를 함께 갱신해야 한다.
```

`§8 argparse 실패도 JSON으로` 절을 §7 다음에 신규 추가:

```markdown
---

## 8. argparse 실패도 JSON으로 — `JSONArgumentParser` 필수

argparse 기본 동작은 인자 오류 시 stderr text + `SystemExit(2)`로 종료한다. agent는 stdout JSON만 파싱하므로 이 출력을 self-correct에 활용하지 못한다.

모든 `_cli.py`는 `scripts/common/cli_parser.py`의 `JSONArgumentParser` + `run_cli`를 사용한다:

```python
from common.cli_parser import JSONArgumentParser, run_cli

def build_parser() -> JSONArgumentParser:
    parser = JSONArgumentParser(prog="scope_cli", description="...")
    sub = parser.add_subparsers(dest="command", required=True)
    # ... add_parser들 ...
    return parser

def main() -> int:
    return run_cli(build_parser())
```

`run_cli`는 argparse 에러를 다음 형태의 JSON으로 변환해 stdout에 출력한다:

```json
{
  "ok": false,
  "code": "bad_args",
  "error": "unrecognized arguments: extra1 extra2",
  "hint": "scope_cli <subcommand> — available: ...",
  "available_subcommands": ["...", "..."],
  "summary": null,
  "next": null
}
```

agent는 `code == "bad_args"`를 보면 `available_subcommands`로 정확한 서브커맨드를 선택해 재호출한다.

`--help`/`-h`는 argparse 기본 동작 그대로 유지해 사람이 직접 실행할 때 도움말이 보이게 한다.
```

- [ ] **Step 4: `test_skill_docs.py`에 references 정합성 회귀 추가**

`scripts/tests/test_skill_docs.py`에 함수 추가:

```python
def test_mcp_rules_document_json_argparse_standard():
    """mcp-subcommand-rules.md에 JSONArgumentParser 사용 규칙이 명시되어야 한다 (이슈 #329)."""
    path = ROOT / "skills" / "references" / "mcp-subcommand-rules.md"
    text = path.read_text(encoding="utf-8")
    assert "JSONArgumentParser" in text
    assert "bad_args" in text
    assert "available_subcommands" in text


def test_plan_skill_does_not_reference_removed_get_next_seq_subcommand():
    """plan/SKILL.md는 issue_cli의 get-next-seq를 참조하면 안 된다 (이슈 #329)."""
    path = ROOT / "skills" / "plan" / "SKILL.md"
    text = path.read_text(encoding="utf-8")
    assert "issue_cli.py 가 `get-next-seq`" not in text
    assert "`get-next-seq`·`normalize-title` 보유" not in text
```

- [ ] **Step 5: 테스트 실행 + 회귀 풀스위트 확인**

Run:
```bash
cd "D:/0-suh/project/suh-github-template"
python -m pytest scripts/tests/ -v
```
Expected: 전부 PASS.

- [ ] **Step 6: 커밋**

```bash
git add skills/issue/SKILL.md skills/plan/SKILL.md skills/references/mcp-subcommand-rules.md scripts/tests/test_skill_docs.py
git commit -m "$(cat <<'EOF'
SKILL.md/references 문서 정정 + JSONArgumentParser 표준 명시 : docs : CLI 표준 강화 #329

- issue/SKILL.md 4단계: get-next-seq 호출 금지 명시
- plan/SKILL.md: issue_cli의 get-next-seq 참조 제거
- mcp-subcommand-rules.md §7: SKILL.md 호출예 필수 규칙 추가
- mcp-subcommand-rules.md §8: JSONArgumentParser 사용 규칙 신규
- test_skill_docs.py: 정합성 회귀 테스트 추가

https://github.com/Cassiiopeia/projectops/issues/329

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: 통합 검증 — 실제 발생했던 케이스 재현 + 수정 확인

**Files:**
- 없음 (검증만)

이슈 #329 본문에 적힌 원래 실패 케이스(`PROJECT_ROOT 20260602` 2개 인자)가 이제 어떻게 처리되는지 확인.

- [ ] **Step 1: 원래 실패 케이스 재현**

Run:
```bash
cd "D:/0-suh/project/suh-github-template/skills/issue/scripts"
PYTHONIOENCODING=utf-8 python issue_cli.py get-next-seq "/some/project/root" "20260602"
```

Expected stdout:
```json
{"ok": false, "code": "bad_args", "error": "...", "hint": "issue_cli <subcommand> — available: create-issue, create-branch-name, get-commit-template, normalize-title, search-issues, update-issue. ...", "available_subcommands": ["create-issue", "create-branch-name", "get-commit-template", "normalize-title", "search-issues", "update-issue"], "summary": null, "next": null}
```

핵심 확인 포인트:
- 종료 코드 1
- stdout이 JSON 한 줄
- `code == "bad_args"`
- `available_subcommands`에 `get-next-seq`가 **없다** (제거됨)
- agent가 보고 즉시 "아 `get-next-seq` 없네 → 다른 방식으로 처리"로 판단 가능

- [ ] **Step 2: 정상 호출 회귀 확인**

Run:
```bash
cd "D:/0-suh/project/suh-github-template/skills/issue/scripts"
PYTHONIOENCODING=utf-8 python issue_cli.py normalize-title "테스트 제목 정규화"
```

Expected stdout:
```json
{"normalized": "...", "summary": "...", "ok": true, "code": "ok", "next": null}
```

기존 호출이 깨지지 않았음을 확인.

- [ ] **Step 3: 전체 테스트 스위트 통과 확인**

Run:
```bash
cd "D:/0-suh/project/suh-github-template"
python -m pytest scripts/tests/ -v
```
Expected: 전부 PASS.

- [ ] **Step 4: 이슈 #329 종료 댓글 작성용 본문 저장**

`docs/suh-template/issue/20260602_329_skill_cli_서브커맨드_시그니처_JSON_문서화_표준_강화_completion.md`에 다음 본문 저장:

```markdown
## 완료 요약 (이슈 #329)

### 적용 사항
- `scripts/common/cli_parser.py` 신규 — `JSONArgumentParser` + `run_cli` 헬퍼.
- 7개 `_cli.py` (issue/commit/report/review/troubleshoot/github/changelog) 전부 `JSONArgumentParser` 적용.
- `issue_cli.py`의 `get-next-seq` 서브커맨드 제거 (사용처 0건 + SKILL.md `TMP1` 절차와 충돌).
- `paths.get_next_seq`에 `strict` 모드 추가.
- `mcp-subcommand-rules.md`에 §7 "SKILL.md 호출예 필수" + §8 "JSONArgumentParser 표준" 추가.
- 회귀 테스트 — argparse 실패 JSON 강제, SKILL.md ↔ CLI 매칭, `get-next-seq` 부재.

### 재현 케이스 검증
원래 실패: `issue_cli.py get-next-seq <root> <date>` → argparse stderr text + Exit 2
수정 후: 동일 호출 → stdout JSON `{"ok": false, "code": "bad_args", "available_subcommands": [...]}`
agent가 응답을 보고 즉시 self-correct 가능.

### 후속 작업 (별도 이슈 권장)
- SKILL.md ↔ CLI 매칭 화이트리스트(`EXPECTED_MISSING`)에 남은 항목 보강.
  특히 `issue`의 `normalize-title`, `create-branch-name`, `get-commit-template` 호출예 추가.
```

- [ ] **Step 5: 커밋**

```bash
git add docs/suh-template/issue/20260602_329_skill_cli_서브커맨드_시그니처_JSON_문서화_표준_강화_completion.md
git commit -m "$(cat <<'EOF'
이슈 #329 완료 보고서 추가 : docs : CLI 표준 강화 완료

https://github.com/Cassiiopeia/projectops/issues/329

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review 결과

**1. 스펙 커버리지 확인**:
- ✅ argparse 에러 JSON 변환 — Task 1, 4–9
- ✅ `safe_parse` 공통 헬퍼 추가 — Task 1 (`run_cli`로 구현)
- ✅ `get-next-seq` 정리 — Task 3 (제거)
- ✅ `paths.get_next_seq` 침묵 실패 제거 — Task 2 (`strict` 추가)
- ✅ SKILL.md ↔ CLI 노출 표준 — Task 10 (회귀 테스트로 강제)
- ✅ `mcp-subcommand-rules.md` "호출예 필수" 절 추가 — Task 11

**2. Placeholder 스캔**: 모든 step에 실제 코드/명령/파일 경로 포함. 없음.

**3. 타입 일관성**: `JSONArgumentParser`, `run_cli`, `build_parser()` 시그니처가 Task 1–9에서 동일.

**4. 누락 호출예 전체 보강 범위 결정**: 본 plan은 회귀 테스트만 도입(Task 10). 누락 호출예 보강은 별도 이슈 권장 — 7개 CLI × 평균 3–5개 서브커맨드 × SKILL.md 호출예 작성은 본 plan에 묶기엔 범위 과대.

---

## Execution Handoff

Plan 저장 완료: `docs/superpowers/plans/2026-06-02-cli-subcommand-standards.md`

실행 방식:

**1. Subagent-Driven (recommended)** — 각 Task별로 fresh subagent에 위임, Task 간 사용자 확인 받음, 분리된 컨텍스트로 정확도 높음, 시간 더 걸림.

**2. Inline Execution** — 본 세션에서 순차 실행, executing-plans skill로 checkpoint마다 사용자 확인, 컨텍스트 누적됨.

어떤 방식?
