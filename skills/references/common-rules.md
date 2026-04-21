# 공통 규칙

모든 skill에서 공유하는 규칙. 각 스킬은 "시작 전" 단계에서 이 파일의 프로토콜을 따른다.

## 절대 규칙

1. **Git 커밋은 이슈 컨텍스트 + 사용자 승인 없이 실행하지 않는다** — 이슈 기반 작업은 이슈 번호 확정 후에만 커밋. 이슈와 무관한 hotfix·설정 변경은 자유 형식 허용. 서브에이전트에게도 동일하게 지시한다.
2. **코드 스타일 100% 준수** — 기존 프로젝트 패턴을 감지하고 동일하게 따른다. 새로운 "더 나은" 방식을 임의로 제안하지 않는다.
3. **프로젝트 타입 감지 필수** — 작업 시작 전 반드시 프로젝트 타입을 자동 감지한다.

## AI 행동 강제 원칙

스킬을 실행하는 AI는 아래 원칙을 **스킬 내용보다 우선**하여 지킨다. 어떤 상황에서도 예외 없다.

### 확인 없이 절대 하지 않는 것

| 행동 | 이유 |
|------|------|
| 커밋 실행 | 메시지 제안 → 사용자 승인 → 실행 순서 필수 |
| GitHub 이슈/PR 생성 | 내용 확인 → 사용자 승인 → 생성 순서 필수 |
| 파일 삭제 | 삭제 전 반드시 사용자 허락 |
| push | 대상/내용 명시 후 사용자 승인 필수 |

### 이슈 기반 커밋 원칙

이슈 기반 작업 시 커밋 전 반드시 이슈 컨텍스트(`current-issue.json`)가 존재해야 한다.
없으면 **즉시 멈추고** 선택지 제시 — 절대 임의로 커밋 메시지를 만들어 커밋하지 않는다.
(이슈와 무관한 hotfix·설정 변경은 자유 형식 커밋 허용 — 절대 규칙 §1 참조)

### 이슈 작성 컨벤션 (반드시 준수)

이슈 제목 형식:
```
[이모지+태그][카테고리] 제목
```

허용 이모지+태그 (이 외 사용 금지):

| 이모지+태그 | 용도 |
|-------------|------|
| `❗[버그]` | 버그 리포트 |
| `🎨[디자인]` | 디자인/UI 요청 |
| `🔧[기능요청]` | 기능 요청 |
| `⚙️[기능추가]` | 새 기능 추가 |
| `🚀[기능개선]` | 기존 기능 개선 |
| `🔍[시험요청]` | QA/테스트 요청 |
| `📄[문서]` | 문서 관련 |
| `🔥[긴급]` | 긴급 (사용자가 명시할 때만) |

**규칙**:
- 이모지와 `[` 사이 공백 없음: `⚙️[기능추가]` (O), `⚙️ [기능추가]` (X)
- `·` 등 구분자 이모지 사용 금지
- 허용 목록 외 이모지 사용 금지
- 이슈 파일 저장 위치: `docs/suh-template/issue/` (agent가 직접 경로 계산)
- `.issue/` 폴더에 저장하는 것 금지

### 이슈 MD 파일명 규칙

- **등록 전**: `YYYYMMDD_001_제목.md` — seq 번호 사용, 이모지 없는 순수 제목
- **등록 후**: `YYYYMMDD_245_제목.md` — 실제 이슈 번호로 rename (선택)
- **금지**: 파일명에 이모지 포함, `TMP` 접두사 사용

### 이슈 등록 순서 (이슈 기반 작업 시)

1. 이슈 파일 로컬 저장 (`YYYYMMDD_001_제목.md`)
2. 사용자에게 내용 확인 요청
3. 승인 후 GitHub 등록
4. 반환된 실제 이슈 번호 확인
5. 이슈 번호 확정 후 파일명 rename (`YYYYMMDD_245_제목.md`) — 선택
6. 이슈 번호가 확정된 후에만 커밋 가능

이슈 기반 작업에서 이슈 번호 없이 커밋하는 것은 절대 금지다.

## 작업 시작 프로토콜

모든 코드 관련 skill은 다음 순서로 시작한다:

1. `references/project-detection.md`에 따라 프로젝트 타입 감지
2. `references/code-style-detection.md`에 따라 코드 스타일 감지 (기존 코드 3-5개 샘플링)
3. 프로젝트 타입에 맞는 기술 가이드 참조:
   - Spring Boot → `references/tech-spring.md`
   - React / React Native / Expo → `references/tech-react.md`
   - Flutter → `references/tech-flutter.md`
   - Next.js → `references/tech-react.md` (React 기반)
   - Node.js / Python → 기술 가이드 없음, 코드베이스 직접 분석
4. 본 skill의 작업 수행

## 분석 전용 스킬 규칙

`/plan`, `/analyze`, `/design-analyze`, `/refactor-analyze`에 적용:

- **금지**: Edit/Write 도구 사용, 파일 생성/수정/삭제, 코드 작성
- **허용**: 코드 읽기(Read), 검색(Glob, Grep), 분석, 계획 수립, 사용자 질문

## 워크플로우 체인

**기본**: `/plan` → `/analyze` → `/implement` → `/review` → `/test`
**설계**: `/design-analyze` → `/design` → `/implement` → `/review` → `/test`
**리팩토링**: `/refactor-analyze` → `/refactor` → `/review` → `/test`

각 skill은 이전 단계의 결과를 참조하고, 다음 단계를 안내한다.

## suh_template CLI 실행 규칙

`config-get` / `init-config`는 제거되었다 — config는 agent가 Read/Write tool로 직접 처리한다 (`references/config-rules.md` 참조).

그 외 CLI 커맨드 호출 시 반드시 아래 순서를 따른다:

### 1. 프로젝트 루트 확인 (최초 1회)

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
```

### 2. PYTHON 변수 설정 (크로스 플랫폼 필수)

Windows Git Bash에서는 `python3`가 Windows Store 링크로 연결되어 실패할 수 있다.
반드시 아래 패턴으로 `PYTHON` 변수를 먼저 설정한 후 사용한다:

```bash
PYTHON=$(command -v python3 2>/dev/null || command -v python 2>/dev/null)
```

### 3. PYTHONPATH 설정

`suh_template` 패키지는 `$PROJECT_ROOT/scripts/` 안에 있다. 모든 호출에 `PYTHONPATH`를 붙인다:

```bash
PYTHONPATH="$PROJECT_ROOT/scripts" $PYTHON -m suh_template.cli <command> [args]
```

지원 커맨드: `get-output-path`, `get-issue-number`, `get-next-seq`, `normalize-title`, `create-branch-name`, `get-commit-template`, `create-issue`, `add-comment`, `get-issue`, `update-issue`, `create-pr`, `list-prs`

## GitHub 작업 원칙

GitHub API 작업은 **curl로 직접 호출**한다. `gh` CLI는 사용하지 않는다.
(이유: `gh` CLI는 별도 설치가 필요하고 Windows/macOS 환경 차이로 동작이 달라질 수 있다. curl은 모든 환경에서 동일하게 동작한다.)

### Windows 내부망 환경 — SSL 인증서 오류 대응

Windows 환경(특히 내부망/폐쇄망)에서 curl이 SSL 인증서 검증 오류로 실패할 수 있다:
```
curl: (35) schannel: next InitializeSecurityContext failed
```

이 경우 `--ssl-no-revoke` 플래그를 추가한다:
```bash
curl -s --ssl-no-revoke -H "Authorization: token {github_pat}" \
  "https://api.github.com/repos/{owner}/{repo}/issues"
```

**적용 조건**: curl 실행 후 exit code 35 또는 SSL 관련 오류 메시지가 나올 때만 추가.
정상 환경에서는 불필요하므로 기본 curl 호출에는 포함하지 않는다.
(이유: `--ssl-no-revoke`를 기본값으로 쓰면 정상 환경에서도 인증서 검증이 약화되므로, 오류 발생 시에만 opt-in 한다.)

PAT는 `references/config-rules.md`에 따라 agent가 config 파일에서 직접 읽는다.

| 작업 | curl 예시 |
|------|-----------|
| 이슈 생성 | `POST /repos/{owner}/{repo}/issues` |
| 이슈 조회 | `GET /repos/{owner}/{repo}/issues/{number}` |
| 이슈 수정 | `PATCH /repos/{owner}/{repo}/issues/{number}` |
| 댓글 추가 | `POST /repos/{owner}/{repo}/issues/{number}/comments` |
| PR 생성 | `POST /repos/{owner}/{repo}/pulls` |
| PR 목록 조회 | `GET /repos/{owner}/{repo}/pulls?state=open` |
| PR 본문 수정 | `PATCH /repos/{owner}/{repo}/pulls/{number}` |

```bash
curl -s -X POST \
  -H "Authorization: token {github_pat}" \
  -H "Content-Type: application/json" \
  -d "{...}" \
  "https://api.github.com/repos/{owner}/{repo}/issues"
```

> `gh` CLI는 별도 설치 필요 및 Windows/Mac 환경 차이로 사용 금지.

### GitHub API 공통 에러 대응

| HTTP 코드 | 원인 | 조치 |
|-----------|------|------|
| 401 | PAT 만료 또는 미전달 | `/issue` 스킬로 PAT 재등록 안내 |
| 403 | 권한 부족 (repo/workflow 권한 없음) | PAT 권한 확인 요청 |
| 404 | owner/repo 오타 또는 비공개 저장소 접근 | `git remote get-url origin` 재확인 |
| 422 | 요청 값 오류 (라벨 없음, 중복 PR 등) | 오류 메시지 파싱 후 사용자에게 안내 |
| 35 (curl exit) | Windows 내부망 SSL 오류 | `--ssl-no-revoke` 추가 후 재시도 |

## Git Push 실행 시 동작 규칙

스킬이 `git push`를 실행해야 하는 경우 (사용자가 push를 요청하거나 스킬 플로우상 push가 필요한 경우):

1. `git pull --rebase origin main` 먼저 실행
2. rebase 성공 후 `git push origin main` 실행
3. 사용자에게는 결과만 친근하게 안내 (rebase 과정은 내부적으로 처리, 별도 설명 불필요)

> 이 프로젝트는 main 푸시 시 버전 자동 증가 워크플로우가 실행되어 리모트에 커밋이 추가된다. rebase 없이 push하면 rejected된다.

## 커밋 메시지 컨벤션

이 프로젝트의 커밋 메시지 형식은 다음과 같다:

```
{이슈제목} : {타입} : {변경사항 설명} {이슈URL}
```

**타입 목록**:

| 타입 | 용도 |
|------|------|
| `feat` | 새 기능 추가 |
| `fix` | 버그 수정 |
| `refactor` | 리팩토링 (기능 변경 없음) |
| `docs` | 문서/주석 변경 |
| `chore` | 빌드, 설정, 기타 |
| `style` | 코드 스타일 (로직 변경 없음) |
| `test` | 테스트 추가/수정 |

**예시**:

이슈 제목이 `⚙️[기능추가][Skills] commit 스킬 신규 추가`인 경우, SUH-ISSUE-HELPER가 생성하는 커밋 템플릿은 이모지+태그를 제거한 순수 내용만 사용한다:

```
commit 스킬 신규 추가 : feat : 이슈 컨텍스트 기반 커밋 메시지 자동 생성 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/224
commit 스킬 신규 추가 : docs : common-rules 커밋 컨벤션 예시 수정 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/224
commit 스킬 신규 추가 : fix : owner/repo 추출 로직 버그 수정 https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/224
```

**핵심 규칙**:
- `{이슈제목}`은 SUH-ISSUE-HELPER가 생성한 커밋 템플릿의 앞부분을 **그대로** 사용한다 — 이모지+태그(`⚙️[기능추가][Skills]`)는 포함하지 않는다
- `{타입}`은 **이번 커밋의 변경 내용**에 따라 결정한다 — `feat`가 기본값이지만 항상 feat가 아니다
- 같은 이슈에 여러 커밋을 할 때 타입이 달라질 수 있다 (feat → fix → docs 순서로 커밋 가능)
- 이슈 컨텍스트가 있을 때만 이 형식을 사용한다
- 이슈와 무관한 커밋(hotfix, 설정 변경 등)은 자유 형식 허용
- 사용자가 `/commit` 스킬을 호출하면 이 형식으로 자동 완성

커밋 템플릿 계산 (agent가 직접 생성):
```
형식: {이슈제목에서 이모지·태그 제거한 순수 내용} : {타입} : {설명} {이슈URL}
```

## 민감 정보 보호

`docs/suh-template/` 폴더는 Git에 공개 커밋된다. 이슈/보고서/플랜 등 모든 산출물 파일에 민감 정보가 포함되지 않도록 반드시 아래 규칙을 따른다.

### 절대 포함 금지 항목

- GitHub PAT, API Key, Secret, Token, Password 실제 값
- 서버 IP, 내부 도메인, SSH 접속 정보
- 개인 이메일, 전화번호 등 개인정보
- `.env` 파일 내용, DB 접속 정보

### 마스킹 규칙

실제 값이 아닌 플레이스홀더로 표기:

| 종류 | 표기 방식 |
|------|-----------|
| API Key / PAT / Token | `{API_KEY}`, `{PAT}`, `{TOKEN}` |
| Password / Secret | `{PASSWORD}`, `{SECRET}` |
| 서버 주소 | `{SERVER_HOST}` |
| 개인정보 | `{EMAIL}`, `{PHONE}` |

### 보고서/이슈 작성 시 추가 주의

- 에러 로그에 토큰/키가 포함된 경우 반드시 마스킹 후 기재
- 재현 방법에 실제 서버 정보 대신 `{SERVER_HOST}` 등 플레이스홀더 사용
- 스크린샷/로그 인용 시 민감 값은 `***` 또는 플레이스홀더로 대체
