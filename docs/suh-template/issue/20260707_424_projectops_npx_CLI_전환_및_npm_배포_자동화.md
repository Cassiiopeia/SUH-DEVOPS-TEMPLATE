📝 현재 문제점
---

- 템플릿 통합 마법사가 `template_integrator.sh`(5,650줄)와 `template_integrator.ps1`(5,120줄) **두 벌로 이중 유지보수**되고 있어, 기능 하나를 고칠 때마다 sh·ps1 대칭을 수동으로 맞춰야 한다.
- macOS 기본 bash 3.2 / BSD 도구 제약, Windows PowerShell 5.1 제약 때문에 플랫폼별 함정(연관배열 금지, `grep -P` 금지, `set -e` 종료 등)이 반복적으로 버그를 만들어 왔다 (#415, #418 실측).
- `curl | bash` / `iex DownloadString` 방식은 배포 채널로서 버전 고정·롤백·설치 통계가 불가능하다.
- 프로젝트 명칭(SUH-DEVOPS-TEMPLATE)이 개인 템플릿 인상을 줘 범용 오픈소스로 확장하기 어렵다.

🛠️ 해결 방안 / 제안 기능
---

- 마법사를 **단일 Node.js CLI(`npx projectops`)로 완전 전환**하여 크로스 플랫폼 단일 코드베이스로 통합한다.
- npm 레지스트리에 `projectops` 패키지로 배포하고, 템플릿 자산(.github 워크플로우·스크립트 등)을 패키지에 번들하여 **npm 버전 = 템플릿 버전** 원자성을 확보한다.
- 기존 CI 체계(main push → patch 자동증가 → PLUGIN-VERSION-SYNC)에 **npm publish 자동화 워크플로우(PROJECT-TEMPLATE-NPM-PUBLISH)** 를 연결한다.
- 단계적 전환: SP1(이름 선점 + 배포 파이프라인) → SP3(리브랜딩) → SP2(마법사 완전 포팅). 과도기 동안 기존 `.sh`/`.ps1`은 deprecated 표기로 유지한다.
- 템플릿 정체성 보존: `bin/`·`src/` 등 CLI 전용 파일은 `template_initializer.sh`와 integrator 제외 목록(3곳 규칙)에 반영하여 사용자 프로젝트로 흘러가지 않게 한다.
- 설계 문서: `docs/superpowers/specs/2026-07-07-projectops-npx-migration-design.md`

⚙️ 작업 내용
---

- [ ] **SP1 — 이름 선점 + npm 배포 파이프라인**
  - 루트 `package.json`을 `projectops` npm 매니페스트로 전환 (`bin`·`files` 화이트리스트·`engines`)
  - `bin/projectops.js` 스텁 CLI 작성 (배너 + 버전 + 기존 스크립트 안내)
  - `PROJECT-TEMPLATE-NPM-PUBLISH.yaml` 워크플로우 신설 (version.yml 변경 트리거, 멱등 publish)
  - `NPM_TOKEN`(Granular Automation Token) Actions Secret 등록 및 workflow_dispatch 최초 배포
  - `template_initializer.sh` + `template_integrator.sh` + `template_integrator.ps1` 3곳 제외 목록에 CLI 전용 파일 반영
- [ ] **SP3 — 리브랜딩 (중간 범위)**
  - 레포명 `projectops` 변경(GitHub 자동 리다이렉트), README·docs·매니페스트 URL 갱신
  - skills 접두사(`suh-*`)·플러그인명(`cassiiopeia`)·config 경로는 유지
- [ ] **SP2 — 마법사 Node 완전 포팅**
  - 기존 플래그(`--mode/--type/--version/--paths/--nexus/--secret-backup/--force`) 100% 호환
  - 복사 제외 목록 단일 소스화(`src/core/exclusions.js`), breaking changes 원격 fetch + 번들 fallback
  - ubuntu/windows/macos 매트릭스 E2E — 기존 `.sh` 실행 결과와 파일 목록 diff 0 검증

🙋‍♂️ 담당자
---

- 개발: Cassiiopeia
