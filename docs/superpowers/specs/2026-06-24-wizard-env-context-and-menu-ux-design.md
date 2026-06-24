# 마법사 배포 env 설정 UX 개선 — 사용처 표시 + 메뉴/미리보기 설계

- 날짜: 2026-06-24
- 대상: `template_integrator.sh`, `template_integrator.ps1`, `.github/wizard/labels.yml`
- 상태: 설계 승인 완료 → 구현 대기
- 선행: 2026-06-23 ask UX 개선(labels.yml label/help/example) 위에 쌓는 개선

---

## 1. 배경 / 문제

마법사(`template_integrator`)가 배포 워크플로우의 env 토큰을 채울 때 사용자가 세 가지 혼란을 겪었다.

1. **어느 워크플로우/타입의 값인지 모른다.** "서비스 도메인"을 물을 때 react 프론트 도메인인지 백엔드 엔드포인트인지 화면에 안 나온다. (실제 `SERVICE_DOMAIN`은 spring 백엔드 무중단배포 전용이고 react엔 도메인 ask 자체가 없는데, 그 사실이 화면에 드러나지 않는다.)
2. **Y/N 텍스트 입력이 남아 있다.** 나머지 질문은 메뉴(↑↓ 선택)로 통일했는데 "전부 기본값으로 빠르게 채울까요? (Y/n)"만 텍스트 입력으로 남았다.
3. **"전부 기본값"의 내용이 불투명하다.** 어떤 KEY에 어떤 기본값이 들어가는지 안 보여주니, 사용자는 무엇이 바뀌는지 몰라 N(하나씩)을 고를 수밖에 없다.

현재 동작:

```
🔅 배포 워크플로우 환경설정을 채웁니다
  전부 기본값으로 빠르게 채울까요? (Y=전부기본 / n=하나씩) (기본: Y): N
  ▸ 서비스 식별자 (영문 슬러그)
    Docker 컨테이너명·이미지명·배포 도메인 prefix에 그대로 사용됩니다.
    예) my-service
  값 입력 (기본: passQL): passql
  ▸ 서비스 도메인
    배포 후 외부에서 접속할 운영 도메인입니다.
    예) api.example.com
  값 입력 (기본: example.com):
```

---

## 2. 현재 구조 (사실 정리)

### 2.1 ask KEY → 워크플로우 분포 (실측)

`@wizard ask:` 마커가 붙은 KEY가 여러 워크플로우에 중복 등장한다. 같은 KEY는 `wf_deploy` 캐싱으로 **한 번만** 묻고 값을 재사용한다.

| KEY | 등장 타입/워크플로우 |
|-----|---------------------|
| `PROJECT_NAME` | spring(SIMPLE·NGINX·TRAEFIK·PR-PREVIEW), react(CI·CICD), next(CI·CICD), python(CI·SIMPLE·PR-PREVIEW) — 11개 |
| `SERVICE_DOMAIN` | spring(NGINX·TRAEFIK) — 2개 |
| `JAVA_VERSION` | spring 4개 + flutter 5개 |
| `DEPLOY_PORT` | spring(SIMPLE), python(SIMPLE) |
| `VOLUME_HOST_PATH` | spring(SIMPLE·NGINX·TRAEFIK), python(SIMPLE) |
| `VOLUME_CONTAINER_PATH` | spring(SIMPLE·TRAEFIK), python(SIMPLE) |
| `SSH_AUTH_METHOD` | spring 4개 + python 2개 |
| `APP_ARTIFACT_NAME` | flutter(SELFHOSTED·PLAYSTORE·FIREBASE) |

> 핵심: 같은 KEY가 흩어져 있어 "사용처"를 한데 모아 보여줄 수 있고, 캐싱 덕에 입력은 KEY당 1회다.

### 2.2 현재 코드 흐름

- `.sh` `configure_workflow_env(type, file)` (2938~) / `.ps1` `Configure-WorkflowEnv(Type, File)` (2493~)
- **워크플로우 파일 1개씩** 호출된다(`copy_workflows`/`Copy-Workflows` 내부 파일 루프).
- `WF_USE_DEFAULTS`/`$script:WfUseDefaults`가 null일 때 **최초 1회** Y/N을 묻고, 그 뒤 모든 파일에 동일 적용.
- ask 분기: `wf_field`로 label/help/example 출력 후 `safe_read`/`Read-UserInput`로 값 입력. 확정값은 `wf_deploy_set`/`Set-WfDeploy`로 캐싱.
- 파일 단위로 묻는 구조라 **전체 KEY를 미리 모을 수 없어** 기본값 표를 못 보여준다.

### 2.3 재사용 가능한 기존 자산

- **메뉴 UI**: `.sh` `interactive_menu`(`--multi`/`--preselect=csv` 지원, 290~) / `.ps1` `Invoke-ChooseMenu`(`-Multi`/`-Preselect` 지원, 573~). 멀티선택 체크박스가 **이미 구현돼 있다** → 새 UI 불필요.
- **labels.yml 경로 폴백**: `.sh` `_wf_labels_path` / `.ps1` `Get-WfLabelsPath` (2026-06-24 추가). dst 없으면 `$TEMP_DIR` 원본 읽음 → 신규 통합에서도 라벨/매핑이 읽힌다.

---

## 3. 목표 / 비목표

### 목표
- 각 ask 항목에 **사용처([어느 워크플로우/타입])**를 라벨 옆에 표시한다.
- Y/N 텍스트 입력을 **메뉴 선택**(1/2/3)으로 바꾼다.
- 메뉴 직전에 **기본값 미리보기 표**(KEY = 값 [사용처])를 보여준다.
- "몇 개만 골라서 바꾸기"를 **체크박스 멀티선택**으로 제공한다.
- `.sh`와 `.ps1`이 **1:1 동일 동작**.

### 비목표
- env KEY 이름·labels.yml의 label/help/example·워크플로우 YAML은 **건드리지 않는다**. 화면/흐름만 바꾼다.
- 최종 토큰 치환 결과는 지금과 **byte-identical**. 묻는 방식만 변경.
- 비대화형/FORCE 모드는 지금처럼 "전부 기본값"으로 자동 진행(표·메뉴 미출력).

---

## 4. 설계

### 4.1 구조 변경: 파일별 즉시 처리 → 전체 수집 후 일괄 (2-pass)

```
[Pass 1: 수집]  설치될 모든 워크플로우를 스캔
   → ask KEY를 유일하게 모으고, 각 KEY가 등장하는 워크플로우 파일 목록 수집
   → KEY 테이블: { key, label, help, example, default, files[] }

[화면]  기본값 미리보기 표 출력 → 메뉴(1/2/3)
[입력]  선택에 따라 값 확정 (KEY당 1회)
[Pass 2: 치환]  확정값으로 모든 워크플로우에 토큰 치환
```

- **불변(invariant)**: 같은 KEY는 항상 같은 값. 기존 `wf_deploy` 캐싱이 암묵적으로 하던 일을 명시적 테이블로 승격.
- 수집 시 `default`는 현재와 동일하게 결정: `@name`이면 resolver, 아니면 리터럴, 재통합이면 `wf_deploy_get`(version.yml 저장값) 우선.

### 4.2 화면 흐름

전체 통합에서 **딱 한 번** (WfUseDefaults null일 때).

```
🔅 배포 워크플로우 환경설정을 채웁니다

   설치되는 배포 워크플로우가 사용할 값입니다. 아래가 기본값이며,
   그대로 두거나 원하는 것만 바꿀 수 있습니다.

┌─ 기본값 미리보기 ──────────────────────────────────────────────┐
   서비스 식별자 (슬러그)   passql           spring·react·next·python
   서비스 도메인            example.com      spring 무중단배포(Nginx·Traefik)
   빌드 JDK 버전            21               spring·flutter
   외부 노출 포트           8080             spring·python 단일배포
   …
└────────────────────────────────────────────────────────────────┘

어떻게 채울까요? (↑↓ 이동, Enter 확정, ESC 취소)
> 1) 위 기본값 그대로 전부 설치
  2) 하나씩 직접 입력
  3) 몇 개만 골라서 바꾸기 (나머지는 기본값)
```

- **1번** → 표의 기본값으로 전부 확정, 입력 없음.
- **2번** → KEY마다 `▸ label [사용처] / help / 예) example / 값 입력 (기본: X)`.
- **3번** → 체크박스 멀티선택 표 → 고른 항목만 순서대로 입력.

**2번 항목 출력:**
```
  ▸ 서비스 도메인  [spring 무중단배포(Nginx·Traefik)]
    배포 후 외부에서 접속할 운영 도메인입니다.
    예) api.example.com
  값 입력 (기본: example.com):
```

**3번 멀티선택:**
```
바꿀 항목을 고르세요 (Space 토글, Enter 확정, ESC 취소)
  [ ] 서비스 식별자 (슬러그)   passql        spring·react·next·python
  [x] 서비스 도메인            example.com   spring 무중단배포(Nginx·Traefik)
  [ ] 빌드 JDK 버전            21            spring·flutter
  [x] 외부 노출 포트           8080          spring·python 단일배포
  …
  ▸ 서비스 도메인  [spring 무중단배포(Nginx·Traefik)]
    예) api.example.com
  값 입력 (기본: example.com):
  ▸ 외부 노출 포트  [spring·python 단일배포]
    값 입력 (기본: 8080):
```

- 사용처 `[...]`는 **표·2번·3번 모든 화면에 일관 표시**.

### 4.3 사용처 라벨 생성 (실제 파일 스캔 + labels.yml 매핑)

KEY의 사용처는 Pass 1에서 모은 **파일명 목록**으로 만든다(labels.yml에 손으로 적지 않음 → 워크플로우 추가/변경돼도 항상 진실).

**파일명 → 사람말 매핑**은 `labels.yml`의 새 섹션 `_workflow_names:`에 둔다(사용자 결정: 한 파일에서 관리). KEY 블록은 대문자로 시작하고 이 섹션은 `_`로 시작하므로 `_wf_read_field`(대문자 KEY만 매칭)와 충돌하지 않는다.

```yaml
# .github/wizard/labels.yml 끝에 추가
# 워크플로우 파일명(부분 매칭) → 사람이 읽는 짧은 이름.
# 마법사가 env 질문에 "[사용처]"를 만들 때 쓴다. (사용자 프로젝트로 함께 복사되지만 무해)
_workflow_names:
  NONSTOP-NGINX:    "무중단배포(Nginx)"
  NONSTOP-TRAEFIK:  "무중단배포(Traefik)"
  PR-PREVIEW:       "PR 프리뷰"
  SIMPLE-CICD:      "단일 서버 배포"
  REACT-CI:         "프론트 빌드"
  REACT-CICD:       "프론트 배포"
  NEXT-CI:          "프론트 빌드"
  NEXT-CICD:        "프론트 배포"
  PYTHON-CI:        "빌드 검증"
  FLUTTER-ANDROID-SELFHOSTED: "안드로이드 자체배포"
  FLUTTER-ANDROID-PLAYSTORE:  "플레이스토어 배포"
  FLUTTER-ANDROID-FIREBASE:   "Firebase 배포"
```

**사용처 문자열 조립 규칙** (`_wf_scope_for_key(key, files[])`):
1. files[]의 각 파일을 타입(상위 폴더)과 사람말로 변환.
2. **단일 타입 + 모든 파일이 매핑됨** → `"{타입} {사람말1·사람말2}"` (예: `spring 무중단배포(Nginx·Traefik)`).
3. **여러 타입** → 타입명만 `·`로 join (예: `spring·react·next·python`). 타입이 많으면 용도 생략(너무 길어짐).
4. **매핑에 없는 파일** → 그 파일은 **파일명 그대로(확장자만 제거)** 표기 (예: `PROJECT-SPRING-NONSTOP-NGINX-CICD`). 폴백이 핵심 안전망: 매핑을 깜빡해도 깨지지 않고 파일명으로 항상 식별 가능.

폴백 우선순위(파일 1개 기준):
```
1) labels.yml _workflow_names 부분매칭   → "무중단배포(Nginx)"
2) 없으면 파일명에서 .yaml/.yml만 제거    → "PROJECT-SPRING-NONSTOP-NGINX-CICD"
```

> 사용처 압축은 "보기 좋게"가 목적이고, 매핑이 비어도 파일명으로 동작하므로 매핑 누락에 강건하다.

### 4.4 메뉴/멀티선택은 기존 함수 재사용

- 1/2/3 선택: `interactive_menu`/`Invoke-ChooseMenu` (단일).
- 3번 체크박스: 같은 함수의 `--multi`/`-Multi` + 항목 라벨에 `값 [사용처]` 포함.
- ESC 처리: 기존 패턴 준수. **`.sh`는 `var=$(menu) || rc=$?`로 ESC(비-0) 종료코드를 흡수**해야 `set -e`에서 마법사가 통째로 안 죽는다(CLAUDE.md 함정). ESC=취소면 "전부 기본값"으로 폴백하거나 통합 취소 — 기존 Y/N 취소와 동일 의미로 맞춘다.

---

## 5. 영향 파일

| 파일 | 변경 |
|------|------|
| `template_integrator.sh` | `configure_workflow_env`를 2-pass로 분리(수집/표·메뉴/치환). 사용처 헬퍼 `_wf_scope_for_key`·파일명→사람말 변환 추가. `interactive_menu` 단일/멀티 호출 |
| `template_integrator.ps1` | `.sh`와 1:1 동일. `Invoke-ChooseMenu -Multi` 재사용 |
| `.github/wizard/labels.yml` | `_workflow_names:` 매핑 섹션 추가 (KEY 블록·스키마는 무변경) |

> labels.yml은 공통 자산이라 cleanup/제외 목록에 넣지 않는다(기존 정책 유지). 워크플로우 YAML·KEY 이름 무변경.

---

## 6. 검증 계획

1. **"전부 기본값(1번)" 결과 불변** — 변경 전/후로 동일 입력 시 워크플로우 치환 결과가 byte-identical인지 대조(가장 중요한 회귀 가드).
2. **2번/3번 동작** — `expect`(.sh, 실제 TTY)·Docker PowerShell(.ps1)로 입력 주입: 표 출력 → 메뉴 선택 → (3번)체크박스 토글 → 고른 KEY만 입력 → 치환 확인.
3. **사용처 문자열** — `SERVICE_DOMAIN`→`spring 무중단배포(Nginx·Traefik)`, 멀티타입 KEY→타입 join, 매핑없는 파일→파일명 폴백 각각 단위 검증.
4. **신규 통합 폴백** — dst에 labels.yml 없는 상태(=`_wf_labels_path`/`Get-WfLabelsPath` 폴백)에서 `_workflow_names`도 `$TEMP_DIR` 원본에서 읽히는지 확인.
5. **ESC 안전** — `.sh`에서 메뉴 ESC가 마법사를 통째로 종료시키지 않는지(`|| rc=$?` 흡수) expect로 확인.
6. **문법** — `bash -n template_integrator.sh`, Docker PowerShell `Parser::ParseFile`로 `.ps1`.
7. **무손상** — `git diff`로 워크플로우 YAML·labels.yml의 KEY 블록·실행 로직 무변경 확인.
