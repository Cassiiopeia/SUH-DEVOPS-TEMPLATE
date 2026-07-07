# GitHub 이슈 생성 검증 및 본문 사후 수정 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `issue_cli.py` 및 `github_cli.py`에서 이슈 본문 파일 미존재 시 조용히 넘어가던 현상을 엄격한 에러(`body_file_not_found`)로 차단하고, `update-issue` 명령에 `--body-file` 파라미터를 추가하여 본문 사후 수정을 완벽히 지원합니다.

**Architecture:** CLI 실행 파서(`argparse`) 수준에서 `--body-file` 옵션을 명세하고, 핸들러 레벨에서 파일 검증을 수행하여 에러 응답 규격 JSON(`{"ok": false, "code": "body_file_not_found", "error": "..."}`)을 일관되게 출력합니다.

**Tech Stack:** Python 3 (urllib, argparse, unittest/pytest)

## Global Constraints
- `issue_cli.py` 및 `github_cli.py` 내의 모든 핸들러는 성공/실패 여부를 불문하고 무조건 JSON을 표준 출력(stdout)으로 `emit`해야 합니다.
- 오류 발생 시에는 반드시 `"ok": false` 및 지정된 snake_case 에러 `"code"`를 담아 AI가 자동 대응하기 쉽게 구성해야 합니다.
- 파일 내용 수정 시 타깃 범위가 아닌 코드를 임의로 제거하거나 리팩토링하지 않는 Surgical Precision을 적용합니다.

---

### Task 1: `issue_cli.py`의 `create-issue` 시 본문 파일 검증 및 `body_length` 응답 추가

**Files:**
- Modify: `skills/suh-issue/scripts/issue_cli.py`
- Create: `scripts/tests/test_cli_body_file.py`

**Interfaces:**
- Consumes: `common.emit.emit`, `common.gh_client.create_issue`
- Produces: `cmd_create_issue` 핸들러가 반환하는 JSON 응답에 `"body_length"` 필드 추가 및 파일 부재 시 `"code": "body_file_not_found"` 오류 반환

- [ ] **Step 1: 실패하는 TDD 테스트 코드 작성**

`scripts/tests/test_cli_body_file.py` 파일을 생성하고, 존재하지 않는 본문 파일 경로로 `create-issue`를 시도했을 때 명확하게 `body_file_not_found` 오류를 뱉는지 검증하는 코드를 작성합니다.

```python
# scripts/tests/test_cli_body_file.py
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT / "scripts") not in sys.path:
    sys.path.insert(0, str(ROOT / "scripts"))

from common.cli_parser import run_cli  # noqa: E402
from issue_cli import build_parser as build_issue_parser  # noqa: E402


def test_create_issue_body_file_not_found(capsys):
    parser = build_issue_parser()
    # 존재하지 않는 임시 경로를 지정
    rc = run_cli(parser, ["create-issue", "Cassiiopeia", "projectops", "테스트 이슈", "nonexistent_body.md", "작업전"])
    
    # 리턴코드는 실패(1)여야 함
    assert rc == 1
    
    # 출력된 JSON 파싱 및 구조 검증
    out = json.loads(capsys.readouterr().out.strip())
    assert out["ok"] is False
    assert out["code"] == "body_file_not_found"
    assert "존재하지 않습니다" in out["error"]
    assert out["path_attempted"] == str(Path("nonexistent_body.md").resolve())
```

- [ ] **Step 2: 테스트를 실행하여 실패하는지 검증**

Run: `pytest scripts/tests/test_cli_body_file.py::test_create_issue_body_file_not_found -v`
Expected: FAIL (AssertionError 혹은 빈 문자열로 인해 다른 결과 발생)

- [ ] **Step 3: `issue_cli.py` 최소 구현**

`skills/suh-issue/scripts/issue_cli.py` 파일의 `cmd_create_issue` 함수를 다음과 같이 수정하여 파일 미존재 시 즉시 에러 응답을 하고, 성공 시 `body_length`를 함께 `emit` 하도록 합니다.

```python
# skills/suh-issue/scripts/issue_cli.py 내 수정 내용

def cmd_create_issue(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    
    body_path = Path(args.body_file)
    if not body_path.exists():
        return emit({
            "ok": False,
            "code": "body_file_not_found",
            "error": f"본문 파일이 존재하지 않습니다: {args.body_file}",
            "path_attempted": str(body_path.resolve())
        })
    
    body = body_path.read_text(encoding="utf-8")
    labels = [l.strip() for l in args.labels.split(",") if l.strip()] if args.labels else []
    assignees = [a.strip() for a in args.assignees.split(",") if a.strip()] if args.assignees else []
    try:
        result = create_issue(args.owner, args.repo, args.title, body, labels, pat, assignees)
        applied = result.get("assignees", [])
        missing = [a for a in assignees if a not in applied]
        
        # body_length 필드를 성공 응답에 추가
        out = {**result, "summary": f"이슈 #{result.get('number')} 생성 완료", "body_length": len(body)}
        if missing:
            out["assignee_warning"] = (
                f"담당자 지정 일부 실패: {', '.join(missing)} (레포 협업자/권한 확인 필요). 이슈는 정상 생성됨."
            )
        return emit(out)
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})
```

- [ ] **Step 4: 테스트를 실행하여 패스하는지 검증**

Run: `pytest scripts/tests/test_cli_body_file.py::test_create_issue_body_file_not_found -v`
Expected: PASS

- [ ] **Step 5: 변경사항 커밋**

```bash
git add skills/suh-issue/scripts/issue_cli.py scripts/tests/test_cli_body_file.py
git commit -m "feat(issue_cli): validate body_file existence on create-issue and emit error"
```

---

### Task 2: `issue_cli.py`의 `update-issue` 명령에 `--body-file` 인자 추가 및 본문 수정 연동

**Files:**
- Modify: `skills/suh-issue/scripts/issue_cli.py`
- Modify: `scripts/tests/test_cli_body_file.py`

**Interfaces:**
- Consumes: `common.gh_client.update_issue` (이미 body 인자를 지원)
- Produces: `cmd_update_issue` 핸들러에서 `--body-file`로 본문을 받아 `update_issue(..., body=body)` 호출 지원

- [ ] **Step 1: 실패하는 TDD 테스트 코드 작성**

`scripts/tests/test_cli_body_file.py`에 `--body-file`을 넘겼으나 파일이 미존재할 때 실패하는 시나리오와, 파서에 `--body-file` 파라미터가 유효하게 등록되었는지를 체크하는 단위 테스트를 추가합니다.

```python
# scripts/tests/test_cli_body_file.py 에 추가할 테스트 코드

def test_update_issue_body_file_not_found(capsys):
    parser = build_issue_parser()
    rc = run_cli(parser, ["update-issue", "Cassiiopeia", "projectops", "426", "--body-file", "nonexistent_update.md"])
    
    assert rc == 1
    out = json.loads(capsys.readouterr().out.strip())
    assert out["ok"] is False
    assert out["code"] == "body_file_not_found"
    assert "수정용 본문 파일" in out["error"]
```

- [ ] **Step 2: 테스트를 실행하여 실패하는지 검증**

Run: `pytest scripts/tests/test_cli_body_file.py::test_update_issue_body_file_not_found -v`
Expected: FAIL (unrecognized arguments 발생하거나 파라미터가 안 읽혀서 패스 안 됨)

- [ ] **Step 3: `issue_cli.py` 구현 및 파서 확장**

`skills/suh-issue/scripts/issue_cli.py`에서 `cmd_update_issue`와 `build_parser` 안의 `p_ui` 파트를 수정합니다.

```python
# skills/suh-issue/scripts/issue_cli.py 내 수정 내용 (cmd_update_issue 및 build_parser)

def cmd_update_issue(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    labels = [l.strip() for l in args.labels.split(",") if l.strip()] if args.labels else None
    assignees = [a.strip() for a in args.assignees.split(",") if a.strip()] if args.assignees else None
    
    # 수정용 본문 파일 검증 및 로드 로직 추가
    body = None
    if args.body_file:
        body_path = Path(args.body_file)
        if not body_path.exists():
            return emit({
                "ok": False,
                "code": "body_file_not_found",
                "error": f"수정용 본문 파일이 존재하지 않습니다: {args.body_file}",
                "path_attempted": str(body_path.resolve())
            })
        body = body_path.read_text(encoding="utf-8")
        
    try:
        # body=body 인자 추가 전달
        result = update_issue(
            args.owner, args.repo, args.number, pat,
            title=args.title, body=body, state=args.state, labels=labels, assignees=assignees,
        )
        return emit({**result, "summary": f"#{args.number} 수정 완료"})
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


# build_parser 함수 내 p_ui 부근 수정
def build_parser() -> JSONArgumentParser:
    # ... (생략) ...
    p_ui = sub.add_parser("update-issue", help="이슈 수정 (담당자 지정 등)")
    p_ui.add_argument("owner")
    p_ui.add_argument("repo")
    p_ui.add_argument("number", type=int)
    p_ui.add_argument("--title")
    p_ui.add_argument("--state", choices=["open", "closed"])
    p_ui.add_argument("--labels")
    p_ui.add_argument("--assignees")
    p_ui.add_argument("--body-file", help="본문 파일 경로")  # 추가된 라인
    p_ui.set_defaults(func=cmd_update_issue)
```

- [ ] **Step 4: 테스트를 실행하여 패스하는지 검증**

Run: `pytest scripts/tests/test_cli_body_file.py::test_update_issue_body_file_not_found -v`
Expected: PASS

- [ ] **Step 5: 변경사항 커밋**

```bash
git add skills/suh-issue/scripts/issue_cli.py scripts/tests/test_cli_body_file.py
git commit -m "feat(issue_cli): support updating issue body via --body-file"
```

---

### Task 3: `github_cli.py`의 `update-issue` 명령에 `--body-file` 인자 추가 및 본문 수정 연동

**Files:**
- Modify: `skills/suh-github/scripts/github_cli.py`
- Modify: `scripts/tests/test_cli_body_file.py`

**Interfaces:**
- Consumes: `common.gh_client.update_issue`
- Produces: `cmd_update_issue` 핸들러에서 `--body-file`을 지원하여 `update_issue(..., body=body)` 호출 가능하게 연동

- [ ] **Step 1: 실패하는 TDD 테스트 코드 작성**

`github_cli` 의 `update-issue` 명령에서 `--body-file` 검증 테스트를 추가합니다.

```python
# scripts/tests/test_cli_body_file.py 에 추가할 테스트 코드
from github_cli import build_parser as build_github_parser  # noqa: E402

def test_github_cli_update_issue_body_file_not_found(capsys):
    parser = build_github_parser()
    rc = run_cli(parser, ["update-issue", "Cassiiopeia", "projectops", "426", "--body-file", "nonexistent_github_update.md"])
    
    assert rc == 1
    out = json.loads(capsys.readouterr().out.strip())
    assert out["ok"] is False
    assert out["code"] == "body_file_not_found"
    assert "수정용 본문 파일" in out["error"]
```

- [ ] **Step 2: 테스트를 실행하여 실패하는지 검증**

Run: `pytest scripts/tests/test_cli_body_file.py::test_github_cli_update_issue_body_file_not_found -v`
Expected: FAIL (unrecognized arguments 혹은 body_file이 생략됨)

- [ ] **Step 3: `github_cli.py` 구현 및 파서 확장**

`skills/suh-github/scripts/github_cli.py`의 `cmd_update_issue`와 `build_parser` 부분을 수정합니다.

```python
# skills/suh-github/scripts/github_cli.py 내 수정 내용

def cmd_update_issue(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 없음"})
    labels = [l.strip() for l in args.labels.split(",") if l.strip()] if args.labels else None
    assignees = [a.strip() for a in args.assignees.split(",") if a.strip()] if args.assignees else None
    
    # 수정용 본문 파일 검증 및 로드 로직 추가
    body = None
    if args.body_file:
        body_path = Path(args.body_file)
        if not body_path.exists():
            return emit({
                "ok": False,
                "code": "body_file_not_found",
                "error": f"수정용 본문 파일이 존재하지 않습니다: {args.body_file}",
                "path_attempted": str(body_path.resolve())
            })
        body = body_path.read_text(encoding="utf-8")
        
    try:
        # body=body 인자 추가 전달
        result = update_issue(
            args.owner, args.repo, args.number, pat,
            title=args.title, body=body, state=args.state, labels=labels, assignees=assignees,
        )
        return emit({**result, "summary": f"#{args.number} 수정 완료"})
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


# build_parser 함수 내 p_ui 부근 수정
def build_parser() -> JSONArgumentParser:
    # ... (생략) ...
    p_ui = sub.add_parser("update-issue", help="이슈 수정")
    p_ui.add_argument("owner")
    p_ui.add_argument("repo")
    p_ui.add_argument("number", type=int)
    p_ui.add_argument("--title")
    p_ui.add_argument("--state", choices=["open", "closed"])
    p_ui.add_argument("--labels", help="csv")
    p_ui.add_argument("--assignees", help="csv")
    p_ui.add_argument("--body-file", help="본문 파일 경로")  # 추가된 라인
    p_ui.set_defaults(func=cmd_update_issue)
```

- [ ] **Step 4: 테스트를 실행하여 패스하는지 검증**

Run: `pytest scripts/tests/test_cli_body_file.py`
Expected: ALL PASS (앞의 세 개의 모든 테스트가 성공적으로 통과함)

- [ ] **Step 5: 변경사항 커밋**

```bash
git add skills/suh-github/scripts/github_cli.py scripts/tests/test_cli_body_file.py
git commit -m "feat(github_cli): support updating issue body via --body-file"
```
