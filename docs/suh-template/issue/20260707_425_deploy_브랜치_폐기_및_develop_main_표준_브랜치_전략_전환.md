📝 현재 문제점
---

- 현재 템플릿은 main(기본 브랜치)을 일상 개발 브랜치로, deploy 브랜치를 프로덕션 배포 브랜치로 사용하는 비표준 구조입니다.
- 일반적인 관례(default 브랜치 = 프로덕션, develop = 개발 통합)와 반대라서 템플릿을 처음 접하는 사용자에게 직관적이지 않습니다.
- deploy 브랜치가 워크플로우 12개 이상(AUTO-CHANGELOG-CONTROL, README-VERSION-UPDATE, PLUGIN-VERSION-SYNC, 타입별 CICD 전부), suh-changelog-deploy 스킬, 문서 전반에 하드코딩되어 있습니다.
- GitHub Actions의 `on:` 트리거는 브랜치명 변수화가 불가능하므로, 구조 자체를 표준으로 재편하는 것이 근본 해결입니다.

🛠️ 해결 방안 / 제안 기능
---

- develop(개발 통합) / main(default=프로덕션) 표준 브랜치 구조로 전면 전환하고 deploy 브랜치를 폐기합니다.
- 릴리스 = develop → main PR. AUTO-CHANGELOG-CONTROL이 릴리스 PR 안에서 버전 증가(patch +1)와 CHANGELOG 스탬프를 머지 전에 확정합니다 — "버전이 먼저 확정되고 소비자는 읽기만 한다"는 기존 불변식을 유지해 버전 어긋남을 원천 차단합니다.
- 배포·README·플러그인 동기화 워크플로우는 deploy push → main push 트리거로 단순 교체합니다 (실행 로직 무수정).
- VERSION-CONTROL은 main 직접 push(핫픽스) 안전망으로 유지하되, 릴리스 머지(push에 version.yml 변경 포함)면 건너뛰는 가드를 추가합니다.
- main이 default가 되면 feature PR의 base가 main으로 기본 제안되므로, AUTO-CHANGELOG-CONTROL에 head=develop 가드를 추가해 실수 PR이 automerge 파이프라인을 타지 않게 보호합니다.
- 기존 프로젝트를 위한 자동 마이그레이션은 제공하지 않고 breaking-changes.json에 critical로 등록합니다 (수동 전환 절차 요약 포함).

⚙️ 작업 내용
---

- 워크플로우 트리거 재배치: deploy→main, main→develop (project-types/common 원본과 .github/workflows 루트 복사본 동일 유지)
- AUTO-CHANGELOG-CONTROL: head=develop 가드 + 머지 전 버전 bump 스텝 추가, 브랜치 참조(default_branch → PR head) 교체
- VERSION-CONTROL: main push 안전망 가드 추가
- suh-changelog-deploy 스킬 SKILL.md·changelog_cli.py 브랜치 기준 변경 (deploy → main, main → develop)
- PROJECT-TEMPLATE-INITIALIZER에 develop 브랜치 자동 생성 추가
- breaking-changes.json critical 등록, README·CONTRIBUTING·docs·CLAUDE.md 브랜치 규칙 갱신
- 템플릿 레포 자체 브랜치 재편 (develop 생성, deploy 삭제)

🙋‍♂️ 담당자
---

- 템플릿: Cassiiopeia
