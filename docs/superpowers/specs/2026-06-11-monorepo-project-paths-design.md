# 멀티타입 모노레포 경로 지원 (project_paths) 설계

- 날짜: 2026-06-11
- 상태: 설계 승인됨 (구현 전)
- 범위: 버전 동기화까지 (타입별 CI/CICD 워크플로우 경로 주입은 비범위 — 2차)

---

## 1. 배경 / 문제

멀티타입(`project_types: ["flutter","react","python"]`)으로 통합해도, 버전 동기화는
**레포 루트**에서만 타입별 파일을 찾는다.

- `version_manager.sh`의 `sync_for_type()`이 `if [ -f "pubspec.yaml" ]` 처럼 루트만 체크
- passQL 같은 서브폴더 모노레포(`app/`, `client/`, `ai/`, `server/`)에서는
  flutter/react/python sync가 **에러 없이 조용히 no-op** — version.yml만 올라가고
  서브프로젝트 버전 파일은 영원히 동기화되지 않음
- 아이러니하게 spring만 `find . -maxdepth 2`로 `server/build.gradle`을 잡음

실측 (passQL, 2026-06-11):

```
passQL/
├── ai/pyproject.toml      ← python   (루트 pyproject.toml 없음)
├── app/pubspec.yaml       ← flutter  (루트 pubspec.yaml 없음)
├── client/package.json    ← react    (루트 package.json 없음)
└── server/build.gradle    ← spring
```

## 2. 목표

1. integrator가 멀티타입 통합 시 **타입별 마커 파일을 자동 감지**하고,
   사용자에게 "이 경로 맞아요?" 확인 / 복수 후보 선택 / 수동 상대경로 입력을 받는다.
2. 확정된 경로를 `version.yml`의 `project_paths` 맵에 저장한다.
3. `version_manager.sh`가 `project_paths`를 읽어 서브폴더의 타입 파일을 동기화한다.
4. `PROJECT-COMMON-VERSION-CONTROL.yaml` 등 **워크플로우는 무수정** —
   스크립트가 경로를 알고, 커밋은 `git add -A`라 서브폴더 변경도 자동 포함된다.
5. `project_paths` 키가 없는 기존 레포는 **100% 기존 동작 유지** (하위 호환).

### 비범위 (이번에 안 함)

- 타입별 CI/CICD 워크플로우(`PROJECT-FLUTTER-CI` 등)의 working-directory/경로 주입
  → 별도 이슈로 등록 후 2차 진행
- 같은 타입 프로젝트 여러 개(예: react 앱 2개) — 타입당 경로 1개만 지원 (YAGNI)
- `template_initializer.sh` (신규 레포 생성용) — 신규 레포는 루트 단일 타입이 일반적

## 3. version.yml 스키마 확장

```yaml
version: "0.0.187"
version_code: 187
project_types: ["flutter", "react", "python"]   # 기존 그대로
project_type: "flutter"                          # 기존 그대로 (project_types[0] 미러)
project_paths:                # ★ 신규 — 타입별 프로젝트 폴더 (레포 루트 기준 상대경로)
  flutter: "app"              # app/pubspec.yaml
  react: "client"             # client/package.json
  python: "ai"                # ai/pyproject.toml
```

- integrator가 기록할 때 위처럼 **각 항목 옆에 실제 마커 파일을 주석으로** 남긴다.
  사용자가 나중에 version.yml만 열어봐도 "이 경로 = 이 파일"임을 바로 알 수 있게.

- 경로는 레포 루트 기준 **상대경로, POSIX 슬래시** (Windows에서 기록해도 `/` 사용)
- 루트에 있는 타입은 `"."`로 **명시 저장** (감지를 거쳤다는 사실을 기록)
- `project_paths` 키 자체가 없으면 → legacy 동작 (루트 체크 + spring find maxdepth 2)
- integrator 재실행 시 기존 `project_paths` 값을 읽어 기본값으로 제시 (Enter = 유지)

## 4. integrator 경로 감지 루틴 (.sh / .ps1 동일 구현)

### 4.1 실행 시점

프로젝트 정보 확인(타입 확정) 직후, version.yml 쓰기 직전. 선택된 타입별 순회.
basic 타입은 감지 대상 아님.

### 4.2 타입별 마커와 오탐 방지

| 타입 | 마커 (우선순위) | 오탐 방지 |
|---|---|---|
| flutter | `pubspec.yaml` | 같은 폴더에 `lib/` 존재해야 인정, `example/` 하위 제외 |
| react / next / node | `package.json` | `node_modules/` 제외, `next.config.*` 있으면 next 신뢰도↑ |
| python | `pyproject.toml` → `setup.py` → `requirements.txt` | `venv/`, `__pycache__/` 제외 |
| spring | `build.gradle` / `pom.xml` | **`android/` 하위 제외** (Flutter android 오탐), `settings.gradle` 동반 시 신뢰도↑ |
| react-native | `package.json` + `android/` + `ios/` 동반 | — |
| react-native-expo | `app.json` (expo 키) | — |

> **구현 노트(1차 범위)**: "신뢰도↑"로 표기된 보조 신호(`next.config.*`, `settings.gradle` 동반)와 react-native/expo의 동반 폴더·expo 키 정밀 검사는 1차 구현에서 단순 마커 파일명 검색으로 갈음했다. 핵심 타입(flutter/react/python/spring)의 오탐 방지(lib 동반·android 제외)는 적용됨. 정밀 신호는 오탐 사례가 보고되면 2차로 보강한다.

### 4.3 검색 규칙

- 깊이 제한: **maxdepth 3**
- 제외 폴더(고정): `node_modules, .git, build, dist, .dart_tool, android, ios, .gradle, venv, .venv, __pycache__`
- 루트에 마커가 있으면 검색 생략하고 `"."` 자동 확정 (질문 없이 한 줄 안내만)

### 4.4 결과 개수별 분기 (대화형)

```
[1개]  app/pubspec.yaml 발견 — flutter 경로를 'app'으로? [Y=예 / n=직접입력]
[N개]  번호 선택 메뉴 + m) 직접 입력
[0개]  상대경로 수동 입력 (그냥 Enter = 루트 ".")
```

- 수동 입력 검증: 입력 경로에 해당 타입 마커가 실제 있는지 확인.
  없으면 경고 후 "그래도 사용할까요?" 재확인 (강제 차단 안 함 — 특수 구조 허용)

#### path 의미를 쉬운 말로 안내 (UX 필수)

"경로"가 뭘 뜻하는지 처음 보는 사용자도 알 수 있게, 질문 직전에 한 줄 설명을 출력한다:

```
💡 경로 = 레포 루트에서 그 프로젝트 폴더까지의 상대경로입니다.
   예) 레포루트/app/pubspec.yaml 이면 → "app"
       레포루트/packages/web/package.json 이면 → "packages/web"
       레포 루트에 바로 있으면 → 그냥 Enter (".")
```

수동 입력 프롬프트 문구도 동일 원칙:
`상대경로 입력 (예: app, client/web — 루트면 그냥 Enter):`

#### 항상 "타입 → 마커 파일 → 경로"를 한 묶음으로 표시

여러 타입이 **같은 종류의 설정 파일**을 쓰기 때문에(react/next/node 전부 `package.json`),
경로만 보여주면 어느 타입 얘기인지 헷갈린다. 모든 안내·확인·요약 출력은
`타입 → 경로/마커파일` 형식으로 묶어서 표시한다:

```
📂 타입별 버전 파일 경로 확정:
   flutter → app/pubspec.yaml
   react   → client/package.json
   python  → ai/pyproject.toml
```

#### 같은 파일을 두 타입이 바라보는 경우

선택된 타입 중 둘 이상이 **동일한 파일 경로**로 확정되면(예: react와 node가
둘 다 `client/package.json`), 막지는 않되 명확히 알린다:

```
⚠️ react와 node가 같은 파일(client/package.json)을 바라봅니다.
   버전 sync 시 같은 파일에 같은 버전이 기록되므로 동작에는 문제없지만,
   의도한 구성이 맞는지 확인하세요.
```

sync 측(`version_manager.sh`)에서도 동일 파일 중복 기록은 같은 값을 다시 쓰는
멱등 동작이므로 별도 dedupe 없이 로그로만 표시한다.

### 4.5 비대화형 (-Force / CLI 모드)

- 신규 옵션: `.sh`는 `--paths "flutter=app,react=client,python=ai"`,
  `.ps1`은 `-Paths "flutter=app,react=client,python=ai"` (값 형식은 동일한 csv)
- 미지정 시: 후보가 정확히 1개면 자동 채택, 0개 또는 복수면 경고 출력 후 `"."` 기록

## 5. version_manager.sh 변경 (수정 지점 3곳)

### 5.1 신규 헬퍼

```bash
# project_paths.<type> 반환 — 키 없으면 "." (legacy)
get_type_path() {
    yq -r ".project_paths.${1} // \".\"" version.yml 2>/dev/null || echo "."
}
```

- `cd` 서브셸 방식은 쓰지 않는다 — `get_version_code` 등이 루트 `version.yml`을
  읽기 때문에 cwd를 바꾸면 깨진다. **경로 prefix 방식**으로 통일.

### 5.2 수정 지점

| # | 함수 (현재 라인) | 수정 내용 |
|---|---|---|
| ① | `read_version_config` `:155-184` | primary 타입의 `VERSION_FILE`에 경로 prefix (`app/pubspec.yaml`) |
| ② | `get_project_file_version` `:322` | ①의 VERSION_FILE을 그대로 읽으므로 자동 해결 |
| ③ | `sync_for_type` `:497-558` | 타입별로 `p=$(get_type_path $t)` 후 `"$p/package.json"` 등 prefix. spring은 `project_paths` 있으면 `find "$p" -maxdepth 2`, 없으면 기존 `find . -maxdepth 2` |

- `update_project_file_version`(legacy 단일타입 쓰기)은 **수정하지 않음** —
  `project_paths` 없는 기존 레포만 이 경로를 타므로 회귀 위험 0
- 경로에 마커 파일이 없으면: 경고 로그 + 해당 타입만 skip (워크플로우 실패시키지 않음 — 현재의 관용적 동작 유지)
- flutter `increment-code`의 pubspec 빌드넘버 쓰기도 ③에 포함되어 경로 적용됨

## 6. 워크플로우 영향

- `PROJECT-COMMON-VERSION-CONTROL.yaml`: **무수정**.
  `version_manager.sh get/increment`만 호출하고 `git add -A`로 커밋하므로
  서브폴더 변경이 자동 포함된다.
- `PROJECT-COMMON-README-VERSION-UPDATE`, `AUTO-CHANGELOG-CONTROL`: version.yml만 읽음 — 영향 없음.

## 7. 테스트 계획

`.github/scripts/test/` 시나리오:

1. **legacy 회귀**: `project_paths` 없음 + 루트 단일 타입 → 기존과 동일 동작
2. **모노레포**: `project_paths` 있는 멀티타입 → 서브폴더 파일들 sync 확인
3. **paths 없는 멀티타입**: 기존 멀티타입 레포 → 루트 체크 no-op (기존 동작) 확인
4. **경로 오류**: `project_paths`가 가리키는 곳에 마커 없음 → 경고 + skip, exit 0

최종 리허설: passQL에서 `flutter,react,python` 통합 실행 →
`app/pubspec.yaml`, `client/package.json`, `ai/pyproject.toml` 버전이 실제로 올라가는지 확인.

## 8. 구현 대상 파일

| 파일 | 작업 |
|---|---|
| `template_integrator.sh` | 경로 감지 루틴 + `--paths` 옵션 + version.yml `project_paths` 기록 |
| `template_integrator.ps1` | 위와 동일 (PowerShell 5.1 호환) |
| `.github/scripts/version_manager.sh` | `get_type_path` 헬퍼 + 수정 지점 ①③ |
| `.github/scripts/test/` | 테스트 시나리오 4종 |
| `CLAUDE.md` / docs | `project_paths` 스키마 문서화 |
