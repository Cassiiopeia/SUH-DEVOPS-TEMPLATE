---
name: changelog-deploy
description: "main 브랜치를 push하고 deploy PR을 생성한 뒤 즉시 릴리스 노트를 작성해 AUTO-CHANGELOG-CONTROL 워크플로우가 CodeRabbit 10분 대기 없이 automerge를 진행하게 한다. automerge 실패 시 기존 PR을 닫고 새 PR을 열어 재트리거하는 fix 기능도 포함. 'deploy해줘', '배포해줘', 'deploy PR 올려줘', 'changelogfix', 'deploy 머지 안 됐어', 'PR 다시 열어줘' 등의 요청 시 사용."
---

# Changelog Deploy Mode

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

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
OWNER=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]([^/]+)/.*|\1|')
REPO=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/][^/]+/([^/.]+)(\.git)?$|\1|')

# PAT 추출: 해당 repo의 pat 우선, 없으면 global_pat fallback
HOME_DIR=$(echo "$HOME")
CONFIG_FILE="$HOME_DIR/.suh-template/config/config.json"
GITHUB_PAT=$($PYTHON -c "
import sys, json
try:
    c = json.load(open('$CONFIG_FILE'))
    gh = c.get('github', {})
    repo_pat = next((r.get('pat') for r in gh.get('repos', []) if r.get('repo') == '$REPO' and r.get('pat')), None)
    print(repo_pat or gh.get('global_pat', ''))
except:
    print('')
" 2>/dev/null)
if [ -z "$GITHUB_PAT" ]; then
  echo "❌ PAT 없음. /issue 스킬로 config를 먼저 등록하세요."
  exit 1
fi
```

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
  /cassiiopeia:commit 으로 커밋할 수 있습니다.
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

### 4단계: deploy PR 생성

VERSION-CONTROL 워크플로우 완료를 기다리지 않고 바로 deploy PR을 생성한다.
(PR 생성 타이밍과 버전 증가 타이밍이 겹쳐도 무방 — 워크플로우가 알아서 처리)

```bash
TODAY=$(date '+%Y%m%d')
TITLE="🚀 Deploy ${TODAY}"

# 기존 open deploy PR이 있으면 재사용
EXISTING_PR=$(curl -s \
  -H "Authorization: token $GITHUB_PAT" \
  "https://api.github.com/repos/$OWNER/$REPO/pulls?state=open&base=deploy" \
  | grep -o '"number":[0-9]*' | head -1 | grep -o '[0-9]*')

if [ -n "$EXISTING_PR" ]; then
  PR_NUMBER=$EXISTING_PR
  echo "기존 deploy PR #$PR_NUMBER 재사용"
else
  PR_NUMBER=$($PYTHON - "$GITHUB_PAT" "$OWNER" "$REPO" "$TITLE" <<'EOF'
import urllib.request, json, sys
pat, owner, repo, title = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
url = f"https://api.github.com/repos/{owner}/{repo}/pulls"
payload = {"title": title, "head": "main", "base": "deploy", "body": ""}
data = json.dumps(payload).encode()
req = urllib.request.Request(url, data=data, method="POST")
req.add_header("Authorization", f"token {pat}")
req.add_header("Content-Type", "application/json")
res = urllib.request.urlopen(req)
print(json.loads(res.read())["number"])
EOF
  )
  echo "새 deploy PR #$PR_NUMBER 생성"
fi

if [ -z "$PR_NUMBER" ]; then
  echo "❌ PR 생성 실패. GitHub API 응답을 확인하세요."
  exit 1
fi
```

### 5단계: 커밋 분석 → 릴리스 노트 작성

PR 생성 직후 바로 커밋을 분석한다 (워크플로우가 CodeRabbit을 기다리는 동안):

```bash
git fetch origin deploy 2>/dev/null || true
git log origin/deploy..HEAD --pretty=format:"%s" | grep -v "\[skip ci\]" | head -60
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

**클라이언트용 작성 기준 (반드시 준수)**:
- 파일명, 클래스명, 함수명, 변수명 언급 금지
- `fix:`, `feat:`, `refactor:` 등 기술 prefix 언급 금지
- 내부 구현 방식 (API 호출, DB 쿼리, 알고리즘 등) 언급 금지
- **사용자가 체감하는 변화**만 서술: "~기능 추가", "~문제 해결", "~개선"
- 항목 하나당 한 줄, 50자 이내로 간결하게

**좋은 예 vs 나쁜 예**:
```
❌ PYTHONPATH 환경변수 패턴으로 크로스플랫폼 호환성 수정
✅ Windows/macOS 환경에서 스킬 실행 오류 해결

❌ config-rules.md §7 Skill별 Config 스키마 인라인화
✅ 스킬 설정 파일 예시 문서 추가

❌ .suh-template/ 폴더 삭제 및 .gitignore 정리
✅ 불필요한 임시 폴더 제거
```

### 6단계: PR 본문 업데이트

워크플로우가 파싱하는 형식과 **100% 동일한 구조**로 작성. 카테고리명은 아래 고정값만 사용:

```bash
$PYTHON - "$GITHUB_PAT" "$OWNER" "$REPO" "$PR_NUMBER" <<'EOF'
import urllib.request, json, sys
pat, owner, repo, pr = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
url = f"https://api.github.com/repos/{owner}/{repo}/pulls/{pr}"
body = """<!-- This is an auto-generated comment: release notes by coderabbit.ai -->

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

<!-- end of auto-generated comment: release notes by coderabbit.ai -->"""
data = json.dumps({"body": body}).encode()
req = urllib.request.Request(url, data=data, method="PATCH")
req.add_header("Authorization", f"token {pat}")
req.add_header("Content-Type", "application/json")
urllib.request.urlopen(req)
print("PR 본문 업데이트 완료")
EOF
```

항목이 없는 카테고리는 생략한다.

### 7단계: 결과 안내

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

### fix 1단계: 현재 deploy PR 상태 확인

```bash
EXISTING_PR=$(curl -s \
  -H "Authorization: token $GITHUB_PAT" \
  "https://api.github.com/repos/$OWNER/$REPO/pulls?state=open&base=deploy" \
  | grep -o '"number":[0-9]*' | head -1 | grep -o '[0-9]*')
```

- open PR이 있으면 번호 확인
- PR이 없으면 → fix 3단계(새 PR 생성)로 바로 이동

### fix 2단계: 기존 PR 닫기 (사용자 확인 후)

```
현재 open된 deploy PR #NNN이 있습니다.
이 PR을 닫고 새로 열어서 워크플로우를 재트리거할까요?

1. 네, 닫고 새로 생성합니다
2. 취소
```

확인 후 실행:

```bash
curl -s -X PATCH \
  -H "Authorization: token $GITHUB_PAT" \
  -H "Content-Type: application/json" \
  -d '{"state":"closed"}' \
  "https://api.github.com/repos/$OWNER/$REPO/pulls/$EXISTING_PR"
```

### fix 3단계: 새 deploy PR 생성

```bash
TODAY=$(date '+%Y%m%d')
TITLE="🚀 Deploy ${TODAY} (재시도)"

PR_NUMBER=$($PYTHON - "$GITHUB_PAT" "$OWNER" "$REPO" "$TITLE" <<'EOF'
import urllib.request, json, sys
pat, owner, repo, title = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
url = f"https://api.github.com/repos/{owner}/{repo}/pulls"
payload = {"title": title, "head": "main", "base": "deploy", "body": ""}
data = json.dumps(payload).encode()
req = urllib.request.Request(url, data=data, method="POST")
req.add_header("Authorization", f"token {pat}")
req.add_header("Content-Type", "application/json")
res = urllib.request.urlopen(req)
print(json.loads(res.read())["number"])
EOF
)

if [ -z "$PR_NUMBER" ]; then
  echo "❌ PR 생성 실패. GitHub API 응답을 확인하세요."
  exit 1
fi
echo "✅ PR #$PR_NUMBER 생성 완료, 릴리스 노트 작성 시작..."
```

### fix 4단계: 커밋 분석 → 릴리스 노트 작성

```bash
git fetch origin deploy 2>/dev/null || true
git log origin/deploy..HEAD --pretty=format:"%s" | grep -v "\[skip ci\]" | head -60
```

커밋 메시지를 deploy 모드 5단계와 동일한 기준으로 타입별 분류 및 클라이언트용으로 재작성한다.
(파일명·기술 prefix·구현 방식 언급 금지, 사용자 체감 변화만 서술)

### fix 5단계: PR 본문 업데이트

```bash
$PYTHON - "$GITHUB_PAT" "$OWNER" "$REPO" "$PR_NUMBER" <<'EOF'
import urllib.request, json, sys
pat, owner, repo, pr = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
url = f"https://api.github.com/repos/{owner}/{repo}/pulls/{pr}"
body = """<!-- This is an auto-generated comment: release notes by coderabbit.ai -->

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

<!-- end of auto-generated comment: release notes by coderabbit.ai -->"""
data = json.dumps({"body": body}).encode()
req = urllib.request.Request(url, data=data, method="PATCH")
req.add_header("Authorization", f"token {pat}")
req.add_header("Content-Type", "application/json")
urllib.request.urlopen(req)
print("PR 본문 업데이트 완료")
EOF
```

항목이 없는 카테고리는 생략한다.

### fix 6단계: 결과 안내

```
✅ PR #NNN 본문 업데이트 완료!

워크플로우가 폴링 중 "Summary by CodeRabbit"을 감지하면 automerge가 자동 진행됩니다.
진행 상황: https://github.com/{owner}/{repo}/actions
```

---

## 주의사항

- 워크플로우가 PR 본문을 초기화하는 타이밍과 스킬이 본문을 올리는 타이밍이 겹칠 수 있다.
  만약 워크플로우가 본문을 다시 지워버리면 fix 모드로 재실행한다.
- deploy PR이 이미 있으면 닫지 않고 재사용한다 — 새로 열면 워크플로우가 다시 트리거되어 본문이 초기화될 수 있다.
- 10분이 지나도 automerge가 안 되면 fix 모드로 재실행한다.
- **Windows 내부망에서 curl exit 35 (SSL 오류) 발생 시**: curl 호출에 `--ssl-no-revoke` 옵션 추가 (`references/common-rules.md` Windows 내부망 환경 섹션 참조).
