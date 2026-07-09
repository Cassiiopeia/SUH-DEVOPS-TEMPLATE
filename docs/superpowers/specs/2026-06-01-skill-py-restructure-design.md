# SKILL Python 실행 구조 재설계 (3-layer + skill별 분산)

> **관련 이슈**: [#322](https://github.com/Cassiiopeia/projectops/issues/322)
> **작성일**: 2026-06-01
> **상태**: design (사용자 승인 완료 → spec)

---

## 1. 목표

suh-github-template skills 시스템을 **3-layer 아키텍처 + skill별 py 분산 + MCP-style JSON 표준**으로 완전 재설계한다.

### 핵심 동기 (실측 기반)

- `skills/references/common-rules.md` 내부 모순: §3(PYTHONPATH) vs §대표호출(cd) 두 패턴을 동시에 표준으로 제시.
- 7개 py 호출 SKILL 중 2개(troubleshoot·review)는 `$SCRIPTS_PATH`·`$PYTHON` 미정의로 100% 실패 (실측 Exit 127).
- 5개 정상 SKILL도 agent가 시작 전 단계 건너뛰면 깨짐 (실측 ModuleNotFoundError).
- 단일 `suh_command.py`(19개 서브커맨드) 구조 → skill 책임 경계 흐릿, 관리 어려움.

---

## 2. Scope

### In-scope (8개 SKILL)

| SKILL | 변경 내용 |
|---|---|
| github | scripts/github_cli.py 신규 + SKILL.md 재작성 |
| issue | scripts/issue_cli.py 신규 + SKILL.md 재작성 |
| commit | scripts/commit_cli.py 신규 + SKILL.md 재작성 |
| report | scripts/report_cli.py 신규 + SKILL.md 재작성 |
| review | scripts/review_cli.py 신규 + SKILL.md 재작성 |
| troubleshoot | scripts/troubleshoot_cli.py 신규 + SKILL.md 재작성 |
| changelog-deploy | scripts/changelog_cli.py 신규 + SKILL.md 재작성 |
| skill-creator | SKILL.md + templates/python_cli_script.py 새 표준 반영 |

### Out-of-scope

- Plan-only 3개 통합 (analyze + design-analyze + refactor-analyze) — 별도 후속 작업
- 17개 도큐먼트형 SKILL (plan, design, document 등 — py 호출 0건)
- ssh (이미 자체 scripts/ssh_connect.py 보유, 동작 OK)
- 외부 CI/CD 워크플로우 변경

---

## 3. 아키텍처 — 3-layer

```
┌─────────────────────────────────────────────────────────────┐
│ Layer 3 — SKILL.md (워크플로우 + 사용자 대화)               │
│ 각 SKILL.md = 사용자 의도 파싱·승인·문서 작성              │
│ Python 호출 = self-contained 5줄 패턴                       │
└──────────────┬──────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 2 — skills/<skill>/scripts/<scope>_cli.py             │
│ skill 1개 = py 1개 = argparse 서브커맨드                    │
│ MCP-style JSON 출력 (ok/code/summary/next 4필드)            │
│ skill 워크플로우에 필요한 helper만                          │
└──────────────┬──────────────────────────────────────────────┘
               ↓
┌─────────────────────────────────────────────────────────────┐
│ Layer 1 — scripts/common/ (공유 인프라)                     │
│ gh_client.py     — GitHub API HTTP                          │
│ config.py        — config.json 로드                         │
│ paths.py         — 출력 경로 계산                           │
│ title.py         — 제목 정규화                              │
│ issue_number.py  — 이슈 번호 추출                           │
│ gh_branch.py     — 브랜치명·커밋 템플릿                     │
└─────────────────────────────────────────────────────────────┘
```

### 책임 분리 원칙

- **Layer 1 = 순수 함수 (도메인 로직)**. skill 의존성 0. import 자유.
- **Layer 2 = skill 1개 = py 1개**. 본인 워크플로우에 필요한 것만. 공유는 Layer 1 import.
- **Layer 3 = SKILL.md = 사용자 대화·승인·문서 작성**. Python 호출은 1줄.

---

## 4. 파일 구조

```
suh-github-template/
├── scripts/
│   ├── common/                           # Layer 1 (NEW)
│   │   ├── __init__.py
│   │   ├── gh_client.py                  # GitHub API HTTP
│   │   ├── gh_branch.py                  # 브랜치명·커밋 템플릿
│   │   ├── paths.py                      # 출력 경로 계산
│   │   ├── title.py                      # 제목 정규화
│   │   ├── issue_number.py               # 이슈 번호 추출
│   │   └── config.py                     # config.json 로드
│   └── ssh/                              # ssh 자체 폴더 (unchanged)
│       └── ssh_connect.py
│
├── skills/
│   ├── github/
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── github_cli.py             # Layer 2
│   ├── issue/
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── issue_cli.py
│   ├── commit/
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── commit_cli.py
│   ├── report/
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── report_cli.py
│   ├── review/
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── review_cli.py
│   ├── troubleshoot/
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── troubleshoot_cli.py
│   ├── changelog-deploy/
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── changelog_cli.py
│   ├── skill-creator/
│   │   ├── SKILL.md
│   │   ├── references/
│   │   └── templates/
│   │       └── python_cli_script.py      # 새 표준 반영
│   └── references/
│       └── common-rules.md               # §3 PYTHONPATH 제거, 새 표준 명시
│
└── (scripts/suh_template/ 삭제됨)
```

---

## 5. 표준 호출 패턴

### 5.1 SKILL.md 측 (Bash) — self-contained 5줄

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
cd "$PROJECT_ROOT/skills/<skill>/scripts" || exit 1
PYTHONIOENCODING=utf-8 "$PYTHON" <scope>_cli.py <subcommand> [args]
```

예시 (github):
```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
cd "$PROJECT_ROOT/skills/github/scripts" || exit 1
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py get-issue Cassiiopeia SUH-DEVOPS-TEMPLATE 322
```

### 5.2 `<scope>_cli.py` 측 (Python) — common import bootstrapping

```python
#!/usr/bin/env python3
"""<scope>_cli — <skill> 전용 CLI 헬퍼."""
import sys
import os
import argparse
import json
from pathlib import Path

# scripts/common import를 위해 sys.path 조작 (cwd 무관 동작)
_HERE = Path(__file__).resolve()
_PROJECT_ROOT = _HERE.parents[3]  # skills/<x>/scripts/<x>_cli.py → 3 up = project root
_SCRIPTS_ROOT = _PROJECT_ROOT / "scripts"
if str(_SCRIPTS_ROOT) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS_ROOT))

from common.gh_client import GitHubAPIError, get_issue, create_issue  # noqa: E402
from common.config import get_github_pat  # noqa: E402


def emit(payload: dict) -> int:
    """MCP-style JSON 출력. 4필드(ok/code/summary/next) 일관 보장."""
    payload.setdefault("ok", True)
    payload.setdefault("code", "ok")
    payload.setdefault("summary", None)
    payload.setdefault("next", None)
    print(json.dumps(payload, ensure_ascii=False))
    return 0 if payload["ok"] else 1


def cmd_get_issue(args) -> int:
    pat = get_github_pat(args.owner, args.repo)
    if not pat:
        return emit({"ok": False, "code": "missing_pat", "error": "PAT 미설정"})
    try:
        issue = get_issue(args.owner, args.repo, args.number, pat)
        return emit({
            "issue": issue,
            "summary": f"#{issue['number']} {issue['state']} — {issue['title']}",
        })
    except GitHubAPIError as e:
        return emit({"ok": False, "code": f"github_api_{e.status_code}", "error": str(e)})


def main() -> int:
    parser = argparse.ArgumentParser(prog="<scope>_cli")
    sub = parser.add_subparsers(dest="command", required=True)

    p_get = sub.add_parser("get-issue", help="이슈 조회")
    p_get.add_argument("owner")
    p_get.add_argument("repo")
    p_get.add_argument("number", type=int)
    p_get.set_defaults(func=cmd_get_issue)

    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
```

### 5.3 자체 표준 효과

- cwd 어디서든 import 동작 (`__file__` 기준 sys.path 조작)
- argparse `--help` 자동 생성 → 입력 계약 명시
- emit() 헬퍼로 MCP-style 4필드 강제

---

## 6. MCP-style JSON 표준

### 6.1 성공 출력

```json
{
  "ok": true,
  "code": "ok",
  "summary": "PR #123 생성 완료",
  "next": "deploy-status Cassiiopeia SUH-DEVOPS-TEMPLATE --pr 123",
  "pr": {"number": 123, "url": "...", "title": "..."}
}
```

### 6.2 에러 출력

```json
{
  "ok": false,
  "code": "missing_pat",
  "error": "GITHUB_PAT 환경변수도 config.json도 없습니다.",
  "summary": null,
  "next": null
}
```

### 6.3 4필드 의미

| 필드 | 의미 | 예시 |
|---|---|---|
| `ok` | 성공 여부 | `true` / `false` |
| `code` | 식별자 (에러시 디버깅용) | `ok`, `missing_pat`, `github_api_404` |
| `summary` | 사람 친화 한 줄 요약 | `"PR #123 생성 완료"` |
| `next` | 다음 행동 힌트 (agent 자율 워크플로우용) | `"deploy-status owner repo --pr 123"` |

---

## 7. 서브커맨드 매핑

기존 `suh_command.py` 19개 서브커맨드를 7개 `_cli.py`에 재배치.

| 새 위치 | 서브커맨드 | 기존 출처 |
|---|---|---|
| `github_cli.py` | get-issue, get-issues, update-issue, create-pr, list-prs, update-pr, search-issues, add-comment, explore, secrets | suh_command 그대로 |
| `issue_cli.py` | create-issue, search-issues (얇은 wrapper), get-next-seq, normalize-title, create-branch-name, get-commit-template | suh_command |
| `commit_cli.py` | get-issue-number, get-issue, normalize-title, get-commit-template | suh_command |
| `report_cli.py` | get-output-path, add-comment | suh_command |
| `review_cli.py` | get-output-path | suh_command |
| `troubleshoot_cli.py` | get-output-path | suh_command |
| `changelog_cli.py` | actions, deploy-status, list-prs, update-pr, create-pr | suh_command |

→ 같은 서브커맨드를 여러 skill이 import. **코드 중복 없음** (Layer 1 공유). SKILL.md는 자기 skill 내 py만 호출.

---

## 8. 의존 모듈 마이그레이션

현재 `scripts/suh_template/`의 6개 모듈을 `scripts/common/`으로 이동:

| 기존 | 새 위치 | 변경 |
|---|---|---|
| `scripts/suh_template/gh_client.py` | `scripts/common/gh_client.py` | mv + import 경로 정정 |
| `scripts/suh_template/gh_branch.py` | `scripts/common/gh_branch.py` | mv + import 경로 정정 |
| `scripts/suh_template/paths.py` | `scripts/common/paths.py` | mv + import 경로 정정 |
| `scripts/suh_template/title.py` | `scripts/common/title.py` | mv + import 경로 정정 |
| `scripts/suh_template/issue_number.py` | `scripts/common/issue_number.py` | mv + import 경로 정정 |
| `scripts/suh_template/config.py` | `scripts/common/config.py` | mv + import 경로 정정 |
| `scripts/suh_template/get_pat.py` | `scripts/common/config.py`에 통합 | 별도 파일 유지 가치 없음. config.py가 get_github_pat 노출 |
| `scripts/suh_template/manifest.py` | `scripts/common/manifest.py` | mv + import 경로 정정. 별 변경 없음 |
| `scripts/suh_template/suh_command.py` | **삭제** | 신규 7개 cli.py로 대체 |
| `scripts/suh_template/__init__.py` | **삭제** | |

---

## 9. references 정정

### `skills/references/common-rules.md`

| 섹션 | 변경 |
|---|---|
| §3 "PYTHONPATH 설정" | **제거** (PYTHONPATH 패턴 폐기) |
| §"대표 호출" | self-contained 5줄 패턴으로 업데이트 |
| 새 섹션 추가 | "skill별 py 분산 호출 규칙" — 위 5.1 코드 명시 |
| 새 섹션 추가 | "MCP-style 4필드 JSON 표준" — 위 6.x 명시 |
| 새 섹션 추가 | "OS 호환성 — Windows Git Bash + macOS/WSL 양쪽 실측 검증 완료" |

### `skills/skill-creator/templates/python_cli_script.py`

신규 skill 작성 시 사용하는 py 템플릿. 위 5.2 골격 그대로 + 주석 + 예시 서브커맨드 1개.

---

## 10. OS 호환성 (실측 검증 완료)

| 환경 | 결과 | PROJECT_ROOT 형식 | PYTHON 검출 |
|---|---|---|---|
| Windows Git Bash MINGW64_NT-10.0-22631 | ⭕ | `/d/0-suh/...` | `/c/Users/USER/.../Python313/python` |
| WSL Linux bash 5.2.21 | ⭕ | `/mnt/d/0-suh/...` | `/usr/bin/python3` |
| macOS bash/zsh | ⭕ (POSIX 호환 — WSL과 동일 동작 추론) | `/Users/...` | `/usr/bin/python3` 또는 `/opt/homebrew/bin/python3` |
| PowerShell | ❌ 미지원 | Claude Code Bash tool = bash 강제 |

---

## 11. 검증 방식

### 11.1 단위 (각 `_cli.py`)
- argparse `--help` 동작 확인
- 모든 서브커맨드 dry-run (인자 없이 호출 → 적절한 에러 JSON)
- 1개 정상 호출 (예: `get-issue owner repo number`)

### 11.2 OS
- Windows Git Bash + WSL Linux 양쪽
- 표준 5줄 패턴 그대로 복사 → 동작 확인

### 11.3 회귀
- 7개 SKILL.md의 모든 코드블록(총 ~30개) 실측
- 변경 전 동작하던 기능 전부 변경 후도 동작 확인

### 11.4 자체 검증 항목
- common-rules.md §3 vs §대표호출 모순 해소
- troubleshoot·review의 `get-output-path` 실측 통과
- 5개 정상 SKILL의 시작 전 단계 건너뛰어도 동작 보장

---

## 12. 구현 단계 (대분류)

1. **Layer 1 마이그레이션**: `scripts/common/` 신설 + 6개 모듈 이동
2. **github_cli.py 작성** (가장 큼, 10개 서브커맨드, 다른 cli 패턴 reference)
3. **나머지 6개 _cli.py 작성**: issue, commit, report, review, troubleshoot, changelog
4. **SKILL.md 7개 재작성**: 표준 5줄 호출 패턴 적용
5. **references/common-rules.md 정정**: §3 제거 + 새 표준 명시
6. **skill-creator 업데이트**: templates/python_cli_script.py 새 표준 + SKILL.md 보강
7. **scripts/suh_template/ 삭제**
8. **회귀 검증**: Windows Git Bash + WSL Linux 양쪽 30개 코드블록 실측

---

## 13. 비호환 영향

- **외부 사용자**: `scripts/suh_template/suh_command.py`를 직접 호출하던 외부 도구 있으면 깨짐. 단 현재 본 레포 외부에서 사용 사례 0건 추정.
- **CI/CD 워크플로우**: `.github/workflows/`에서 `suh_command.py` 호출하는 곳 점검 필요 (구현 단계에서 grep 검증).
- **사용자 명령어**: 사용자가 직접 `python -m suh_template.suh_command` 입력하는 경우 깨짐. SKILL.md 내부 호출만 표준이므로 영향 미미.

---

## 13.5 확장성 설계 (Extensibility)

### 13.5.1 신규 skill 추가 — 표준 절차

신규 skill에 py 호출 필요 시:

1. `skills/suh-<new>/scripts/<scope>_cli.py` 작성 (Layer 2)
2. `skill-creator/templates/python_cli_script.py` 골격 그대로 복사 → 서브커맨드만 추가
3. 공유 로직 필요하면 `scripts/common/`의 모듈 import — 새로 작성하지 않는다
4. SKILL.md 코드블록 = self-contained 5줄 그대로 (skill 이름만 치환)
5. `references/common-rules.md` 변경 0 — 표준이 그대로 적용

→ **신규 skill 추가 비용 = py 1개 + SKILL.md 1개**. references·common 코드 손대지 않음.

### 13.5.2 신규 서브커맨드 추가

기존 skill에 서브커맨드 추가 시:

1. 해당 `<scope>_cli.py`에 `def cmd_<name>(args) -> int` 추가
2. argparse subparser 등록
3. JSON 출력은 `emit()` 헬퍼 통해 4필드 일관 자동 보장
4. SKILL.md에 새 서브커맨드 사용 예시 추가 (선택)

→ 신규 서브커맨드 = 함수 1개 + subparser 1개. 단일 파일 변경.

### 13.5.3 신규 공통 모듈 추가

여러 skill에서 쓸 새 로직 발생 시:

1. `scripts/common/<new_module>.py` 작성
2. 필요한 `_cli.py`에서 `from common.<new_module> import ...`
3. 단위 함수 = pure function (skill 의존성 0) — Layer 1 원칙

→ skill 간 재사용 보장.

### 13.5.4 다양한 외부 시스템 통합 — 패턴 확장

GitHub만 지원 → 향후 GitLab/Bitbucket/Jira 등 통합 가능성:

```
scripts/common/
├── gh_client.py       # GitHub (현재)
├── gitlab_client.py   # GitLab (향후)
├── jira_client.py     # Jira (향후)
└── http_base.py       # 공통 HTTP 헬퍼 (선택)
```

각 client = 단일 책임, 같은 인터페이스 패턴(예: `<verb>_<resource>(args, pat) -> dict + GitHubAPIError`).

skill 단에서는 필요한 client만 import. 신규 client 추가가 다른 skill에 영향 0.

### 13.5.5 다중 config 프로필

현재 `~/.suh-template/config/config.json` 단일. 향후 multi-profile 지원:

- `config.json` (default)
- `config.work.json`, `config.personal.json` 등
- 환경변수 `SUH_PROFILE=work` 로 선택

`scripts/common/config.py` 가 profile 인자 받도록 설계. _cli.py는 그대로.

### 13.5.6 OS 환경 확장

현재 검증된 환경 외:

- **Native Windows PowerShell** — 미지원 (Claude Code Bash tool 외부). 사용자가 PowerShell에서 직접 호출 원하면 `scripts/suh.ps1` launcher 추가 가능 (별도 이슈)
- **Docker container** — `git rev-parse` + `python3` 있으면 동작. 별도 처리 불필요
- **CI/CD (GitHub Actions Ubuntu)** — POSIX 호환, 동작 보장

### 13.5.7 출력 포맷 확장

JSON only가 표준. 향후 plain text·yaml·csv 지원 필요 시:

- `_cli.py` 에 `--format json|text|yaml` 옵션 추가
- 기본값 = json (현재 동작 유지)
- emit() 헬퍼에 format 분기 추가

### 13.5.8 테스트 인프라

각 `_cli.py` 옆에 `tests/test_<scope>_cli.py` 추가 가능:

```
skills/github/
├── scripts/github_cli.py
└── tests/test_github_cli.py
```

unittest/pytest 둘 다 지원. CI에서 `pytest skills/**/tests/` 일괄 실행.

→ 신규 skill 추가 시 테스트 위치도 표준화.

---

## 14. 롤백 전략

전체 작업 = 1개 PR 또는 단계별 PR 시리즈. 롤백 시:
- PR 시리즈면 단계별 revert
- 1개 PR이면 전체 revert

`scripts/suh_template/` 삭제는 **마지막 단계 8번에서만 수행**. 그 전까지는 신구 병존 → 안전.

---

## 15. 변경 이력

| 버전 | 날짜 | 변경 |
|---|---|---|
| v1 | 2026-06-01 (이전 brainstorming) | self-contained 패턴 + common-rules 정정 (소규모) |
| v2-v3 | 같은 날 | OS 호환성 보강·PYTHON 가드 추가 |
| v4 | 같은 날 | Windows + macOS + WSL 실측 검증 |
| v5 | 같은 날 | 하이브리드 분산 + launcher 검토 + skill 통합 분석 |
| **v6** | 같은 날 | **3-layer 아키텍처 확정·전체 재설계·8개 SKILL scope 확정** |
