---
name: pro-github
description: "GitHub Mode - 독립적인 GitHub 제어 스킬. 이슈 조회/수정/댓글, PR 생성/조회/릴리스노트, 레포 탐색, GitHub Actions Secret 관리를 수행한다. PR 생성, PR 올려줘, 이슈 댓글, 댓글 달아줘, 이슈 확인해줘, 이슈 닫아줘, 이슈 수정해줘, 라벨 바꿔줘, '/github', 내 레포 보여줘, 레포 목록 탐색해줘, README 가져와줘, {레포명} 정보 봐줘, Org 레포 탐색해줘, secret 업데이트해줘, Actions secret 등록해줘, 환경변수 secret 올려줘, BACKEND_ENV_FILE 업데이트 등을 언급하면 반드시 이 skill을 사용한다. 다른 스킬보다 먼저 트리거되어야 한다."
---

# GitHub Mode

독립적인 GitHub 제어 스킬이다. 다른 스킬 없이 단독으로 GitHub 작업을 수행한다.

## 시작 전

**프로젝트 루트 확인**:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

> **⚠️ 스크립트는 플러그인 캐시에 설치된다 — 작업 중인 프로젝트 루트에 없다.**
> `github_cli.py`는 `~/.claude/plugins/cache/<marketplace>/projectops/<version>/skills/pro-github/scripts/`에 있다. 사용자 프로젝트(템플릿으로 생성·통합된 레포 포함)에는 `skills/` 폴더 자체가 없으므로(통합 시 제외) `$PROJECT_ROOT/skills/...` 고정 경로는 다른 레포에서 실패한다. 아래 모든 Bash 블록의 `SCRIPTS=$(ls -d ~/.claude/plugins/cache/...)` 라인이 **캐시 우선 → 프로젝트 루트 폴백**으로 스크립트를 찾으므로 어느 레포에서든 동작한다. config(`~/.projectops/config/config.json`)는 항상 user 홈 기준이라 프로젝트 위치와 무관하다.

**Config / PAT 확인** — `references/config-rules.md` §2~3 절차를 따른다.

> ⚠️ **config는 탐색 금지.** config.json은 고정 경로 `{HOME}/.projectops/config/config.json` 한 곳뿐이다 — Read tool로 바로 읽는다. 위 ⚠️ 블록의 `ls ~/.claude/plugins/cache/...` 패턴은 **스크립트(`github_cli.py`) 전용**이며 config는 그 캐시 안에 없다. 캐시를 뒤지면 "config 없음"으로 오판해 등록된 PAT를 다시 묻게 된다.

**MCP-style 서브커맨드 표준** — `references/mcp-subcommand-rules.md`를 따른다.

GitHub API 호출은 재사용 스크립트 `skills/pro-github/scripts/github_cli.py`로만 수행한다. PAT는 `github_cli`가 `GITHUB_PAT` 환경변수 → `config.json`(`github.global_pat`, repo별 `pat` 우선) 순으로 자동 로드하므로 호출부에서 직접 추출하지 않는다.

- SKILL.md에 긴 Python heredoc, 임시 Python 파일, curl 파이프 Python, 일회용 Python 생성 금지
- 출력 JSON의 `ok`/`code`/`summary`/`next`를 보고 다음 행동을 판단
- config 파일이 없으면 → `/issue` 스킬로 PAT를 먼저 등록하도록 안내한다 (config는 모든 GitHub 스킬이 공유한다).

**Repo 자동 감지**:

```bash
git remote get-url origin
```

`https://github.com/{owner}/{repo}.git` 또는 `git@github.com:{owner}/{repo}.git` 형식에서 `owner`와 `repo`를 추출한다.

추출한 `owner/repo`를 config `repos` 배열과 대조한다:
- 매칭되는 항목이 있으면 → 해당 repo 사용
- 매칭 실패 시 → config `repos` 목록을 번호로 나열해 사용자가 선택하게 한다
- **`$ARGUMENTS`에 `owner/repo` 형식이 명시된 경우 → git remote 감지를 건너뛰고 해당 repo를 바로 사용한다**

> 주의: Claude Code의 primary working directory가 작업 대상 레포와 다른 경우(멀티 레포 워크트리 환경) git remote 감지가 오작동할 수 있다. 이 경우 arguments로 대상 레포를 명시하거나 config repos 목록에서 선택한다.

## 사용자 입력

$ARGUMENTS

## 지원 작업

### 이슈 조회

`#번호` 형식이나 "이슈 427 확인해줘"처럼 번호를 명시하면 해당 이슈를 조회한다.
본문과 댓글이 모두 필요하면 `--with-comments`를 붙인다.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
SCRIPTS=$(ls -d ~/.claude/plugins/cache/*/projectops/*/skills/pro-github/scripts 2>/dev/null | sort -V | tail -1); [ -z "$SCRIPTS" ] && SCRIPTS="$PROJECT_ROOT/skills/pro-github/scripts"; cd "$SCRIPTS" || exit 1
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py get-issue {owner} {repo} {이슈번호}
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py get-issue {owner} {repo} {이슈번호} --with-comments
```

출력 JSON: `{"ok":true,"issue":{number,title,url,state,body,labels,assignees,created_at,updated_at,comments_count},"comments":...,"summary","next":null}`.

여러 이슈를 한 번에 조회해야 하면:

```bash
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py get-issues {owner} {repo} 712 707 715
```

일부 이슈가 404여도 해당 항목만 `{number,error,code}`로 들어오며 전체 조회는 계속된다.

### 이슈 수정

제목, 상태(open/closed), 라벨, 담당자 변경 가능.
변경할 항목만 payload dict에 포함하면 된다. 나머지는 기존 값 유지.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
SCRIPTS=$(ls -d ~/.claude/plugins/cache/*/projectops/*/skills/pro-github/scripts 2>/dev/null | sort -V | tail -1); [ -z "$SCRIPTS" ] && SCRIPTS="$PROJECT_ROOT/skills/pro-github/scripts"; cd "$SCRIPTS" || exit 1
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py update-issue {owner} {repo} {이슈번호} \
  --title "새 제목" --state closed --labels "작업중" --assignees "Cassiiopeia"
```

### 이슈에 댓글 추가

본문에 한국어·이모지·줄바꿈이 포함될 수 있으므로 댓글 본문을 파일로 저장한 뒤 `add-comment`에 전달한다.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
SCRIPTS=$(ls -d ~/.claude/plugins/cache/*/projectops/*/skills/pro-github/scripts 2>/dev/null | sort -V | tail -1); [ -z "$SCRIPTS" ] && SCRIPTS="$PROJECT_ROOT/skills/pro-github/scripts"; cd "$SCRIPTS" || exit 1
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py add-comment {owner} {repo} {이슈번호} "{댓글 본문 파일 경로}"
```

### PR 생성

현재 브랜치 이름을 자동 감지하여 PR을 생성한다.

**PR 생성 전 반드시 remote 브랜치 존재 여부를 확인한다 (한글 브랜치명 422 오류 방지):**

```bash
HEAD_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git ls-remote --heads origin "$HEAD_BRANCH" | grep -q "$HEAD_BRANCH" || echo "브랜치가 remote에 없습니다. git push 먼저 실행하세요."
```

`head` 필드는 반드시 `owner:branch` 형식으로 지정한다 (한글 포함 브랜치명의 422 오류 방지):

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
SCRIPTS=$(ls -d ~/.claude/plugins/cache/*/projectops/*/skills/pro-github/scripts 2>/dev/null | sort -V | tail -1); [ -z "$SCRIPTS" ] && SCRIPTS="$PROJECT_ROOT/skills/pro-github/scripts"; cd "$SCRIPTS" || exit 1
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py create-pr {owner} {repo} "{제목}" "{PR 본문 파일 경로}" "{owner}:{head_branch}" main
```

#### PR 제목 규칙 (필수)

브랜치명이 `YYYYMMDD_#번호_제목` 형식이면 번호를 추출해 이슈 API로 제목을 조회한다.
조회한 이슈 제목에서 **앞에 붙은 이모지와 `[태그]` 형식을 모두 제거**한 순수 텍스트만 PR 제목으로 사용한다.

예) 이슈 제목이 `❗[버그][개발자도구] SSE 서버 로그 스트리밍 연결 즉시 종료 및 구독자 누적 문제`이면
→ PR 제목: `SSE 서버 로그 스트리밍 연결 즉시 종료 및 구독자 누적 문제`

#### PR 본문 규칙 (필수)

PR 본문에는 반드시 관련 이슈 링크를 포함한다:

```
- https://github.com/{owner}/{repo}/issues/{이슈번호}
```

이슈 번호는 브랜치명(`YYYYMMDD_#번호_...`)에서 자동 추출한다.

### PR 목록 조회

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
SCRIPTS=$(ls -d ~/.claude/plugins/cache/*/projectops/*/skills/pro-github/scripts 2>/dev/null | sort -V | tail -1); [ -z "$SCRIPTS" ] && SCRIPTS="$PROJECT_ROOT/skills/pro-github/scripts"; cd "$SCRIPTS" || exit 1
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py list-prs {owner} {repo} --state open
# 닫힌 PR 포함: --state closed 또는 --state all
```

### PR 릴리스 노트 업데이트 (CodeRabbit 폴백)

릴리스 PR(develop→main)에 CodeRabbit Summary가 없을 때 Claude Code가 직접 커밋을 분석하여 한국어 릴리스 노트를 작성하고 PR 본문에 업데이트한다.

"릴리스 노트 업데이트해줘", "changelog 폴백", "PR 본문 업데이트" 등의 요청 시 실행.

**절차**:

1. PR 번호 확인 (사용자 입력 또는 `list-prs`로 최근 릴리스 PR 조회)

2. main(프로덕션) 대비 커밋 목록 수집

```bash
git fetch origin main 2>/dev/null || true
git log origin/main..HEAD --pretty=format:"%H %s" | grep -v "\[skip ci\]" | head -60
```

3. 커밋 메시지를 분석하여 한국어 릴리스 노트 작성

   - `feat:` → 새 기능
   - `fix:` → 버그 수정
   - `refactor:` / `perf:` / `style:` → 개선
   - `docs:` → 문서
   - 나머지 → 기타
   - 커밋 메시지를 그대로 쓰지 말고 사용자가 이해하기 쉬운 한국어 문장으로 재작성

4. 릴리스 노트 본문을 파일로 저장한 뒤 `update-pr`로 PATCH 전송:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
SCRIPTS=$(ls -d ~/.claude/plugins/cache/*/projectops/*/skills/pro-github/scripts 2>/dev/null | sort -V | tail -1); [ -z "$SCRIPTS" ] && SCRIPTS="$PROJECT_ROOT/skills/pro-github/scripts"; cd "$SCRIPTS" || exit 1
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py update-pr {owner} {repo} {pr_number} "{릴리스 노트 파일 경로}"
```

---

## GitHub Actions 로그 조회

GitHub Actions의 run/job 상태와 **실패 로그**를 조회한다. 빌드 실패 원인 진단에 사용한다.

**트리거 예시**: "빌드 실패 확인해줘", "Actions 로그 봐줘", "이 PR 왜 빌드 실패?", run/job/PR URL 붙여넣기, "main 빌드 됐어?"

### 핵심 원리

- 모든 로직은 재사용 스크립트 `skills/pro-github/scripts/github_cli.py`의 `actions` 서브커맨드에 있다. **인라인 Python 작성 금지.**
- **입력 해석은 agent(너)의 책임**이다. 사용자가 주는 URL·PR번호·브랜치명·빈 입력을 보고 아래 라우팅 표에 따라 적절한 서브커맨드와 인자를 결정한다.
- `github_cli`는 **명확한 인자만** 받는다 (URL을 파싱하지 않는다). 출력은 **언제나 JSON**이며 `ok`·데이터·`next`(이어서 호출할 다음 서브커맨드 힌트) 필드를 담는다.
- `next` 필드가 비어있지 않으면 그 값을 그대로 다음 명령으로 실행해 체인을 잇는다 (예: `show-run`의 `next` → `joblog` 호출).

### agent 입력 라우팅 (필수)

사용자 입력을 다음 규칙으로 서브커맨드에 매핑한다. owner/repo는 시작 절차에서 결정한 값을 쓴다.

| 사용자 입력 | 추출 | 서브커맨드 |
|------------|------|-----------|
| `.../actions/runs/{run_id}` | run_id | `actions show-run {owner} {repo} {run_id}` |
| `.../actions/runs/{run_id}/job/{job_id}` | job_id | `actions joblog {owner} {repo} {job_id}` |
| `.../actions/runs/{run_id}/attempts/{n}` | run_id | `actions show-run {owner} {repo} {run_id}` |
| 순수 숫자 (예: `26554093214`) | 그 숫자=run_id | `actions show-run {owner} {repo} {숫자}` |
| `.../pull/{pr}` 또는 "PR 883" | pr | `actions resolve-pr {owner} {repo} {pr}` |
| 브랜치명 또는 "main 빌드" | branch | `actions resolve-branch {owner} {repo} {branch}` |
| `.../actions` (전체 페이지) / 빈 입력 / "빌드 실패했어" | 없음 | `actions list-failed {owner} {repo}` |
| `.../actions/workflows/{file}.yaml` | 없음 | `actions list-failed {owner} {repo}` (결과에서 해당 워크플로명 필터) |

**전형적 진단 흐름**:
1. 입력에 run_id 없음(PR/브랜치/빈입력) → `resolve-pr`·`resolve-branch`·`list-failed`로 실패 run 찾기
2. 실패 run의 `next`(=`show-run ...`) 실행 → 실패 job_id + 실패 step 확인
3. `show-run`의 `next`(=`joblog ...`) 실행 → 실제 에러 로그 라인 확인
4. 로그 라인을 읽고 사용자에게 원인 진단 제시

### 서브커맨드 호출법

PAT는 `github_cli`가 config.json에서 자동 로드하므로 `export GITHUB_PAT`는 생략 가능하다(환경변수가 있으면 우선 사용). `PYTHONIOENCODING=utf-8` 필수(한글 출력 보호).

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
SCRIPTS=$(ls -d ~/.claude/plugins/cache/*/projectops/*/skills/pro-github/scripts 2>/dev/null | sort -V | tail -1); [ -z "$SCRIPTS" ] && SCRIPTS="$PROJECT_ROOT/skills/pro-github/scripts"; cd "$SCRIPTS" || exit 1

# run 메타 + job 목록 + 실패 step
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py actions show-run {owner} {repo} {run_id}

# 실패 job 로그 (error 라인 필터, Azure redirect 자동 처리)
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py actions joblog {owner} {repo} {job_id}
#   --grep ".dart"  : 특정 키워드 라인만 (기본 "error")
#   --tail 30       : 매칭 라인 끝 N개 (기본 30)

# 최근 실패 run 목록
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py actions list-failed {owner} {repo} --limit 10

# PR → 연결된 run 추적
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py actions resolve-pr {owner} {repo} {pr_number}

# 브랜치 → 최근 run 목록
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py actions resolve-branch {owner} {repo} "{branch}" --limit 10
```

> **Windows 주의**: 위 표준 호출 패턴(캐시 우선 탐색)으로 스크립트 디렉토리를 잡은 뒤 `github_cli.py`로 실행한다. 임시 파일 파싱·curl 파이프 Python·heredoc 보간은 사용하지 않는다 (Windows Git Bash에서 깨짐). 인자는 모두 명령행/환경변수로 전달한다.

### 출력 예시

```json
{"run_id": 26554093214, "name": "프로젝트 빌드 테스트", "conclusion": "failure",
 "jobs": [{"job_id": 78222159478, "name": "프로젝트 빌드 테스트", "conclusion": "failure", "failed_steps": ["코드 분석 실행"]}],
 "failed_job_ids": [78222159478],
 "ok": true, "next": "actions joblog TEAM-ROMROM RomRom-FE 78222159478"}
```

---

## explore 모드

GitHub 유저 또는 Organization의 레포 목록과 개별 레포 상세 정보를 조회한다.
출력은 `github_cli explore`의 JSON을 그대로 파싱해 판단한다.

"내 레포 보여줘", "레포 목록 탐색해줘", "README 가져와줘", "{레포명} 정보 봐줘", "Org 레포 탐색해줘" 등의 요청 시 실행.

### Phase 0 — Owner 결정

**Owner 결정 규칙**:

1. "내 레포", owner 미명시 → config의 기본 repo owner 또는 현재 git remote owner를 사용한다. 사용자가 실제 PAT 소유자 레포 목록을 원하면 owner를 명시하게 한다.
2. owner 명시 ("TEAM-ROMROM", "Cassiiopeia" 등) → 해당 owner 사용. 기본 `--type auto`로 user/org를 자동 판별한다.

### Phase 1 — 레포 목록 조회

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
SCRIPTS=$(ls -d ~/.claude/plugins/cache/*/projectops/*/skills/pro-github/scripts 2>/dev/null | sort -V | tail -1); [ -z "$SCRIPTS" ] && SCRIPTS="$PROJECT_ROOT/skills/pro-github/scripts"; cd "$SCRIPTS" || exit 1
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py explore list-repos {owner} --type auto
# user/org가 확실하면: --type user 또는 --type org
```

**필터링**: 사용자가 "fork 제외", "Java만", "stars 높은 순" 등을 요청하면
별도 API 재호출 없이 위 결과에서 agent가 직접 필터링한다.

### Phase 2 — 단일 레포 상세 조회

특정 레포명이 언급되면 아래 4개 정보를 순서대로 수집한다.
각 호출은 독립적으로 실행하며, 하나가 실패해도 나머지는 계속 진행한다.

**2-1. 기본 메타정보**

```bash
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py explore repo-detail {owner} {repo}
```

**2-2. README**

```bash
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py explore readme {owner} {repo}
```

**2-3. 언어 구성**

```bash
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py explore languages {owner} {repo}
```

**2-4. 최근 커밋 10개**

```bash
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py explore commits {owner} {repo} --limit 10
```

`next` 값이 있으면 그대로 이어서 실행해 탐색 흐름을 연결한다.

---

## GitHub Actions Secret 관리

GitHub 레포의 Actions Secret을 조회·생성·업데이트한다.

**트리거 예시**: "BACKEND_ENV_FILE secret 업데이트해줘", "secret 바꿔줘", "환경변수 secret 올려줘", "Actions secret 등록해줘"

### 자동 탐색 절차

사용자가 secret 이름이나 값을 명시하지 않아도 스킬이 먼저 탐색한다:

**1단계 — secret 이름 결정**

- `$ARGUMENTS`에 이름이 명시된 경우 → 그대로 사용
- 미명시 시 → 현재 레포의 secrets 목록 조회 후 번호로 선택지 제시

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
SCRIPTS=$(ls -d ~/.claude/plugins/cache/*/projectops/*/skills/pro-github/scripts 2>/dev/null | sort -V | tail -1); [ -z "$SCRIPTS" ] && SCRIPTS="$PROJECT_ROOT/skills/pro-github/scripts"; cd "$SCRIPTS" || exit 1
PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py secrets list {owner} {repo}
```

**2단계 — secret 값 결정**

- `$ARGUMENTS`에 값이 명시된 경우 → 그대로 사용
- 미명시 시 → 프로젝트 루트와 서브디렉터리에서 `.env` 파일 자동 탐색:

```bash
find "$PROJECT_ROOT" -maxdepth 3 -name ".env" -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null
```

  - `.env` 파일 발견 시 → 내용을 보여주고 "이 내용으로 업데이트할까요?" 확인
  - `.env` 없음 → 직접 입력 요청

> **주의**: `.env` 내용에 민감 정보가 포함될 수 있으므로, 사용자에게 내용을 보여주고 반드시 확인 후 진행한다.

### Secret 업데이트 실행

값은 `SECRET_VALUE` 환경변수로 전달한다. 멀티라인 `.env`도 인자 이스케이프 없이 보존된다.
`github_cli secrets set`이 PyNaCl로 GitHub public key 암호화 후 PUT한다. PyNaCl 미설치 시 자동 설치를 시도하고, 실패하면 `code:"pynacl_missing"` JSON을 반환한다.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
[ -z "$PYTHON" ] && { echo "Python not found"; exit 1; }
SCRIPTS=$(ls -d ~/.claude/plugins/cache/*/projectops/*/skills/pro-github/scripts 2>/dev/null | sort -V | tail -1); [ -z "$SCRIPTS" ] && SCRIPTS="$PROJECT_ROOT/skills/pro-github/scripts"; cd "$SCRIPTS" || exit 1
SECRET_VALUE="{secret_value}" PYTHONIOENCODING=utf-8 "$PYTHON" github_cli.py secrets set {owner} {repo} {secret_name}
```

### 오류 대응

| 오류 | 원인 | 대응 |
|------|------|------|
| `403` on secrets API | PAT에 `repo` scope 없음 | PAT 재발급 시 `repo` 전체 체크 안내 |
| `404` on secrets list | private 레포 권한 없음 | 권한 확인 안내 |
| `nacl` import 오류 | PyNaCl 설치 실패 | `pip install PyNaCl --user` 수동 실행 안내 |
| `.env` 내용에 특수문자 | 인자 이스케이프 문제 | `SECRET_VALUE` 환경변수로 전달 |

---

## 오류 처리

| 오류 코드 | 의미 | 대응 |
|-----------|------|------|
| `missing_pat` | GITHUB_PAT 미설정 | `/issue` 스킬로 PAT 등록 안내 |
| `github_api_401` | PAT 인증 실패 | PAT 갱신 안내 |
| `github_api_403` | 권한 없음 (private 레포 등) | 접근 불가 안내, 나머지 진행 |
| `github_api_404` | 이슈/PR/레포/README 없음 | 해당 항목 "없음"으로 표시, 나머지 진행 |
| `github_api_422` | 이미 PR 존재 등 | API 오류 메시지 그대로 안내 |
| API rate limit | 요청 한도 초과 | `X-RateLimit-Remaining: 0` 감지 시 안내 |
| curl 네트워크 오류 | 연결 실패 | exit code 확인 후 재시도 1회, 실패 시 안내 |
