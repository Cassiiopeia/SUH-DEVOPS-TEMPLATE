---
name: changelogfix
description: "deploy PR의 automerge가 실패했을 때 기존 PR을 닫고 새 PR을 열어 AUTO-CHANGELOG-CONTROL 워크플로우를 재트리거한 뒤, 직접 릴리스 노트를 작성해 PR 본문에 올려 10분 대기 없이 automerge가 진행되게 한다. 'changelogfix', 'deploy 머지 안 됐어', 'PR 다시 열어줘', 'changelog 재실행' 등의 요청 시 사용."
---

# Changelog Fix Mode

deploy PR automerge 실패 시 기존 PR을 닫고 새 PR을 열어 워크플로우를 재트리거한다.
워크플로우가 CodeRabbit을 10분 대기하는 동안, 스킬이 먼저 git diff를 분석해
릴리스 노트를 작성하고 PR 본문에 올린다.
워크플로우 폴링 중 `Summary by CodeRabbit`을 감지하면 automerge가 즉시 진행된다.

## 핵심 원칙

- **사용자 확인 없이 PR을 닫거나 열지 않는다**
- `git push`는 절대 실행하지 않는다

## 시작 전

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
if [ -d "$PROJECT_ROOT/scripts/suh_template" ]; then
  SCRIPTS_PATH="$PROJECT_ROOT/scripts"
else
  SCRIPTS_PATH=$(find "$HOME/.claude/plugins/cache" -type d -name "suh_template" 2>/dev/null | head -1 | xargs -I{} dirname {} 2>/dev/null)
fi
GITHUB_PAT=$(PYTHONPATH="$SCRIPTS_PATH" $PYTHON -m suh_template.cli config-get issue github_pat)
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
OWNER=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]([^/]+)/.*|\1|')
REPO=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/][^/]+/([^/.]+)(\.git)?$|\1|')
```

## 사용자 입력

$ARGUMENTS

## 프로세스

### 1단계: 현재 deploy PR 상태 확인

```bash
GH_TOKEN=$GITHUB_PAT gh pr list --repo $OWNER/$REPO --base deploy --state open --json number,title,state
```

- open PR이 있으면 번호 확인
- PR이 없으면 → 3단계(새 PR 생성)로 바로 이동

### 2단계: 기존 PR 닫기 (사용자 확인 후)

```
현재 open된 deploy PR #NNN이 있습니다.
이 PR을 닫고 새로 열어서 워크플로우를 재트리거할까요?

1. 네, 닫고 새로 생성합니다
2. 취소
```

확인 후 실행:

```bash
GH_TOKEN=$GITHUB_PAT gh pr close {pr_number} --repo $OWNER/$REPO
```

### 3단계: 새 deploy PR 생성

```bash
TODAY=$(date '+%Y%m%d')
TITLE="🚀 Deploy ${TODAY} (재시도)"

NEW_PR_NUMBER=$(GH_TOKEN=$GITHUB_PAT gh pr create \
  --repo $OWNER/$REPO \
  --base deploy \
  --head main \
  --title "$TITLE" \
  --body "" \
  --json number -q .number)

echo "✅ PR #$NEW_PR_NUMBER 생성 완료, 릴리스 노트 작성 시작..."
```

### 4단계: git diff 분석

워크플로우가 본문 초기화 + CodeRabbit 요청을 처리하는 동안, 스킬이 바로 커밋을 분석한다.

```bash
git fetch origin deploy 2>/dev/null || true
git log origin/deploy..HEAD --pretty=format:"%s" | grep -v "\[skip ci\]" | head -60
```

커밋 메시지를 타입별로 분류한다:

| prefix | 분류 |
|--------|------|
| `feat` | 새 기능 |
| `fix` | 버그 수정 |
| `refactor` / `perf` / `style` | 개선 |
| `docs` | 문서 |
| 나머지 | 기타 |

**커밋 메시지를 그대로 쓰지 않는다.** 이슈 제목, URL, 타입 prefix를 제거하고
핵심 변경 내용만 간결한 한국어로 재작성한다.

예시:
```
입력: 📄[문서][README/Docs] 전체 문서 개편 : docs : README 재구성·가치 어필 강화 https://...
출력: README 재구성 및 가치 어필 강화, SKILLS.md /commit 스킬 추가
```

### 5단계: PR 본문 업데이트

워크플로우가 파싱하는 형식과 100% 동일하게 작성해야 한다:

```bash
cat > /tmp/pr_release_notes.md << 'EOF'
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
EOF
```

항목이 없는 카테고리는 생략한다.

PR 본문 업데이트:

```bash
BODY=$(cat /tmp/pr_release_notes.md | $PYTHON -c "import sys,json; print(json.dumps(sys.stdin.read()))")
curl -s -H "Authorization: token $GITHUB_PAT" \
     -H "Content-Type: application/json" \
     -X PATCH -d "{\"body\": $BODY}" \
     "https://api.github.com/repos/$OWNER/$REPO/pulls/$NEW_PR_NUMBER"
```

### 6단계: 결과 안내

```
✅ PR #NNN 본문 업데이트 완료!

워크플로우가 폴링 중 "Summary by CodeRabbit"을 감지하면 automerge가 자동 진행됩니다.
GitHub Actions 탭에서 진행 상황을 확인하세요:
https://github.com/{owner}/{repo}/actions
```

## 주의사항

- 워크플로우가 PR 본문을 초기화하는 타이밍과 스킬이 본문을 올리는 타이밍이 겹칠 수 있다.
  만약 워크플로우가 본문을 다시 지워버리면 `/changelogfix`를 재실행한다.
- 10분이 지나도 automerge가 안 되면 스킬을 다시 실행한다.
