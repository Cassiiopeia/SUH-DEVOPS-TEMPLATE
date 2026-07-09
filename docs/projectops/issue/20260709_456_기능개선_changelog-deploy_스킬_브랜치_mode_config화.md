📝 현재 문제점
---

- `skills/changelog-deploy/SKILL.md`가 `develop` → `main` 브랜치를 하드코딩하고 있습니다. deploy 브랜치·default 브랜치가 다른 레포에서는 맞지 않습니다.
- A 이슈에서 도입되는 `changelog.mode`(coderabbit/commit/ai)를 스킬이 알지 못하면, 릴리스 노트를 스킬이 직접 만들어야 하는지 워크플로우에 맡겨도 되는지 판단할 수 없습니다.
- 브랜치명을 스킬 내부에 하드코딩하는 것은 확장성·재사용성 측면에서 좋지 않습니다.

🛠️ 해결 방안 / 제안 기능
---

- deploy/default 브랜치 정보를 하드코딩 대신 **SSOT(version.yml / config.json)에서 읽도록** 변경합니다.
  - `version.yml`의 `metadata.template.default_branch`가 이미 존재합니다. deploy 브랜치(릴리스 PR의 head) 개념 추가 여부를 검토합니다.
- A 이슈의 `changelog.mode`를 스킬이 읽어 흐름을 맞춥니다.
  - `commit` 모드면 워크플로우가 즉시 노트를 만드므로 스킬은 예쁜 노트를 만들지, 아니면 워크플로우에 맡길지 정책을 정합니다.
  - `coderabbit`/`ai` 모드면 기존처럼 스킬이 릴리스 노트를 선제 작성해 CodeRabbit 대기를 우회합니다.
- 브랜치 정보 읽기 실패 시 안전한 기본값(develop→main)으로 폴백합니다.

⚙️ 작업 내용
---

- `changelog-deploy` 스킬이 version.yml/config.json에서 브랜치·mode를 읽는 로직 설계
- 하드코딩된 `develop`/`main` 참조를 설정 기반으로 치환
- `changelog.mode`에 따른 릴리스 노트 작성 정책 분기 정의
- (필요 시) `changelog_cli.py`에 브랜치/mode 조회 서브커맨드 추가

🔗 로드맵 / 의존성
---

- 상세 지도: `docs/superpowers/specs/2026-07-09-optimization-roadmap.md`
- 순서: A → **B(이 이슈)·C(병렬)** → D
- **선행 의존**: A(#455 CodeRabbit 탈의존 provider 아키텍처)에서 `changelog.mode` 옵션이 확정되어야 이 작업의 mode 연동 부분을 확정할 수 있음

🙋‍♂️ 담당자
---

- Cassiiopeia
