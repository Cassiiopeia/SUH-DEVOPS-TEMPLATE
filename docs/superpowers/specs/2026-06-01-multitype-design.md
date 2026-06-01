# Multi Project Type Support

**Date**: 2026-06-01
**Issue**: #302 — 단일 레포에 여러 프로젝트 타입이 공존하는 경우 지원
**Scope**: `template_integrator.{sh,ps1}`, `version.yml` 스키마, `.github/scripts/version_manager.sh`, `.github/scripts/changelog_manager.py`, `PROJECT-COMMON-VERSION-CONTROL.yaml`, `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml`, 문서

---

## 1. Motivation

현재 `template_integrator.{sh,ps1}`는 단일 `PROJECT_TYPE` 변수로만 동작한다. 하나의 레포에 Spring + React + Python 같은 여러 타입이 공존하는 모노레포에서는 한 타입의 워크플로우만 적용되어 나머지는 수동 추가가 필요하다. `version_manager.sh`도 단일 타입의 동기화 파일만 sync해 멀티 타입 버전이 어긋난다.

본 작업은 멀티 프로젝트 타입을 일급(first-class)으로 지원한다:
- 자동 감지 시 모든 일치 타입을 반환
- 사용자가 인터랙티브 다중 선택 메뉴로 확인·수정
- 워크플로우·util 모듈을 선택된 모든 타입에 대해 복사
- `version.yml`에 `project_types` 배열 신규 키 추가
- `version_manager.sh`가 배열 순회로 모든 타입의 sync 파일 동기화
- 기존 단수 `project_type` 키만 있는 레포 100% 하위 호환

---

## 2. Goals / Non-Goals

### Goals
- `version.yml` 스키마에 `project_types: ["spring", "react", "python"]` 배열 키 신규 추가
- `project_type` 단수 키는 항상 `project_types[0]`으로 자동 미러링 — 직접 수정 금지
- integrator의 자동 감지·다중 선택 메뉴·워크플로우 복사·util 복사·안내 메시지를 멀티 대응으로 확장
- `version_manager.sh`가 `project_types` 배열을 우선 읽고, 없으면 기존 단수 동작
- `changelog_manager.py`가 `PROJECT_TYPES` env 받아 CHANGELOG에 배열도 같이 기록
- `PROJECT-COMMON-VERSION-CONTROL.yaml`, `PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml`에 `project_types` step output 추가
- 단일 타입 레포 100% 하위 호환 (기존 `version.yml` 그대로 동작)
- #326의 단일 선택 메뉴 컴포넌트를 `--multi` 플래그로 확장 (Space 토글, csv 출력)

### Non-Goals
- CI 트리거 충돌 해결 (멀티타입 레포에서 여러 `*-CI.yaml`이 동일 push에 동시 실행되는 문제) — 사용자가 `paths:` 필터를 수동 추가하는 책임. 강한 경고 메시지만 출력.
- `PROJECT_NAME` / `CONTAINER_NAME` / `DEPLOY_PORT` 등 워크플로우 env placeholder 자동 치환 — 단일 타입에서도 사용자가 늘 수정해 왔던 부분, 본 scope 초과
- 디렉토리 매핑 입력 (`--type spring:backend,react:frontend`) — yaml `paths` 자동 주입은 미지원
- `react-native` / `react-native-expo` 등 특수 처리(`Info.plist` + `build.gradle` 두 파일 sync) 변경 — 기존 동작 유지

---

## 3. Architecture

### 3.1 version.yml 스키마

```yaml
version: "3.0.78"
version_code: 270
project_types: ["spring", "react", "python"]    # 멀티타입 배열 — 첫 항목이 primary
project_type: "spring"                          # project_types[0] 자동 동기화 — 직접 수정 금지
metadata:
  last_updated: "2026-06-01 02:30:07"
  last_updated_by: "Cassiiopeia"
```

**규칙**:
- 단일 타입도 배열 형태로 통일: `project_types: ["basic"]`
- `project_type` 단수 키는 `project_types[0]`의 자동 미러
- 기존 단수 키만 있는 version.yml(legacy) → `project_types` 키 없음, 기존 단수 동작 그대로 (하위 호환)
- 인라인 배열 표기 — grep으로 파싱 가능, `yq` 의존성 불필요

### 3.2 자동 동기화 정합화

`project_type ↔ project_types[0]` 정합화 시점:

- **integrator의 `create_version_yml()` / `update_version_yml()`** — 항상 두 키 같이 작성. 배열의 첫 항목으로 단수 키 작성.
- **`version_manager.sh` 실행 시작 시** — `project_types` 키 존재하면 `project_type`을 첫 항목으로 강제 덮어쓰기. 사용자가 수동 편집 실수해도 다음 실행 시 자동 복구.

정합화 로직 (bash, yq 없이):
```bash
if grep -q "^project_types:" version.yml; then
    PROJECT_TYPES_CSV=$(grep "^project_types:" version.yml | sed -E 's/.*\[([^]]*)\].*/\1/' | tr -d '" ')
    FIRST_TYPE=$(echo "$PROJECT_TYPES_CSV" | cut -d',' -f1)
    CURRENT_SINGLE=$(grep "^project_type:" version.yml | sed -E 's/project_type: *"([^"]*)".*/\1/')
    if [ "$CURRENT_SINGLE" != "$FIRST_TYPE" ]; then
        sed -i.bak "s|^project_type:.*|project_type: \"$FIRST_TYPE\"|" version.yml
        rm -f version.yml.bak
    fi
fi
```

### 3.3 자동 감지

`detect_project_types()` (sh, ps1 동일 로직):

```bash
detect_project_types() {
    local detected=()
    [ -f "pubspec.yaml" ] && detected+=("flutter")
    [ -f "build.gradle" ] || [ -f "build.gradle.kts" ] || [ -f "pom.xml" ] && detected+=("spring")
    [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ] && detected+=("python")
    if [ -f "package.json" ]; then
        # next.config.* → next, ios/ + android/ → react-native, expo presence → expo, 기본 → react
        ...
    fi
    [ ${#detected[@]} -eq 0 ] && detected=("basic")
    printf '%s\n' "${detected[@]}"
}
```

반환: 배열. 호출측이 csv로 변환해 표시·확정.

### 3.4 사용자 확인 흐름 (자동 감지 후)

```
🛰️ 감지된 프로젝트 타입: spring, react, python

이대로 적용하시겠습니까?
> [•] 1) 네, 모두 적용
  [ ] 2) 아니오, 직접 선택
  [ ] 3) 취소
```

- 1 선택 → 감지 배열 그대로 확정
- 2 선택 → 다중 선택 메뉴(Multi mode) 호출 — 감지된 타입은 초기 `[✓]`, 다른 타입은 `[ ]`
- 3 선택 → exit 0

### 3.5 다중 선택 메뉴 컴포넌트 (#326 확장)

기존 `choose_menu` (sh) / `Invoke-ChooseMenu` (ps1)에 `--multi` 플래그 추가.

**키 매핑 (multi mode)**:
| 키 | 동작 |
|---|---|
| `↑` / `k` | 커서 위로 (wrap) |
| `↓` / `j` | 커서 아래로 (wrap) |
| `Space` | 현재 행 토글 (`[ ]` ↔ `[✓]`) |
| `1`~`9` | 점프 (선택 토글 안 함) |
| `Enter` | 다중 확정 → csv 출력 |
| `a` | 전체 토글 |
| `ESC` / `q` | 취소 |

**시각**:
```
프로젝트 타입을 선택하세요 (↑↓ 이동, Space 토글, Enter 확정, ESC 취소):

> [✓] 1) spring         Spring Boot 백엔드     ← 현재 (cyan) + 선택 (green ✓)
  [✓] 2) react          React 웹 앱            ← 선택 (green ✓)
  [ ] 3) flutter        Flutter 모바일 앱
  [ ] 4) python         Python 프로젝트
```

**호출 시그니처**:
- Bash: `selected_csv=$(choose_menu --multi --preselect "spring,react" "프로젝트 타입" "spring|Spring Boot" ...)`
- PowerShell: `Invoke-ChooseMenu -Multi -Preselect 'spring,react' -Prompt '...' -Options @(...)`

**비TTY fallback**:
- `legacy_numeric_menu` (sh) / `Invoke-LegacyNumericMenu` (ps1)도 `--multi` 지원
- 사용자가 csv 입력: `1,2,3` 또는 `spring,react,python` 둘 다 허용

### 3.6 CLI 옵션

```bash
# 단일 (기존)
./template_integrator.sh --type spring

# 멀티 (신규) — csv
./template_integrator.sh --type spring,react,python

# 단일/멀티 자동 — 파싱 시 csv 분해
```

`PROJECT_TYPE` 단일 변수 + `PROJECT_TYPES` 배열 변수 둘 다 유지:
- `PROJECT_TYPE` = `PROJECT_TYPES[0]` (자동 미러, 기존 코드 참조 호환)
- `PROJECT_TYPES` = 배열, 새 코드는 이걸 순회

### 3.7 워크플로우 복사

```bash
copy_workflows() {
    # common 그대로 (변경 없음)
    
    # 타입별 — 배열 순회
    for t in "${PROJECT_TYPES[@]}"; do
        local type_dir="$project_types_dir/$t"
        [ -d "$type_dir" ] || continue
        copy_type_workflows "$t" "$type_dir"   # 기존 로직 함수화
    done
}
```

타입별 워크플로우 파일명은 `PROJECT-{TYPE}-` prefix로 완전 분리 → **충돌 0**. 기존 T/S/O (template / skip / overwrite) 로직은 각 타입 폴더 단위로 동일하게 적용.

### 3.8 util 모듈 복사

`.github/util/{type}/` 폴더는 타입별 분리 → 배열 순회로 모두 복사.

### 3.9 안내 메시지 (`show_util_module_description`, Spring/Flutter 안내)

기존 `case "$PROJECT_TYPE" in` → 배열 순회:

```bash
for t in "${PROJECT_TYPES[@]}"; do
    show_util_module_description "$t"
done

# Spring 안내, Flutter 안내 — 배열에 포함되어 있으면 출력
contains() { local needle=$1; shift; for x in "$@"; do [ "$x" = "$needle" ] && return 0; done; return 1; }
contains "spring" "${PROJECT_TYPES[@]}" && print_spring_secrets_guide
contains "flutter" "${PROJECT_TYPES[@]}" && print_flutter_wizard_guide
```

### 3.10 최종 요약 prefix 매칭

기존 (L3228):
```bash
elif [[ "$filename" =~ ^${WORKFLOW_PREFIX}-$(echo "$PROJECT_TYPE" | tr '[:lower:]' '[:upper:]')- ]]; then
    type_workflows+=("$filename")
```

→ 배열 순회로:
```bash
local matched=false
for t in "${PROJECT_TYPES[@]}"; do
    local prefix="^${WORKFLOW_PREFIX}-$(echo "$t" | tr '[:lower:]' '[:upper:]')-"
    if [[ "$filename" =~ $prefix ]]; then
        type_workflows+=("$filename")
        matched=true
        break
    fi
done
```

### 3.11 `version_manager.sh` 멀티 sync

```bash
parse_version_yml() {
    # 1. project_types 배열 파싱
    PROJECT_TYPES_CSV=""
    if grep -q "^project_types:" version.yml; then
        PROJECT_TYPES_CSV=$(grep "^project_types:" version.yml | sed -E 's/.*\[([^]]*)\].*/\1/' | tr -d '" ')
    fi

    # 2. 단수 키 (legacy + 미러)
    PROJECT_TYPE=$(yq -r '.project_type // "basic"' version.yml)

    # 3. 정합화 — 배열 있고 단수 키 어긋나면 첫 항목으로 덮어쓰기
    if [ -n "$PROJECT_TYPES_CSV" ]; then
        local first
        first=$(echo "$PROJECT_TYPES_CSV" | cut -d',' -f1)
        if [ "$PROJECT_TYPE" != "$first" ]; then
            sed -i.bak "s|^project_type:.*|project_type: \"$first\"|" version.yml
            rm -f version.yml.bak
            PROJECT_TYPE="$first"
        fi
    fi
}

sync_for_type() {
    local t=$1
    case "$t" in
        spring) sync_build_gradle ;;
        flutter) sync_pubspec ;;
        react|next|node) sync_package_json ;;
        python) sync_pyproject ;;
        react-native-expo) sync_app_json ;;
        react-native) sync_info_plist; sync_build_gradle ;;
        basic) ;;
    esac
}

main() {
    parse_version_yml
    
    if [ -n "$PROJECT_TYPES_CSV" ]; then
        # 멀티 — 배열 순회
        IFS=',' read -ra TYPES <<< "$PROJECT_TYPES_CSV"
        for t in "${TYPES[@]}"; do sync_for_type "$t"; done
    else
        # Legacy — 단수만
        sync_for_type "$PROJECT_TYPE"
    fi
}
```

기존 `case` 분기를 `sync_for_type()` 함수로 추출. 외부 호출 인터페이스(`./version_manager.sh increment` 등) 변경 없음.

### 3.12 `changelog_manager.py` + 워크플로우

**`PROJECT-COMMON-VERSION-CONTROL.yaml`** 신규 step output:
```yaml
- id: project_info
  run: |
    PROJECT_TYPE=$(grep "^project_type:" version.yml | sed 's/project_type: *"\([^"]*\)".*/\1/')
    PROJECT_TYPES=$(grep "^project_types:" version.yml 2>/dev/null | sed -E 's/.*\[([^]]*)\].*/\1/' | tr -d '" ' || echo "")
    [ -z "$PROJECT_TYPES" ] && PROJECT_TYPES="$PROJECT_TYPE"
    echo "project_type=$PROJECT_TYPE" >> $GITHUB_OUTPUT
    echo "project_types=$PROJECT_TYPES" >> $GITHUB_OUTPUT
```

**`PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml`** 동일 step output + env 전달:
```yaml
env:
  PROJECT_TYPE: ${{ needs.detect-and-parse.outputs.project_type }}
  PROJECT_TYPES: ${{ needs.detect-and-parse.outputs.project_types }}
```

**`changelog_manager.py`** 확장:
```python
project_type = os.environ.get('PROJECT_TYPE', 'basic')
project_types_csv = os.environ.get('PROJECT_TYPES', '')
project_types = [t.strip() for t in project_types_csv.split(',') if t.strip()] or [project_type]

new_release = {
    "version": version,
    "project_type": project_type,                  # 기존 단수 — 유지
    "project_types": project_types,                # 신규 배열 — 멀티 정보
    "date": today,
    ...
}

changelog_data["metadata"]["projectType"] = project_type
changelog_data["metadata"]["projectTypes"] = project_types     # 신규
```

기존 `"project_type"` 키 유지 — 다른 도구가 단수 키 읽어도 OK.

---

## 4. 충돌 가능 영역 — 정리

| 영역 | 충돌 발생? | 본 작업 대응 |
|---|---|---|
| 워크플로우 파일명 (`PROJECT-{TYPE}-*`) | ❌ prefix 분리 | 배열 순회 복사만 |
| `common/` 워크플로우 | ❌ | 그대로 |
| util 모듈 폴더 | ❌ 타입별 분리 | 배열 순회 복사만 |
| `version.yml` 단수 키 참조 (워크플로우·스크립트 다수) | ❌ | 단수 키 + 배열 키 둘 다 유지 |
| `version_manager.sh` case 분기 | ⚠️ 멀티 sync 미지원 | `sync_for_type()` 함수 + 배열 순회 |
| `changelog_manager.py` 단수 기록 | ⚠️ 정보 손실 | 배열도 같이 기록 |
| CI 트리거 동시 발화 (예: main push에 Spring CI + React CI) | ⚠️ 사용자 책임 | 강한 경고 메시지만 |
| `PROJECT_NAME`/`DEPLOY_PORT` placeholder | ⚠️ 사용자 책임 | 멀티 시 안내 메시지 강화 |
| 자동 감지 false positive | ⚠️ docs/ 안 package.json 등 | 사용자 확인 + multi select |

---

## 5. 적용 지점 — 파일별 변경 요약

| 파일 | 변경 |
|---|---|
| `template_integrator.sh` | `PROJECT_TYPES` 배열 변수, `detect_project_types()`, `--type csv` 파싱, 다중 선택 메뉴(`--multi`), 워크플로우/util 배열 순회, 안내 메시지 배열 순회, `create_version_yml`/`update_version_yml` 두 키 작성 |
| `template_integrator.ps1` | sh와 동일 로직 PowerShell 포팅 |
| `version.yml` (실제 파일) | `project_types: ["basic"]` 키 추가 (기본값) |
| `.github/scripts/version_manager.sh` | `parse_version_yml()` 멀티 파싱·정합화, `sync_for_type()` 함수, 배열 순회 sync |
| `.github/scripts/changelog_manager.py` | `PROJECT_TYPES` env 받아 release/metadata에 배열 기록 |
| `.github/workflows/PROJECT-COMMON-VERSION-CONTROL.yaml` | `project_types` step output 추가 |
| `.github/workflows/PROJECT-COMMON-AUTO-CHANGELOG-CONTROL.yaml` | `project_types` step output + env 전달 |
| `.github/scripts/template_initializer.sh` | version.yml 초기 생성 시 두 키 같이 작성 |
| `docs/TEMPLATE-INTEGRATOR.md` | 멀티 사용 예시 추가 |
| `docs/SYNOLOGY-DEPLOYMENT-GUIDE.md` | 멀티 시 포트/이름 분리 안내 |
| `docs/VERSION-CONTROL.md` | `project_types` 키 설명 |
| `CONTRIBUTING.md` | 멀티타입 관련 기여 가이드 |
| `CLAUDE.md` | 멀티타입 짧은 설명 (지원 프로젝트 타입 표 보강) |

---

## 6. 에러 처리 / Edge Case

| 상황 | 동작 |
|---|---|
| `project_types` 키 없음 (legacy version.yml) | 기존 단수 동작 — 100% 호환 |
| `project_types: []` 빈 배열 | `["basic"]`으로 fallback + 경고 |
| `project_types: ["unknown"]` 미지원 타입 | `VALID_TYPES` 검증 fail → 사용자 안내 후 종료 |
| `project_type` ↔ `project_types[0]` 불일치 (사용자 수동 편집) | `version_manager.sh` / integrator 실행 시 단수 키를 첫 항목으로 자동 덮어쓰기 |
| 자동 감지 0개 일치 | `basic` 단일 fallback (기존 동작) |
| 자동 감지 multi (예: Flutter + package.json 둘 다) | 모두 반환 후 사용자 확인 |
| CLI `--type spring,unknown,react` 일부 unknown | 검증 단계에서 전체 reject + 명확한 에러 |
| `--type` 중복 (`spring,spring`) | dedup 후 진행 |

---

## 7. 호환성

- **기존 단일 타입 version.yml** (`project_types` 키 없음) → 모든 코드 경로가 단수 키만 읽어도 정상 동작
- **기존 워크플로우 yaml** (`grep "^project_type:"` 단수 키 파싱) → 변경 없이 동작. 새 step output(`project_types`)만 추가됨
- **CLI 단일 `--type spring`** → 내부적으로 배열 `["spring"]`로 변환, 사용자 인터페이스 그대로
- **VALID_TYPES 검증** → 단일도 csv 분해 후 각 항목 검증

---

## 8. 테스트 (수동)

| 시나리오 | 확인 항목 |
|---|---|
| 단일 타입 레포 (기존) | 기존 동작 100% — `--type spring`, 자동 감지 단일 |
| 멀티 자동 감지 | Spring + Node 공존 레포 → 두 타입 감지 → 다중 선택 메뉴 |
| 멀티 명시 (`--type spring,react,python`) | 세 타입 워크플로우 모두 복사 (충돌 0) |
| 멀티 → 단일 변경 | Edit 메뉴에서 다중 선택 → 일부 해제 → version.yml 업데이트 |
| Legacy version.yml (`project_types` 없음) | 워크플로우 트리거 시 단수 동작 그대로 |
| version_manager.sh 정합화 | `project_type`을 사용자가 수동 변경 → 다음 실행 시 첫 항목으로 복구 |
| changelog 멀티 기록 | deploy PR → CHANGELOG.json에 `project_types` 배열 기록 |
| 비TTY (CI) | csv 입력으로 multi 선택 가능 |
| 다중 선택 메뉴 ESC | 취소 흐름 — 기존 값 유지 |

---

## 9. Out of Scope (향후)

- CI 트리거 `paths:` 자동 주입 (디렉토리 매핑 입력)
- 워크플로우 yaml의 `PROJECT_NAME` 등 placeholder 자동 치환
- multi 시 각 타입별 `Dockerfile`/`Procfile` 등 자동 생성
- 멀티 타입에 따른 자동 `application.yml` / `package.json` 분리

---

## 10. 참고

- 이슈: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/issues/302
- 선행 작업 (메뉴 컴포넌트 신설): #326 — `docs/superpowers/specs/2026-06-01-interactive-menu-design.md`
