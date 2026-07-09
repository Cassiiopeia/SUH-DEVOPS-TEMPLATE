# github/issue 즉석 Python 제거 + 확장 설계

작성일: 2026-05-31
대상 스킬: `projectops:github`, `projectops:issue`
설계 표준: `skills/references/mcp-subcommand-rules.md`

## 문제

`github`/`issue` 스킬이 GitHub 작업 시 `/tmp`에 일회용 Python을 즉석 생성하거나 heredoc 인라인 Python을 쓴다. 원인 3가지:

1. **CLI 없는 영역** — explore(레포 탐색) 5종, secrets(Actions Secret) 2종은 CLI가 아예 없어 agent가 즉석 Python을 만들 수밖에 없다.
2. **반환 필드 부족** — `get-issue`가 `labels`/`assignees`를 안 줘서 agent가 직접 뽑는다. 여러 이슈를 한 번에 보는 수단이 없어 `/tmp/read_issues.py` 루프를 만든다.
3. **SKILL.md가 인라인 Python을 가르침** — 이미 CLI가 있는 이슈 조회/수정/댓글/PR생성/릴리스노트조차 heredoc Python으로 안내한다 ("인라인 Python 금지" 문구와 모순).

## 목표

세 원인을 모두 제거한다. 모든 신규 서브커맨드는 `mcp-subcommand-rules.md` 표준(`{ok, 데이터, verdict?, summary, next}` JSON)을 따른다.

---

## 섹션 A: 신규 서브커맨드 7개 (2개 그룹)

`actions`처럼 **그룹 + 하위 서브커맨드** 구조. 최상위 평면 나열 안 함.

### A-1. `explore` 그룹 (레포 탐색, 5개 하위)

| 서브커맨드 | 엔드포인트 | 반환 데이터 |
|-----------|-----------|------------|
| `explore list-repos <owner> [--type user\|org\|auto]` | `/users/{o}/repos` 또는 `/orgs/{o}/repos` (`--type auto`면 `/users/{o}` type 판별) | `repos:[{name,desc,lang,stars,updated,fork,private,url,topics[]}]` |
| `explore repo-detail <owner> <repo>` | `/repos/{o}/{r}` | `repo:{name,desc,lang,stars,forks,open_issues,default_branch,created_at,updated_at,topics[],url}` |
| `explore readme <owner> <repo>` | `/repos/{o}/{r}/readme` | `readme:{content}` (base64 디코딩; 없으면 `content:null`) |
| `explore languages <owner> <repo>` | `/repos/{o}/{r}/languages` | `languages:[{lang,percent}]` (내림차순) |
| `explore commits <owner> <repo> [--limit N]` | `/repos/{o}/{r}/commits?per_page=N` | `commits:[{sha,date,author,msg}]` (기본 N=10) |

- 인자 부족 시 `subcommands` 힌트 JSON.
- `next` 힌트: list-repos → `explore repo-detail {o} {특정repo}`, repo-detail → `explore readme {o} {r}` 식으로 연결.

### A-2. `secrets` 그룹 (Actions Secret, 2개 하위)

| 서브커맨드 | 엔드포인트 | 반환/동작 |
|-----------|-----------|----------|
| `secrets list <owner> <repo>` | `GET /repos/{o}/{r}/actions/secrets` | `secrets:[{name,updated_at}]` |
| `secrets set <owner> <repo> <name> <value>` | `GET .../secrets/public-key` → 암호화 → `PUT .../secrets/{name}` | `{ok, name, status:"updated"}` |

- **`secrets set`의 암호화**: PyNaCl sealed box. `mcp-subcommand-rules.md §5`대로 — `import nacl` 실패 시 `pip install PyNaCl -q` 시도, 그래도 실패하면 `{ok:false, error, code:"pynacl_missing", hint:"수동 설치: pip install PyNaCl"}` JSON 반환(내부망 우아한 처리).
- **`value`가 멀티라인 .env**일 수 있으므로 환경변수(`SECRET_VALUE`)로 전달받는다 (인자 이스케이프 깨짐 방지). agent가 `.env` 내용을 `SECRET_VALUE`에 담아 호출.

---

## 섹션 B: 반환 필드 확충 + 복수 조회

### B-1. `get_issue` 헬퍼 필드 추가 (`gh_client.py`)

```
기존: number, title, url, state, body
추가: labels[] (이름 배열), assignees[] (login 배열), created_at, updated_at, comments_count
```

### B-2. `get-issue`에 `--with-comments` 옵션

- 붙이면 `GET /repos/{o}/{r}/issues/{n}/comments`도 호출해 `comments:[{author,body,created_at}]` 추가.
- 이슈 본문+댓글 전체 맥락을 한 번에 (트랜스크립트의 본문+댓글 동시 조회 니즈).

### B-3. 신규 `get-issues` (복수형) — `/tmp/read_issues.py` 직격 대체

```bash
suh_command get-issues <owner> <repo> 712 707 715
→ {ok, count, issues:[{number,title,state,labels,...}], next}
```

- 여러 이슈 번호를 한 번에 조회.
- 일부 실패(404 등)해도 해당 이슈만 `{number, error}`로 표시하고 나머지는 정상 반환 (전체 실패 안 함).
- 각 이슈는 B-1 확충 필드 포함.

---

## 섹션 C: SKILL.md 인라인 Python 전부 교체

### C-1. `github/SKILL.md`

heredoc/curl Python 블록을 대응 CLI 호출로 교체:

| 현재 (인라인) | 교체 → |
|--------------|--------|
| 이슈 조회 (curl+파일) | `get-issue` (확충 필드) |
| 이슈 수정 (heredoc) | `update-issue` |
| 댓글 추가 (heredoc) | `add-comment` |
| PR 생성 (heredoc) | `create-pr` |
| 릴리스노트 (heredoc) | `update-pr` |
| explore 5종 (curl+Python) | `explore` 그룹 |
| secrets 2종 (PyNaCl heredoc) | `secrets` 그룹 |

추가로:
- 모순된 "인라인 Python 금지" 문구와 실제 내용 일치시킴.
- 상단에 `references/mcp-subcommand-rules.md` 포인터 추가 (새 작업 시 참조).
- verdict/next가 있는 커맨드는 행동 라우팅 표 명시.

### C-2. `issue/SKILL.md`

- `cli.py` → `suh_command` 명칭 정정 (이미 rename됨, 문서 잔재).
- 중복 검색 결과 표시에 확충된 `labels`/`state` 활용.

---

## gh_client.py 변경 요약

신규 헬퍼:
- `list_repos(owner, repo_type, pat)`, `get_repo_detail`, `get_readme`, `get_languages`, `list_commits` (explore용)
- `list_secrets`, `set_secret` (secrets용 — set은 public-key 조회+암호화+PUT)
- `get_issue` 필드 확충 + `get_issue_comments`
- `get_user_type(owner, pat)` (explore list-repos --type auto용)

신규 헬퍼는 순수 조회/동작만. verdict/JSON 조립은 suh_command 레이어.

## suh_command.py 변경 요약

- `cmd_explore(args)` — explore 그룹 디스패처 (5개 하위)
- `cmd_secrets(args)` — secrets 그룹 디스패처 (2개 하위)
- `cmd_get_issues(args)` — 복수 이슈 조회
- `cmd_get_issue` 수정 — `--with-comments` 옵션, 확충 필드
- `_COMMANDS`에 `explore`/`secrets`/`get-issues` 등록

## 테스트

`scripts/tests/`:
- `test_gh_client.py` — 신규 헬퍼별 urllib mock 단위 테스트 (list_repos, get_repo_detail, get_readme base64 디코딩, get_languages 백분율, list_commits, list_secrets, get_issue 확충 필드)
- `test_cli_github.py` — explore/secrets/get-issues 디스패처 JSON 형식·verdict·부분실패 처리 테스트 (gh_client mock)
- `secrets set` PyNaCl 경로는 `nacl` import 가능할 때만 실행, 없으면 skip + `pynacl_missing` JSON 경로 테스트.

## 범위 밖 (YAGNI)

- explore에 이슈/PR 목록까지 통합 — 이미 `list-prs`/`search-issues` 있음.
- secrets 삭제(`secrets delete`) — 현재 니즈 없음. 필요 시 후속.
- 모든 기존 커맨드를 MCP 패턴으로 일괄 리팩터 — 신규/수정 대상만. 기존 잘 동작하는 단순 JSON 커맨드는 건드리지 않음(YAGNI).
