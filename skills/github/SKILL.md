---
name: github
description: "GitHub Mode - 독립적인 GitHub 제어 스킬. 이슈 조회/수정/댓글, PR 생성/조회/릴리스노트, 레포 탐색을 수행한다. PR 생성, PR 올려줘, 이슈 댓글, 댓글 달아줘, 이슈 확인해줘, 이슈 닫아줘, 이슈 수정해줘, 라벨 바꿔줘, '/github', 내 레포 보여줘, 레포 목록 탐색해줘, README 가져와줘, {레포명} 정보 봐줘, Org 레포 탐색해줘 등을 언급하면 반드시 이 skill을 사용한다. 다른 스킬보다 먼저 트리거되어야 한다."
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

`https://github.com/{owner}/{repo}.git` 또는 `git@github.com:{owner}/{repo}.git` 형식에서 `owner`와 `repo`를 추출한다.

추출한 `owner/repo`를 config `repos` 배열과 대조한다:
- 매칭되는 항목이 있으면 → 해당 repo 사용
- 매칭 실패 시 → config `repos` 목록을 번호로 나열해 사용자가 선택하게 한다
- **`$ARGUMENTS`에 `owner/repo` 형식이 명시된 경우 → git remote 감지를 건너뛰고 해당 repo를 바로 사용한다**

> 주의: Claude Code의 primary working directory가 작업 대상 레포와 다른 경우(멀티 레포 워크트리 환경) git remote 감지가 오작동할 수 있다. 이 경우 arguments로 대상 레포를 명시하거나 config repos 목록에서 선택한다.

## 사용자 입력

$ARGUMENTS

## 지원 작업

### 이슈 조회

config에서 읽은 PAT(`repos[].pat` 또는 `global_pat`)을 사용해 GitHub API를 직접 호출한다.

`#번호` 형식이나 "이슈 427 확인해줘"처럼 번호를 명시하면 해당 이슈를 조회한다.

**Windows Git Bash에서 `curl | python3` 파이프는 Exit code 49 오류가 발생한다. 반드시 파일로 저장 후 파싱한다:**

```bash
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
curl -s -H "Authorization: token {pat}" \
  "https://api.github.com/repos/{owner}/{repo}/issues/{이슈번호}" -o /tmp/issue_result.json
PYTHONIOENCODING=utf-8 $PYTHON - <<'EOF'
import json
d = json.load(open("/tmp/issue_result.json", encoding="utf-8"))
print(f"#{d['number']} — {d['title']}")
print(f"상태: {d['state']}")
print(f"URL: {d['html_url']}")
EOF
```

출력 예시:
```
#427 — ⚙️[기능추가][Skills] 드롭다운 디자인 변경
상태: open
URL: https://github.com/owner/repo/issues/427
```

### 이슈 수정

제목, 상태(open/closed), 라벨, 담당자 변경 가능.
변경할 항목만 payload dict에 포함하면 된다. 나머지는 기존 값 유지.

```bash
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
$PYTHON - <<'EOF'
import urllib.request, json
pat = "{github_pat}"
url = "https://api.github.com/repos/{owner}/{repo}/issues/{이슈번호}"
payload = {"title": "새 제목", "state": "closed", "labels": ["작업중"], "assignees": ["Cassiiopeia"]}
data = json.dumps(payload).encode()
req = urllib.request.Request(url, data=data, method="PATCH")
req.add_header("Authorization", f"token {pat}")
req.add_header("Content-Type", "application/json")
res = urllib.request.urlopen(req)
print(json.loads(res.read())["html_url"])
EOF
```

### 이슈에 댓글 추가

본문에 한국어·이모지·줄바꿈이 포함될 수 있으므로 Python urllib로 직접 전송한다 (curl 인라인 이스케이프 문제 방지).

```bash
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
$PYTHON - <<'EOF'
import urllib.request, json
pat = "{github_pat}"
url = "https://api.github.com/repos/{owner}/{repo}/issues/{이슈번호}/comments"
body = """댓글 내용을 여기에 작성
여러 줄도 가능하고 이모지도 OK"""
data = json.dumps({"body": body}).encode()
req = urllib.request.Request(url, data=data, method="POST")
req.add_header("Authorization", f"token {pat}")
req.add_header("Content-Type", "application/json")
res = urllib.request.urlopen(req)
print(json.loads(res.read())["html_url"])
EOF
```

### PR 생성

현재 브랜치 이름을 자동 감지하여 PR을 생성한다.

**PR 생성 전 반드시 remote 브랜치 존재 여부를 확인한다 (한글 브랜치명 422 오류 방지):**

```bash
HEAD_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git ls-remote --heads origin "$HEAD_BRANCH" | grep -q "$HEAD_BRANCH" || echo "브랜치가 remote에 없습니다. git push 먼저 실행하세요."
```

`head` 필드는 반드시 `owner:branch` 형식으로 지정한다 (한글 포함 브랜치명의 422 오류 방지):

```bash
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
PYTHONIOENCODING=utf-8 $PYTHON - <<'EOF'
import urllib.request, json
pat = "{github_pat}"
url = "https://api.github.com/repos/{owner}/{repo}/pulls"
payload = {
    "title": "{제목}",
    "body": "{본문}",
    "head": "{owner}:{head_branch}",
    "base": "main"
}
data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
req = urllib.request.Request(url, data=data, method="POST")
req.add_header("Authorization", f"token {pat}")
req.add_header("Content-Type", "application/json; charset=utf-8")
res = urllib.request.urlopen(req)
print(json.loads(res.read().decode("utf-8"))["html_url"])
EOF
```

#### PR 제목 규칙 (필수)

브랜치명이 `YYYYMMDD_#번호_제목` 형식이면 번호를 추출해 이슈 API로 제목을 조회한다.
조회한 이슈 제목에서 **앞에 붙은 이모지와 `[태그]` 형식을 모두 제거**한 순수 텍스트만 PR 제목으로 사용한다.

예) 이슈 제목이 `❗[버그][개발자도구] SSE 서버 로그 스트리밍 연결 즉시 종료 및 구독자 누적 문제`이면
→ PR 제목: `SSE 서버 로그 스트리밍 연결 즉시 종료 및 구독자 누적 문제`

#### PR 본문 규칙 (필수)

PR 본문에는 반드시 관련 이슈 링크를 포함한다:

```
- https://github.com/{owner}/{repo}/issues/{이슈번호}
```

이슈 번호는 브랜치명(`YYYYMMDD_#번호_...`)에서 자동 추출한다.

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

4. 릴리스 노트 본문을 아래 형식으로 작성한 뒤 Python urllib로 직접 PATCH 전송 (임시 파일 불필요):

```bash
PYTHON=$(for _py in python3 python; do _path=$(command -v "$_py" 2>/dev/null) || continue; "$_path" -c "import sys; sys.exit(0)" 2>/dev/null && echo "$_path" && break; done)
$PYTHON - <<'EOF'
import urllib.request, json
pat = "{github_pat}"
url = "https://api.github.com/repos/{owner}/{repo}/pulls/{pr_number}"
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

<!-- end of auto-generated comment: release notes by coderabbit.ai -->"""
data = json.dumps({"body": body}).encode()
req = urllib.request.Request(url, data=data, method="PATCH")
req.add_header("Authorization", f"token {pat}")
req.add_header("Content-Type", "application/json")
res = urllib.request.urlopen(req)
print(json.loads(res.read())["html_url"])
EOF
```

---

## explore 모드

GitHub 유저 또는 Organization의 레포 목록과 개별 레포 상세 정보를 조회한다.
출력 포맷을 strict하게 강제하지 않으며, agent가 데이터를 받아 스스로 판단한다.

"내 레포 보여줘", "레포 목록 탐색해줘", "README 가져와줘", "{레포명} 정보 봐줘", "Org 레포 탐색해줘" 등의 요청 시 실행.

### Phase 0 — Owner 결정

**Python 실행 파일 결정** (OS별 분기):

- **macOS / Linux**:
  ```bash
  PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
  ```
- **Windows (PowerShell)**: `command -v` 미지원. 아래로 대체:
  ```powershell
  $PYTHON = if (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" } else { "python" }
  ```

**Owner 결정 규칙**:

1. "내 레포", owner 미명시 → PAT 소유자 자동 사용. PAT 소유자는 항상 User 타입이므로 타입 판별 불필요.
   ```bash
   curl -s -H "Authorization: token {github_pat}" "https://api.github.com/user" \
     | $PYTHON -c "import sys,json; print(json.load(sys.stdin).get('login',''))"
   ```
   → 이후 `/users/{owner}/repos` 엔드포인트 직접 사용.

2. owner 명시 ("TEAM-ROMROM", "Cassiiopeia" 등) → 해당 owner 사용. **이 경우에만** 타입 판별 실행:
   ```bash
   curl -s -H "Authorization: token {github_pat}" "https://api.github.com/users/{owner}" \
     | $PYTHON -c "import sys,json; print(json.load(sys.stdin).get('type','User'))"
   # "User" → /users/{owner}/repos
   # "Organization" → /orgs/{owner}/repos
   ```

### Phase 1 — 레포 목록 조회

```bash
# User 타입
curl -s -H "Authorization: token {github_pat}" \
  "https://api.github.com/users/{owner}/repos?per_page=100&sort=updated" \
  | $PYTHON -c "
import sys, json
repos = json.load(sys.stdin)
if isinstance(repos, dict):
    print('ERROR:', repos.get('message', ''))
else:
    for r in repos:
        topics = ', '.join(r.get('topics') or [])
        desc = (r.get('description') or '').replace('|', '-')
        print(f\"name={r['name']} | desc={desc} | lang={r.get('language') or '?'} | stars={r['stargazers_count']} | updated={r['updated_at'][:10]} | fork={r['fork']} | private={r['private']} | url={r['html_url']} | topics={topics}\")
"

# Organization 타입
curl -s -H "Authorization: token {github_pat}" \
  "https://api.github.com/orgs/{owner}/repos?per_page=100&sort=updated" \
  | $PYTHON -c "
import sys, json
repos = json.load(sys.stdin)
if isinstance(repos, dict):
    print('ERROR:', repos.get('message', ''))
else:
    for r in repos:
        topics = ', '.join(r.get('topics') or [])
        desc = (r.get('description') or '').replace('|', '-')
        print(f\"name={r['name']} | desc={desc} | lang={r.get('language') or '?'} | stars={r['stargazers_count']} | updated={r['updated_at'][:10]} | fork={r['fork']} | private={r['private']} | url={r['html_url']} | topics={topics}\")
"
```

**필터링**: 사용자가 "fork 제외", "Java만", "stars 높은 순" 등을 요청하면
별도 API 재호출 없이 위 결과에서 agent가 직접 필터링한다.

### Phase 2 — 단일 레포 상세 조회

특정 레포명이 언급되면 아래 4개 정보를 순서대로 수집한다.
각 호출은 독립적으로 실행하며, 하나가 실패해도 나머지는 계속 진행한다.

**2-1. 기본 메타정보**

```bash
curl -s -H "Authorization: token {github_pat}" \
  "https://api.github.com/repos/{owner}/{repo}" \
  | $PYTHON -c "
import sys, json
r = json.load(sys.stdin)
if r.get('message'):
    print('ERROR:', r['message'])
else:
    print('name:', r['name'])
    print('description:', r.get('description') or '')
    print('language:', r.get('language') or '?')
    print('stars:', r['stargazers_count'], '| forks:', r['forks_count'])
    print('open_issues:', r['open_issues_count'])
    print('default_branch:', r['default_branch'])
    print('created_at:', r['created_at'][:10], '| updated_at:', r['updated_at'][:10])
    print('topics:', ', '.join(r.get('topics') or []))
    print('url:', r['html_url'])
"
```

**2-2. README**

```bash
curl -s -H "Authorization: token {github_pat}" \
  "https://api.github.com/repos/{owner}/{repo}/readme" \
  | $PYTHON -c "
import sys, json, base64
r = json.load(sys.stdin)
if r.get('message') == 'Not Found':
    print('README: 없음')
elif r.get('message'):
    print('ERROR:', r['message'])
else:
    content = base64.b64decode(r['content']).decode('utf-8', errors='replace')
    print(content)
"
```

**2-3. 언어 구성**

```bash
curl -s -H "Authorization: token {github_pat}" \
  "https://api.github.com/repos/{owner}/{repo}/languages" \
  | $PYTHON -c "
import sys, json
data = json.load(sys.stdin)
if isinstance(data, dict) and data.get('message'):
    print('ERROR:', data['message'])
else:
    total = sum(data.values()) or 1
    for lang, bytes_count in sorted(data.items(), key=lambda x: -x[1]):
        pct = round(bytes_count / total * 100, 1)
        print(f'{lang}: {pct}%')
"
```

**2-4. 최근 커밋 10개**

```bash
curl -s -H "Authorization: token {github_pat}" \
  "https://api.github.com/repos/{owner}/{repo}/commits?per_page=10" \
  | $PYTHON -c "
import sys, json
data = json.load(sys.stdin)
if isinstance(data, dict):
    print('ERROR:', data.get('message', ''))
else:
    for c in data:
        sha = c['sha'][:7]
        msg = c['commit']['message'].splitlines()[0]
        author = c['commit']['author']['name']
        date = c['commit']['author']['date'][:10]
        print(f'{sha} | {date} | {author} | {msg}')
"
```

---

## 오류 처리

| 오류 코드 | 의미 | 대응 |
|-----------|------|------|
| `missing_pat` | GITHUB_PAT 미설정 | `/issue` 스킬로 PAT 등록 안내 |
| `github_api_401` | PAT 인증 실패 | PAT 갱신 안내 |
| `github_api_403` | 권한 없음 (private 레포 등) | 접근 불가 안내, 나머지 진행 |
| `github_api_404` | 이슈/PR/레포/README 없음 | 해당 항목 "없음"으로 표시, 나머지 진행 |
| `github_api_422` | 이미 PR 존재 등 | API 오류 메시지 그대로 안내 |
| API rate limit | 요청 한도 초과 | `X-RateLimit-Remaining: 0` 감지 시 안내 |
| curl 네트워크 오류 | 연결 실패 | exit code 확인 후 재시도 1회, 실패 시 안내 |
