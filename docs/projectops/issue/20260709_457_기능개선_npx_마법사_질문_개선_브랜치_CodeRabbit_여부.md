📝 현재 문제점
---

- `npx projectops` 통합 마법사가 `basic` 단독 타입을 통합할 때 브랜치 전략·CodeRabbit 사용 여부 등 중요한 결정을 **아무것도 묻지 않고** 넘어갑니다.
- 실제 실행 로그에서 배포/publish는 물어보지만, 그 외에 물어봐야 할 것을 그냥 기본값으로 확정해버려 사용자가 원하는 대로 설정하지 못합니다.
- A 이슈에서 `changelog.mode`(coderabbit/commit/ai)가 생기면, 마법사가 이 값을 사용자에게 물어봐야 하는데 현재는 그런 질문 자체가 없습니다.

🛠️ 해결 방안 / 제안 기능
---

- A 이슈의 `changelog.mode`를 마법사가 **질문**하도록 추가합니다.
  - "CodeRabbit AI 리뷰를 쓸까요? 아니면 빠른 커밋 기반 changelog로 갈까요?" 형태
  - CodeRabbit을 안 쓰기로 하면 `.coderabbit.yaml`을 **조건부로만 복사**합니다 (안 쓰는 레포에 불필요한 설정 파일이 안 들어가게).
- 브랜치 전략(develop→main 릴리스 구조를 쓸지) 질문 추가를 검토합니다.
- 질문 앞에는 "왜 묻는지" 맥락 한 줄을 붙여 사용자가 당황하지 않게 합니다 (기존 배포 질문 UX와 동일 철학).
- 선택 결과는 `version.yml`의 `metadata.template.options`에 저장합니다.

⚙️ 작업 내용
---

- 마법사(`bin/projectops.js` — npx 단일 경로)에 changelog mode 질문 추가
- CodeRabbit 미사용 선택 시 `.coderabbit.yaml` 복사 스킵 로직
- (검토) 브랜치 전략 질문 추가
- 분석 카드에 선택된 changelog mode 표시
- 선택값을 version.yml options에 기록

🔗 로드맵 / 의존성
---

- 상세 지도: `docs/superpowers/specs/2026-07-09-optimization-roadmap.md`
- 순서: A → **B·C(이 이슈, 병렬)** → D
- **선행 의존**: A(#455 CodeRabbit 탈의존 provider 아키텍처)에서 `changelog.mode` 옵션이 확정되어야 마법사가 무엇을 물을지 정할 수 있음
- 참고: 이 이슈는 npx 마법사만 대상으로 함. integrator.sh/.ps1은 D 이슈에서 EOF 예정이므로 두 스크립트에는 반영하지 않음

🙋‍♂️ 담당자
---

- Cassiiopeia
