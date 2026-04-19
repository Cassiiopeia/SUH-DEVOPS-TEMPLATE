# Sub-project #6: GitHub Skill 통합 설계

## 목표

`/issue`, `/report`, `/github` 세 스킬을 GitHub API와 연결하여 이슈 생성 → 브랜치 생성 → 댓글 보고까지 이어지는 워크플로우를 끊김 없이 완성한다.

---

## 문제 정의

| 현재 상태 | 목표 상태 |
|-----------|-----------|
| `/issue`가 로컬 `.issue/*.md` 파일만 생성 | GitHub API로 이슈 실제 생성까지 완료 |
| 브랜치명 계산이 SUH-ISSUE-HELPER Action에 의존 (수 초 딜레이) | Python으로 즉시 로컬 계산 |
| `/report`가 로컬 파일만 저장 | 해당 이슈에 GitHub 댓글로 자동 포스팅 |
| GitHub 제어 스킬 없음 | `/github` 스킬로 독립적 GitHub 작업 가능 |

---

## 허용 이슈 제목 이모지+태그

`.github/ISSUE_TEMPLATE/` 파일들에서 파싱한 허용 조합만 사용한다. 공백 없이 이모지와 `[` 괄호가 붙어야 한다.

### 주요 태그 (타입 결정)

| 이모지+태그 | 출처 템플릿 |
|-------------|------------|
| `❗[버그]` | `bug_report.md` |
| `🎨[디자인]` | `design_request.md` |
| `🔧[기능요청]` | `feature_request.md` |
| `⚙️[기능추가]` | `feature_request.md` |
| `🚀[기능개선]` | `feature_request.md` |
| `🔍[시험요청]` | `qa_request.md` |

### 수식어 태그 (선택적 추가)

| 이모지+태그 | 의미 |
|-------------|------|
| `🔥[긴급]` | 긴급 (사용자가 명시할 때만) |
| `📄[문서]` | 문서 관련 |
| `⌛[~월/일]` | 마감일 |

**규칙**: 이모지와 `[` 사이 공백 없음. 위 목록에 없는 이모지 사용 금지.

---

## 새 Python 모듈

### `scripts/suh_template/gh_branch.py`

SUH-ISSUE-HELPER TypeScript 로직을 Python으로 포팅한다.

**브랜치명 형식**: `YYYYMMDD_#이슈번호_정규화제목`

정규화 규칙:
- 한국어(가-힣), 영문(a-zA-Z), 숫자(0-9) 이외의 문자 → `_`
- 연속된 `_` → 단일 `_`
- 앞뒤 `_` 제거
- 전체 길이 100자 이하 (초과 시 잘라내고 `_` 로 끝나면 제거)

```python
def normalize_title(title: str) -> str: ...
def create_branch_name(issue_title: str, issue_number: int, date_yyyymmdd: str) -> str: ...
def get_commit_template(issue_title: str, issue_url: str) -> str: ...
```

커밋 메시지 템플릿: `"{issue_title} : feat : {설명} {issue_url}"`

### `scripts/suh_template/gh_client.py`

GitHub REST API 클라이언트. `urllib` 표준 라이브러리만 사용 (외부 의존성 없음).

```python
def create_issue(owner: str, repo: str, title: str, body: str, labels: list[str], pat: str) -> dict:
    """이슈 생성 → {number, url, title} 반환"""

def add_comment(owner: str, repo: str, issue_number: int, body: str, pat: str) -> dict:
    """이슈에 댓글 추가 → {id, url} 반환"""

def get_issue(owner: str, repo: str, issue_number: int, pat: str) -> dict:
    """이슈 조회 → {number, title, url, state, body} 반환"""

def list_issues(owner: str, repo: str, pat: str, state: str = "open") -> list[dict]:
    """이슈 목록 조회"""

def create_pull_request(owner: str, repo: str, title: str, body: str, head: str, base: str, pat: str) -> dict:
    """PR 생성 → {number, url} 반환"""
```

오류 처리: HTTP 4xx/5xx는 `GitHubAPIError(status_code, message)` 예외.

---

## 스킬별 변경 사항

### `/issue` 스킬 확장

**현재**: 로컬 `.issue/*.md` 파일 생성만 수행  
**변경 후**: GitHub 이슈 생성 + 즉시 브랜치명 계산 + 워크트리/브랜치 선택지 제공

#### 플로우

```
1. config-get issue github_pat → PAT 확인
2. .github/ISSUE_TEMPLATE/ 파일 파싱 → 허용 이모지+태그 목록 추출
3. 사용자 설명에서 이슈 타입 자동 판단
4. 이슈 제목/본문 작성 (허용 이모지+태그만 사용)
5. 제목 사용자 확인 (수정 가능)
6. GitHub API → 이슈 생성 → issue_number, issue_url 획득
7. gh_branch.py로 즉시 브랜치명 계산 (YYYYMMDD_#번호_제목)
8. 로컬 .issue/*.md 파일 저장
9. 선택지 제시:
   1. 지금 git worktree 생성 (`git worktree add -b {브랜치명} ../{브랜치명}`)
   2. 브랜치만 생성 (`git checkout -b {브랜치명}`)
   3. 나중에 (브랜치명만 알려줌)
```

#### 출력 예시

```
이슈 생성 완료: #427 — ⚙️[기능추가][Skills] 드롭다운 디자인 변경
브랜치명: 20260115_#427_드롭다운_디자인_변경
이슈 URL: https://github.com/owner/repo/issues/427

다음 작업을 선택하세요:
1. 지금 worktree 생성 (../20260115_#427_드롭다운_디자인_변경/)
2. 브랜치만 생성 (현재 디렉토리에서 작업)
3. 나중에 직접 (브랜치명 복사만)
```

### `/report` 스킬 확장

**현재**: `docs/suh-template/report/` 에 로컬 파일 저장  
**변경 후**: 로컬 파일 저장 + 이슈 번호 자동 감지 후 GitHub 댓글 포스팅

#### 이슈 번호 자동 감지 순서

1. 현재 디렉토리 경로에서 추출 (worktree 경로 `*_#123_*` 패턴)
2. `.issue/` 폴더 파일명에서 추출
3. git 브랜치명에서 추출
4. 감지 실패 시 사용자에게 질문

#### 플로우

```
1. 보고서 내용 작성
2. docs/suh-template/report/ 에 파일 저장
3. config-get issue github_pat → PAT 확인 (없으면 로컬 저장만)
4. 이슈 번호 자동 감지
5. GitHub API → 이슈 댓글 포스팅
6. 완료 메시지 (댓글 URL 포함)
```

### `/github` 스킬 (신규)

독립적인 GitHub 제어 스킬. 다른 스킬 없이 단독으로 사용 가능.

#### 지원 작업

| 명령 | 설명 |
|------|------|
| 이슈 조회 | `#번호` 또는 검색어로 이슈 조회 |
| 이슈 댓글 | 이슈에 댓글 추가 |
| PR 생성 | 현재 브랜치로 PR 생성 |
| PR 조회 | 열린 PR 목록 또는 특정 PR 조회 |

#### 플로우

```
1. config-get issue github_pat → PAT 확인
2. 사용자 의도 파악 (이슈 조회/댓글/PR 생성/PR 조회)
3. repo 자동 감지 (git remote origin에서 owner/repo 추출)
4. 해당 GitHub API 호출
5. 결과 출력
```

---

## CLI 커맨드 추가

`cli.py`에 `github-*` 계열 커맨드는 추가하지 않는다. `gh_client.py`와 `gh_branch.py`는 스킬에서 직접 `python3 -c "..."` 또는 새 서브커맨드로 호출한다.

### 새 CLI 커맨드

```
python3 -m suh_template.cli create-issue <owner> <repo> <title> <body_file> <labels_csv>
python3 -m suh_template.cli add-comment <owner> <repo> <issue_number> <body_file>
python3 -m suh_template.cli get-issue <owner> <repo> <issue_number>
python3 -m suh_template.cli create-branch-name <issue_title> <issue_number> [--date YYYYMMDD]
python3 -m suh_template.cli create-pr <owner> <repo> <title> <body_file> <head> <base>
```

PAT는 환경변수 `GITHUB_PAT`로 전달 (CLI 인수에 노출 방지).

---

## 테스트 계획

### `tests/test_gh_branch.py`

- `normalize_title`: 특수문자, 연속 언더스코어, 한국어, 영문, 숫자 혼합
- `create_branch_name`: 형식 검증 `YYYYMMDD_#번호_제목`
- 길이 초과 시 잘라내기 검증

### `tests/test_gh_client.py`

- `unittest.mock.patch('urllib.request.urlopen')` 으로 HTTP 응답 모킹
- `create_issue`: 정상 응답, 401, 422 오류 처리
- `add_comment`: 정상 응답, 404 (이슈 없음) 처리
- `get_issue`: 정상 응답, 404 처리
- `create_pull_request`: 정상 응답, 422 (이미 PR 존재) 처리

### `tests/test_cli_gh_client.py`

- `create-branch-name` CLI 커맨드 인수 검증
- `create-issue` 환경변수 `GITHUB_PAT` 누락 시 오류

---

## 파일 구조 변경 요약

```
scripts/suh_template/
├── gh_branch.py          ← 신규: 브랜치명 계산 (TypeScript 포팅)
├── gh_client.py          ← 신규: GitHub REST API 클라이언트
├── cli.py             ← 수정: create-issue, add-comment, get-issue, create-branch-name, create-pr 추가
└── __init__.py        ← 수정: SUPPORTED_SKILL_IDS에 'github' 추가

skills/
├── issue/SKILL.md     ← 수정: GitHub API 연동 + 브랜치 선택지
├── report/SKILL.md    ← 수정: GitHub 댓글 포스팅
└── github/SKILL.md    ← 신규: 독립 GitHub 제어 스킬

.cursor/skills/
└── github.mdc         ← 신규: skills/github/SKILL.md와 동기화

.suh-template.example/config/
└── issue.config.example.json  ← 기존 유지 (PAT + repos 구조)
```

---

## 스코프 외

- GitHub Actions 워크플로우 변경 없음
- WebSocket / 실시간 알림 없음
- 이슈 편집/삭제 없음 (생성과 조회만)
- PAT 갱신 UI 없음 (직접 config 파일 수정)
