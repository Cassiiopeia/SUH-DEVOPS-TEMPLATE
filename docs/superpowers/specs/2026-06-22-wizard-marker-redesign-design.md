# @wizard 마커 시스템 전면 재설계 — `ask:기본값` / `auto:resolver` 문법 + labels.yml(문구만) + resolver 레지스트리

- 작성일: 2026-06-22
- 관련 템플릿 이슈: SUH-DEVOPS-TEMPLATE #399 (Flutter 배포 포팅의 선행 작업)
- 후행 스펙: `2026-06-22-romrom-store-deploy-port-to-template-design.md` (§9 모노레포 경로 대응이 이 스펙에 의존)
- 작업 순서: **이 스펙(마커 재설계) 먼저 → Flutter 포팅 스펙 나중.** Flutter의 `FLUTTER_ROOT`는 여기서 만든 `auto:flutter-root` resolver 위에 올린다.

## 1. 목표 (한 줄)

현재 `# @wizard ask/auto/auto-find/...` 마커 시스템은 **주석 한 줄에 action·한글설명·기본값을 욱여넣고**(따옴표·한글이 YAML 값과 섞임) 정규식으로 긁어내는 구조라 파싱이 복잡하고 문법이 제각각이며 기본값이 여러 곳에 분산돼 있다. 이를 **① 마커엔 `ask:<기본값>`/`auto:<resolver>`만(한글·따옴표 안 넣음) ② 질문 한글 문구만 `labels.yml`로 분리(없으면 키명 폴백, 선택적 의존) ③ 타입별 기본값·동적값은 resolver 함수로 흡수** 구조로 전면 교체한다. **하위호환 미고려** — 기존 마커 전량 마이그레이션.

> **설계 균형(사용자 피드백)**: 처음엔 모든 명세를 `fields.yml`로 빼는 안을 검토했으나 파일 의존성이 과했다. 정작 분리가 필요한 건 **한글 질문 문구(label) 하나뿐**(주석 따옴표 충돌 회피용)이므로, action·기본값·resolver는 마커에 남기고 label만 분리한다.

## 2. 현재 시스템의 문제 (조사 결과)

- 마커 종류마다 동작이 **1:1 하드코딩**: `auto`=PROJECT_NAME, `auto-find`=application.yml 탐색. 새 값마다 분기 추가.
- 기본값이 **3곳에 분산**: 마커 `[기본: ...]` 리터럴 / `default_for_type_key()` 하드코딩 표(.sh+.ps1 양쪽) / `version.yml deploy` 블록.
- **문법 불일치**: `ask:`는 콜론+설명+`[기본:]`, `auto-find:`는 콜론+설명(기본값 불가), `paths-anchor`는 괄호 설명. 파서가 케이스별로 복잡.
- **따옴표/공백 충돌 위험**: 한 줄에 YAML 값 따옴표와 마커 설명이 섞여 sed 정규식이 깨지기 쉬움.
- `.sh`/`.ps1`에 **로직·기본값 표를 각각 두 벌** → 한쪽만 고치면 어긋남.
- 현재 사용량: `ask` 31, `auto-find` 4, `paths-anchor` 4, `auto` 0(코드 분기만 존재).

## 3. 새 설계

### 3-1. 워크플로우 — 마커에 action·기본값·resolver
```yaml
env:
  FLUTTER_ROOT: "."   # @wizard auto:flutter-root
  PROJECT_NAME: "x"   # @wizard ask:@repo
  JAVA_VERSION: "17"  # @wizard ask:21
  DEPLOY_PORT: "8080" # @wizard ask:@port
```
- **action·기본값·resolver는 마커에 둔다**(워크플로우만 봐도 동작이 보임). 주석에 **한글·따옴표를 넣지 않아** YAML 값 따옴표와 충돌하지 않는다(현 시스템 버그의 근원 제거).
- **문법**: `# @wizard <action>:<arg>`
  - `ask:<기본값>` — 사용자에게 물음, 엔터 시 기본값. 기본값은 리터럴(`21`) 또는 `@<resolver>`(동적, 예 `@repo`/`@port`).
  - `auto:<resolver>` — 묻지 않고 resolver 실행값으로 채움.
  - 기본값에 공백이 있으면 `ask:"a b"`처럼 따옴표(드묾 — VOLUME_HOST_PATH 정도).
- **파싱**: `#[[:space:]]*@wizard[[:space:]]+(ask|auto):(.*)$` — 정규식 1개로 action·arg 추출. env 키는 같은 줄 앞쪽 `^[[:space:]]*([A-Z_]+):`. 줄 수 안 늘림.
- env 값(`"."`,`"17"`)은 integrator 미경유 시 안전 폴백.

### 3-2. `.github/wizard/labels.yml` — 질문 문구만 (선택적 의존)
```yaml
# ask 마커의 사용자 표시 질문 문구. 키=env키, 값=한글 라벨. 그게 전부.
JAVA_VERSION: "JDK 버전"
DEPLOY_PORT: "배포 포트"
PROJECT_NAME: "프로젝트 이름"
VOLUME_HOST_PATH: "호스트 볼륨 경로"
SSH_AUTH_METHOD: "SSH 인증 방식(password/key)"
```
- **labels.yml은 "질문 문구 사전" 역할만.** action·기본값·resolver·override는 마커에 있으므로 여기 없음 → 파일이 단순 `KEY: "문구"` 맵.
- **label 없으면 env 키명으로 폴백** → labels.yml이 없어도 동작(가벼운 선택적 의존). 한글·따옴표 충돌을 피하려고 **이것만** 분리.
- `auto:` 필드는 안 물으니 label 불필요.

### 3-3. resolver 레지스트리 — 각 언어에 함수로
- `.sh`: `resolve_<name>()` 함수. `.ps1`: `Resolve-<Name>()` 함수. 디스패처가 이름으로 호출. `auto:<name>`과 `ask:@<name>` 둘 다 같은 레지스트리 사용.
- 초기 resolver 목록:
  | resolver | 반환 | 대체하는 기존 |
  |----------|------|---------------|
  | `repo` | 레포명(`detect_repo_name`) | 기존 `auto`(PROJECT_NAME)·ask 레포명 기본값 |
  | `port` | 타입별 기본 포트(spring 8080 / python 8000 / react·next·node 3000) | 기존 `default_for_type_key` 포트 |
  | `flutter-root` | `get_path_for_type "flutter"`(`.`/`app`) | 신규(Flutter 스펙) |
  | `spring-app-yml-dir` | `find <typepath>/src/main/resources/application*.yml`의 dir | 기존 `auto-find`(DIR) |
  | `spring-app-yml-path` | 위의 파일 경로 그대로 | 기존 `auto-find`(PATH) |
- **타입별로 값이 다른 기본값**(포트, JAVA_VERSION 등)은 resolver가 현재 타입을 보고 분기(`@port`처럼). 즉 `default_for_type_key` 하드코딩 표는 **resolver 함수 안으로 흡수**된다(별도 override yml 불필요).
- 새 값 종류 추가 = **resolver 함수 1개**(+물어볼 거면 labels.yml 한 줄). 워크플로우 마커는 `ask:@x`/`auto:x`만.
- `.sh`/`.ps1` 동일 이름·동일 반환. 동기화는 검증(§5)으로 강제.

### 3-4. integrator 처리 흐름 (configure_workflow_env 교체)
1. 워크플로우에서 `# @wizard <action>:<arg>` 줄 스캔 → (env 키, action, arg) 추출.
2. **`auto:<resolver>`** → resolver 실행값으로 치환(안 물음).
3. **`ask:<기본값>`** → 기본값 해소: `@<resolver>`면 resolver 실행, 리터럴이면 그대로. 일괄기본 모드면 기본값 사용 / 아니면 labels.yml(없으면 키명) 문구로 질문(엔터=기본값).
4. env 값 치환 + **`# @wizard ...` 주석 줄째 삭제**(치환 후 워크플로우 깔끔, 값만 남음).
5. ask 결과는 `version.yml deploy` 블록에 저장(재실행 시 "이전 입력값"을 기본값보다 우선 제시 — 기억 용도).

### 3-5. paths-anchor는 별개 — 유지
- `# @wizard paths-anchor`는 env 치환이 아니라 `on.push.paths` 주입 기능. 이번 마커(env 채움)와 별개라 **그대로 유지**(동작 불변).

## 4. 마이그레이션 (하위호환 없이 전량 교체)
- 기존 `# @wizard ask: 설명 [기본: X]` (31개) → `# @wizard ask:X`(기본값 X가 리터럴이면 그대로, 레포명류면 `@repo`, 포트면 `@port`) + 한글 설명은 `labels.yml`로.
- 기존 `# @wizard auto-find: ...` (4개, Spring) → `# @wizard auto:spring-app-yml-dir` / `auto:spring-app-yml-path`.
- 기존 `auto`(PROJECT_NAME) → `# @wizard ask:@repo`(또는 auto:repo). `default_for_type_key` 하드코딩 표 → **삭제, resolver 함수로 흡수**(`@port` 등).
- 영향 워크플로우: spring/python/react/next/flutter 전반 + `template_integrator.sh`/`.ps1` 엔진.

## 5. 검증
- **회귀(가장 중요)**: 마이그레이션 전후로 **각 타입 워크플로우의 치환 결과가 동일한지** 픽스처로 대조. 특히 Spring `application.yml` 탐색값, 타입별 포트(`@port`)·JAVA_VERSION 기본값이 기존 `default_for_type_key`와 같은 값인지.
- **`.sh`/`.ps1` 동등**: 같은 픽스처(단일레포/모노레포/spring resources)에 둘 다 돌려 마커 파싱·resolver 반환·최종 치환이 일치하는지. CLAUDE.md 검증법(Docker `Parser::ParseFile`, expect TTY, `bash -n`).
- **마커 파싱 견고성**: env 값에 콜론/따옴표가 있어도(예: `"a:b"`) `@wizard <action>:<arg>` 추출이 안 깨지는지(주석 부분만 파싱).
- **label 폴백**: `labels.yml`에 없는 ask 키는 env 키명으로 질문 프롬프트가 뜨는지. labels.yml 파일 자체가 없어도 동작하는지.
- **치환 후 깔끔**: 결과 워크플로우에 `# @wizard` 주석이 안 남고 잔류 `__TOKEN__`이 없는지.

## 6. 비범위 (YAGNI)
- 본 스펙은 **마커 문법(ask:/auto:)·labels.yml·resolver 레지스트리 + 기존 마커 전량 마이그레이션**까지. `flutter-root` resolver의 실제 적용(워크플로우 경로 변수화)은 후행 Flutter 스펙 §9.
- YAML 파서 전면 도입(sed→yq로 워크플로우 자체 편집) 같은 대공사는 안 함 — env 줄 치환은 기존 `_wf_set_env` 줄단위 sed 유지(따옴표 충돌은 마커에서 따옴표를 뺀 것으로 해소).
- `paths-anchor` 로직 변경 없음.
- labels.yml은 "질문 문구"만 — 기본값·resolver·타입override를 이 파일에 넣지 않는다(그건 마커·resolver 소관).

## 7. 후행 Flutter 스펙과의 연결
- Flutter 스펙 §9는 본 스펙 완료를 전제로, **워크플로우에 `FLUTTER_ROOT: "."  # @wizard auto:flutter-root` 마커 추가 + `resolve_flutter_root()`/`Resolve-FlutterRoot` resolver 1개 추가**만 하면 된다. labels.yml은 auto라 불필요. 워크플로우 경로 변수화(job defaults working-directory)는 Flutter 스펙 그대로.
