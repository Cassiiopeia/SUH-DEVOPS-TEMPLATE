---
name: github
description: "GitHub Mode - 독립적인 GitHub 제어 스킬. 이슈 조회, 댓글 추가, PR 생성/조회를 직접 수행한다. '/github', '이슈 확인해줘', 'PR 만들어줘', '댓글 달아줘' 등을 언급하면 이 skill을 사용한다."
---

# GitHub Mode

독립적인 GitHub 제어 스킬이다. 다른 스킬 없이 단독으로 GitHub 작업을 수행한다.

## 시작 전

**Config 확인**:

```bash
python3 -m suh_template.cli config-get issue github_pat
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
GITHUB_PAT={pat} python3 -m suh_template.cli get-issue {owner} {repo} {이슈번호}
```

`#번호` 형식이나 "이슈 427 확인해줘"처럼 번호를 명시하면 해당 이슈를 조회한다.

출력 예시:
```
#427 — ⚙️[기능추가][Skills] 드롭다운 디자인 변경
상태: open
URL: https://github.com/owner/repo/issues/427
```

### 이슈에 댓글 추가

사용자가 댓글 내용을 주면 임시 파일에 저장 후 포스팅한다:

```bash
GITHUB_PAT={pat} python3 -m suh_template.cli add-comment {owner} {repo} {이슈번호} /tmp/comment.md
```

### PR 생성

현재 브랜치 이름을 자동 감지하여 PR을 생성한다:

```bash
git rev-parse --abbrev-ref HEAD  # head 브랜치 확인
GITHUB_PAT={pat} python3 -m suh_template.cli create-pr {owner} {repo} "{제목}" /tmp/pr_body.md {head} main
```

PR 제목은 사용자가 명시하지 않으면 현재 브랜치명의 이슈 제목을 기반으로 자동 생성한다.
브랜치명이 `YYYYMMDD_#번호_제목` 형식이면 `python3 -m suh_template.cli get-issue-number`로 이슈 번호를 추출하고 이슈 조회로 제목을 가져온다.

### PR 목록 조회

repo의 열린 PR 목록은 GitHub API를 직접 호출한다:

```bash
GITHUB_PAT={pat} python3 -c "
import sys; sys.path.insert(0, 'scripts')
import urllib.request, json
url = 'https://api.github.com/repos/{owner}/{repo}/pulls?state=open'
req = urllib.request.Request(url, headers={
    'Authorization': f'Bearer {pat}',
    'Accept': 'application/vnd.github+json',
})
with urllib.request.urlopen(req) as r:
    prs = json.loads(r.read())
    for pr in prs:
        print(f\"#{pr['number']} — {pr['title']}\")
"
```

## 오류 처리

| 오류 코드 | 의미 | 대응 |
|-----------|------|------|
| `missing_pat` | GITHUB_PAT 미설정 | `/issue` 스킬로 PAT 등록 안내 |
| `github_api_401` | PAT 인증 실패 | PAT 갱신 안내 |
| `github_api_404` | 이슈/PR 없음 | 번호 재확인 요청 |
| `github_api_422` | 이미 PR 존재 등 | API 오류 메시지 그대로 안내 |
