---
name: github
description: "GitHub Mode - 독립적인 GitHub 제어 스킬. 이슈 조회, 댓글 추가, PR 생성/조회를 직접 수행한다. '/github', '이슈 확인해줘', 'PR 만들어줘', '댓글 달아줘' 등을 언급하면 이 skill을 사용한다."
---

# GitHub Mode

독립적인 GitHub 제어 스킬이다. 다른 스킬 없이 단독으로 GitHub 작업을 수행한다.

## 시작 전

**프로젝트 루트 확인**:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

**Config 확인** — `references/config-rules.md` §2~3 절차를 따른다.

- 파일이 존재하면 → repo 확인 후 해당 repo의 `pat`(non-null) 또는 `global_pat` 추출. PAT 준비 완료.
- 파일이 없으면 → `/issue` 스킬로 PAT를 먼저 등록하도록 안내한다 (`/issue` 스킬 실행 시 설정한 config가 이 스킬에서도 공유 사용된다).

**Repo 자동 감지**:

```bash
git remote get-url origin
```

`https://github.com/{owner}/{repo}.git` 또는 `git@github.com:{owner}/{repo}.git` 형식에서 `owner`와 `repo`를 추출한다. 감지 실패 시 config의 `repos` 목록에서 선택하게 한다.

## 사용자 입력

$ARGUMENTS

## 지원 작업

### 이슈 조회

config에서 읽은 PAT(`repos[].pat` 또는 `global_pat`)을 사용해 GitHub API를 직접 호출한다:

```bash
curl -s -H "Authorization: token {pat}" \
  "https://api.github.com/repos/{owner}/{repo}/issues/{이슈번호}"
```

`#번호` 형식이나 "이슈 427 확인해줘"처럼 번호를 명시하면 해당 이슈를 조회한다.

출력 예시:
```
#427 — ⚙️[기능추가][Skills] 드롭다운 디자인 변경
상태: open
URL: https://github.com/owner/repo/issues/427
```

### 이슈 수정

제목, 상태(open/closed), 라벨, 담당자 변경 가능:

```bash
curl -s -X PATCH \
  -H "Authorization: token {github_pat}" \
  -H "Content-Type: application/json" \
  -d "{\"title\": \"새 제목\", \"state\": \"closed\", \"labels\": [\"작업중\"], \"assignees\": [\"Cassiiopeia\"]}" \
  "https://api.github.com/repos/{owner}/{repo}/issues/{이슈번호}"
```

변경할 항목만 JSON body에 포함하면 된다. 나머지는 기존 값 유지.

### 이슈에 댓글 추가

```bash
curl -s -X POST \
  -H "Authorization: token {github_pat}" \
  -H "Content-Type: application/json" \
  -d "{\"body\": \"{댓글 내용}\"}" \
  "https://api.github.com/repos/{owner}/{repo}/issues/{이슈번호}/comments"
```

### PR 생성

현재 브랜치 이름을 자동 감지하여 PR을 생성한다:

```bash
git rev-parse --abbrev-ref HEAD  # head 브랜치 확인
curl -s -X POST \
  -H "Authorization: token {github_pat}" \
  -H "Content-Type: application/json" \
  -d "{\"title\": \"{제목}\", \"body\": \"{본문}\", \"head\": \"{head}\", \"base\": \"main\"}" \
  "https://api.github.com/repos/{owner}/{repo}/pulls"
```

PR 제목은 사용자가 명시하지 않으면 현재 브랜치명의 이슈 제목을 기반으로 자동 생성한다.
브랜치명이 `YYYYMMDD_#번호_제목` 형식이면 번호를 추출해 이슈 API로 제목을 조회한다.

### PR 목록 조회

```bash
curl -s -H "Authorization: token {github_pat}" \
  "https://api.github.com/repos/{owner}/{repo}/pulls?state=open"
# 닫힌 PR 포함: ?state=closed 또는 ?state=all
```

### PR 릴리스 노트 업데이트 (CodeRabbit 폴백)

deploy PR에 CodeRabbit Summary가 없을 때 Claude Code가 직접 커밋을 분석하여 한국어 릴리스 노트를 작성하고 PR 본문에 업데이트한다.

"릴리스 노트 업데이트해줘", "changelog 폴백", "PR 본문 업데이트" 등의 요청 시 실행.

**절차**:

1. PR 번호 확인 (사용자 입력 또는 최근 deploy PR 자동 조회)

```bash
curl -s -H "Authorization: token {github_pat}" \
  "https://api.github.com/repos/{owner}/{repo}/pulls?state=open"
```

2. deploy 브랜치 대비 커밋 목록 수집

```bash
git fetch origin deploy 2>/dev/null || true
git log origin/deploy..HEAD --pretty=format:"%H %s" | grep -v "\[skip ci\]" | head -60
```

3. 커밋 메시지를 분석하여 한국어 릴리스 노트 작성

   - `feat:` → 새 기능
   - `fix:` → 버그 수정
   - `refactor:` / `perf:` / `style:` → 개선
   - `docs:` → 문서
   - 나머지 → 기타
   - 커밋 메시지를 그대로 쓰지 말고 사용자가 이해하기 쉬운 한국어 문장으로 재작성

4. PR 본문을 다음 형식으로 작성 후 `/tmp/pr_release_notes.md`에 저장:

```markdown
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

<!-- end of auto-generated comment: release notes by coderabbit.ai -->
```

5. PR 본문 업데이트

```bash
curl -s -X PATCH \
  -H "Authorization: token {github_pat}" \
  -H "Content-Type: application/json" \
  -d "{\"body\": \"{릴리스 노트 본문}\"}" \
  "https://api.github.com/repos/{owner}/{repo}/pulls/{pr_number}"
```

## 오류 처리

| 오류 코드 | 의미 | 대응 |
|-----------|------|------|
| `missing_pat` | GITHUB_PAT 미설정 | `/issue` 스킬로 PAT 등록 안내 |
| `github_api_401` | PAT 인증 실패 | PAT 갱신 안내 |
| `github_api_404` | 이슈/PR 없음 | 번호 재확인 요청 |
| `github_api_422` | 이미 PR 존재 등 | API 오류 메시지 그대로 안내 |
