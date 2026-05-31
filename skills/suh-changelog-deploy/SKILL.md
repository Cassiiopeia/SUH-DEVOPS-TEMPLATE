---
name: suh-changelog-deploy
description: "main 브랜치를 push하고 deploy PR을 생성한 뒤 즉시 릴리스 노트를 작성해 AUTO-CHANGELOG-CONTROL 워크플로우가 CodeRabbit 10분 대기 없이 automerge를 진행하게 한다. automerge 실패 시 기존 PR을 닫고 새 PR을 열어 재트리거하는 fix 기능도 포함. 'deploy해줘', '배포해줘', 'deploy PR 올려줘', 'changelogfix', 'deploy 머지 안 됐어', 'PR 다시 열어줘' 등의 요청 시 사용."
---

# Changelog Deploy Mode

> **⚠️ 모델 권고**: 이 스킬은 릴리스 노트 작성이 주 작업이다. **lite(haiku) 모델로 실행을 권장**한다. 커밋 분석과 자연어 재작성만 하면 되므로 강력한 모델이 불필요하다.

SUH-DEVOPS-TEMPLATE 전용 스킬. `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` (deploy PR 감지 → CodeRabbit 대기 → CHANGELOG 업데이트 → automerge) 워크플로우와 연동.

main 브랜치 push → deploy PR 생성 → 릴리스 노트 즉시 작성 → automerge 자동 진행.
automerge 실패 시 기존 PR 닫고 새 PR 재생성 → 릴리스 노트 재작성.

`CodeRabbit` (AI PR 리뷰 봇) 10분 대기 없이 스킬이 직접 릴리스 노트를 작성하므로,
워크플로우 폴링 중 `Summary by CodeRabbit`을 감지하면 즉시 automerge가 진행된다.

## 이때는 쓰지 마라

- 배포가 아닌 일반 커밋/PR 작업
- `deploy` 브랜치가 없는 프로젝트 (이 스킬은 main → deploy PR 구조 전용)
- `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` 워크플로우가 설정되지 않은 저장소

## 핵심 원칙

- `git push --force`는 절대 실행하지 않는다
- **사용자 확인 없이 PR을 닫거나 열지 않는다** (fix 모드)

## 시작 전

**Config 파일 위치**: `~/.suh-template/config/config.json` (글로벌 단일 파일)

상세 경로 규칙: `references/config-rules.md §2~3` 참조.

> **⚠️ 실행 모델 (반드시 숙지)**: Claude Code의 Bash 도구는 **stateless**다 — 변수·`export`가 호출 간 유지되지 **않는다**.
> 한 Bash 호출에서 `export GITHUB_PAT=...` 해도 다음 Bash 호출에선 빈값이다.
> 따라서 이 스킬은 PAT·OWNER·REPO·PYTHON·PROJECT_ROOT 5개 값을 **agent가 아래에서 한 번 알아내 기억해 두고, 이 값들이 필요한 모든 Bash 블록 맨 앞에 실제 값으로 인라인 prefix(`VAR="값" ...`)** 한다. 셸 변수 재사용에 의존하지 않는다.

### 1) OWNER · REPO · PYTHON · PROJECT_ROOT 알아내기 (bash)

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(
  for _py in python3 python; do
    _path=$(command -v "$_py" 2>/dev/null) || continue
    "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break
  done
)
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
OWNER=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]([^/]+)/.*|\1|')
REPO=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/][^/]+/([^/.]+)(\.git)?$|\1|')
echo "PROJECT_ROOT=$PROJECT_ROOT"; echo "PYTHON=$PYTHON"; echo "OWNER=$OWNER"; echo "REPO=$REPO"
```

출력된 4개 값을 **그대로 기억**한다 (이후 모든 Bash 블록의 placeholder를 이 실제 값으로 치환). `PYTHON`이 비면 "❌ Python을 찾을 수 없습니다." 안내 후 종료.

### 2) PAT 추출 — **agent가 `Read` 도구로 직접 읽는다 (bash Python 추출 금지)**

> **중요**: PAT 추출은 bash 인라인 Python으로 하지 않는다.
> Windows Git Bash의 `$HOME`은 `/c/Users/...` (POSIX 경로)라 네이티브 Windows Python `open()`이 파일을 못 연다 → PAT 추출 실패(NO_PAT). 실측 검증된 버그다.
> 따라서 **agent가 `Read` 도구로 config 파일을 직접 읽어** PAT를 얻는다 — OS·셸 보간 무관하게 항상 동작한다.

1. `Read` 도구로 config 파일을 읽는다.
   - Windows: `C:\Users\<사용자>\.suh-template\config\config.json`
   - macOS/Linux: `~/.suh-template/config/config.json`
   - 파일이 없으면 → "❌ PAT 없음. /issue 스킬로 config를 먼저 등록하세요." 안내 후 종료.
2. `github` 섹션에서 PAT 선택:
   - `repos[]` 중 `repo == 위에서 구한 REPO` 이고 `pat`이 non-null이면 그 값 사용
   - 아니면 `global_pat` 사용
   - 둘 다 없으면 → 위와 동일 안내 후 종료.
3. 추출한 PAT 값을 **기억**한다. (PAT는 `ghp_`+영숫자라 따옴표 이스케이프 불필요.)

> **이후 모든 Bash 블록의 사용 규칙**: PAT/OWNER/REPO/PYTHON/PROJECT_ROOT가 등장하는 블록은 **그 블록 맨 앞에 실제 값을 인라인 prefix**로 붙인다. 예:
> ```bash
> GITHUB_PAT="ghp_실제값" OWNER="Cassiiopeia" REPO="SUH-DEVOPS-TEMPLATE" \
> PYTHON="/c/Users/USER/.../python" PROJECT_ROOT="/d/0-suh/.../suh-github-template" \
>   bash -c '...아래 블록 내용...'
> ```
> 또는 더 간단히, 블록 첫 줄에서 `GITHUB_PAT="..."; OWNER="..."; REPO="..."; PYTHON="..."; PROJECT_ROOT="..."` 로 재선언한 뒤 나머지를 실행한다. **핵심은 "이전 Bash 호출의 변수가 살아있다"고 가정하지 않는 것.**

## 사용자 입력

$ARGUMENTS

## 모드 판별

사용자 요청에 따라 두 모드 중 하나로 진행:

- **deploy 모드**: "deploy해줘", "배포해줘", "PR 올려줘" → [1단계]부터 시작
- **fix 모드**: "머지 안 됐어", "changelogfix", "다시 해줘", "PR 재시도" → [fix 1단계]부터 시작

---

## deploy 모드

### 1단계: 커밋 상태 확인

아래 명령어를 **각각 별도로** 실행한다. 절대 한 줄로 합치지 않는다.

```bash
git status --short
```

```bash
git fetch origin
```

```bash
# deploy 브랜치 대비 미반영 커밋 목록 (이게 핵심 — main→deploy PR이 목적이므로)
git log origin/deploy..HEAD --oneline 2>/dev/null
```

```bash
# 위 결과가 비어 있을 경우 대비용 — main remote 대비도 함께 확인
git log origin/main..HEAD --oneline 2>/dev/null
```

**판단 기준**:

- `git status --short` 결과에 미커밋 변경사항이 있으면 **즉시 멈추고** 안내:
  ```
  커밋되지 않은 변경사항이 있습니다. 먼저 커밋 후 다시 실행해주세요.
  /cassiiopeia:suh-commit 으로 커밋할 수 있습니다.
  ```
- `git log origin/deploy..HEAD` 결과가 비어 있으면 → `git log origin/main..HEAD` 결과도 확인
- **두 결과 모두 비어 있을 때만** "deploy할 커밋이 없습니다" 안내 후 종료
- 둘 중 하나라도 커밋이 있으면 다음 단계 진행

### 2단계: push 전 확인

push할 커밋 목록을 보여주고 사용자 승인받기:

```
📋 push할 커밋 (main → deploy 미반영):
  - {커밋 메시지 1}
  - {커밋 메시지 2}

git push origin main 을 실행할까요?
1. 네, push합니다
2. 취소
```

### 3단계: push

```bash
git pull --rebase origin main
git push origin main
```

push 완료 후 `VERSION-CONTROL` (patch 버전 자동 증가) 워크플로우가 자동 트리거된다.

> **⚠️ 단계 순서 (레이스컨디션 방지 — 반드시 지킨다)**
>
> AUTO-CHANGELOG-CONTROL 워크플로우는 deploy PR `opened` 시점에 본문을 확인해, 본문에 `Summary by CodeRabbit`이 **없으면 본문을 초기화**한다. 따라서 빈 본문으로 PR을 먼저 만들면, 워크플로우가 그 순간 끼어들어 본문을 비워 릴리스 노트가 사라진다.
>
> 이를 막기 위해 **PR 생성을 맨 마지막에** 둔다: 커밋 분석(4단계) → 릴리스 노트 작성(5단계) → 릴리스 노트를 본문에 담아 PR 생성(6단계). PR이 처음부터 `Summary by CodeRabbit`을 담고 태어나므로 워크플로우가 본문을 지우지 않는다. (워크플로우 로직은 수정하지 않는다.)

### 4단계: 커밋 분석

PR을 만들기 **전에** 먼저 main → deploy 변경분을 분석한다:

```bash
git fetch origin deploy main 2>/dev/null || true
# 분석 base는 HEAD가 아닌 origin/main — README 버전 워크플로우가 origin/main을
# 로컬 HEAD보다 앞서게 push할 수 있어 origin/deploy..HEAD가 빈 결과를 낼 수 있다.
git log origin/deploy..origin/main --pretty=format:"%s" | grep -v "\[skip ci\]" | head -60
```

커밋 메시지를 타입별로 분류:

| prefix | 분류 |
|--------|------|
| `feat` | 새 기능 |
| `fix` | 버그 수정 |
| `refactor` / `perf` / `style` | 개선 |
| `docs` | 문서 |
| 나머지 | 기타 |

**커밋 메시지를 그대로 쓰지 않는다.** 이슈 제목, URL, 타입 prefix, 파일명, 기술 용어를 모두 제거하고
**클라이언트(사용자)가 이해할 수 있는 기능/변경 관점**으로 재작성한다.

### 5단계: 릴리스 노트 작성

> **⚠️ AGENT 필독: 노트 파일을 만든 뒤 반드시 6단계(PR 생성)를 실행한다. PR 생성 없이 끝내지 않는다.**

**릴리스 노트 작성 원칙 — 앱스토어 업데이트 노트처럼 쓴다**:

일반 사용자가 "이번 업데이트에서 뭐가 바뀌었지?" 를 읽는다고 생각하고 작성한다.

- 파일명, 클래스명, 함수명, 변수명 **절대 언급 금지**
- `fix:`, `feat:`, `refactor:`, `chore:` 등 기술 prefix **절대 금지**
- API 호출, DB 쿼리, 알고리즘, 라이브러리명 등 내부 구현 **절대 금지**
- 이슈 번호, GitHub URL **절대 금지**
- **사용자가 직접 느끼는 변화**로만 서술
- 항목 하나당 한 줄, 40자 이내, 간결하게

**좋은 예 vs 나쁜 예**:
```
❌ PYTHONPATH 환경변수 패턴으로 크로스플랫폼 호환성 수정
✅ Windows와 macOS에서 실행 오류가 발생하던 문제 해결

❌ config-rules.md §7 Skill별 Config 스키마 인라인화
✅ 설정 초기화 과정이 더 간단해졌습니다

❌ Node.js 20 → 24 Dockerfile 업그레이드 (npm ci lock 파일 불일치 해결)
✅ 빌드 시 패키지 설치 오류가 발생하던 문제 해결

❌ .suh-template/ 폴더 삭제 및 .gitignore 정리
✅ 앱 설치 용량이 소폭 감소했습니다
```

릴리스 노트 본문 파일은 워크플로우가 파싱하는 형식과 **100% 동일한 구조**로 작성한다. 카테고리명은 아래 고정값만 사용하고, 항목이 없는 카테고리는 생략한다.

**Write tool로 `$PROJECT_ROOT/scripts/_release_notes.md`에 저장**:

```
<!-- This is an auto-generated comment: release notes by coderabbit.ai -->

## Summary by CodeRabbit

## 릴리스 노트

* **새 기능**
  * (항목)

* **버그 수정**
  * (항목)

* **개선**
  * (항목)

* **문서**
  * (항목)

* **기타**
  * (항목)

<!-- end of auto-generated comment: release notes by coderabbit.ai -->
```

이 파일이 완성되면 **즉시 6단계(PR 생성)로 넘어간다.**

### 6단계: deploy PR 생성 (릴리스 노트 본문 포함)

VERSION-CONTROL 워크플로우 완료를 기다리지 않고 deploy PR을 생성한다. **5단계에서 만든 릴리스 노트 파일을 본문으로 담아 생성**하는 것이 핵심이다 — PR이 처음부터 `Summary by CodeRabbit`을 담고 있어야 AUTO-CHANGELOG-CONTROL 워크플로우가 본문을 초기화하지 않는다.

```bash
# ⚠️ Bash stateless — 이 블록 맨 앞 5개 변수를 [시작 전]에서 구한 실제 값으로 채운다.
GITHUB_PAT="..."; OWNER="..."; REPO="..."; PYTHON="..."; PROJECT_ROOT="..."

TODAY=$(date '+%Y%m%d')
TITLE="🚀 Deploy ${TODAY}"

# 기존 open deploy PR이 있으면 재사용 — 닫지 않는다 (새로 열면 워크플로우 재트리거되어 본문 초기화 위험)
EXISTING_PR=$(curl -s \
  -H "Authorization: token $GITHUB_PAT" \
  "https://api.github.com/repos/$OWNER/$REPO/pulls?state=open&base=deploy" \
  | grep -o '"number":[0-9]*' | head -1 | grep -o '[0-9]*')

cd "$PROJECT_ROOT/scripts"
if [ -n "$EXISTING_PR" ]; then
  # 재사용 케이스: 이미 PR이 존재하므로 update-pr로 릴리스 노트 본문만 갱신한다.
  PR_NUMBER=$EXISTING_PR
  echo "기존 deploy PR #$PR_NUMBER 재사용 → 본문 업데이트"
  GITHUB_PAT="$GITHUB_PAT" PYTHONIOENCODING=utf-8 "$PYTHON" -m suh_template.suh_command \
    update-pr "$OWNER" "$REPO" "$PR_NUMBER" "_release_notes.md"
else
  # 신규 케이스: create-pr의 body_file에 릴리스 노트 파일 경로를 넘겨 본문 포함 PR 생성.
  # suh_command가 body_file을 읽어 본문에 채운다 (빈 경로를 넘기던 기존 동작과 달리, 노트 파일을 넘긴다).
  CREATE_OUT=$(GITHUB_PAT="$GITHUB_PAT" PYTHONIOENCODING=utf-8 "$PYTHON" -m suh_template.suh_command \
    create-pr "$OWNER" "$REPO" "$TITLE" "_release_notes.md" "main" "deploy")
  PR_NUMBER=$(CREATE_OUT="$CREATE_OUT" "$PYTHON" -c "import os,json; print(json.loads(os.environ['CREATE_OUT']).get('number',''))")
  echo "새 deploy PR #$PR_NUMBER 생성 (릴리스 노트 본문 포함)"
fi
rm -f _release_notes.md
cd "$PROJECT_ROOT"

if [ -z "$PR_NUMBER" ]; then
  echo "❌ PR 생성/업데이트 실패. GitHub API 응답을 확인하세요. ($CREATE_OUT)"
  exit 1
fi
```

출력 JSON(`{"number","url"}`)으로 성공을 확인한다.

### 7단계: automerge 검증 (deploy-status)

PR 생성 직후, **`/tmp`에 즉석 Python을 만들지 말고** 아래 재사용 커맨드 한 번으로 상태를 확인한다. owner/repo/PR번호만 주면 PR 머지·CodeRabbit 본문·워크플로우 run·deploy HEAD를 한 번에 조회해 `verdict`로 판정한 JSON을 반환한다.

```bash
# ⚠️ Bash stateless — 5개 변수를 [시작 전]에서 구한 실제 값으로 채운다. PR_NUMBER는 6단계에서 구한 값.
GITHUB_PAT="..."; OWNER="..."; REPO="..."; PYTHON="..."; PROJECT_ROOT="..."; PR_NUMBER="..."

cd "$PROJECT_ROOT/scripts"
GITHUB_PAT="$GITHUB_PAT" PYTHONIOENCODING=utf-8 "$PYTHON" -m suh_template.suh_command \
  deploy-status "$OWNER" "$REPO" --pr "$PR_NUMBER"
cd "$PROJECT_ROOT"
```

반환 JSON의 `verdict`를 보고 라우팅한다:

| verdict | 의미 | 행동 |
|---------|------|------|
| `merged` | automerge 완료 | 8단계 결과 안내, 종료 |
| `waiting_for_automerge` | 정상 대기 중 | **sleep 금지.** `ScheduleWakeup`으로 ~90초 후 `next` 힌트(`deploy-status ... --pr N`)를 재호출해 재확인 |
| `missing_coderabbit_summary` | 본문 초기화됨(레이스컨디션) | fix 모드로 재실행 |
| `workflow_failed` | 워크플로우 실패 | `workflow.run_url` 안내 + fix 모드로 재실행 |
| `conflict` | 머지 충돌/차단 | 사용자에게 충돌 상태 안내, 수동 확인 요청 |
| `no_pr` | open deploy PR 없음 | `deploy_branch.head_sha`로 이미 머지됐는지 확인 후 안내 |

> **재확인 시 sleep을 쓰지 않는다.** Claude Code Bash는 `sleep 120`을 차단한다. 대기가 필요하면 `ScheduleWakeup(delaySeconds=90)`으로 자기 페이스를 잡고, 깨어나면 `next` 힌트의 `deploy-status` 커맨드를 다시 호출한다.

### 8단계: 결과 안내

```
✅ 완료!

📋 요약:
  • push: origin/main
  • deploy PR: #NNN
  • 릴리스 노트: 작성 완료

AUTO-CHANGELOG-CONTROL 워크플로우가 "Summary by CodeRabbit"을 감지하면
CHANGELOG 업데이트 후 deploy 브랜치 automerge가 자동 진행됩니다.

진행 상황: https://github.com/{owner}/{repo}/actions
```

---

## fix 모드 (automerge 실패 시 재트리거)

### fix 1단계: 현재 deploy PR 상태 확인 (deploy-status)

curl 즉석 파싱 대신 deploy-status로 현재 상태를 종합 조회한다. `--pr` 없이 호출하면 open deploy PR을 자동 탐색한다.

```bash
# ⚠️ Bash stateless — 5개 변수를 실제 값으로 채운다.
GITHUB_PAT="..."; OWNER="..."; REPO="..."; PYTHON="..."; PROJECT_ROOT="..."

cd "$PROJECT_ROOT/scripts"
GITHUB_PAT="$GITHUB_PAT" PYTHONIOENCODING=utf-8 "$PYTHON" -m suh_template.suh_command \
  deploy-status "$OWNER" "$REPO"
cd "$PROJECT_ROOT"
```

반환 JSON의 `verdict`로 분기한다:

- `no_pr` → open PR 없음. fix 3단계(새 PR 생성)로 이동
- `merged` → 이미 머지됨. 재시도 불필요, 사용자에게 안내 후 종료
- 그 외(`waiting_for_automerge`/`missing_coderabbit_summary`/`workflow_failed`/`conflict`) → `pr.number`를 EXISTING_PR로 기억하고 fix 2단계(기존 PR 닫기)로 진행

### fix 2단계: 기존 PR 닫기 (사용자 확인 후)

```
현재 open된 deploy PR #NNN이 있습니다.
이 PR을 닫고 새로 열어서 워크플로우를 재트리거할까요?

1. 네, 닫고 새로 생성합니다
2. 취소
```

확인 후 실행:

```bash
# ⚠️ Bash stateless — 변수 + EXISTING_PR(fix 1단계 번호)을 실제 값으로 채운다.
GITHUB_PAT="..."; OWNER="..."; REPO="..."; EXISTING_PR="..."

curl -s -X PATCH \
  -H "Authorization: token $GITHUB_PAT" \
  -H "Content-Type: application/json" \
  -d '{"state":"closed"}' \
  "https://api.github.com/repos/$OWNER/$REPO/pulls/$EXISTING_PR"
```

> **⚠️ fix 모드도 deploy 모드와 동일하게 PR 생성을 맨 마지막에 둔다.** 빈 본문으로 새 PR을 먼저 열면 워크플로우가 본문을 초기화한다. 따라서 커밋 분석(fix 3단계) → 릴리스 노트 작성(fix 4단계) → 릴리스 노트 본문 담아 PR 생성(fix 5단계) 순으로 진행한다.

### fix 3단계: 커밋 분석

새 PR을 만들기 **전에** main → deploy 변경분을 먼저 분석한다:

```bash
git fetch origin deploy main 2>/dev/null || true
# 분석 base는 origin/main (deploy 4단계와 동일 이유 — HEAD가 origin/main보다 뒤일 수 있음).
git log origin/deploy..origin/main --pretty=format:"%s" | grep -v "\[skip ci\]" | head -60
```

커밋 메시지를 deploy 모드 4·5단계와 **완전히 동일한 기준**으로 분류 및 재작성한다.
앱스토어 업데이트 노트처럼 — 파일명·기술 prefix·구현 방식·이슈 번호·URL 모두 금지. 사용자가 직접 느끼는 변화만, 40자 이내로 간결하게.

### fix 4단계: 릴리스 노트 작성

> **⚠️ AGENT 필독: 노트 파일을 만든 뒤 반드시 fix 5단계(PR 생성)를 실행한다.**

deploy 6단계와 **동일한 고정 구조**로 릴리스 노트 파일을 작성한다 (Write tool로 `$PROJECT_ROOT/scripts/_release_notes.md`에 저장). 구조는 deploy 5단계의 고정 템플릿(`Summary by CodeRabbit` 포함)을 그대로 따른다.

### fix 5단계: 새 deploy PR 생성 (릴리스 노트 본문 포함)

fix 4단계에서 만든 릴리스 노트 파일을 **본문으로 담아** 새 PR을 생성한다. PR이 처음부터 `Summary by CodeRabbit`을 담고 태어나야 워크플로우가 본문을 초기화하지 않는다.

```bash
# ⚠️ Bash stateless — 5개 변수를 실제 값으로 채운다.
GITHUB_PAT="..."; OWNER="..."; REPO="..."; PYTHON="..."; PROJECT_ROOT="..."

TODAY=$(date '+%Y%m%d')
TITLE="🚀 Deploy ${TODAY} (재시도)"

# create-pr의 body_file에 릴리스 노트 파일 경로를 넘겨 본문 포함 PR 생성 (deploy 6단계와 동일 패턴).
cd "$PROJECT_ROOT/scripts"
CREATE_OUT=$(GITHUB_PAT="$GITHUB_PAT" PYTHONIOENCODING=utf-8 "$PYTHON" -m suh_template.suh_command \
  create-pr "$OWNER" "$REPO" "$TITLE" "_release_notes.md" "main" "deploy")
PR_NUMBER=$(CREATE_OUT="$CREATE_OUT" "$PYTHON" -c "import os,json; print(json.loads(os.environ['CREATE_OUT']).get('number',''))")
rm -f _release_notes.md
cd "$PROJECT_ROOT"

if [ -z "$PR_NUMBER" ]; then
  echo "❌ PR 생성 실패. GitHub API 응답을 확인하세요. ($CREATE_OUT)"
  exit 1
fi
echo "✅ PR #$PR_NUMBER 생성 완료 (릴리스 노트 본문 포함)"
```

출력 JSON(`{"number","url"}`)으로 성공을 확인한다.

### fix 6단계: 결과 안내

```
✅ PR #NNN 본문 업데이트 완료!

워크플로우가 폴링 중 "Summary by CodeRabbit"을 감지하면 automerge가 자동 진행됩니다.
진행 상황: https://github.com/{owner}/{repo}/actions
```

---

## 주의사항

- **PR 생성/재시도 후 반드시 `deploy-status` 커맨드로 검증한다.** PR 상태·automerge·워크플로우 확인용 Python을 `/tmp`에 즉석 생성하지 않는다 — `deploy-status`가 그 모든 것을 JSON으로 반환한다.
- **PR은 릴리스 노트를 본문에 담아 생성한다** (deploy 6단계 / fix 5단계). PR이 처음부터 `Summary by CodeRabbit`을 담고 있어 워크플로우가 본문 초기화를 건너뛴다. 빈 본문으로 먼저 만든 뒤 나중에 본문을 채우면 레이스컨디션으로 노트가 사라진다.
- 그래도 워크플로우가 본문을 지워버린 정황이 보이면 fix 모드로 재실행한다.
- deploy PR이 이미 있으면 닫지 않고 재사용한다 — 새로 열면 워크플로우가 다시 트리거되어 본문이 초기화될 수 있다.
- 10분이 지나도 automerge가 안 되면 fix 모드로 재실행한다.
- **Windows 내부망에서 curl exit 35 (SSL 오류) 발생 시**: curl 호출에 `--ssl-no-revoke` 옵션 추가 (`references/common-rules.md` Windows 내부망 환경 섹션 참조).
