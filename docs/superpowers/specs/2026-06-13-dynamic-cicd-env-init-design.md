# 마법사 동적 CICD 환경설정 init 설계 (토큰+마커 엔진)

- 작성일: 2026-06-13
- 대상 레포: SUH-DEVOPS-TEMPLATE (템플릿 원본 — "Use this template" + 마법사 배포원, 두 정체성)
- 관련: `template_integrator.sh` / `.ps1`, `.github/workflows/project-types/**`, `version.yml`
- 선행 설계: [모노레포 project_paths](2026-06-11-monorepo-project-paths-design.md), [멀티타입](2026-06-01-multitype-design.md)

---

## 1. 문제 정의

`template_integrator` 마법사로 워크플로우를 통합하면 파일은 **그대로 복사만** 되고 `env` 값은
다른 프로젝트의 하드코딩 기본값(`PROJECT_NAME: "mapsy-back"`, `APPLICATION_YML_DIR: "MS-Web/src/main/resources"`)이
그대로 남는다. 사용자는 매번 **수동으로** 워크플로우 env를 자기 프로젝트에 맞게 고쳐야 한다.

추가로 전수조사 결과 **예시값 자체가 일관성이 없다**(아래 §3). 같은 `PROJECT_NAME`인데
`project` / `mapsy-back` / `프로젝트명-ai` / `suh-project-utility` / `your-project` 5종이 혼재한다.

### 목표 (사용자 요구 4가지)
1. **전체 워크플로우 정비** — 배포뿐 아니라 가변값 있는 모든 워크플로우
2. **완전 커스텀 가능** — 미리 정한 키 외 임의 값도 사용자가 자기 워크플로우에 추가해 동적 처리 가능
3. **예시값 일관성 통일** — 제각각인 기본값을 표준 토큰으로 정리
4. **모든 레포에 동적 적용** — 특정 프로젝트 전용이 아닌 범용 메커니즘

핵심 원칙: 자동화하되, 결과물은 사람이 열어 **바로 이해하고 직접 수정할 수 있는 평범한 env**.

### 비목표 (YAGNI)
- GitHub Secrets(토큰/비밀번호/SERVER_HOST) 수집·주입 — 영원히 마법사 미관여
- Flutter fastlane/서명키/번들ID — 기존 web 마법사(testflight/playstore-wizard) 담당
- 워크플로우가 런타임에 version.yml을 `yq`로 읽는 구조 — 17개 job 수정+yq 의존, 채택 안 함

---

## 2. 핵심 엔진 — 토큰 + 마커 (확정)

### 발상
마법사가 "어떤 키를 자동/질문/유지할지" **키 목록을 외우지 않는다**. 대신 **워크플로우 자신이 주석으로 선언**한다.
마법사는 `@wizard` 마커가 붙은 줄을 스캔해 토큰을 치환할 뿐. → 새 키 추가 시 마법사 코드 불변 = 완전 커스텀 + 모든 레포 동적.

### 형식 — 마커는 ASCII `@wizard` (이모지 금지)
이모지(`🪄`)는 macOS BSD sed와 Linux GNU sed, Windows Git Bash에서 멀티바이트 처리가 달라 매칭이 깨질 수 있다.
이 레포는 mac+Windows 양쪽에서 돌아야 하므로 **마커는 ASCII `@wizard`로 고정**한다. `grep '@wizard'`로 안전하게 잡히고,
사람이 새 키를 추가할 때 타이핑도 쉽다.

```yaml
env:
  PROJECT_NAME: "__PROJECT_NAME__"        # @wizard ask: 프로젝트 이름 [기본: 레포명]
  DEPLOY_PORT: "__DEPLOY_PORT__"          # @wizard ask: 배포 포트 [기본: 8080]
  JAVA_VERSION: "__JAVA_VERSION__"        # @wizard ask: JDK 버전 [기본: 21]
  APPLICATION_YML_DIR: "__APPLICATION_YML_DIR__"  # @wizard auto-find: application.yml 위치
  VOLUME_HOST_PATH: "__VOLUME_HOST_PATH__"        # @wizard ask: 볼륨 경로 [기본: /volume1/projects/__PROJECT_NAME__]
  SPRING_PROFILE: "prod"                  # (마커 없음 = 마법사 미관여, 고정값)
  REDIS_PORT: "__REDIS_PORT__"            # @wizard ask: 레디스 포트  ← 사용자가 추가해도 마법사가 자동 질문
```

### 마커 4종
| 마커 | 의미 | 마법사 동작 |
|------|------|------------|
| `@wizard auto: <설명>` | 자동 도출 | 자동값으로 토큰 치환 (질문 안 함) |
| `@wizard ask: <설명> [기본: <값>]` | 질문 | version.yml 기존값 또는 [기본]을 디폴트로 질문 → 치환 + 저장 |
| `@wizard auto-find: <설명>` | 파일탐색 | `find`로 후보 탐색 → 확인 → 치환 (못 찾으면 질문) |
| (마커 없음) | 유지 | 손대지 않음 (SPRING_PROFILE 등 고정값) |

### 토큰 규칙
- 형식: `__KEY__` (키명과 동일하게). 예: `PROJECT_NAME` → `__PROJECT_NAME__`
- 토큰 안에 토큰 중첩 허용: `/volume1/projects/__PROJECT_NAME__` → PROJECT_NAME 치환 후 재치환
- 마법사 실행 후 **치환 안 된 토큰이 남으면 경고** (마커 누락 탐지)

### 치환 후 결과 (사람 친화)
```yaml
env:
  PROJECT_NAME: "passql"        # @wizard set (직접 수정 가능)
  DEPLOY_PORT: "8097"           # @wizard set (직접 수정 가능)
```
→ 평범한 값. `yq` 참조 아님. 사람이 열면 바로 이해·수정.
- 치환 시 원래 마커(`@wizard ask: ...`)를 `@wizard set`으로 바꿔 **이미 처리됨**을 표시 → 재실행 시 set은 "이미 값 있음" 디폴트로.
- 모든 매칭 마커는 ASCII `@wizard ...`. 사람용 장식 이모지는 워크플로우 본문 주석에만(매칭 대상 아님) 허용.

---

## 3. 현재 일관성 깨짐 (전수조사 2026-06-13, 44개 파일)

### PROJECT_NAME 5종 혼재
| 값 | 사용처 |
|----|--------|
| `project` | next/react CI·CICD |
| `mapsy-back` | spring SIMPLE/NONSTOP-NGINX/NONSTOP-TRAEFIK |
| `suh-project-utility` | spring PR-PREVIEW |
| `프로젝트명-ai` | python CI/CICD (한글 플레이스홀더) |
| `your-project` | flutter |

### 키명 혼용
| 개념 | 혼용된 키명 | 통일안 |
|------|------------|--------|
| env 파일 | `ENV_FILE` / `ENV_FILE_NAME` / `ENV_FILE_PATH` | **`ENV_FILE`** |
| 도메인 | `DOMAIN_NAME`(nginx) / `PRODUCTION_DOMAIN`(traefik) | **`PRODUCTION_DOMAIN`** |
| yml 경로 | `APPLICATION_YML_DIR`(dir) / `APPLICATION_YML_PATH`(file) | 의미가 달라 둘 다 유지, 주석 명확화 |
| 볼륨 컨테이너 | `/app` / `/mnt/<name>` / `/mnt` | **`/mnt/__PROJECT_NAME__`** |

### 버전 키
- NODE_VERSION `20.15.0` / FLUTTER_VERSION `3.35.5` / PYTHON_VERSION `3.13` / XCODE_VERSION `26.0` — 일관 → 마커 없이 고정값 유지
- **JAVA_VERSION은 25/21/17 혼용 → `ask` 대상** (사용자 요구 반영). 실태:
  - Flutter Android 5개 = `17` (Android Gradle Plugin 제약)
  - Spring 배포 4개 = `21` 3개 + `'17'` 1개(PR-PREVIEW, 싱글쿼트 — 21이어야 할 오류값으로 추정)
  - 추가로 프로젝트에 따라 25(LTS)까지 쓰임
  → **타입별 기본값을 다르게** ask: `__JAVA_VERSION__` + `@wizard ask: JDK 버전 [기본: <타입별>]`
    - flutter → 기본 17, spring/기타 → 기본 21. 사용자가 25 등으로 변경 가능.

### on: 트리거 6패턴 / 주석 스타일 4패턴
- paths 앵커는 44개 중 0개 → 멀티타입 동시실행 문제. paths 주입은 별도 처리(§5).
- 주석 스타일 표준화: env 위 블록 주석 + 키별 `@wizard` 마커 한 줄.

---

## 4. 아키텍처 — 2단계

```
[1단계] 템플릿 원본 정비 (이 레포에서 1회, 사람이 수행)
   가변값 있는 모든 워크플로우의 env를 토큰+마커로 변환:
     · PROJECT_NAME 5종 → "__PROJECT_NAME__" 통일 + @wizard ask
     · 포트/볼륨/도메인/yml경로 → 토큰화 + 적절한 마커
     · JAVA_VERSION → 토큰화 + @wizard ask (타입별 기본값)
     · 고정값(SPRING_PROFILE, NODE_VERSION 등)은 마커 없이 유지
     · on: 블록에 # @wizard paths-anchor 주석 심기

[2단계] 마법사 런타임 (template_integrator.sh / .ps1)
   _copy_workflows_for_type() 로 cp 복사
        │  (복사 직후 신규 호출)
        ▼
   configure_workflow_env(type, file)
     1. 파일에서 @wizard 마커 줄 전부 스캔 (키 목록 외우지 않음)
     2. 마커별 처리:
          auto      → 자동값 치환
          ask       → version.yml deploy.{type}.{key} 또는 [기본] 디폴트로 질문 → 치환 + 저장
          auto-find → find 탐색 → 확인 → 치환
     3. 토큰 재귀 치환 (__PROJECT_NAME__ 중첩 해소)
     4. paths 앵커 → project_paths 있고 멀티타입이면 주입 (flutter·NONSTOP 제외)
     5. 잔류 토큰 검사 → 있으면 경고
```

### 자동값 출처 (auto / auto-find)
| 토큰 | 출처 |
|------|------|
| `__PROJECT_NAME__` | git remote 레포명 (실패 시 폴더명) |
| `__APPLICATION_YML_DIR__` | `find {type경로} -path "*/src/main/resources/application*.yml"` → dirname |
| `__VOLUME_HOST_PATH__` (ask지만 기본 도출) | `/volume1/projects/__PROJECT_NAME__` |

### ask 마커의 [기본값]은 타입 의존 가능
`@wizard ask: ... [기본: 21]`의 `[기본]`은 **고정 리터럴이거나 타입별 분기**일 수 있다.
JAVA_VERSION처럼 타입마다 권장값이 다르면, 마법사가 처리 중인 `type`에 따라 디폴트를 고른다:
| 토큰 | flutter 기본 | spring/기타 기본 |
|------|:---:|:---:|
| `__JAVA_VERSION__` | 17 | 21 |
> 우선순위: version.yml `deploy.{type}` 기존값 > 타입별 기본 > 마커의 `[기본]` 리터럴.

---

## 4.5 마법사 함수 `configure_workflow_env` — 구현 상세 (2단계)

`resolve_project_paths`(`template_integrator.sh:1313`)와 **동일한 패턴**으로 구현한다. 그 함수가 본보기다.

### 호출 위치
`_copy_workflows_for_type()`(`:2638`)에서 워크플로우를 `cp`로 복사한 **직후**, 복사된 각 파일에 대해 호출.
`.ps1`은 `Configure-WorkflowEnv`로 1:1 동일.

### 입력 UX — "엔터 = 기본값" (타이핑 강요 금지) ⭐
ask 마커를 만나면 기본값을 **미리 채워 보여주고**, 사용자가 엔터만 치면 그 기본값을 채택한다.
```
Spring 배포 포트를 입력하세요 [기본: 8080]: ▮      ← 엔터 → 8080 채택
                                          9090     ← 입력 → 9090 채택
```
- `safe_read`로 입력받되 **빈 입력(엔터)이면 기본값 사용**. ESC는 기본값 유지하고 다음으로.

### 기본값 우선순위 (위→아래, 먼저 발견 채택)
1. version.yml `deploy.{type}.{KEY}` 기존값 (재실행 시)
2. **타입별 상식 기본값** (아래 테이블 — 마법사 내장)
3. 마커의 `[기본: X]` 리터럴

### 타입별 상식 기본값 테이블 (마법사 내장 — `default_for_type_key()`)
| KEY | spring | python | react/next | flutter | node |
|-----|:---:|:---:|:---:|:---:|:---:|
| `DEPLOY_PORT` | 8080 | 8000 | 3000 | — | 3000 |
| `JAVA_VERSION` | 21 | — | — | 17 | — |
| `VOLUME_HOST_PATH` | /volume1/projects/{name} | /volume1/projects/{name} | — | — | — |
| `VOLUME_CONTAINER_PATH` | /mnt/{name} | /mnt/{name} | — | — | — |
| `DOMAIN_NAME`·`PRODUCTION_DOMAIN` | example.com | — | — | — | — |
> 테이블에 없는 KEY는 마커의 `[기본]` 리터럴을 사용. 그것도 없으면 빈 문자열로 두고 경고.

### 3가지 진행 모드 ⭐
1. **하나씩 확인** (기본 대화형): ask 마커마다 질문하되 엔터=기본값
2. **전부 기본값 일괄**: 함수 시작 시 "배포 설정을 전부 기본값으로 빠르게 채울까요? [Y/n]" 한 번 물어 Y면 이후 질문 생략하고 전부 기본값 적용
3. **비대화형** (`--force` 또는 no-TTY): `resolve_project_paths`와 동일하게 **묻지 않고** 우선순위대로 기본값 자동 채택

### 처리 순서 (한 파일당)
```
1. grep '@wizard' 로 마커 줄 스캔 (없으면 즉시 return — 안전 폴백)
2. 각 마커:
     auto       → 자동값으로 토큰 sed 치환 (PROJECT_NAME=레포명)
     auto-find  → find 탐색 → 후보 1개면 자동, 여러개면 질문(엔터=첫후보) → 치환
     ask        → 기본값 우선순위로 디폴트 결정 → (모드에 따라) 질문/자동 → sed 치환 + version.yml 저장 예약
3. 토큰 재귀 치환: 값에 남은 __PROJECT_NAME__ 등을 한 번 더 해소
4. paths 앵커: # @wizard paths-anchor 줄을 project_paths 기반 paths 블록으로 치환 (멀티타입+모노레포만, flutter·NONSTOP 제외)
5. 잔류 토큰 검사: __[A-Z_]+__ 가 남으면 print_warning
```

### 치환 헬퍼 (BSD/GNU sed 양립 — `.bak` 임시파일 후 삭제)
```bash
_wf_set_env() {   # $1=파일 $2=키 $3=값
  # 키 줄의 따옴표 값만 교체, @wizard 주석은 'set'으로 갱신해 처리됨 표시
  sed -i.wftmp -E "s|^([[:space:]]*$2:[[:space:]]*\")[^\"]*(\".*)|\1$3\2|" "$1"
  sed -i.wftmp -E "s|(^[[:space:]]*$2:.*)# @wizard (ask\|auto\|auto-find)[^\"]*|\1# @wizard set (직접 수정 가능)|" "$1"
  rm -f "$1.wftmp"
}
```
> 값에 `&`·`|`·`/` 가 들어갈 수 있어(경로) sed 구분자는 `|`를 쓰고, 값은 별도 이스케이프 처리한다.

---

## 5. 멱등성 / 사람 우선 / 안전 폴백

- **멱등성**: 토큰 치환은 1회성이나, 재실행 시 이미 치환된 파일은 토큰이 없으므로 건너뜀. version.yml deploy 값을 질문 디폴트로 제시("지난번 8097 유지?").
- **사람 우선**: 사람이 치환 후 값을 직접 고쳤으면, 재실행 시 **현재값 vs 새 제안 diff 표시 후 덮어쓸지 질문**. yml이 런타임에 덮어쓰지 않음.
- **안전 폴백**: `@wizard` 마커가 없는 워크플로우(사용자 자작·외부)는 **건드리지 않고 cp만**. 기존 동작 100% 보존.
- **paths 주입 제외**: flutter(workflow_run 트리거), NONSTOP(push 주석처리·dispatch only).

---

## 6. version.yml 스키마 (신규 `deploy` 블록 — 비민감, 기억용)

```yaml
deploy:                          # 마법사가 기억하는 배포 설정 (비민감 / 사람이 직접 수정 가능)
  spring:
    PROJECT_NAME: "passql"
    DEPLOY_PORT: "8097"
    VOLUME_HOST_PATH: "/volume1/projects/passql"
    APPLICATION_YML_DIR: "server/PQL-Web/src/main/resources"
  python:
    PROJECT_NAME: "passql-ai"
    DEPLOY_PORT: "8092"
```
- **키를 워크플로우 env 키명 그대로** 저장 → 범용. 커스텀 키(`REDIS_PORT`)도 자동 수용.
- 비민감 값만. Secret 절대 미포함. (DEPLOY_PORT·VOLUME_HOST_PATH는 이미 워크플로우 yaml에 평문 커밋되는 값)
- 권위 아님(기억용). `create_version_yml()`(`template_integrator.sh:2091`)에 deploy 블록 생성 추가.

---

## 7. 정비 대상 워크플로우 분류

| 분류 | 파일 | 토큰화 범위 |
|------|------|------------|
| Spring 배포 | SIMPLE / NONSTOP-NGINX / NONSTOP-TRAEFIK / PR-PREVIEW | PROJECT_NAME, JAVA_VERSION(ask 21), 포트(타입별), 볼륨, 도메인, yml경로 |
| Python 배포 | SYNOLOGY-CICD / PR-PREVIEW | PROJECT_NAME, DEPLOY_PORT, 볼륨 |
| React/Next 배포 | REACT-CICD / NEXT-CICD | PROJECT_NAME, DOCKER_IMAGE_PREFIX, ENV_FILE |
| Flutter | CI / PLAYSTORE/FIREBASE/SYNOLOGY-CICD / TEST-APK 등 | **PROJECT_NAME + JAVA_VERSION(ask 17)** (fastlane·서명은 web 마법사) |
| CI류 | REACT-CI/NEXT-CI/PYTHON-CI | PROJECT_NAME, ENV_FILE (가변값만) |
| Common | VERSION-CONTROL 등 | 가변값 거의 없음 — 정비 불필요 |

> Flutter는 §2 비목표(fastlane/서명)는 제외하되, **CI성 가변값(PROJECT_NAME·JAVA_VERSION)은 토큰화**한다. JAVA_VERSION 혼용 해소가 목적.

---

## 8. 레포 동기화 의무 (CLAUDE.md 규칙)

- 공통 워크플로우 수정 시 `project-types/common/` + `.github/workflows/` 루트 **두 곳 동일 유지**
- `.sh`/`.ps1` **1:1 일치** (메시지·흐름 동일)
- 검증: `bash -n template_integrator.sh` / Docker PowerShell 파서로 `.ps1` / `expect`로 TTY 동작
- 새 루트 파일 추가 아님 → template_initializer cleanup / plugin_items 수정 불필요

---

## 9. 테스트 전략

| 대상 | 방법 |
|------|------|
| 마커 스캔 | env에 마커 5종 섞어두고 각각 올바른 분기로 가는지 |
| 토큰 재귀 치환 | `/volume1/projects/__PROJECT_NAME__` 가 PROJECT_NAME 치환 후 재해소되는지 |
| 커스텀 키 | 워크플로우에 `REDIS_PORT + @wizard ask` 추가 → 마법사 코드 무수정으로 질문되는지 |
| 잔류 토큰 경고 | 마커 누락 시 `__X__`가 남고 경고 뜨는지 |
| 마커 없는 파일 | cp만 되고 안 건드리는지 (안전 폴백) |
| flutter 범위 | PROJECT_NAME만 치환 |
| 재실행 디폴트 | version.yml deploy 값이 질문 디폴트로 |
| `.sh`/`.ps1` 동등성 | 동일 입력 → 동일 결과 (Docker PS + expect) |

---

## 10. 영향 범위 / 리스크

- 가변값 있는 워크플로우 ~20개 원본 토큰화 + `template_integrator.sh`/`.ps1`에 `configure_workflow_env` 함수쌍 + `create_version_yml` 확장
- 리스크: 토큰화 후 사람이 마커를 지우면 다음 통합 때 그 키는 미처리 → 잔류 토큰 경고로 안전망
- 리스크: 멀티타입에서 같은 env 키가 타입마다 다른 값 필요 → version.yml deploy를 **타입별 네임스페이스**로 분리 (§6)
- 기존 동작 보존: 마커 없는 파일/타입은 지금처럼 cp만
