# 공통 규칙

모든 skill에서 공유하는 규칙. 각 스킬은 "시작 전" 단계에서 이 파일의 프로토콜을 따른다.

## 절대 규칙

1. **Git 커밋 금지** — `git add`, `git commit`, `git push` 등 git 변경 명령어를 절대 실행하지 않는다. 서브에이전트에게도 동일하게 지시한다.
2. **코드 스타일 100% 준수** — 기존 프로젝트 패턴을 감지하고 동일하게 따른다. 새로운 "더 나은" 방식을 임의로 제안하지 않는다.
3. **프로젝트 타입 감지 필수** — 작업 시작 전 반드시 프로젝트 타입을 자동 감지한다.

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

## GitHub 작업 원칙

GitHub API 관련 작업은 반드시 `python3 -m suh_template.cli` 커맨드로 처리한다. `gh` CLI는 사용하지 않는다.

| 작업 | 커맨드 |
|------|--------|
| 이슈 생성 | `create-issue <owner> <repo> <title> <body_file> <labels_csv>` |
| 이슈 조회 | `get-issue <owner> <repo> <issue_number>` |
| 댓글 추가 | `add-comment <owner> <repo> <issue_number> <body_file>` |
| PR 생성 | `create-pr <owner> <repo> <title> <body_file> <head> <base>` |
| PR 목록 조회 | `list-prs <owner> <repo> [--state open\|closed\|all]` |
| 브랜치명 계산 | `create-branch-name "<title>" <number>` |

PAT는 항상 환경변수로 전달: `GITHUB_PAT=$(python3 -m suh_template.cli config-get issue github_pat)`

> `gh` CLI는 Windows/Mac 호환성 문제 및 별도 설치 필요로 사용 금지. Python 표준 라이브러리(urllib)만 사용한다.

## Git Push 실행 시 동작 규칙

스킬이 `git push`를 실행해야 하는 경우 (사용자가 push를 요청하거나 스킬 플로우상 push가 필요한 경우):

1. `git pull --rebase origin main` 먼저 실행
2. rebase 성공 후 `git push origin main` 실행
3. 사용자에게는 결과만 친근하게 안내 (rebase 과정은 내부적으로 처리, 별도 설명 불필요)

> 이 프로젝트는 main 푸시 시 버전 자동 증가 워크플로우가 실행되어 리모트에 커밋이 추가된다. rebase 없이 push하면 rejected된다.

## 민감 정보 보호

출력에 다음 정보가 포함되면 반드시 마스킹:
- API Key → `{API_KEY}`
- Password → `{PASSWORD}`
- Token → `{TOKEN}`
- Secret → `{SECRET}`
