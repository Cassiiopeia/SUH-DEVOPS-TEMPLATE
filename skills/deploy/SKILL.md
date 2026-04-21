---
name: deploy
description: "main 브랜치를 push하고 deploy PR을 생성한 뒤 즉시 릴리스 노트를 작성해 AUTO-CHANGELOG-CONTROL 워크플로우가 CodeRabbit 10분 대기 없이 automerge를 진행하게 한다. 'deploy해줘', '배포해줘', 'deploy PR 올려줘' 등의 요청 시 사용."
---

# Deploy Mode

main 브랜치 push → deploy PR 생성 → 릴리스 노트 즉시 작성 → automerge 자동 진행.

CodeRabbit 10분 대기 없이 스킬이 직접 릴리스 노트를 작성하므로,
워크플로우 폴링 중 `Summary by CodeRabbit`을 감지하면 즉시 automerge가 진행된다.

## 핵심 원칙

- **사용자 확인 없이 push하지 않는다** — push 전 staged/unstaged 상태 확인 후 승인받기
- **커밋되지 않은 변경사항이 있으면 push하지 않는다** — 사용자에게 먼저 커밋 요청
- `git push --force`는 절대 실행하지 않는다

## 시작 전

**Config 확인** — `references/config-rules.md` §2~3 절차를 따른다 (`skill_id = issue`).

파일에서 `github_pat`을 추출한다. 파일이 없으면 `/issue` 스킬로 PAT 등록을 먼저 안내한다.

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
OWNER=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]([^/]+)/.*|\1|')
REPO=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/][^/]+/([^/.]+)(\.git)?$|\1|')
```

## 사용자 입력

$ARGUMENTS

## 프로세스

### 1단계: 커밋 상태 확인

```bash
git status --short
git log origin/main..HEAD --oneline 2>/dev/null || git log --oneline -5
```

- 미커밋 변경사항이 있으면 **즉시 멈추고** 안내:
  ```
  커밋되지 않은 변경사항이 있습니다. 먼저 커밋 후 다시 실행해주세요.
  /cassiiopeia:commit 으로 커밋할 수 있습니다.
  ```
- push할 커밋이 없으면 "push할 커밋이 없습니다" 안내 후 종료

### 2단계: push 전 확인

push할 커밋 목록을 보여주고 사용자 승인받기:

```
📋 push할 커밋:
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

push 완료 후 VERSION-CONTROL 워크플로우가 자동 트리거되어 버전이 증가한다.

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
  PR_NUMBER=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_PAT" \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"$TITLE\",\"head\":\"main\",\"base\":\"deploy\",\"body\":\"\"}" \
    "https://api.github.com/repos/$OWNER/$REPO/pulls" \
    | grep -o '"number":[0-9]*' | head -1 | grep -o '[0-9]*')
  echo "새 deploy PR #$PR_NUMBER 생성"
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

**커밋 메시지를 그대로 쓰지 않는다.** 이슈 제목, URL, 타입 prefix를 제거하고
핵심 변경 내용만 간결한 한국어로 재작성한다.

예시:
```
입력: 📄[문서][README/Docs] 전체 문서 개편 : docs : README 재구성·가치 어필 강화 https://...
출력: README 재구성 및 가치 어필 강화, SKILLS.md /commit 스킬 추가
```

### 6단계: PR 본문 업데이트

워크플로우가 파싱하는 형식과 100% 동일하게 작성:

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

BODY=$(cat /tmp/pr_release_notes.md | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null || cat /tmp/pr_release_notes.md | python -c "import sys,json; print(json.dumps(sys.stdin.read()))")
curl -s -H "Authorization: token {config에서 읽은 github_pat}" \
     -H "Content-Type: application/json" \
     -X PATCH -d "{\"body\": $BODY}" \
     "https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER"
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

## 주의사항

- 워크플로우가 PR 본문을 초기화하는 타이밍과 스킬이 본문을 올리는 타이밍이 겹칠 수 있다.
  만약 워크플로우가 본문을 다시 지워버리면 `/cassiiopeia:changelogfix`를 실행한다.
- deploy PR이 이미 있으면 닫지 않고 재사용한다 — 새로 열면 워크플로우가 다시 트리거되어 본문이 초기화될 수 있다.
