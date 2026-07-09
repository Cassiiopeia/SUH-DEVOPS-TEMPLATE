# Hypercortex — 지식 그래프 (작업중 산출물)

`harness/WORKFLOW.md`의 SDLC 프로세스가 각 Phase에서 생성하는 **지식 산출물**을 모으는 디렉토리다. 모든 결정과 산출물은 여기에 기록되어 추적 가능해야 한다.

> **경로 단일 규칙**: 산출물은 항상 `docs/suh-template/` 우산 아래에 둔다 (`harness/WORKFLOW.md` §"산출물 경로 단일 규칙").

## 파일 구조

| 파일 | 생성 Phase | 내용 |
|------|-----------|------|
| `TODO.md` | 전 단계 | 동적 작업 트래커 (요구사항·엣지케이스·리팩토링·하위작업) |
| `REQUIREMENT.md` | Phase 1 요구사항 | 문제 정의·제약조건·`[ASSUMPTIONS]`·`[AMBIGUITY]`·`[PROBLEM]`·`[REQUIREMENT]` |
| `DESIGN.md` | Phase 2 설계 | 아키텍처 제안·`[ALTERNATIVES_CONSIDERED]`·`[SOLUTION]` |
| `SPECIFICATION.md` | Phase 3 사양 | 기술 인터페이스·데이터 흐름(ASCII 다이어그램) |
| `DEVELOPMENT.md` | Phase 4 개발 | 개발자 자체 리뷰 로그·리팩토링 포인트 |
| `QUALITY.md` | Phase 5·6 감사/테스트 | `[RISK]`·`[PROBLEM]`·`[SOLUTION]`·테스트 시나리오/결과 |

각 문서 하단에는 리뷰어의 `[REVIEW_LOG]`가 물리적으로 기록되어야 한다 (전역 규칙 1·2).
