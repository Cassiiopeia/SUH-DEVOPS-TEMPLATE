# NPX 마법사 가이드 (npx projectops)

기존 프로젝트에 템플릿을 통합·업데이트하는 유일한 공식 경로입니다. 구 `template_integrator.sh`/`.ps1`은 v4.3.0에서 지원 종료(EOF)되었습니다 ([상세](TEMPLATE-INTEGRATOR.md)).

- **요구사항**: Node.js 20.12 이상
- macOS / Linux / Windows 공통 단일 경로

---

## 기본 사용법

```bash
# 대화형 마법사
npx projectops

# 비대화형 (CI 등)
npx projectops --mode full --type spring,react --force

# Agent Skills만 설치
npx projectops --mode skills

# 전체 옵션
npx projectops --help
```

| 모드 | 기능 |
|------|------|
| `full` | 워크플로우 + version.yml + 이슈 템플릿 + Skills 전체 통합 |
| `version` | version.yml만 |
| `workflows` | 워크플로우만 |
| `issues` | 이슈/PR 템플릿만 |
| `skills` | Agent Skills만 |

선택 값은 전부 `version.yml`의 `metadata.template.options.*`에 저장되어, 다음 업데이트 시 재질문 없이 재사용됩니다.

---

## 배포/publish 2축 (#439)

배포는 서로 독립인 **두 개의 축**으로 표현됩니다. 마법사가 타입 확정 직후 질문합니다.

| 축 | 의미 | 다중성 | 값 | version.yml 키 |
|----|------|--------|-----|---------------|
| **deploy** | 실행물(서버/앱)을 어디에 올리나 | **택1** | `docker-ssh`(기본) · `vercel` · `none` | `options.deploy` |
| **publish** | 라이브러리/패키지를 어느 레지스트리에 내나 | **0..n 공존** | `nexus` · `npm` · `github-packages` | `options.publish` 배열 |

```bash
# 비대화형 지정
npx projectops --deploy docker-ssh --publish nexus,npm
```

### 축별로 포함되는 워크플로우

| 선택 | 포함되는 워크플로우 | 원본 위치 |
|------|-------------------|----------|
| `--deploy docker-ssh` | SIMPLE/NONSTOP-TRAEFIK/NONSTOP-NGINX/PR-PREVIEW 등 서버 배포 세트 | `project-types/spring/server-deploy/` |
| `--deploy vercel` | `PROJECT-COMMON-VERCEL-DEPLOY` (VERCEL_TOKEN·VERCEL_ORG_ID·VERCEL_PROJECT_ID secret 필요) | `project-types/common/deploy/vercel/` |
| `--deploy none` | 서버 배포 워크플로우 제외 | - |
| `--publish nexus` | `PROJECT-SPRING-NEXUS-CI` / `-NEXUS-PUBLISH` | `project-types/spring/publish/nexus/` |
| `--publish npm` | `PROJECT-NODE-NPM-PUBLISH` (NPM_TOKEN secret) | `project-types/node/publish/npm/` |
| `--publish github-packages` | `PROJECT-SPRING-GITHUB-PACKAGES-PUBLISH` | `project-types/spring/publish/github-packages/` |
| `--secret-backup` | `PROJECT-COMMON-SECRET-FILE-UPLOAD` (opt-in) | `project-types/common/secret-backup/` |

### 알아둘 규칙

- **`basic` 단독 타입은 배포/publish 질문을 건너뜁니다** — `deploy=none`·`publish=[]`로 조용히 확정됩니다. 타입을 실타입으로 바꾸면 그때 질문이 등장합니다.
- **구 플래그 deprecated**: `--nexus`/`--npm-publish`는 각각 `--publish nexus`/`--publish npm`으로 해석되며 경고가 출력됩니다 (`--nexus`는 추가로 `--deploy none` 함의). 1 minor 유지 후 제거 예정.
- version.yml의 구 키(`nexus`/`npm_publish`)는 업데이트 시 신 축으로 자동 변환·기록됩니다.

---

## 모노레포 경로 (`project_paths`)

타입별 프로젝트가 서브폴더에 있으면 경로를 지정합니다. 상세는 [버전 관리](VERSION-CONTROL.md) 참조.

```bash
npx projectops --paths "flutter=app,react=client"
```

---

## 레거시 워크플로우 자동 마이그레이션 (#470)

`full`/`workflows` 모드로 통합·업데이트하면 마법사가 대상 레포의 **구세대 템플릿 워크플로우 잔재를 자동 감지**합니다. 구 워크플로우가 신 워크플로우와 공존하면 릴리스 PR 이중 처리·CI 중복 실행 같은 실해가 발생하기 때문입니다.

### 2티어 안전 정책

| 티어 | 판정 기준 | 조치 |
|------|----------|------|
| **safe** | 순수 리네임·대체 (공존 시 중복 실행 실해) | 대화형: 확인 1회 후 `.bak` 무해화 / 비대화형(`--force`): 자동 무해화 |
| **confirm** | 배포 파이프라인일 수 있음 (그 레포의 유일한 현역 배포 가능성) | **자동 조치 없음** — 안내만 출력. `--force`에서도 건드리지 않음 |

### 보장 사항

- **커스텀 워크플로우 불가침**: 레지스트리는 정확한 파일명 매칭만 사용합니다 (글롭 금지). 사용자가 직접 만든 워크플로우는 절대 건드리지 않습니다.
- **복원 가능**: safe 조치는 삭제가 아니라 `.bak` 확장자 무해화입니다. 되돌리려면 `.bak`을 제거하면 됩니다.
  ```bash
  mv .github/workflows/PROJECT-OLD-NAME.yaml.bak .github/workflows/PROJECT-OLD-NAME.yaml
  ```
- **멱등**: 같은 명령을 다시 실행해도 이미 처리된 항목은 재조치되지 않습니다.

### 감지 대상 (v4.3.x 스냅샷)

전체 목록의 SSOT는 `src/core/migrations/registry.js`입니다. 요약:

- **workflow / safe (16종)**: 1세대 리네임(`PROJECT-VERSION-CONTROL` 등), 구명칭 릴리스 워크플로우(`PROJECT-AUTO-CHANGELOG-CONTROL`·`PROJECT-COMMON-AUTO-CHANGELOG-CONTROL` → `PROJECT-COMMON-RELEASE-CHANGELOG`), 리브랜딩 리네임(`PROJECT-FLUTTER-SUH-LAB-APP-BUILD-TRIGGER` → `PROJECT-FLUTTER-PROJECTOPS-APP-BUILD-TRIGGER`), next 타입 폐지(`PROJECT-NEXT-CI`/`-CICD` → `PROJECT-REACT-*`), 구 확장자(.yml) CI 등
- **workflow / confirm (22종)**: SYNOLOGY 세대 배포 7종, 1세대 Spring/Python/Android/iOS 배포, AUTO-FILE-UPLOAD 계열, 구 Nexus publish 계열 등 — 전부 "현역 배포일 수 있음"이라 안내만
- **root-file / safe (2종)**: `SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md`·`SETUP-GUIDE.md` → `PROJECTOPS-SETUP-GUIDE.md` (구 설치 가이드 잔재)

### 기여자 가이드라인 — 워크플로우를 리네임/삭제할 때

템플릿에서 워크플로우나 루트 파일을 리네임·폐기하면 **반드시 구 이름을 `src/core/migrations/registry.js`에 한 줄 추가**합니다. 이것이 기존 통합 레포의 구 파일을 자동 정리하는 유일한 경로입니다 (레거시 마이그레이션은 전부 이 레지스트리 한 곳에서 관리).

1. 항목 스키마: `id`(kebab-case) · `category`("workflow"|"root-file") · `tier` · `file`(정확한 파일명, 글롭 금지) · `replacedBy`(없으면 null) · `since` · `reason` · `contentMarker`(선택 — 파일명이 범용적일 때 오탐 방지)
2. **tier 판단 기준**: 실해로 고른다 —
   - `safe`: 신형이 같은 기능을 완전 대체(순수 리네임). 공존 시 이중 트리거가 실해
   - `confirm`: 배포 파이프라인일 수 있음. 오살하면 그 레포의 배포가 끊긴다 → 자동 조치 금지
3. `test/migrations.test.js`가 레지스트리 항목이 **현행 배포 세트와 겹치지 않는지**(살아있는 워크플로우 오살 방지) 자동 검증한다. 등록 후 `npm test`로 확인.

---

## 관련 문서

- [Template Integrator EOF 안내](TEMPLATE-INTEGRATOR.md) — 구 스크립트 → npx 플래그 대응표
- [버전 관리](VERSION-CONTROL.md) — version.yml·모노레포 project_paths
- [체인지로그 자동화](CHANGELOG-AUTOMATION.md#릴리스-노트-provider-사다리) — 릴리스 노트 provider 사다리
