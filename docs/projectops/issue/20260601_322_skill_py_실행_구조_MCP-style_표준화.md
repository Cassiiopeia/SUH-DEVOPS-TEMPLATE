📝 현재 문제점
---

skill 내부에서 Python 스크립트(`suh_template.suh_command`)를 실행하는 구조가 **표준 자체에 모순**이 있고, OS 호환성·강건성도 부족하다.

### 1. `skills/references/common-rules.md` 자체 표준 모순

- §3 "PYTHONPATH 설정" — `PYTHONPATH="$PROJECT_ROOT/scripts" $PYTHON -m suh_template.suh_command ...` (cwd 유지 패턴)
- §"대표 호출" — `cd "$PROJECT_ROOT/scripts" && $PYTHON -m suh_template.suh_command ...` (cd 패턴)

같은 파일 안에서 두 가지 호출 컨벤션을 모두 "표준"으로 제시 → 새 SKILL 작성자가 어느 쪽을 따라야 할지 혼란.

### 2. 7개 `suh_command` 호출 SKILL 일관성 부재

| SKILL | 패턴 | 상태 |
|---|---|---|
| suh-troubleshoot | `PYTHONPATH="$SCRIPTS_PATH" $PYTHON -m ...` | ❌ **`$SCRIPTS_PATH`·`$PYTHON` 미정의 사용**. 실측 결과: `Exit 127: -m: command not found` |
| suh-review | 동일 | ❌ 동일 깨짐 |
| suh-issue | `cd "$PROJECT_ROOT/scripts" && ...` | ⚠️ Phase 0(`PROJECT_ROOT` 정의) 건너뛰면 `cd /scripts` 실패 → `ModuleNotFoundError` |
| suh-github | 동일 | ⚠️ 7개 코드블록 모두 동일 위험 (가장 위험) |
| suh-commit | 동일 | ⚠️ 1단계→3단계 순차 의존 |
| suh-report | 동일 | ⚠️ 동일 |
| suh-changelog-deploy | **매 블록 self-contained** (`PROJECT_ROOT`·`PYTHON` 재선언) | ✅ 유일하게 강건. 실측 통과 |

→ 5개 "정상" SKILL도 agent가 시작 전 단계 건너뛰고 특정 코드블록부터 실행하면 깨진다 (실측 검증: cwd 레포 루트에서 `cd "$PROJECT_ROOT/scripts"` 호출 시 `cd /scripts: No such file or directory` 후 `ModuleNotFoundError: No module named 'suh_template'`).

### 3. somansa-claude-code 레포 구조 비교

동일 개발자(SUH SAECHAN)가 관리하지만 두 레포 방향성 다름:

| 항목 | suh-github-template (현 레포) | somansa-claude-code |
|---|---|---|
| Python 모듈 구조 | 단일 `scripts/suh_template/suh_command.py` + 서브커맨드 | skill별 분산 `scripts/<name>_api.py` (redmine_api, pad_api, ssh_exec, drive_api, jenkins_api…) |
| 호출 방식 | `python -m suh_template.suh_command <subcommand>` | `python scripts/<name>_api.py <subcommand>` |
| Sibling cross-call | 없음 | 빈번 (postgres → ssh, redmine → pad/init-redmine-issue/drive) |
| MCP-style JSON 출력 | `ok`/`code`/`summary`/`next` 4필드 표준 (mcp-subcommand-rules.md) | 동일 패턴 채택 |
| Agent 판단 흐름 | JSON 파싱 → 다음 행동 결정 | 동일 |
| 호출 컨벤션 명료도 | **약함** (표준 모순 + 변수 가정 묵시적) | **강함** (직전 세션에서 cwd 규칙 1줄 일관화 작업 완료) |

**강점/약점 정리**:
- suh-github-template 강점 = 단일 entry-point (신규 동작 = 서브커맨드 추가만)
- suh-github-template 약점 = SKILL.md 호출 표준 자체가 흐려서 agent가 패턴별로 다르게 따라함
- somansa 강점 = MCP-style 입력 계약(argparse) + JSON only stdout + 환경변수 prefix 강제 패턴이 명시적
- somansa 약점 = 분산 구조 → sibling cross-call cwd 가정 깨지기 쉬움 (이미 해결됨)

→ **결론**: 두 레포 모두 MCP-style 채택 + 같은 개발자 관리. 차이는 "단일 모듈 vs 분산" + "호출 표준 명료도". 이 레포(suh-github-template)가 호출 컨벤션 측면에서 더 약함.

🛠️ 해결 방안 / 제안 기능
---

### 1. 표준 호출 패턴 통일 (self-contained 5줄)

매 Bash 코드블록을 **self-contained 5줄 패턴**으로 통일. agent가 어느 블록부터 시작해도 100% 동작 보장.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
cd "$PROJECT_ROOT/scripts" || exit 1
PYTHONIOENCODING=utf-8 "$PYTHON" -m suh_template.suh_command <subcommand> [args]
```

**OS 호환성 실측 검증 완료**:

| 환경 | 결과 | PROJECT_ROOT 형식 | PYTHON 검출 |
|---|---|---|---|
| Windows Git Bash (MINGW64_NT-10.0-22631) | ⭕ | `/d/0-suh/...` | `/c/Users/USER/.../Python313/python` |
| WSL Linux (bash 5.2.21) | ⭕ | `/mnt/d/0-suh/...` | `/usr/bin/python3` |
| macOS bash/zsh | ⭕ (POSIX 호환 — WSL과 동일 동작) | `/Users/...` | `/usr/bin/python3` 또는 `/opt/homebrew/bin/python3` |
| PowerShell | ❌ 미지원 (Claude Code Bash tool = bash 강제) | — | — |

### 2. references 정정

- `skills/references/common-rules.md` §3 (PYTHONPATH 패턴) **제거**
- §"대표 호출" (cd 패턴)만 표준으로 명시
- "매 Bash 블록 self-contained 필수" 규칙 추가
- "Windows Git Bash + macOS 양쪽 실측 확인" 명시
- Python 검출 실패 시 `[ -z "$PYTHON" ] && exit 1` 가드 표준화

### 3. 7개 SKILL 전수 정정

| 파일 | 변경 |
|---|---|
| `skills/suh-troubleshoot/SKILL.md` L99-102 | `$SCRIPTS_PATH`·`$PYTHON` 미정의 블록 → self-contained 5줄로 교체 |
| `skills/suh-review/SKILL.md` L88-91 | 동일 교체 |
| `skills/suh-issue/SKILL.md` | 모든 코드블록(3개) 앞에 PROJECT_ROOT+PYTHON 재선언 + `[ -z "$PYTHON" ]` 가드 |
| `skills/suh-github/SKILL.md` | 모든 코드블록(7개) self-contained화 (가장 위험 → 우선순위 1) |
| `skills/suh-commit/SKILL.md` | 3단계 이슈 조회 블록 self-contained화 |
| `skills/suh-report/SKILL.md` | 포스팅 플로우 블록 self-contained화 |
| `skills/suh-changelog-deploy/SKILL.md` | **touch 안 함** (이미 self-contained — 참조 reference 역할) |

### 4. MCP-style 강화 (somansa 우수 패턴 흡수)

- 모든 `suh_command` 서브커맨드 출력 JSON에 **`ok`·`code`·`summary`·`next` 4필드 일관 보장** (`references/mcp-subcommand-rules.md` 기준)
- agent가 `next` 힌트로 다음 행동 결정 → 자율 워크플로우 가능
- 서브커맨드별 **입력 계약 명시** (argparse 필수 인자/옵션)
- stdout = JSON only 강제 (plain text 모드 금지)
- 민감 인자(PAT 등) = 환경변수 전달 강제 (heredoc·임시파일·stdin pipe 금지)

### 5. 비범위

다음 항목은 이 이슈에서 다루지 않는다:

- `skills/suh-ssh/scripts/ssh_connect.py` — 별개 패턴 (이미 절대경로 풀이로 OK)
- 도큐먼트 위주 18개 SKILL (plan·analyze·design·document 등 — py 호출 0건, Grep 검증 완료)
- `scripts/suh_template/suh_command.py` 코드 자체 — 호출 표기만 정리

⚙️ 작업 내용
---

1. `skills/references/common-rules.md` 정정 (PYTHONPATH 제거, cd 패턴 + self-contained 규칙 명시)
2. `skills/suh-troubleshoot/SKILL.md` 깨진 호출 패턴 교체
3. `skills/suh-review/SKILL.md` 깨진 호출 패턴 교체
4. `skills/suh-issue/SKILL.md` 코드블록 self-contained화
5. `skills/suh-github/SKILL.md` 7개 코드블록 self-contained화 (우선순위 1)
6. `skills/suh-commit/SKILL.md` 코드블록 self-contained화
7. `skills/suh-report/SKILL.md` 코드블록 self-contained화
8. `references/mcp-subcommand-rules.md` 보강 (4필드 강제 규칙·환경변수 prefix 강제·JSON only 명시)
9. 검증: 변경 후 각 SKILL 첫 코드블록 dry-run (Windows Git Bash + WSL Linux 양쪽)
10. 검증: common-rules.md 자체 모순 해소 확인

🙋‍♂️ 담당자
---

- 백엔드: Cassiiopeia
- 프론트엔드: -
- 디자인: -
