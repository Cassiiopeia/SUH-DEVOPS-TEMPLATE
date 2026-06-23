# 마법사 ask UX 개선 + env KEY UNIQUE화 설계

- 날짜: 2026-06-23
- 대상: `template_integrator.sh`, `template_integrator.ps1`, `.github/wizard/labels.yml`, `.github/workflows/project-types/**`
- 상태: 설계 승인 완료 → 구현 대기

---

## 1. 배경 / 문제

`template_integrator`(마법사)가 워크플로우 env 토큰을 채울 때, "하나씩" 모드에서 사용자에게 **KEY 라벨 한 단어만** 보여준다.

```
PROJECT_NAME (기본: passQL): passQL
DOMAIN_NAME (기본: example.com):
```

이 때문에 사용자가 **"이게 백엔드 도메인인지 프론트 도메인인지, 무슨 값을 넣으라는 건지 모르겠다"** 고 혼란을 겪었다.

근본 원인 3가지:

1. **설명 부재** — `labels.yml`이 `KEY: "한 줄 라벨"` 평면 매핑만 담아, "무엇에 쓰는 값인지" help/example을 줄 수 없다.
2. **라벨 비고유** — `DOMAIN_NAME`과 `PRODUCTION_DOMAIN`이 둘 다 "서비스 도메인"으로 표시돼 구별 불가.
3. **같은 KEY, 다른 의미** — `PROJECT_NAME`이 spring/python/react/next에서는 "배포 슬러그(컨테이너·이미지·도메인 prefix)"지만, flutter에서는 "APK·아티팩트 파일명"이다. 같은 질문이 타입마다 다른 의미를 가져 헷갈린다.

> 전제: 이 템플릿을 실제 운영에 쓴 사용자가 아직 없어, **env KEY 이름을 바꿔도 깨질 운영 워크플로우가 없다**(사용자 확인). 따라서 KEY 리네이밍을 안전하게 수행할 수 있다.

---

## 2. 목표 / 비목표

### 목표
- 마법사가 각 ask 항목에 대해 **라벨 + 한 줄 설명(help) + 예시(example)** 를 보여준다.
- 의미가 다른데 이름이 같은 env KEY를 **고유한 이름으로 분리**한다.
- example 값은 common 템플릿답게 **일반명사형**(특정 프로젝트에 안 치우침)으로 둔다.
- `.sh`와 `.ps1`이 **1:1 동일 동작**을 유지한다.

### 비목표
- env KEY를 전부 바꾸지 않는다. **의미가 다른/중복인 것만** 바꾼다.
- 워크플로우의 `run:`/`uses:`/`with:`/`steps:` 등 **실행 로직은 손대지 않는다**(env 키 이름과 그 참조만 일괄 치환).
- 마법사의 "전부 기본값(Y)" 일괄 모드 흐름은 그대로 둔다(도움말은 "하나씩(n)" 모드에서만 출력).

---

## 3. 현재 동작 (사실 정리)

### 3.1 ask 항목 전수 (8 KEY)

`@wizard ask:` 마커로 사용자에게 묻는 KEY:

| KEY | 사용 타입 | 실제 의미 |
|-----|----------|----------|
| `PROJECT_NAME` | spring·python·react·next | 컨테이너·이미지·배포 도메인 prefix 슬러그 |
| `PROJECT_NAME` | flutter (selfhosted·playstore·firebase) | APK·아티팩트·히스토리 파일명 |
| `DOMAIN_NAME` | spring nginx | Nginx server_name 운영 도메인 |
| `PRODUCTION_DOMAIN` | spring traefik | Traefik 진입 운영 도메인 |
| `JAVA_VERSION` | spring·flutter | 빌드 JDK 버전 |
| `DEPLOY_PORT` | spring·python | 호스트 노출 포트 |
| `VOLUME_HOST_PATH` | spring·python | NAS 호스트 볼륨 경로 |
| `VOLUME_CONTAINER_PATH` | spring·python | 컨테이너 내부 마운트 경로 |
| `SSH_AUTH_METHOD` | spring·python | SSH 인증 방식 (password/key) |

> `@wizard auto:` (flutter-root, spring-app-yml-dir 등)는 사용자에게 묻지 않으므로 이 작업 범위 밖이다.

### 3.2 라벨 출력 경로

- `.sh`: `configure_workflow_env()` (2896~) → ask 분기에서 `wf_label "$_key"` (2802~) 호출 → `labels.yml` 조회 → `safe_read "  ${_label} [기본: ${_default}]: "` (2942).
- `.ps1`: `Configure-WorkflowEnv` (2445~) → `Read-UserInput ("  " + (Get-WfLabel $key)) $def` (2478) → `Get-WfLabel` (2391~)이 `labels.yml` 조회.
- `labels.yml`: `.github/wizard/labels.yml`. **integrator가 사용자 프로젝트로 복사하는 공통 자산**(ps1 2915~2932행 `.github/wizard` 폴더 복사). 따라서 cleanup/제외 목록에 넣지 않는다.

### 3.3 워크플로우 위치
- 타입별 배포 워크플로우는 **`project-types/` 하위에만** 존재하고 `.github/workflows/` 루트에는 복사본이 없다(확인 완료). 따라서 KEY 리네이밍은 `project-types/` 한 곳만 수정한다.

---

## 4. 설계

### 4.1 `labels.yml` 스키마 확장 (하위호환)

기존 `KEY: "문자열"` 형식을 **계속 지원**하면서, 새 블록 형식과 타입 네임스페이스를 추가한다.

```yaml
# 공통 폴백 (타입 무관) — 블록 형식
JAVA_VERSION:
  label: "빌드 JDK 버전"
  help: "GitHub Actions 빌드 러너의 JDK 버전입니다. Spring은 보통 21, Flutter Android는 17."
  example: "21"

# 타입별 오버라이드 — "{type}.{KEY}" 키
spring.PROJECT_NAME:
  label: "서비스 식별자 (영문 슬러그)"
  help: "Docker 컨테이너명·이미지명·배포 도메인 prefix에 그대로 사용됩니다. 소문자-하이픈을 권장합니다."
  example: "my-service"

flutter.APP_ARTIFACT_NAME:
  label: "앱 산출물 이름 (영문)"
  help: "빌드된 APK 파일명·아티팩트명·빌드 히스토리 파일명에 사용됩니다."
  example: "my-app"
```

**조회 우선순위** (`wf_field(type, key, field)`):
1. `{type}.{key}` 블록의 해당 field
2. `{key}` 블록의 해당 field
3. (구형) `{key}: "문자열"` → label로 간주
4. 폴백: field=label이면 KEY 이름, help/example이면 빈 문자열

> 파서는 셸/PowerShell로 YAML 일부만 읽으면 되므로, **2단 들여쓰기 블록만** 지원하면 충분하다(중첩 없음). 정규식 기반 라인 스캔으로 구현(외부 YAML 라이브러리 불필요 — 내부망/OS 호환).

### 4.2 마법사 출력 (양쪽 동일)

"하나씩(n)" 모드에서 ask 직전 출력:

```
  ▸ 서비스 식별자 (영문 슬러그)
    Docker 컨테이너명·이미지명·배포 도메인 prefix에 그대로 사용됩니다. 소문자-하이픈을 권장합니다.
    예) my-service
  값 입력 [기본: passql]: 
```

- 1행 `▸ {label}` — 무엇을 묻는지
- 2행 `  {help}` — 회색/들여쓰기 설명 (없으면 생략)
- 3행 `  예) {example}` — 예시 (없으면 생략)
- 4행 `값 입력 [기본: {default}]: ` — 입력 프롬프트

help/example이 비면 해당 행을 건너뛴다(구형 labels.yml 하위호환).

구현:
- `.sh`: `wf_label()` → `wf_field()` 로 확장(또는 신규 함수 추가). `configure_workflow_env`의 ask 분기에서 `_label`/`_help`/`_example`을 각각 조회해 `print_to_user`로 출력 후 `safe_read "  값 입력 [기본: ${_default}]: "`.
- `.ps1`: `Get-WfLabel` → `Get-WfField` 로 확장. ask 분기에서 동일 출력 후 `Read-UserInput "  값 입력" $def`.

> **"전부 기본값(Y)" 모드는 도움말을 출력하지 않는다**(질문 자체를 건너뛰므로). 기존 흐름 유지.

### 4.3 env KEY 리네이밍 (의미 다른/중복인 것만)

| 현재 KEY | 위치 | 새 KEY | 사유 |
|---------|------|--------|------|
| `PROJECT_NAME` | flutter (selfhosted·playstore·firebase) | `APP_ARTIFACT_NAME` | 슬러그가 아니라 빌드 산출물 파일명 |
| `DOMAIN_NAME` | spring nginx | `SERVICE_DOMAIN` | 의미: 서비스 도메인. traefik과 통일 |
| `PRODUCTION_DOMAIN` | spring traefik | `SERVICE_DOMAIN` | 위와 동일 의미 → 동일 이름 |

**유지**: spring/python/react/next의 `PROJECT_NAME`(모두 동일 의미 = 배포 슬러그).

#### 리네이밍 시 같이 바꿔야 하는 참조부 (누락 시 워크플로우 깨짐)

`PROJECT_NAME → APP_ARTIFACT_NAME` (flutter selfhosted, 참조 8곳 + 주석):
- 선언부 `PROJECT_NAME: "__PROJECT_NAME__"` + `@wizard ask:@repo` 마커
- 본문 `${{ env.PROJECT_NAME }}` (APK rename, artifact name/path, SMB 경로, 히스토리 파일명)
- playstore·firebase: 선언부만(본문 참조 없음) — 선언부 + 주석만 변경
- 선언부 토큰: `"__PROJECT_NAME__"` → `"__APP_ARTIFACT_NAME__"` 로 함께 변경하고, 재귀 치환이 새 토큰을 처리하도록 보장(§4.4 참조).

`DOMAIN_NAME → SERVICE_DOMAIN` (spring nginx):
- 선언부 `DOMAIN_NAME: "__DOMAIN_NAME__"` + 마커
- `${{ env.DOMAIN_NAME }}` (job-level env, 206행)
- **`envs:` SSH 전달 목록**(235행) 내 `DOMAIN_NAME` — **반드시 포함**(빠지면 서버로 미전달)
- 셸 본문 `${DOMAIN_NAME}` (도메인 검증·awk·로그 출력 다수)
- 상단 설명 주석 `# DOMAIN_NAME: ...`, `server_name ${DOMAIN_NAME}` 등

`PRODUCTION_DOMAIN → SERVICE_DOMAIN` (spring traefik):
- 선언부 + 마커
- `${{ env.PRODUCTION_DOMAIN }}` (200행)
- **`envs:` SSH 전달 목록**(227행) — 반드시 포함
- 셸 본문 `${PRODUCTION_DOMAIN}` (Traefik Host 라벨, curl Host 헤더, 로그 등)
- 설명 주석

#### labels.yml ask 기본값 토큰 정합
- `VOLUME_HOST_PATH`/`VOLUME_CONTAINER_PATH`의 `@wizard ask:` 기본값에 `__PROJECT_NAME__` 토큰이 들어있음(spring/python). 이들은 **PROJECT_NAME을 유지하는 타입(spring/python)** 이므로 변경 불필요. flutter엔 볼륨 KEY가 없어 영향 없음.

### 4.4 토큰 치환 정합성 (`__APP_ARTIFACT_NAME__`)

flutter 선언부는 `KEY`만 바꾸고 **플레이스홀더 토큰은 `"__APP_ARTIFACT_NAME__"`로 함께 바꾼다**(KEY와 토큰명을 일치시켜 가독성 유지):

```
# 변경 전
PROJECT_NAME: "__PROJECT_NAME__"  # @wizard ask:@repo
# 변경 후
APP_ARTIFACT_NAME: "__APP_ARTIFACT_NAME__"  # @wizard ask:@repo
```

치환 정합:
- ask 마커(`@wizard ask:@repo`)가 붙은 라인은 마법사 ask 분기가 `_wf_set_env`로 **값을 통째로 덮으므로** 토큰이 남지 않는다(주 경로에서 안전).
- 그래도 **방어적으로**, 마법사의 "남은 토큰 재귀 치환" 블록(`.sh` 2951~, `.ps1` 2491~)이 현재 `__PROJECT_NAME__`만 처리하므로 **`__APP_ARTIFACT_NAME__`도 레포명으로 치환**하도록 한 줄을 추가한다(양쪽 동일). 이렇게 하면 어떤 경로로 와도 토큰 잔여가 없다.

---

## 5. 신규 labels.yml 전체 (확정안)

```yaml
# @wizard ask 마커의 사용자 질문 문구.
# 형식 1 (구형, 지원 유지): KEY: "라벨"
# 형식 2 (신규): KEY: { label, help, example }
# 형식 3 (타입 오버라이드): "{type}.KEY": { label, help, example }
# 조회 우선순위: {type}.KEY → KEY → 구형 → 폴백(KEY명)

PROJECT_NAME:
  label: "서비스 식별자 (영문 슬러그)"
  help: "Docker 컨테이너명·이미지명·배포 도메인 prefix에 그대로 사용됩니다. 소문자-하이픈 권장."
  example: "my-service"

flutter.APP_ARTIFACT_NAME:
  label: "앱 산출물 이름 (영문)"
  help: "빌드된 APK 파일명·아티팩트명·빌드 히스토리 파일명에 사용됩니다."
  example: "my-app"

SERVICE_DOMAIN:
  label: "서비스 도메인"
  help: "배포 후 외부에서 접속할 운영 도메인입니다. 실제 보유한 도메인으로 바꿔야 합니다."
  example: "api.example.com"

JAVA_VERSION:
  label: "빌드 JDK 버전"
  help: "GitHub Actions 빌드 러너의 JDK 버전입니다. Spring은 보통 21, Flutter Android는 17."
  example: "21"

DEPLOY_PORT:
  label: "외부 노출 포트"
  help: "호스트(서버)에서 컨테이너로 연결할 포트입니다. 다른 서비스와 겹치지 않게 정하세요."
  example: "8080"

VOLUME_HOST_PATH:
  label: "호스트(NAS) 볼륨 경로"
  help: "서버에 데이터를 영구 저장할 실제 디렉토리 경로입니다."
  example: "/volume1/projects/my-service"

VOLUME_CONTAINER_PATH:
  label: "컨테이너 내부 마운트 경로"
  help: "컨테이너 안에서 위 볼륨이 보일 위치입니다."
  example: "/mnt/my-service"

SSH_AUTH_METHOD:
  label: "SSH 인증 방식"
  help: "배포 서버 접속 방식입니다. password(비밀번호) 또는 key(개인키) 중 하나."
  example: "password"
```

> spring nginx/traefik 양쪽이 `SERVICE_DOMAIN`을 쓰므로 타입 오버라이드 없이 공통 1개로 충분.

---

## 6. 영향 파일 목록

| 파일 | 변경 |
|------|------|
| `.github/wizard/labels.yml` | 스키마 확장 + 신규 라벨 전체 (§5) |
| `template_integrator.sh` | `wf_label`→`wf_field` 확장, `configure_workflow_env` ask 분기 도움말 출력, 재귀 치환에 `__APP_ARTIFACT_NAME__` 추가 |
| `template_integrator.ps1` | `Get-WfLabel`→`Get-WfField` 확장, `Configure-WorkflowEnv` ask 분기 도움말 출력, 재귀 치환에 토큰 추가 |
| `project-types/flutter/PROJECT-FLUTTER-ANDROID-SELFHOSTED-CICD.yaml` | `PROJECT_NAME`→`APP_ARTIFACT_NAME` (선언+참조 8+주석) |
| `project-types/flutter/PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` | `PROJECT_NAME`→`APP_ARTIFACT_NAME` (선언+주석) |
| `project-types/flutter/PROJECT-FLUTTER-ANDROID-FIREBASE-CICD.yaml` | `PROJECT_NAME`→`APP_ARTIFACT_NAME` (선언+주석) |
| `project-types/spring/PROJECT-SPRING-NONSTOP-NGINX-CICD.yaml` | `DOMAIN_NAME`→`SERVICE_DOMAIN` (선언+참조+envs목록+셸본문+주석) |
| `project-types/spring/PROJECT-SPRING-NONSTOP-TRAEFIK-CICD.yaml` | `PRODUCTION_DOMAIN`→`SERVICE_DOMAIN` (선언+참조+envs목록+셸본문+주석) |

> CLAUDE.md 동기화 체크: labels.yml은 **공통 자산이라 cleanup/제외 목록에 넣지 않는다**. 타입별 배포 워크플로우는 루트 복사본이 없어 `project-types/`만 수정. 실행 로직(run/uses/with/steps) 무손상 — `git diff`로 자가검증.

---

## 7. 검증 계획

1. **labels.yml 파서** — `.sh`/`.ps1`의 `wf_field`가 신규 블록·타입오버라이드·구형 라인·폴백을 모두 올바르게 읽는지 최소 하네스로 검증(CLAUDE.md의 expect / Docker PowerShell 패턴).
2. **마법사 출력** — "하나씩(n)" 모드에서 `▸ label / help / 예) example / 값 입력` 4줄이 나오는지(help·example 결손 시 생략) 입력 주입으로 확인.
3. **KEY 리네이밍 무결성** — 각 워크플로우에서 옛 KEY 잔존 0건 확인:
   - `grep -rn "PROJECT_NAME" project-types/flutter/*SELFHOSTED*` → 0
   - `grep -rn "DOMAIN_NAME\b" .../NGINX*` / `PRODUCTION_DOMAIN` `.../TRAEFIK*` → 0
   - `envs:` 목록에 새 KEY 포함 확인.
4. **실행 로직 무손상** — `git diff <workflow파일> | grep '^+' | grep -vE 'SERVICE_DOMAIN|APP_ARTIFACT_NAME|__APP_ARTIFACT_NAME__'` 결과가 KEY 치환 외 라인을 포함하지 않는지.
5. **문법** — `bash -n template_integrator.sh`, Docker PowerShell `Parser::ParseFile`로 `.ps1`, GitHub Actions YAML은 운영 이력 대조(actionlint 빨간불=참고용).
