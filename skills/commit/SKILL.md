---
name: commit
description: "브랜치명에서 이슈 번호를 자동 추출해 커밋 메시지를 완성하고 커밋한다. 이슈 연동 커밋, 커밋 메시지 자동 생성이 필요할 때 사용. /commit 호출 시 사용."
---

# Commit Mode

브랜치명에서 이슈 번호를 추출하고, GitHub API로 이슈 정보를 조회해 **커밋 컨벤션에 맞는 메시지를 자동 완성하고 커밋**한다.

## 핵심 원칙

- **사용자 확인 없이 절대 커밋하지 않는다** — 메시지는 반드시 제안 후 승인받고 실행
- **이슈를 자동 생성하지 않는다** — 이슈 없으면 선택지 제시 후 사용자가 결정
- **staged 파일 없으면 `git add`를 대신하지 않는다** — 사용자가 직접 스테이징
- **`git push`는 절대 실행하지 않는다** — 커밋까지만 담당

## 시작 전

`references/common-rules.md`의 커밋 컨벤션 규칙을 숙지한다.

## 사용자 입력

$ARGUMENTS

## 프로세스

### 1단계: 환경 준비

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

### 2단계: staged 변경사항 확인

```bash
git diff --cached --stat
git status --short
```

staged 파일이 없으면 **즉시 멈추고** 선택지 제시:

```
커밋할 staged 파일이 없습니다.

어떻게 할까요?
1. 직접 git add 후 다시 /commit 실행할게요
2. 취소
```

선택을 기다린다. 절대 자동으로 `git add`하지 않는다.

### 3단계: 이슈 번호 자동 추출

브랜치명에서 이슈 번호를 추출한다:

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
ISSUE_NUMBER=$(echo "$BRANCH" | grep -oE '#[0-9]+' | grep -oE '[0-9]+' | head -1)
```

브랜치명 형식 예시: `20260422_#260_기능개선_제목` → 이슈 번호 `260` 추출

**이슈 번호가 추출된 경우** — GitHub API로 이슈 정보 조회:

```bash
REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
OWNER=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]([^/]+)/.*|\1|')
REPO=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/][^/]+/([^/.]+)(\.git)?$|\1|')
```

`references/config-rules.md` §2~3 절차로 config의 `github` 섹션에서 `global_pat` 읽기.

```bash
curl -s -H "Authorization: token {github_pat}" \
  "https://api.github.com/repos/{owner}/{repo}/issues/{ISSUE_NUMBER}"
```

응답에서 `title`, `html_url` 추출 → 4단계로 진행

**이슈 번호가 없는 경우** — 즉시 멈추고 선택지 제시:

```
브랜치명에서 이슈 번호를 찾을 수 없습니다. (현재 브랜치: {브랜치명})

어떻게 할까요?
1. 이슈 번호를 직접 입력할게요
2. 이슈 없이 자유 형식으로 커밋할게요
3. 취소
```

- **1 선택**: 이슈 번호 입력받아 GitHub API 조회 후 4단계 진행
- **2 선택**: 커밋 메시지 직접 입력받아 5단계로 진행 (이슈 형식 없이)
- **3 선택**: 종료

### 4단계: 변경사항 분석

staged 파일 목록과 diff를 분석하여 적절한 타입 추천:

| 변경 내용 | 추천 타입 |
|-----------|-----------|
| 새 기능, 새 파일 추가 | `feat` |
| 버그 수정, 에러 처리 | `fix` |
| 코드 구조 변경 (로직 유지) | `refactor` |
| 문서, 주석, README | `docs` |
| 설정 파일, 빌드 관련 | `chore` |
| 테스트 추가/수정 | `test` |
| 스타일, 포맷 | `style` |

### 5단계: 커밋 메시지 제안 후 사용자 확인

`references/common-rules.md` 커밋 컨벤션에 따라 메시지를 구성한 뒤 **제안만** 한다:

- 형식: `{이슈제목에서 이모지·태그 제거한 순수 내용} : {타입} : {변경사항 설명} {이슈URL}`
- 이모지·태그(`🚀[기능개선][ChangeLog]` 등)는 **반드시 제거**한다

```
📝 제안 커밋 메시지:

{완성된 커밋 메시지}

이 메시지로 커밋할까요?
1. 네, 커밋합니다
2. 타입을 바꾸고 싶어요 (feat/fix/refactor/docs/chore/test/style)
3. 설명을 직접 수정할게요
4. 취소
```

사용자 응답을 기다린다. **응답 전까지 커밋을 절대 실행하지 않는다.**

2 선택 시: 타입 목록 출력 후 입력받아 메시지 재구성 → 다시 확인 요청
3 선택 시: 설명 부분만 입력받아 메시지 재구성 → 다시 확인 요청

### 6단계: 커밋 실행

사용자가 1번(확인)을 선택한 경우에만 실행한다:

```bash
git commit -m "{최종 커밋 메시지}"
```

커밋 성공 후 결과 출력:

```
✅ 커밋 완료!
메시지: {커밋 메시지}
해시: {커밋 해시 앞 7자리}

push가 필요하면 직접 실행하세요:
git push origin {현재 브랜치명}
```
