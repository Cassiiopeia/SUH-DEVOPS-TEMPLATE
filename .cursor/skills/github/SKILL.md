---
name: github
description: "GitHub Mode - 독립적인 GitHub 제어 스킬. 이슈 조회, 댓글 추가, PR 생성/조회를 직접 수행한다. '/github', '이슈 확인해줘', 'PR 만들어줘', '댓글 달아줘' 등을 언급하면 이 skill을 사용한다."
---

# GitHub Mode

독립적인 GitHub 제어 스킬이다. 다른 스킬 없이 단독으로 GitHub 작업을 수행한다.

## 시작 전

**프로젝트 루트 및 PYTHONPATH 설정**:

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

이후 모든 `python3 -m suh_template.cli` 호출 시 `PYTHONPATH="$PROJECT_ROOT/scripts"` 를 앞에 붙인다.

**Config 확인**:

```bash
PYTHONPATH="$PROJECT_ROOT/scripts" python3 -m suh_template.cli config-get issue github_pat
```

- 값이 반환되면 → PAT 준비 완료.
- `config_not_found` 에러 → issue 스킬의 Config 설정 절차를 안내한다 (`/issue` 스킬을 먼저 실행하여 PAT를 등록하면 이 스킬에서도 공유 사용된다).

**Repo 자동 감지**:

```bash
git remote get-url origin
```

`https://github.com/{owner}/{repo}.git` 또는 `git@github.com:{owner}/{repo}.git` 형식에서 `owner`와 `repo`를 추출한다. 감지 실패 시 config의 `github_repos` 목록에서 선택하게 한다.

## 사용자 입력

$ARGUMENTS

## 지원 작업

### 이슈 조회

```bash
GITHUB_PAT={pat} PYTHONPATH="$PROJECT_ROOT/scripts" python3 -m suh_template.cli get-issue {owner} {repo} {이슈번호}
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
GITHUB_PAT={pat} PYTHONPATH="$PROJECT_ROOT/scripts" python3 -m suh_template.cli update-issue {owner} {repo} {이슈번호} \
  --title "새 제목" \
  --state closed \
  --labels "작업중" \
  --assignees "Cassiiopeia"
```

변경할 항목만 옵션으로 전달하면 된다. 나머지는 기존 값 유지.

### 이슈에 댓글 추가

사용자가 댓글 내용을 주면 임시 파일에 저장 후 포스팅한다:

```bash
GITHUB_PAT={pat} PYTHONPATH="$PROJECT_ROOT/scripts" python3 -m suh_template.cli add-comment {owner} {repo} {이슈번호} /tmp/comment.md
```

### PR 생성

현재 브랜치 이름을 자동 감지하여 PR을 생성한다:

```bash
git rev-parse --abbrev-ref HEAD  # head 브랜치 확인
GITHUB_PAT={pat} PYTHONPATH="$PROJECT_ROOT/scripts" python3 -m suh_template.cli create-pr {owner} {repo} "{제목}" /tmp/pr_body.md {head} main
```

PR 제목은 사용자가 명시하지 않으면 현재 브랜치명의 이슈 제목을 기반으로 자동 생성한다.
브랜치명이 `YYYYMMDD_#번호_제목` 형식이면 `PYTHONPATH="$PROJECT_ROOT/scripts" python3 -m suh_template.cli get-issue-number`로 이슈 번호를 추출하고 이슈 조회로 제목을 가져온다.

### PR 목록 조회

```bash
GITHUB_PAT={pat} PYTHONPATH="$PROJECT_ROOT/scripts" python3 -m suh_template.cli list-prs {owner} {repo}
# 닫힌 PR 포함: --state closed 또는 --state all
```

### PR 릴리스 노트 업데이트 (CodeRabbit 폴백)

deploy PR에 CodeRabbit Summary가 없을 때 Claude Code가 직접 커밋을 분석하여 한국어 릴리스 노트를 작성하고 PR 본문에 업데이트한다.

"릴리스 노트 업데이트해줘", "changelog 폴백", "PR 본문 업데이트" 등의 요청 시 실행.

**절차**:

1. PR 번호 확인 (사용자 입력 또는 최근 deploy PR 자동 조회)

```bash
GITHUB_PAT={pat} PYTHONPATH="$PROJECT_ROOT/scripts" python3 -m suh_template.cli list-prs {owner} {repo} --state open
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
GITHUB_PAT={pat} PYTHONPATH="$PROJECT_ROOT/scripts" python3 -m suh_template.cli update-pr-body {owner} {repo} {pr_number} /tmp/pr_release_notes.md
```

> `update-pr-body` 커맨드가 없는 경우 GitHub API 직접 호출:
> ```bash
> BODY=$(cat /tmp/pr_release_notes.md | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))")
> curl -s -H "Authorization: token {pat}" -H "Content-Type: application/json" \
>      -X PATCH -d "{\"body\": $BODY}" \
>      "https://api.github.com/repos/{owner}/{repo}/pulls/{pr_number}"
> ```

## 오류 처리

| 오류 코드 | 의미 | 대응 |
|-----------|------|------|
| `missing_pat` | GITHUB_PAT 미설정 | `/issue` 스킬로 PAT 등록 안내 |
| `github_api_401` | PAT 인증 실패 | PAT 갱신 안내 |
| `github_api_404` | 이슈/PR 없음 | 번호 재확인 요청 |
| `github_api_422` | 이미 PR 존재 등 | API 오류 메시지 그대로 안내 |
