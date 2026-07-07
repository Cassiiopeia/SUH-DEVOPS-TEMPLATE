# projectops npx 전환 설계 (Design Spec)

작성일: 2026-07-07
상태: 사용자 리뷰 대기
선행 문서: `docs/suh-template/plan/20260707_001_projectops_rebranding_and_npm_publish.md` (전 세션 WHAT 계획 — 본 문서가 설계로 구체화·대체)

---

## 1. 목표

1. `template_integrator.sh`(5,650줄) / `template_integrator.ps1`(5,120줄) 이중 유지보수 마법사를 **단일 Node.js CLI**로 완전 전환한다.
2. `npx projectops` 한 줄로 기존 프로젝트에 템플릿 통합이 가능하도록 npm 레지스트리에 배포한다.
3. 이 레포의 **템플릿 정체성**(GitHub "Use this template" → `template_initializer.sh` 정리)을 깨지 않는다.
4. 기존 CI 파이프라인(main push → patch 자동증가 → 매니페스트 버전 동기화)에 **npm publish 자동화**를 연결한다.

## 2. 확정 결정 사항

| # | 결정 | 선택 | 근거 |
|---|------|------|------|
| D1 | 전환 전략 | **단계적 전환 (SP1→SP3→SP2)** | 이름 즉시 선점, 단계별 독립 검증, 과도기 사용자 이탈 없음 |
| D2 | 템플릿 자산 전달 | **npm 패키지에 번들** (`files` 화이트리스트, ~2MB) | npm 버전=템플릿 버전 원자성(기존 PLUGIN-VERSION-SYNC가 이미 동기화), git 불필요, 내부망 npm 미러로도 수신 가능 |
| D3 | npm publish 케이던스 | **deploy 브랜치 push 시 자동** (+ workflow_dispatch) | 실측: VERSION-CONTROL이 GITHUB_TOKEN으로 version.yml을 커밋하면 후속 워크플로우가 트리거되지 않아 main paths 트리거는 동작 안 함. PLUGIN-VERSION-SYNC와 동일 패턴(deploy push → ref: main 체크아웃). `npm view` 중복확인으로 멱등 |
| D4 | 인증 방식 | **Granular Automation Token** → `NPM_TOKEN` secret | 2FA OTP 우회 가능. 최초 배포 후 Trusted Publishing(OIDC) 전환 검토(선택) |
| D5 | CLI 플래그 | 기존 `.sh`/`.ps1`과 **100% 동일 플래그** | 문서·사용자 습관 연속성 (`--mode/--type/--version/--paths/--nexus/--secret-backup/--force`) |
| D6 | 과도기 fallback | `.sh`/`.ps1` **deprecated 배너 부착 후 유지** → SP2 안정화 후 제거 | Node 미설치 사용자(Spring/Flutter 일부) 보호 |

### 가정 [ASSUMPTION — 사용자 확인 필요]

- **A1. 리브랜딩 범위 = 중간**: npm 패키지·CLI·레포명·README·docs·integrator URL은 `projectops`로 전환. **skills 접두사(`suh-*`)·플러그인명(`cassiiopeia`)·config 경로(`~/.suh-template`)는 유지**하고 별도 서브프로젝트로 미룬다. (사용자 부재로 추천안 채택 — 전면 리브랜딩 원하시면 SP3 범위만 확장하면 되고 SP1·SP2는 영향 없음)

## 3. 서브프로젝트 분해

### SP1 — 이름 선점 + npm 배포 파이프라인 (최우선, 소규모)

**산출물**:
1. 루트 `package.json` 전환:
   - `name: "projectops"`, `private` 제거, `bin: {"projectops": "bin/projectops.js"}`, `type: "module"`, `engines: {"node": ">=18"}`
   - `files` 화이트리스트: `bin/`, `src/`, `.github/workflows/`, `.github/scripts/`, `.github/ISSUE_TEMPLATE/`, `.github/config/`, `.github/util/`, `.github/PULL_REQUEST_TEMPLATE.md` (누출 금지: `skills/`, `docs/`, `harness/`, `.claude-plugin/`, 테스트 폴더)
   - 기존 `"pi"` 필드 처리는 미해결 질문 Q1 참조
2. `bin/projectops.js` 스텁 CLI: 배너 + 버전 표시 + "마법사는 곧 제공, 현재는 기존 스크립트 안내" + 기존 curl/ps1 명령 출력
3. `.github/workflows/PROJECT-TEMPLATE-NPM-PUBLISH.yaml` 신설 (§5)
4. **3곳 규칙 즉시 반영** (`bin/`·`src/`가 루트에 생기므로):
   - `template_initializer.sh` `cleanup_template_files()`에 `bin/`·`src/` 삭제 블록 추가
   - `template_integrator.sh` `plugin_items_to_remove` 배열에 추가
   - `template_integrator.ps1` `$pluginItemsToRemove` 배열에 추가
5. npm 계정에서 `NPM_TOKEN`(Granular, automation, publish 권한) 발급 → 레포 Actions secret 등록 (사용자 수동 작업)
6. 최초 배포는 `workflow_dispatch`로 CI에서 실행 — **내부망 로컬 publish 금지** (registry.npmjs.org 직접 접근 불가 가능성)

**완료 기준**: `npx projectops@latest`가 외부망 환경에서 배너를 출력하고, main push 시 새 patch 버전이 npm에 자동 게시된다. 템플릿으로 생성한 새 레포에 `bin/`·`src/`·`package.json`이 남지 않는다.

### SP3 — 리브랜딩 (중간 범위, SP2보다 먼저)

> SP2보다 먼저 수행하는 이유: 새 CLI에 구 URL/구 명칭을 포팅했다가 다시 고치는 재작업 방지.

**변경**:
- GitHub 레포명: `SUH-DEVOPS-TEMPLATE` → `projectops` (GitHub이 구 URL 자동 리다이렉트 — 기존 curl 명령·git remote 계속 동작)
- `README.md`, `docs/` 전반의 명칭·URL·뱃지
- `template_integrator.sh`의 `TEMPLATE_RAW_URL`·`TEMPLATE_REPO`, `.ps1` 대응 상수
- `.claude-plugin/plugin.json`·`marketplace.json`의 `homepage`/`repository`/`url`
- `version.yml` 신규 생성분의 `metadata.template.source` 문자열 → analyze 단계에서 integrator의 update 감지 로직이 이 문자열을 비교하는지 확인 후 **하위호환(구·신 문자열 모두 인정)** 처리

**유지 (A1 가정)**: `suh-*` 스킬 폴더명, `cassiiopeia` 플러그인/마켓플레이스명, `~/.suh-template/config`, 커밋 메시지 prefix

### SP2 — 마법사 Node 완전 포팅 (최대 덩어리)

**패키지 구조**:

```
bin/projectops.js          # #!/usr/bin/env node — ESM 엔트리
src/
  index.js                 # argv 파싱 + 모드 라우팅 (플래그는 .sh와 동일)
  commands/
    interactive.js         # 대화형 마법사 (전체 설치/버전 관리만/워크플로우만/AI 스킬만/되돌리기)
    full.js  version.js  workflows.js  skills.js  revert.js
  core/
    detect.js              # 프로젝트 타입/버전/브랜치 감지 (detect_* 함수군 포팅)
    assets.js              # 패키지 루트 기준 번들 자산 경로 해석 (import.meta.url)
    version-yml.js         # version.yml 생성/파싱/project_paths 처리
    breaking.js            # breaking-changes.json — 원격 fetch 우선 + 번들 fallback
    options.js             # nexus/secret-backup 옵션 저장·판독 (server-deploy/ 폴더 제외 규칙 포함)
    exclusions.js          # ★ 복사 제외 목록 단일 소스 (현행 3곳 동기화 → 1곳)
  ui/
    prompts.js             # @clack/prompts 래핑 — 화살표 메뉴·ESC 뒤로가기·비대화형(--force) 분기
```

**의존성 최소주의**: `@clack/prompts`(대화형 메뉴), `picocolors`(색상), `yaml`(version.yml 파싱) — 전부 순수 JS, 네이티브 애드온 없음. HTTP는 Node 18+ 내장 `fetch`.

**기능 등가 체크리스트** (analyze 단계에서 `.sh` 함수 130개를 모드별로 매핑):
- 모드 5종(interactive/full/version/workflows/skills) + revert
- 멀티타입 csv(`--type spring,react`), 모노레포 `--paths "flutter=app"`
- `--nexus` 시 `server-deploy/` 폴더째 제외 규칙
- breaking changes 버전 비교·경고
- Codex/Claude 플러그인 마켓플레이스 등록(skills 모드)
- stdin/TTY 감지(비대화형 환경에서 `--force` 요구)

**`.sh`/`.ps1` 처리**: 파일 상단 deprecated 배너("npx projectops 사용 권장") 추가 후 유지. N버전(제안: 2개 마이너) 후 삭제 별도 결정.

**얻는 것**: bash 3.2/BSD 도구/`set -e` 함정(CLAUDE.md의 macOS 실측 함정 문서 대부분)이 신규 개발에서 소멸. Windows/macOS 단일 코드 경로. 프롬프트 주입으로 테스트 자동화 용이(expect/Docker QEMU 불필요).

## 4. 데이터 흐름

```
[개발자] npx projectops --mode full
   → npm 레지스트리(또는 사내 미러)에서 projectops@latest 수신
   → CLI가 자기 패키지 내부의 번들 자산(.github/workflows 등)을 읽음
   → 대상 프로젝트 감지(타입/버전/브랜치) → 대화형 확인 or --force
   → exclusions.js 목록 제외하고 복사 + version.yml 생성/갱신
   → breaking-changes.json은 GitHub raw에서 fetch(실패 시 번들본 fallback)
```

## 5. CI/CD — PROJECT-TEMPLATE-NPM-PUBLISH.yaml

```yaml
on:
  push: { branches: [deploy] }   # ★ main paths 트리거 불가 — VERSION-CONTROL의 GITHUB_TOKEN 커밋은 후속 워크플로우를 트리거하지 않음 (PLUGIN-VERSION-SYNC와 동일 패턴)
  workflow_dispatch:             # 최초 선점 배포·재시도용
permissions: { id-token: write, contents: read }
jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - checkout (ref: main)     # deploy push 트리거라도 항상 main 기준으로 게시
      - setup-node (node 20, registry-url: https://registry.npmjs.org)
      - VERSION=$(./.github/scripts/version_manager.sh get | tail -n 1)
      - npm pkg set version=$VERSION          # PLUGIN-VERSION-SYNC 선행 여부와 무관하게 결정적
      - npm view projectops@$VERSION 성공 시 → 이미 배포됨, 정상 종료(멱등)
      - npm publish --provenance --access public   # env: NODE_AUTH_TOKEN=${{ secrets.NPM_TOKEN }}
```

- 커밋을 만들지 않으므로 `[skip ci]` 루프 없음. `concurrency` 그룹 지정.
- `PROJECT-TEMPLATE-PLUGIN-VERSION-SYNC`와의 순서 경합은 `npm pkg set version`으로 무력화(레지스트리에 올라가는 버전은 항상 version.yml 기준).
- 실측 확인(2026-07-07): `npm pack --dry-run`에서 `files`에 명시한 `.github/workflows/`가 정상 포함됨 — D2 번들 전략 실현 가능.
- 이 워크플로우는 마켓플레이스 전용 → **initializer 삭제 목록에 추가** (PLUGIN-VERSION-SYNC와 동일 취급).

## 6. 템플릿 이중 정체성 정합표

| 파일/폴더 | npm 패키지(`files`) | 템플릿 생성 레포(initializer) | 통합 대상 레포(integrator/CLI) |
|---|---|---|---|
| `bin/`, `src/` | ✅ 포함 | ❌ 삭제 (신규 추가) | ❌ 복사 제외 (신규 추가) |
| `package.json` | ✅ (매니페스트) | ❌ 삭제 (기존 동작) | ❌ 복사 제외 (기존) |
| `.github/workflows` 등 자산 | ✅ 번들 | ✅ 유지 | ✅ 복사 대상 |
| `skills/`, `docs/`, `harness/`, `.claude-plugin/` | ❌ 미포함 | ❌ 삭제 (기존) | ❌ 제외 (기존) |
| NPM-PUBLISH 워크플로우 | ✅ (files상 .github 포함이면 같이 들어감 — 무해) | ❌ 삭제 (신규 추가) | ❌ 복사 제외 (신규 추가) |

## 7. 에러 처리

- **npm 이름 선점 실패**(`projectops` 이미 존재): 첫 publish 시 판명 → fallback `@cassiiopeia/projectops` (`npx @cassiiopeia/projectops`). SP1에서 즉시 확인되므로 이후 SP 영향 최소.
- **비-TTY 환경**: `.sh`의 stdin 모드와 동일하게 `--force` + 플래그 완비 요구, 아니면 명확한 에러.
- **Node < 18**: `engines` + 런타임 버전 체크 → 기존 curl 방식 안내 메시지.
- **breaking-changes fetch 실패**: 번들본 fallback + 경고 1줄.
- **publish 중복**: `npm view` 선확인으로 멱등 종료(실패 아님).

## 8. 테스트 전략

- **단위**: `node:test` 또는 vitest — `detect`/`version-yml`/`exclusions`/`options` 순수 로직. 프롬프트는 주입 스텁(현행 expect 하네스 대체).
- **패키징**: `npm pack --dry-run` 결과를 CI에서 검사 — `skills/`·`docs/`·`harness/` 누출 시 실패 처리.
- **E2E**: CI 매트릭스(ubuntu/windows/macos)에서 임시 폴더에 `--mode full --force --type spring,react` 실행 → 기존 `.sh` 실행 결과와 **파일 목록 diff 0** 확인(등가성 증명, SP2 완료 게이트).
- **기준 레포 검증**: RomRom-FE/BE에서 실측 (passQL은 신뢰 기준 아님 — CLAUDE.md 규칙).

## 9. 미해결 질문 (사용자 결정 필요)

- **Q1. pi 매니페스트 충돌**: 루트 `package.json`의 `name`이 `cassiiopeia`(pi 패키지 식별자) → `projectops`로 바뀜. pi 생태계 설치 사용자에게 이름 변경이 허용되는가? (허용 시 그대로, 불가 시 pi 매니페스트 분리 방안 필요)
- **Q2. A1 가정 승인**: 리브랜딩 중간 범위(suh-* 스킬·cassiiopeia 플러그인명 유지)로 진행해도 되는가?
- **Q3. `.sh`/`.ps1` 제거 시점**: SP2 안정화 후 언제 삭제할지 (제안: 2 마이너 버전 유예)

## 10. 자가 리뷰 로그

- placeholder 없음 / D1~D6 상호모순 없음 확인.
- 범위: SP1은 단일 구현 계획으로 적정. SP2는 자체적으로 크므로 **SP2 진입 시 analyze(함수 130개 → 모듈 매핑표)를 별도 수행** 전제.
- 모호성 제거: "npx 전환"의 의미를 D2(번들) + D5(플래그 동일)로 고정. 자산을 clone하는 대안은 명시적으로 폐기.
