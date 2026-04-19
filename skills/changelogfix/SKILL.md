---
name: changelogfix
description: "deploy PR의 automerge가 실패했을 때 기존 PR을 닫고 새 PR을 열어 AUTO-CHANGELOG-CONTROL 워크플로우를 재트리거한다. 'changelogfix', 'deploy 머지 안 됐어', 'PR 다시 열어줘', 'changelog 재실행' 등의 요청 시 사용."
---

# Changelog Fix Mode

deploy PR의 automerge가 실패했거나 워크플로우가 정상 동작하지 않을 때,
기존 PR을 닫고 새 PR을 열어 `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` 워크플로우를 재트리거한다.

**왜 이 방법인가**: 워크플로우는 `pull_request_target: [opened]`에만 트리거된다.
PR 본문을 수동으로 수정해도 워크플로우가 다시 돌지 않는다.
새 PR을 열어야 전체 파이프라인(CodeRabbit 대기 → 폴백 → automerge)이 재실행된다.

## 핵심 원칙

- **사용자 확인 없이 PR을 닫거나 열지 않는다**
- `git push`는 절대 실행하지 않는다

## 시작 전

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
GITHUB_PAT=$(PYTHONPATH="$PROJECT_ROOT/scripts" python3 -m suh_template.cli config-get issue github_pat)
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

GH_TOKEN=$GITHUB_PAT gh pr create \
  --repo $OWNER/$REPO \
  --base deploy \
  --head main \
  --title "$TITLE" \
  --body ""
```

### 4단계: 결과 안내

```
✅ 새 PR #NNN 생성 완료!

PROJECT-COMMON-AUTO-CHANGELOG-CONTROL 워크플로우가 자동 트리거됩니다.
- CodeRabbit Summary 최대 10분 대기
- 없으면 커밋 분석 폴백 자동 실행
- 완료 시 deploy 브랜치 자동 머지

GitHub Actions 탭에서 진행 상황을 확인하세요:
https://github.com/{owner}/{repo}/actions
```

## 주의사항

- 워크플로우가 PR 본문을 즉시 빈 문자열로 초기화하고 제목도 변경한다 — 정상 동작
- 10분 이상 기다려도 automerge가 안 되면 이 스킬을 다시 실행하거나
  `/github` 스킬로 PR 상태를 확인한다
