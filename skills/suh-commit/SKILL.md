---
name: suh-commit
description: "브랜치명에서 이슈 번호를 자동 추출해 커밋 메시지를 완성하고 커밋한다. 이슈 연동 커밋, 커밋 메시지 자동 생성이 필요할 때 사용. /suh-commit 호출 시 사용."
---

# Commit Mode

브랜치명에서 이슈 번호를 추출하고, GitHub API로 이슈 정보를 조회해 **커밋 컨벤션에 맞는 메시지를 자동 완성하고 커밋**한다.

## 핵심 원칙

- **사용자 확인 없이 절대 커밋하지 않는다** — 메시지는 반드시 제안 후 승인받고 실행
- **이슈를 자동 생성하지 않는다** — 이슈 없으면 선택지 제시 후 사용자가 결정
- **staged 파일이 없으면 변경 파일을 자동으로 `git add`한다** — 사용자가 멈춰서 직접 스테이징할 필요 없음
- **`git push`는 절대 실행하지 않는다** — 커밋까지만 담당 (CLAUDE.md 규칙: push는 명시 허락 시에만)
- **커밋에 Claude/AI 흔적을 절대 남기지 않는다** — `Co-Authored-By`, `Generated with Claude`, `🤖` 등 AI 서명/푸터 일절 금지. 사용자의 git 설정으로만 커밋되어 사용자가 직접 작성한 것처럼 보여야 한다. 커밋 메시지는 본문만 작성한다.

## 시작 전

`references/common-rules.md`의 커밋 컨벤션 규칙을 숙지한다.

## 사용자 입력

$ARGUMENTS

## 프로세스

### 1단계: 환경 준비

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

### 2단계: 변경사항 확인 및 스테이징

```bash
git diff --cached --stat
git status --short
```

**staged 파일이 있으면** 그대로 진행한다.

**staged 파일이 없으면** 변경된(추적/미추적) 파일을 자동으로 스테이징한다:

```bash
git add -A
```

스테이징 후 다시 확인하고 진행한다:

```bash
git diff --cached --stat
```

> 이슈별로 따로 커밋하려는 경우(사용자가 명시), 해당 이슈 관련 파일만 골라서 `git add <파일들>` 한다. 그 외엔 `git add -A`로 일괄 스테이징한다.

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

**이슈 조회는 인라인 Python으로 하지 않는다.** 재사용 스크립트 `suh_command`의 `get-issue`로 이슈 정보를 가져온다. PAT는 `suh_command`가 config.json에서 자동 로드하므로 직접 추출할 필요가 없다(환경변수가 있으면 우선 사용).

```bash
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
cd "$PROJECT_ROOT/scripts"
PYTHONIOENCODING=utf-8 "$PYTHON" -m suh_template.suh_command get-issue {owner} {repo} {추출된 이슈번호}
```

출력 JSON에서 `title`(원본 제목)과 `html_url`을 얻는다. **이슈 제목은 agent가 임의 요약/재작성하지 않고**, 아래 규칙으로 결정적으로 정제해 커밋 메시지에 쓴다 (SUH-ISSUE-HELPER의 `extractIssueTitle`과 동일):

1. `[태그]` 형식(`[버그]`, `[기능개선]` 등)을 모두 제거
2. 앞에 붙은 이모지·제어문자(So/VS16/ZWJ)를 제거
3. 앞뒤 공백 trim — 결과가 비면 원본 제목을 그대로 사용

`get-issue`가 `[ERROR] ... github_api_401`(PAT 만료) 또는 `github_api_404`(이슈 없음)을 stderr로 내면, 그 사유를 안내하고 사용자에게 제목을 직접 입력받는다. → 4단계로 진행

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

`references/common-rules.md` 커밋 컨벤션에 따라 메시지를 구성한 뒤 **제안만** 한다.

**형식**: `{clean_title} : {타입} : {변경설명} {html_url}`

| 부분 | 결정 방식 |
|------|-----------|
| `clean_title` | 3단계 정적 추출 스크립트의 `clean_title` **그대로** — agent가 다시 요약/재작성하지 않는다 |
| `html_url` | 3단계 스크립트의 `html_url` **그대로** |
| `{타입}` | 4단계 diff 분석으로 agent 추천 (사용자 승인) |
| `{변경설명}` | staged diff 분석으로 agent 작성 (사용자 승인) |

- agent가 자유 판단하는 부분은 **타입과 변경설명뿐**이다. 제목·URL은 이슈 원본에서 정규식으로 정리한 값을 손대지 않고 사용한다.
- 이슈 없이 자유 형식으로 커밋하는 경우(3단계 2선택)에만 제목을 직접 입력받는다.

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

사용자가 1번(확인)을 선택한 경우에만 실행한다.

**커밋 메시지에 AI 서명/푸터를 절대 추가하지 않는다.** `Co-Authored-By`, `Generated with Claude`, `🤖` 등 금지. 아래 명령 외에 `--author` 옵션이나 추가 trailer를 붙이지 않는다 — 사용자 git 설정 그대로 커밋한다:

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
