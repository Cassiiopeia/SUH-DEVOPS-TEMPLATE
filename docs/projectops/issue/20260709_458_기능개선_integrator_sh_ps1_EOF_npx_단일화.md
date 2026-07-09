📝 현재 문제점
---

- 현재 템플릿 통합 경로가 세 갈래(`npx projectops`, `template_integrator.sh`, `template_integrator.ps1`)로 나뉘어 있습니다.
- 세 경로를 항상 동시에 유지·검증해야 해서 유지보수 비용이 큽니다 (같은 로직을 js·bash·PowerShell 3중 구현).
- 앞으로 npx만 지원하기로 확정했습니다. 두 스크립트(`.sh`/`.ps1`)는 EOF(지원 종료) 대상입니다.

🛠️ 해결 방안 / 제안 기능
---

- **npx 단일화**: `template_integrator.sh`·`template_integrator.ps1`을 지원 종료하고 `npx projectops`만 통합 경로로 남깁니다.
- 폐기 방식(즉시 삭제 vs deprecation 안내 후 삭제)은 이 이슈에서 결정합니다.
  - 안내 후 삭제: 두 스크립트를 실행하면 "이제 npx projectops를 쓰라"는 안내만 출력하고 종료하는 얇은 shim으로 1버전 유지 후 다음 minor에서 제거하는 안
  - 즉시 삭제: 바로 제거하고 README·문서에서 참조 삭제
- 관련 문서(CLAUDE.md, README, docs/)에서 integrator 참조를 정리합니다.

⚙️ 작업 내용
---

- `template_integrator.sh` / `template_integrator.ps1` 폐기 (방식은 결정 후)
- CLAUDE.md의 integrator 검증 가이드(macOS bash 3.2, Docker PowerShell 등) 정리 — npx 기준으로 대체
- README·docs의 integrator 사용법 → npx 사용법으로 교체
- 마법사 전용 파일 제외 목록(`plugin_items_to_remove` 등)에서 integrator 관련 항목 정리

🔗 로드맵 / 의존성
---

- 상세 지도: `docs/superpowers/specs/2026-07-09-optimization-roadmap.md`
- 참고 기존 설계: `docs/superpowers/specs/2026-07-07-projectops-npx-migration-design.md`, `2026-07-08-projectops-oss-design.md`
- 순서: A → B·C → **D(이 이슈, 마지막)**
- **선행 의존**: npx 마법사가 A(#455 changelog mode)·C(#457 마법사 질문)를 완전히 반영한 뒤에야 안전하게 두 스크립트를 폐기할 수 있음. 그 전에 폐기하면 기능 공백 발생

🙋‍♂️ 담당자
---

- Cassiiopeia
