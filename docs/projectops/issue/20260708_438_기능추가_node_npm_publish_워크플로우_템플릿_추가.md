📝 현재 문제점
---

`node` 타입에는 **워크플로우 자산이 하나도 없다**. `project-types/node/` 폴더 자체가 존재하지 않는다.

- `node`는 "package.json 있음 + react/react-native 아님"인 fallback 타입으로 감지·버전관리(package.json)만 되고, CI도 CICD도 npm publish도 없다.
- npm 라이브러리를 개발해 npmjs에 배포하려는 사용자가 물려받을 publish 워크플로우가 템플릿에 없다.
- 현재 이 레포(projectops) 자신을 배포하는 `PROJECT-TEMPLATE-NPM-PUBLISH.yaml`은 존재하지만, 이는 **이 레포 전용**(template_initializer가 삭제, integrator가 복사 제외)이라 사용자 프로젝트로 흘러가지 않는다.

관련 파일:
- `.github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml` (이 레포 전용 — 로직 승격 베이스)
- `.github/workflows/project-types/node/` (신규 생성 대상)
- `template_integrator.sh` / `.ps1` (opt-in 옵션 파싱·복사·version.yml 저장)

🛠️ 해결 방안 / 제안 기능
---

**이 레포 전용 npm publish 로직을 사용자 프로젝트용 워크플로우로 승격하고, `--npm-publish` opt-in으로 포함한다.** (공개 npmjs 대상)

새 워크플로우: `project-types/node/npm-publish/PROJECT-NODE-NPM-PUBLISH.yaml`

- **트리거**: main push (릴리스 머지 시 자동 배포). README-VERSION-UPDATE 등 다른 main-push 워크플로우와 동일 타이밍. `workflow_dispatch`도 포함.
- **버전**: `version_manager.sh get`으로 version.yml에서 읽어 package.json에 주입.
- **멱등**: `npm view`로 이미 배포된 버전이면 skip.
- **배포**: `npm publish --provenance --access public` (공개 npmjs 확정).
- **Secret**: `NPM_TOKEN`.

이 레포 전용 원본 대비 변경점:
- 헤더 주석을 일반 사용자용으로 교체
- `checkout ref: main` 고정 제거
- 요약 메시지의 하드코딩된 패키지명(`projectops`)을 `npm pkg get name` 변수로 치환

**integrator opt-in** (Spring `--nexus` 패턴 미러링):
- `--npm-publish` / `--no-npm-publish` 플래그 (`.ps1`은 `-NpmPublish`)
- `INCLUDE_NPM_PUBLISH` 변수
- 꺼져 있으면 `npm-publish/` 폴더째 복사 제외
- `version.yml`의 `metadata.template.options.npm_publish`에 저장 (`nexus`·`secret_backup`과 나란히)
- 대화형 질문 + 편집 메뉴 항목 추가

> 폴더 구조는 Spring 패턴(`nexus/`·`server-deploy/`)을 따라 `node/npm-publish/` 하위 폴더로 둔다. 나중에 node CI/CICD를 추가해도 자리가 안 옮겨진다.

⚙️ 작업 내용
---

- `PROJECT-NODE-NPM-PUBLISH.yaml` 작성 (전용 원본 승격)
- `template_integrator.sh`: `--npm-publish` 파싱·복사 로직·version.yml 저장/읽기·편집메뉴
- `template_integrator.ps1`: 동일 (`-NpmPublish`)
- CLAUDE.md에 node 타입 워크플로우 표 + `--npm-publish` 옵션 문서화
- `bash -n`·PowerShell 파서·macOS bash 3.2 호환 검증

> **참고**: node 서버 CICD(Docker+SSH)와 배포/publish 타겟 축 일반화는 별도 이슈([배포/publish 타겟 재설계])에서 다룬다. 이 이슈는 npm publish 워크플로우 추가에만 집중한다.

🙋‍♂️ 담당자
---

- 백엔드: Cassiiopeia
