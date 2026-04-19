---
name: commit
description: "이슈 컨텍스트를 기반으로 커밋 메시지를 자동 완성하고 커밋한다. 이슈 연동 커밋, 커밋 메시지 자동 생성이 필요할 때 사용. /commit 호출 시 사용."
---

# Commit Mode

이슈 컨텍스트를 읽어 **프로젝트 커밋 컨벤션에 맞는 메시지를 자동 완성하고 커밋**한다.

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

staged 파일이 없으면 사용자에게 안내하고 종료:
```
커밋할 staged 파일이 없습니다.
git add <파일> 로 파일을 추가한 후 다시 실행하세요.
```

### 3단계: 이슈 컨텍스트 로드

```bash
CONTEXT_FILE="$PROJECT_ROOT/.suh-template/context/current-issue.json"
```

**컨텍스트가 있는 경우** (`current-issue.json` 존재):
- `issue_title`, `issue_url`, `issue_number`, `commit_template` 읽기
- 기본 커밋 메시지 템플릿:
  ```
  {issue_title} : {타입} : {설명} {issue_url}
  ```

**컨텍스트가 없는 경우**:
- 사용자에게 이슈 정보를 물어본다:
  ```
  이슈 컨텍스트가 없습니다. 어떻게 진행할까요?
  1. 이슈 번호 입력 (GitHub에서 정보 조회)
  2. 이슈 없이 커밋 (자유 형식)
  ```
- 1 선택: 이슈 번호 입력받아 `get-issue`로 제목/URL 조회
- 2 선택: 자유 형식 커밋 메시지 직접 입력받아 커밋

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

### 5단계: 커밋 메시지 제안

이슈 컨텍스트와 변경사항 분석을 합쳐 커밋 메시지를 완성하여 제안한다:

```
📝 제안 커밋 메시지:

{issue_title} : {추천타입} : {변경사항 요약} {issue_url}

이 메시지로 커밋할까요?
1. 네, 커밋합니다
2. 타입을 바꾸고 싶어요 (feat/fix/refactor/docs/chore/test/style)
3. 설명을 직접 수정할게요
4. 취소
```

### 6단계: 커밋 실행

사용자가 확인하면 커밋을 실행한다:

```bash
git commit -m "{최종 커밋 메시지}"
```

커밋 성공 후 결과 출력:
```
✅ 커밋 완료!
메시지: {커밋 메시지}
해시: {커밋 해시 앞 7자리}
```

## 중요 규칙

- **staged 파일이 없으면 `git add`를 대신 실행하지 않는다** — 사용자가 직접 스테이징한다
- **`git push`는 절대 실행하지 않는다** — 커밋까지만 담당
- 이슈 컨텍스트 없이도 동작하며, 이 경우 자유 형식 커밋을 지원한다
- 커밋 메시지는 반드시 사용자 확인 후 실행한다
