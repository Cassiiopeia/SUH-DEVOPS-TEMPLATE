# @wizard 마커 시스템 전면 재설계 — `# wizard` 표식 + fields.yml 명세 + resolver 레지스트리

- 작성일: 2026-06-22
- 관련 템플릿 이슈: SUH-DEVOPS-TEMPLATE #399 (Flutter 배포 포팅의 선행 작업)
- 후행 스펙: `2026-06-22-romrom-store-deploy-port-to-template-design.md` (§9 모노레포 경로 대응이 이 스펙에 의존)
- 작업 순서: **이 스펙(마커 재설계) 먼저 → Flutter 포팅 스펙 나중.** Flutter의 `FLUTTER_ROOT`는 여기서 만든 resolver 위에 올린다.

## 1. 목표 (한 줄)

현재 `# @wizard ask/auto/auto-find/...` 마커 시스템은 **주석 한 줄에 action·설명·기본값을 욱여넣고 정규식으로 긁어내는** 구조라 파싱이 복잡하고 문법이 제각각이며 확장 시 여러 곳을 고쳐야 한다. 이를 **① 워크플로우엔 `# wizard` 표식만 ② 질문·기본값·resolver는 `fields.yml` 단일 명세 ③ resolver 함수 레지스트리** 구조로 전면 교체한다. **하위호환 미고려** — 기존 마커 전량 마이그레이션.

## 2. 현재 시스템의 문제 (조사 결과)

- 마커 종류마다 동작이 **1:1 하드코딩**: `auto`=PROJECT_NAME, `auto-find`=application.yml 탐색. 새 값마다 분기 추가.
- 기본값이 **3곳에 분산**: 마커 `[기본: ...]` 리터럴 / `default_for_type_key()` 하드코딩 표(.sh+.ps1 양쪽) / `version.yml deploy` 블록.
- **문법 불일치**: `ask:`는 콜론+설명+`[기본:]`, `auto-find:`는 콜론+설명(기본값 불가), `paths-anchor`는 괄호 설명. 파서가 케이스별로 복잡.
- **따옴표/공백 충돌 위험**: 한 줄에 YAML 값 따옴표와 마커 설명이 섞여 sed 정규식이 깨지기 쉬움.
- `.sh`/`.ps1`에 **로직·기본값 표를 각각 두 벌** → 한쪽만 고치면 어긋남.
- 현재 사용량: `ask` 31, `auto-find` 4, `paths-anchor` 4, `auto` 0(코드 분기만 존재).

## 3. 새 설계

### 3-1. 워크플로우 — `# wizard` 표식만
```yaml
env:
  FLUTTER_ROOT: "."    # wizard
  PROJECT_NAME: "x"    # wizard
  JAVA_VERSION: "17"   # wizard
  DEPLOY_PORT: "8080"  # wizard
```
- 마커는 **`# wizard` 단일 표식**. action·설명·기본값을 **주석에 안 적는다**(따옴표·한글 충돌 원천 제거).
- 파싱: "그 줄에 `# wizard` 주석이 있는가 + 같은 줄 앞쪽 `KEY:`가 무엇인가"만. **정규식 1개**(`^[[:space:]]*([A-Z_]+):.*#[[:space:]]*wizard[[:space:]]*$`), 따옴표 안 건드림.
- env 키는 마커와 **같은 줄**(줄 수 안 늘림). 값(`"."`, `"17"`)은 integrator 미경유 시의 안전 폴백 기본값 역할.

### 3-2. `.github/wizard/fields.yml` — 단일 명세 (타입별 override)
```yaml
# 모든 wizard 필드의 질문·기본값·resolver를 한 곳에서 선언
FLUTTER_ROOT:
  resolve: flutter-root          # resolver만 → 자동 채움(사용자 안 물음)

PROJECT_NAME:
  label: "프로젝트 이름"
  default: { resolve: repo }     # 동적 기본값(resolver로 해소)

JAVA_VERSION:
  label: "JDK 버전"
  default: 17
  override: { spring: 21 }       # 타입별 기본값 차이는 override로

DEPLOY_PORT:
  label: "배포 포트"
  default: 8080
  override: { python: 8000, react: 3000, next: 3000, node: 3000 }

APPLICATION_YML_DIR:
  resolve: spring-app-yml-dir

VOLUME_HOST_PATH:
  label: "호스트 볼륨 경로"
  default: "/volume1/projects/{PROJECT_NAME}"   # 다른 필드 참조(토큰 치환)

SSH_AUTH_METHOD:
  label: "SSH 인증 방식(password/key)"
  default: password
```
- **ask냐 resolve냐를 fields.yml이 결정**: `resolve:`만 있으면 자동, `label:`이 있으면 사용자 질문(엔터=default).
- `default`: 리터럴(`17`) 또는 동적(`{ resolve: <name> }`). `{PROJECT_NAME}` 같은 **다른 필드 참조 토큰**도 지원(치환 순서: resolve→ask→토큰 해소).
- `override: { <type>: <값> }`로 타입별 기본값 차이 처리(`default_for_type_key` 하드코딩 표를 이 파일로 흡수).
- 단일 파일 — 공통 필드(PROJECT_NAME 등) 중복 선언 없음.

### 3-3. resolver 레지스트리 — 각 언어에 함수로
- `.sh`: `resolve_<name>()` 함수. `.ps1`: `Resolve-<Name>()` 함수. 디스패처가 이름으로 호출.
- 초기 resolver 목록:
  | resolver | 반환 | 대체하는 기존 |
  |----------|------|---------------|
  | `repo` | 레포명(`detect_repo_name`) | 기존 `auto`(PROJECT_NAME) |
  | `flutter-root` | `get_path_for_type "flutter"`(`.`/`app`) | 신규(Flutter 스펙) |
  | `spring-app-yml-dir` | `find <typepath>/src/main/resources/application*.yml`의 dir | 기존 `auto-find`(DIR) |
  | `spring-app-yml-path` | 위의 파일 경로 그대로 | 기존 `auto-find`(PATH) |
- 새 값 종류 추가 = **resolver 함수 1개 + fields.yml 한 블록.** 워크플로우는 `# wizard`만 그대로.
- `.sh`/`.ps1` 동일 이름·동일 반환. 동기화 책임은 검증(§5)으로 강제.

### 3-4. integrator 처리 흐름 (configure_workflow_env 교체)
1. 워크플로우에서 `# wizard` 줄 스캔 → env 키 목록 추출.
2. 각 키를 `fields.yml`에서 조회(없으면 **경고**: 동기화 깨짐 자동 감지).
3. `resolve:`만 → resolver 실행값. `label:` 있음 → (일괄기본 모드면 default / 아니면 질문). default가 `{resolve:}`면 resolver, 리터럴이면 그대로, `override`에 현재 타입 있으면 그 값.
4. `{OTHER_FIELD}` 토큰 해소(이미 정해진 다른 필드 값으로 치환).
5. env 값 치환 + **`# wizard` 주석 줄째 삭제**(치환 후 워크플로우 깔끔, 값만 남음).
6. ask 결과는 `version.yml deploy` 블록에 저장(재실행 시 "이전 입력값"을 default보다 우선 제시 — 기억 용도로만).

### 3-5. paths-anchor는 별개 — 유지
- `# @wizard paths-anchor`는 env 치환이 아니라 `on.push.paths` 주입 기능. 이번 마커(env 채움)와 별개라 **그대로 유지**(필요 시 `# wizard-paths` 정도로 네이밍만 통일, 동작 불변).

## 4. 마이그레이션 (하위호환 없이 전량 교체)
- 기존 `# @wizard ask: 설명 [기본: X]` (31개) → 워크플로우 `# wizard` + fields.yml에 `label`/`default` 이전.
- 기존 `# @wizard auto-find: ...` (4개, Spring) → 워크플로우 `# wizard` + fields.yml `resolve: spring-app-yml-dir`/`-path`.
- 기존 `auto` 분기/`default_for_type_key` 표 → **삭제**(fields.yml로 흡수).
- 영향 워크플로우: spring/python/react/next/flutter 전반 + `template_integrator.sh`/`.ps1` 엔진.

## 5. 검증
- **회귀(가장 중요)**: 마이그레이션 전후로 **각 타입 워크플로우의 치환 결과가 동일한지** 픽스처로 대조. 특히 Spring `application.yml` 탐색값, 타입별 JAVA_VERSION/DEPLOY_PORT override가 기존 `default_for_type_key`와 같은 값인지.
- **`.sh`/`.ps1` 동등**: 같은 픽스처(단일레포/모노레포/spring resources)에 둘 다 돌려 fields.yml 해석·resolver 반환·최종 치환이 일치하는지. CLAUDE.md 검증법(Docker `Parser::ParseFile`, expect TTY, `bash -n`).
- **동기화 경고**: 워크플로우 `# wizard` 키가 fields.yml에 없을 때 경고 뜨는지.
- **치환 후 깔끔**: 결과 워크플로우에 `# wizard` 주석이 안 남고 잔류 `__TOKEN__`이 없는지.
- **fields.yml 파싱**: yq로 읽으며(이미 워크플로우 의존성에 있음) mac/win 양쪽 동작.

## 6. 비범위 (YAGNI)
- 본 스펙은 **마커 엔진·문법·fields.yml·resolver 골격 + 기존 마커 마이그레이션**까지. `flutter-root` resolver의 실제 적용(워크플로우 경로 변수화)은 후행 Flutter 스펙 §9에서.
- YAML 파서 전면 도입(sed→yq로 워크플로우 자체 편집) 같은 대공사는 안 함 — env 줄 치환은 기존 `_wf_set_env` 줄단위 sed 유지(따옴표 충돌은 마커에서 따옴표를 뺀 것으로 이미 해소).
- `paths-anchor` 로직 변경 없음(네이밍 통일만 선택).

## 7. 후행 Flutter 스펙과의 연결
- Flutter 스펙 §9-2의 "`@wizard auto:flutter-root` 디스패처" 서술은 **이 스펙의 `fields.yml` + `resolve: flutter-root`로 대체**된다. Flutter 스펙은 본 스펙 완료를 전제로, `fields.yml`에 `FLUTTER_ROOT: { resolve: flutter-root }` 한 블록과 `resolve_flutter_root()`/`Resolve-FlutterRoot` resolver만 추가하면 된다. 워크플로우 경로 변수화(job defaults working-directory)는 Flutter 스펙 그대로.
