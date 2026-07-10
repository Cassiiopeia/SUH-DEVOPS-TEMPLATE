# pro-issue → pro-github 통합 + GitHub 편집 CLI 전면 보강 설계

작성일: 2026-07-10
상태: 설계 확정 대기

## 배경 / 문제

이슈 관련 GitHub 작업을 할 때 `pro-github`를 불러야 할지 `pro-issue`를 불러야 할지 헷갈린다. 두 스킬의 경계가 모호하고(둘 다 이슈 조회/수정/검색을 함), 사용자는 "GitHub 작업은 그냥 github 하나로" 통일하기를 원한다.

동시에, 현재 `github_cli.py`는 이슈/PR 편집 작업이 불완전하다:
- 댓글은 **추가만** 되고 수정/삭제 불가
- 라벨은 `update-issue --labels`로 **전체 교체만** 가능 (기존 라벨 유지하며 하나만 추가/제거 불가)
- 담당자도 전체 교체만 가능 (기존 담당자가 날아감)
- PR은 생성/목록/본문수정만 되고 머지/닫기/댓글 불가

핵심 사실 (코드 조사로 확인):
- **공유 로직(`scripts/common/gh_client.py`)은 이미 단일 통합돼 있다.** `github_cli.py`와 `issue_cli.py` 둘 다 같은 `common`을 import한다. 따라서 "합친다"는 것은 로직 이전이 아니라 **CLI 서브커맨드 노출 + SKILL.md 통합 + 폴더 삭제**의 문제다.
- `gh_client.py`엔 이미 `add_issue_labels`(라벨 추가, POST), `list_labels`, `list_issues`, `get_pull_detail` 등 **CLI에 노출 안 된 함수**가 여럿 있다.
- `issue_cli.py`를 **다른 스킬이 직접 호출하지 않는다** (pro-commit은 `common.gh_branch`를 직접 import). 따라서 삭제 안전. 단, `normalize-title`/`create-branch-name`/`get-commit-template` 서브커맨드는 문서(CLAUDE.md, common-rules, pro-plan)가 참조하므로 **github_cli로 이관**해야 문서 정합성이 유지된다.

## 목표

1. GitHub 이슈/PR로 할 수 있는 편집 작업을 `github_cli.py`가 **전부** 커버 (댓글 수정/삭제, 라벨 add/remove/set, 담당자 add/remove, PR 머지/닫기/댓글 등).
2. `pro-issue`의 이슈 **생성** 워크플로우(템플릿·중복검사·auto_approve·담당자 첫설정·브랜치명 계산)를 `pro-github`로 완전 흡수.
3. `pro-issue` 폴더를 삭제하고, 이를 가리키는 모든 살아있는 참조를 `pro-github`(또는 자기참조)로 정리.
4. 하위 호환: `/issue` 슬래시커맨드는 사라진다(완전 제거). 사용자는 `/github` 또는 "이슈 만들어줘"로 호출.

## 비목표 (YAGNI)

- PR **review** 코멘트(`/pulls/comments/`) — 일반 이슈 댓글과 다른 엔드포인트. 이번 범위 밖.
- config 키 `issue.auto_approve` **이름 변경** — 사용자 config.json에 이미 저장돼 있을 수 있으므로 **키 이름은 그대로 유지**(하위 호환). 스킬만 통합.
- 스크립트(initializer/integrator)·플러그인 매니페스트 수정 — 조사 결과 pro-issue 개별 항목이 없고 폴더 통째 처리이므로 **손댈 것 없음**.

---

## 설계 1 — `gh_client.py` 신규 API 함수

GitHub REST API v3 (2022-11-28) 스펙 확인 완료. urllib 구현 주의사항 포함.

| 함수 | 엔드포인트 | 메서드 | 주의 |
|------|-----------|--------|------|
| `update_comment(owner, repo, comment_id, body, pat)` | `/repos/{o}/{r}/issues/comments/{comment_id}` | PATCH | issue_number 불필요. issue·PR 공용. 200 반환 |
| `delete_comment(owner, repo, comment_id, pat)` | `/repos/{o}/{r}/issues/comments/{comment_id}` | DELETE | body 없음. **204 반환 → JSON 파싱 금지** |
| `remove_issue_label(owner, repo, issue_number, name, pat)` | `/repos/{o}/{r}/issues/{n}/labels/{name}` | DELETE | **`name`은 `quote(name, safe='')`** 필수(한글 라벨). 200(남은 라벨 배열). 없으면 404 → 멱등 처리 |
| `set_issue_labels(owner, repo, issue_number, labels, pat)` | `/repos/{o}/{r}/issues/{n}/labels` | PUT | `{"labels":[...]}`. 전체 교체. `[]`면 전부 제거. 존재하지 않는 라벨 사전 필터 |
| `add_assignees(owner, repo, issue_number, assignees, pat)` | `/repos/{o}/{r}/issues/{n}/assignees` | POST | `{"assignees":[...]}`. 기존 유지+추가. **201 반환**. 최대 10명. 무효 유저 silent drop |
| `remove_assignees(owner, repo, issue_number, assignees, pat)` | `/repos/{o}/{r}/issues/{n}/assignees` | DELETE | **DELETE에 body 필요.** 지정 유저만 제거. 200(이슈 객체) |
| `merge_pull_request(owner, repo, pr_number, pat, merge_method, commit_title, commit_message, sha)` | `/repos/{o}/{r}/pulls/{n}/merge` | PUT | method: merge/squash/rebase. 405(머지 불가)/409(sha 불일치)/422(rebase 불허) 처리 |

기존 함수 재사용:
- `add_issue_labels`(라벨 추가) — 이미 있음. CLI에 노출만.
- `get_pull_detail`(PR 상세) — 이미 있음. CLI에 노출만.
- `list_labels`, `list_issues`, `get_issue_comments`, `update_issue`, `add_comment`, `update_pull_request` — 재사용.

구현 규칙:
- `gh_client` 함수는 **순수 조회/변경만**(raw dict 반환, 판정 없음). verdict·next 힌트는 CLI 레이어.
- 204 응답을 위해 `_request`가 빈 응답을 이미 `{}`/`""`로 처리함(확인됨). DELETE는 `_request("DELETE", ..., data=None or payload)`.
- `remove_assignees`는 DELETE + body → `_request("DELETE", url, {"assignees": [...]}, pat)`. `_request`는 method를 명시 인자로 받으므로 안전.
- 라벨 제거 404는 `GitHubAPIError`로 올라오므로, CLI 레이어에서 404를 "이미 없음"으로 흡수해 멱등 처리.

## 설계 2 — `github_cli.py` 서브커맨드 (단일 CLI 통합)

기존(get-issue, get-issues, update-issue, add-comment, create-pr, list-prs, update-pr, search-issues, explore, secrets, actions)에 추가:

### 이슈 생성/조회 (issue_cli 흡수)
- `create-issue OWNER REPO TITLE BODY_FILE LABELS [--assignees ...]` — issue_cli에서 그대로 이관
- `list-issues OWNER REPO [--state open|closed|all] [--label L] [--assignee U]` — `list_issues` 확장

### 댓글
- `list-comments OWNER REPO NUMBER` — `get_issue_comments` 노출
- `edit-comment OWNER REPO COMMENT_ID BODY_FILE` — `update_comment`
- `delete-comment OWNER REPO COMMENT_ID` — `delete_comment`

### 라벨 (세분화 — 기존 안 날아감)
- `list-labels OWNER REPO` — 레포 라벨 목록
- `add-labels OWNER REPO NUMBER LABELS_CSV` — 기존 유지+추가 (`add_issue_labels`)
- `remove-label OWNER REPO NUMBER LABEL` — 하나만 제거, 404 멱등
- `set-labels OWNER REPO NUMBER LABELS_CSV` — 전체 교체 (`set_issue_labels`)

### 담당자 (세분화)
- `add-assignees OWNER REPO NUMBER ASSIGNEES_CSV` — 기존 유지+추가
- `remove-assignees OWNER REPO NUMBER ASSIGNEES_CSV` — 지정만 제거

### 이슈 상태 편의 alias
- `close-issue OWNER REPO NUMBER` — `update-issue --state closed`
- `reopen-issue OWNER REPO NUMBER` — `update-issue --state open`

### PR 편집
- `get-pr OWNER REPO NUMBER` — `get_pull_detail`(mergeable_state 등)
- `add-pr-comment OWNER REPO NUMBER BODY_FILE` — PR=issue이므로 `add_comment` 재사용
- `close-pr` / `reopen-pr OWNER REPO NUMBER` — `update_pull_request --state`
- `merge-pr OWNER REPO NUMBER [--method merge|squash|rebase] [--title T] [--message M]` — `merge_pull_request`. 405/409/422를 code로 반환

### 이슈 헬퍼 (issue_cli 흡수 — 문서 정합성)
- `normalize-title TITLE...` — `common.title.normalize`
- `create-branch-name ISSUE_TITLE ISSUE_NUMBER [--date]` — `common.gh_branch`
- `get-commit-template ISSUE_TITLE ISSUE_URL` — `common.gh_branch`

모든 신규 서브커맨드는 `ok`/`code`/`summary`/`next` JSON. `merge-pr`는 `verdict`(merged/blocked/conflict)도 반환.

## 설계 3 — SKILL.md 통합

`pro-github/SKILL.md`:
- **이슈 생성 워크플로우**(가장 긴 부분: 타입판단→이모지태그→중복검사→로컬md저장→auto_approve게이트→담당자첫설정→등록→브랜치명→다음작업)를 **`skills/references/issue-creation.md`로 분리**. SKILL.md는 "이슈 만들어달라는 요청이면 references/issue-creation.md를 따른다"로 라우팅. (기존 프로젝트의 references 분리 관행과 일관)
- **신규 서브커맨드 전부 호출예 추가** — `test_cli_signatures_doc_sync.py`가 강제. ①bash 실행라인 ②기대 JSON ③agent 사용법 3종 포함.
- `description`에 이슈 생성/버그리포트/기능요청 등 pro-issue 트리거 키워드 흡수.
- `/issue 스킬로 PAT 등록` → "config 등록 절차 안내"(자기참조)로 문구 수정.
- 로컬 md 저장 경로 `docs/projectops/issue/` **유지**.

`skills/references/issue-creation.md` (신규):
- pro-issue/SKILL.md의 생성 로직 전체 이관.
- config 키 `issue.auto_approve`·`default_assignee`·`repos[].issue.assignee` **이름 그대로 유지**(하위 호환).

## 설계 4 — pro-issue 삭제 + 참조 정리

삭제: `skills/pro-issue/`(SKILL.md, scripts/issue_cli.py, __pycache__) 통째.

참조 정리 (조사로 특정한 정확한 지점):

| 파일 | 조치 |
|------|------|
| `CLAUDE.md` L111, L434, L571, L588, L629 | Skill routing/CLI표/명령어표의 issue 행 → github 흡수, `/issue`→`/pro-github`, issue_cli 서브커맨드 소유를 github_cli로 재기술 |
| `README.md` L30, L43, L174 (+스킬 카운트 25종→24종) | `/pro-issue`→`/pro-github`, mermaid, 스킬 표 |
| `docs/SKILLS.md` L322, L333, L397~408, L520 | pro-commit 설명의 pro-issue 참조→github, `/pro-issue` 상세 섹션 삭제, mermaid |
| `skills/references/common-rules.md` L137, L147, L165, L210, L277 | `/issue 스킬로 이동`→github, py표의 issue 행 삭제(stale 경로), PAT 재등록 안내 |
| `skills/references/config-rules.md` L98, L172 | 주석·키 설명의 issue→github (키 이름 자체는 유지) |
| `skills/pro-github/SKILL.md` L31, L393 | `/issue 스킬로 PAT 등록`→자기참조 문구 |
| `skills/pro-changelog-deploy/SKILL.md` L88 | PAT 없음 안내 `/issue`→`/pro-github` |
| `skills/pro-plan/SKILL.md` L111 | issue_cli 서브커맨드 소유→github_cli 재기술 |
| `scripts/tests/test_cli_signatures_doc_sync.py` | `CLI_TO_SKILL`의 stale 경로(`issue/`, `github/` 등)를 `pro-github/`로 갱신, issue 항목 제거, EXPECTED_MISSING에서 issue 항목 제거 |

손대지 않음(조사로 확인): `template_initializer.sh/.py`, `template_integrator.sh/.ps1`, `.claude-plugin/*`(폴더 통째 처리).

## 설계 5 — 테스트

- `scripts/tests/test_gh_client.py`(신규 또는 기존): 신규 함수 7종을 urllib mock으로 단위 테스트 (204 파싱금지, 라벨 quote, DELETE body, merge 405 등).
- `scripts/tests/test_cli_github.py`(신규): github_cli 신규 서브커맨드를 gh_client mock으로 in-process 호출, verdict/JSON 검증.
- `test_cli_signatures_doc_sync.py`가 github_cli 신규 서브커맨드 전부 SKILL.md에 있음을 강제 → 통과 확인.
- 전체 pytest 48개+ 통과 유지.

## 리스크 / 완화

| 리스크 | 완화 |
|--------|------|
| SKILL.md 비대화 → 트리거·가독성 저하 | 이슈 생성 로직을 references/로 분리 |
| issue_cli 헬퍼 서브커맨드 이관 누락 시 pro-commit/pro-plan 깨짐 | github_cli에 normalize-title/create-branch-name/get-commit-template 반드시 이관 |
| config 키 이름 변경 시 기존 사용자 config 무효화 | 키 이름 `issue.auto_approve` 등 그대로 유지 |
| doc-sync 테스트가 stale 경로로 조용히 skip 중 | CLI_TO_SKILL을 pro-github 경로로 갱신해 실제 검증 활성화 |
| Windows/mac 호환 | urllib 표준 라이브러리, quote 인코딩, 환경변수 인자 전달 준수 |

## 검증 방법

1. `cd scripts && pytest tests/ -q` 전체 통과.
2. 실제 레포(예: TEAM-ROMROM/RomRom-FE)에 대해 신규 서브커맨드 몇 개 실 호출로 JSON 정상 확인(read 계열 우선, 파괴적 커맨드는 사용자 승인 후).
3. `test_cli_signatures_doc_sync.py`가 github_cli 전 서브커맨드를 검증하는지 확인.
