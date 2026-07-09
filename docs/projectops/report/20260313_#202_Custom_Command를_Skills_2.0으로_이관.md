# 🚀[기능개선][CustomCommand][Skills] 기존 커스텀 커맨드를 Claude Code Skills 2.0으로 이관

## 개요

기존 `.claude/commands/`에 단순 마크다운으로 구현되어 있던 19개 커스텀 커맨드를 Claude Code Skills 2.0 형식(`.claude/skills/`)으로 전면 이관했다. 중복되던 공통 로직을 6개 공유 레퍼런스 파일로 추출하여 context 최적화를 달성했으며, 리뷰를 통해 누락/불일치 항목을 보완했다.

## 변경 사항

### 공유 레퍼런스 파일 신규 생성 (6개)

- `.claude/skills/references/common-rules.md`: 절대 규칙(Git 커밋 금지, 스타일 준수), 작업 시작 프로토콜, 분석 전용 스킬 규칙, 워크플로우 체인(기본/설계/리팩토링), 민감 정보 마스킹
- `.claude/skills/references/project-detection.md`: 9개 프로젝트 타입(Spring Boot, React, React Native, Expo, Flutter, Next.js, Node.js, Python, basic) 자동 감지 규칙
- `.claude/skills/references/code-style-detection.md`: 기술별 코드 스타일 감지 체크리스트 (Spring Boot, React/RN, Expo, Flutter, Next.js, Node.js/Python)
- `.claude/skills/references/tech-spring.md`: Spring Boot 기술 가이드 (아키텍처, JPA, API, 보안, 구현, 테스트, 리팩토링)
- `.claude/skills/references/tech-react.md`: React/React Native 기술 가이드 (컴포넌트, 상태 관리, 성능, TypeScript, Hooks, 테스트, 리팩토링)
- `.claude/skills/references/tech-flutter.md`: Flutter 기술 가이드 (Widget, 상태 관리, 성능, 레이아웃, 테스트, 반응형 크기 변환)

### 스킬 SKILL.md 신규 생성 (19개)

- `.claude/skills/plan/SKILL.md`: 전략 수립 (코드 수정 없음)
- `.claude/skills/analyze/SKILL.md`: 코드 분석 (코드 수정 없음)
- `.claude/skills/implement/SKILL.md`: 코드 구현 (스타일 100% 준수)
- `.claude/skills/review/SKILL.md`: 코드 리뷰 (6가지 관점, 4단계 심각도)
- `.claude/skills/test/SKILL.md`: 테스트 작성 (피라미드 70/20/10)
- `.claude/skills/design/SKILL.md`: 시스템 설계 + 구현
- `.claude/skills/design-analyze/SKILL.md`: 설계 분석 (코드 수정 없음)
- `.claude/skills/refactor/SKILL.md`: 리팩토링 실행 (Before/After)
- `.claude/skills/refactor-analyze/SKILL.md`: 리팩토링 분석 (코드 수정 없음)
- `.claude/skills/figma/SKILL.md`: Figma → 반응형 코드 변환
- `.claude/skills/suh-spring-test/SKILL.md`: Spring Boot 테스트 템플릿 생성
- `.claude/skills/document/SKILL.md`: 기술 문서화
- `.claude/skills/report/SKILL.md`: 구현 보고서 생성
- `.claude/skills/ppt/SKILL.md`: 기술 발표 자료 작성
- `.claude/skills/issue/SKILL.md`: GitHub 이슈 자동 작성
- `.claude/skills/testcase/SKILL.md`: QA 테스트케이스 생성
- `.claude/skills/build/SKILL.md`: 빌드 자동화
- `.claude/skills/troubleshoot/SKILL.md`: 디버깅/트러블슈팅
- `.claude/skills/init-worktree/SKILL.md`: Git Worktree 자동 생성

### 기존 커맨드 삭제 (19개)

- `.claude/commands/analyze.md` ~ `.claude/commands/troubleshoot.md`: 19개 파일 전체 삭제
- `.cursor/commands/`는 Cursor IDE가 Skills 미지원이므로 기존 유지

## 주요 구현 내용

### Context 최적화 구조

기존 커맨드 19개는 프로젝트 타입 감지, 코드 스타일 감지, 기술별 체크리스트를 각 파일마다 반복 포함하고 있었다. 이를 6개 공유 레퍼런스로 추출하여 Progressive Disclosure 구조를 적용했다:

1. **Metadata** (name + description): 항상 context에 로드 (~100 words/스킬)
2. **SKILL.md 본문**: 스킬 트리거 시 로드 (평균 ~80줄/스킬)
3. **references/**: 필요시 on-demand 로드

### 참조 체계 통일

- 19개 스킬 중 18개가 `common-rules.md` 참조 (init-worktree만 특수 스킬로 예외)
- `common-rules.md` → `project-detection.md` → `code-style-detection.md` → `tech-*.md` 계층 구조
- 분석 전용 4개 스킬(plan/analyze/design-analyze/refactor-analyze)의 금지사항을 `common-rules.md`에 중앙화
- 워크플로우 체인을 3가지(기본/설계/리팩토링)로 확장

### 리뷰 기반 보완

- `react-native-expo` 및 `basic` 타입 감지 규칙 추가
- Node.js/Python 기술 가이드 부재 명시 (코드베이스 직접 분석 안내)
- `/ppt` 스킬의 하드코딩된 작성자명을 플레이스홀더로 변경
- `/report` 스킬의 민감 정보 마스킹 규칙 중복 제거

### 수치

| 항목 | 값 |
|------|-----|
| 스킬 SKILL.md | 19개, 1,551줄 |
| 공유 레퍼런스 | 6개, 388줄 |
| 전체 | 25개 파일, 1,939줄 |
| 삭제된 커맨드 | 19개 |

## 주의사항

- `.cursor/commands/`는 별도 유지 중 (Cursor IDE Skills 미지원)
- `template_initializer.sh` / `template_integrator.sh`에 `.claude/skills/` 복사 로직 추가가 필요 (이슈에서 언급된 후속 작업)
- CLAUDE.md의 "IDE 명령어" 섹션도 Skills 구조로 업데이트 필요
- Node.js/Python 전용 `tech-node.md`, `tech-python.md` 기술 가이드는 미작성 상태 (필요시 후속 추가)
