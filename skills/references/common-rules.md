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

## 민감 정보 보호

출력에 다음 정보가 포함되면 반드시 마스킹:
- API Key → `{API_KEY}`
- Password → `{PASSWORD}`
- Token → `{TOKEN}`
- Secret → `{SECRET}`
