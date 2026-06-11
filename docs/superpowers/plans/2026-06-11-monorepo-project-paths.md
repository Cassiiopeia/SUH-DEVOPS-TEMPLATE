# 멀티타입 모노레포 경로 지원 (project_paths) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 서브폴더 모노레포(예: `app/`, `client/`, `ai/`)에서도 멀티타입 버전 동기화가 동작하도록, integrator가 타입별 경로를 감지·확인해 `version.yml`의 `project_paths`에 기록하고 `version_manager.sh`가 그 경로를 따라가게 한다.

**Architecture:** 경로의 단일 진실 공급원은 `version.yml`의 `project_paths` 맵. integrator(.sh/.ps1)는 통합 시 마커 파일을 maxdepth 3으로 검색해 사용자 확인 후 기록하고, `version_manager.sh`는 `get_type_path()` 헬퍼로 읽어 파일 경로에 prefix한다(`cd` 금지 — `get_version_code`가 루트 version.yml을 읽으므로). `project_paths` 키가 없으면 100% 기존 동작. 워크플로우 yaml은 무수정.

**Tech Stack:** bash 3.2 호환(macOS 기본 bash — `declare -A`/`mapfile` 금지), PowerShell 5.1 호환(`&&`/삼항연산자 금지), yq(mikefarah v4)/jq, GitHub Actions ubuntu-latest.

**스펙:** `docs/superpowers/specs/2026-06-11-monorepo-project-paths-design.md`

---

## File Structure

| 파일 | 작업 | 책임 |
|---|---|---|
| Create: `.github/scripts/test/test_version_manager_paths.sh` | 신규 | version_manager.sh 경로 동기화 회귀/신규 테스트 (기존 `test_truncate_release_notes.sh`의 PASS/FAIL 컨벤션 준수) |
| Modify: `.github/scripts/version_manager.sh` | 수정 3지점 | `get_type_path()` 헬퍼 신설, `read_version_config`의 VERSION_FILE 경로 prefix, `sync_for_type` 경로 prefix + 누락 경고 |
| Modify: `template_integrator.sh` | 수정 | `--paths` 옵션, 경로 헬퍼 4종(`get_path_for_type`/`set_path_for_type`/`marker_for_type`/`find_type_path_candidates`), `resolve_project_paths` 대화 루틴, `create_version_yml`에 project_paths 블록 기록, `execute_integration` 호출부 |
| Modify: `template_integrator.ps1` | 수정 | 위와 동일 (PS 5.1 문법) — `-Paths` 파라미터, `$script:ProjectPaths` ordered hashtable |
| Modify: `CLAUDE.md` | 수정 | project_paths 스키마 한 줄 문서화 |

주의: `version_manager.sh`의 `update_project_file_version()`(legacy 단일타입 쓰기)은 **절대 수정하지 않는다** — `project_paths` 없는 기존 레포 회귀 방지.

---

### Task 1: version_manager.sh 경로 동기화 테스트 작성 (failing)

**Files:**
- Create: `.github/scripts/test/test_version_manager_paths.sh`

- [ ] **Step 1: 테스트 파일 작성**

전체 내용 (기존 테스트 컨벤션: `set -u`, mktemp 작업폴더, `chk` PASS/FAIL 카운터):

```bash
#!/bin/bash
# version_manager.sh project_paths(모노레포 경로) 테스트 스위트
# 실행: bash .github/scripts/test/test_version_manager_paths.sh
set -u
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/version_manager.sh"
PASS=0
FAIL=0

# yq/jq 없는 환경(일부 로컬)은 스킵 — ubuntu-latest에는 기본 설치
command -v yq >/dev/null 2>&1 || { echo "SKIP: yq 필요"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "SKIP: jq 필요"; exit 0; }

chk() {
  local d="$1" a="$2" e="$3"
  if [ "$a" = "$e" ]; then
    echo "  PASS: $d"; PASS=$((PASS+1))
  else
    echo "  FAIL: $d (got: '$a', want: '$e')"; FAIL=$((FAIL+1))
  fi
}

new_workdir() {
  WORK=$(mktemp -d)
  cd "$WORK" || exit 1
}

echo "=== (1) legacy 회귀: project_paths 없음 + 루트 flutter ==="
new_workdir
cat > version.yml << 'EOF'
version: "0.0.2"
version_code: 5
project_type: "flutter"
EOF
printf 'name: demo\nversion: 0.0.1+1\n' > pubspec.yaml
bash "$SCRIPT" sync >/dev/null 2>&1
chk "루트 pubspec 동기화" "$(yq -r '.version' pubspec.yaml)" "0.0.2+5"

echo "=== (2) 모노레포: project_paths 있는 멀티타입 sync ==="
new_workdir
cat > version.yml << 'EOF'
version: "0.0.9"
version_code: 5
project_types: ["flutter", "react", "python"]
project_type: "flutter"
project_paths:
  flutter: "app"
  react: "client"
  python: "ai"
EOF
mkdir -p app client ai
printf 'name: demo\nversion: 0.0.1+1\n' > app/pubspec.yaml
printf '{"name":"demo","version":"0.0.1"}\n' > client/package.json
printf '[project]\nname = "demo"\nversion = "0.0.1"\n' > ai/pyproject.toml
bash "$SCRIPT" sync >/dev/null 2>&1
chk "app/pubspec.yaml" "$(yq -r '.version' app/pubspec.yaml)" "0.0.9+5"
chk "client/package.json" "$(jq -r '.version' client/package.json)" "0.0.9"
chk "ai/pyproject.toml" "$(grep -E '^version' ai/pyproject.toml | sed 's/.*"\(.*\)".*/\1/')" "0.0.9"

echo "=== (3) paths 없는 멀티타입: 서브폴더 미동기화(기존 no-op) + exit 0 ==="
new_workdir
cat > version.yml << 'EOF'
version: "0.0.9"
version_code: 5
project_types: ["flutter", "react"]
project_type: "flutter"
EOF
mkdir -p app client
printf 'name: demo\nversion: 0.0.1+1\n' > app/pubspec.yaml
printf '{"name":"demo","version":"0.0.1"}\n' > client/package.json
bash "$SCRIPT" sync >/dev/null 2>&1
chk "exit 0" "$?" "0"
chk "app/pubspec 그대로" "$(yq -r '.version' app/pubspec.yaml)" "0.0.1+1"
chk "client/package.json 그대로" "$(jq -r '.version' client/package.json)" "0.0.1"

echo "=== (4) 경로에 마커 없음: 경고 + skip + exit 0 ==="
new_workdir
cat > version.yml << 'EOF'
version: "0.0.9"
version_code: 5
project_types: ["flutter"]
project_type: "flutter"
project_paths:
  flutter: "nope"
EOF
OUT=$(bash "$SCRIPT" sync 2>&1)
chk "exit 0" "$?" "0"
echo "$OUT" | grep -q "없음" && chk "경고 출력" "1" "1" || chk "경고 출력" "0" "1"

echo "=== (5) increment: 경로 따라 patch 증가 ==="
new_workdir
cat > version.yml << 'EOF'
version: "0.0.9"
version_code: 5
project_types: ["flutter", "react"]
project_type: "flutter"
project_paths:
  flutter: "app"
  react: "client"
EOF
mkdir -p app client
printf 'name: demo\nversion: 0.0.9+5\n' > app/pubspec.yaml
printf '{"name":"demo","version":"0.0.9"}\n' > client/package.json
bash "$SCRIPT" increment >/dev/null 2>&1
chk "version.yml 증가" "$(yq -r '.version' version.yml)" "0.0.10"
chk "app/pubspec 증가" "$(yq -r '.version' app/pubspec.yaml | cut -d'+' -f1)" "0.0.10"
chk "client/package.json 증가" "$(jq -r '.version' client/package.json)" "0.0.10"

echo ""
echo "결과: PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

Run (Git Bash): `bash .github/scripts/test/test_version_manager_paths.sh`
Expected: 시나리오 (1), (3)은 PASS (기존 동작), 시나리오 **(2), (5)는 FAIL** (서브폴더 파일이 0.0.1 그대로), (4)는 "경고 출력" FAIL 가능. 최종 `FAIL>0`으로 exit 1.

- [ ] **Step 3: 커밋은 하지 않음** (Task 2에서 구현과 함께 커밋)

---

### Task 2: version_manager.sh 경로 지원 구현

**Files:**
- Modify: `.github/scripts/version_manager.sh:106` (parse_project_types 함수 뒤에 헬퍼 추가)
- Modify: `.github/scripts/version_manager.sh:154-184` (VERSION_FILE case 블록)
- Modify: `.github/scripts/version_manager.sh:497-558` (sync_for_type)
- Test: `.github/scripts/test/test_version_manager_paths.sh`

- [ ] **Step 1: `get_type_path` 헬퍼 추가**

`parse_project_types()` 함수 정의가 끝나는 `:106` 직후에 삽입:

```bash
# project_paths.<type> 반환 — 키 없으면 "." (legacy: 루트 기준)
# 모노레포에서 타입별 프로젝트가 서브폴더에 있을 때 integrator가 기록한 경로
get_type_path() {
    local t=$1
    local p
    p=$(yq -r ".project_paths.\"${t}\" // \".\"" version.yml 2>/dev/null) || p="."
    if [ -z "$p" ] || [ "$p" = "null" ]; then
        p="."
    fi
    echo "$p"
}
```

- [ ] **Step 2: `read_version_config`의 VERSION_FILE case 블록 교체**

기존 `:154-184`의 `# 5. VERSION_FILE — ...` case 블록 전체를 다음으로 교체 (경로 prefix 통합):

```bash
    # 5. VERSION_FILE — primary 타입(단수 키) 기준 + project_paths 경로 prefix
    #    (project_paths 키 없으면 _ppath="." → "./pubspec.yaml" — 기존 동작과 동일)
    local _ppath
    _ppath=$(get_type_path "$PROJECT_TYPE")
    case "$PROJECT_TYPE" in
        "spring")
            VERSION_FILE="$_ppath/build.gradle"
            ;;
        "flutter")
            VERSION_FILE="$_ppath/pubspec.yaml"
            ;;
        "react"|"next"|"node")
            VERSION_FILE="$_ppath/package.json"
            ;;
        "react-native")
            # iOS 우선, 없으면 Android
            local ios_plist
            ios_plist=$(find "$_ppath/ios" -name "Info.plist" -type f 2>/dev/null | head -1 || true)
            if [ -n "$ios_plist" ]; then
                VERSION_FILE="$ios_plist"
            else
                VERSION_FILE="$_ppath/android/app/build.gradle"
            fi
            ;;
        "react-native-expo")
            VERSION_FILE="$_ppath/app.json"
            ;;
        "python")
            VERSION_FILE="$_ppath/pyproject.toml"
            ;;
        "basic"|*)
            VERSION_FILE="version.yml"
            ;;
    esac
```

- [ ] **Step 3: `sync_for_type` 교체**

기존 `:497-558`의 `sync_for_type()` 함수 전체를 다음으로 교체:

```bash
sync_for_type() {
    local t=$1
    local new_version=$2
    local p
    p=$(get_type_path "$t")

    log_info "타입별 sync: $t → $new_version (경로: $p)"

    case "$t" in
        "spring")
            find "$p" -maxdepth 2 -name "build.gradle" -type f 2>/dev/null | while read -r gradle_file; do
                sed -i.bak "s/version = '[^']*'/version = '$new_version'/g; s/version = \"[^\"]*\"/version = \"$new_version\"/g" "$gradle_file"
                rm -f "${gradle_file}.bak"
                log_success "업데이트: $gradle_file"
            done
            ;;
        "flutter")
            if [ -f "$p/pubspec.yaml" ]; then
                local code
                code=$(get_version_code)
                yq -i ".version = \"$new_version+$code\"" "$p/pubspec.yaml"
                log_success "업데이트: $p/pubspec.yaml"
            else
                log_warning "flutter: $p/pubspec.yaml 없음 — 건너뜀"
            fi
            ;;
        "react"|"next"|"node")
            if [ -f "$p/package.json" ]; then
                jq ".version = \"$new_version\"" "$p/package.json" > tmp.json && mv tmp.json "$p/package.json"
                log_success "업데이트: $p/package.json"
            else
                log_warning "$t: $p/package.json 없음 — 건너뜀"
            fi
            ;;
        "python")
            if [ -f "$p/pyproject.toml" ]; then
                # TOML: sed 유지 (파서 없음)
                sed -i.bak "s/^version = \"[^\"]*\"/version = \"$new_version\"/" "$p/pyproject.toml"
                rm -f "$p/pyproject.toml.bak"
                log_success "업데이트: $p/pyproject.toml"
            else
                log_warning "python: $p/pyproject.toml 없음 — 건너뜀"
            fi
            ;;
        "react-native")
            find "$p/ios" -name "Info.plist" -type f 2>/dev/null | while read -r plist_file; do
                if grep -q "CFBundleShortVersionString" "$plist_file"; then
                    sed -i.bak '/CFBundleShortVersionString/{n;s/<string>[^<]*<\/string>/<string>'"$new_version"'<\/string>/;}' "$plist_file"
                    rm -f "${plist_file}.bak"
                    log_success "업데이트: $plist_file"
                fi
            done
            if [ -f "$p/android/app/build.gradle" ]; then
                sed -i.bak "s/versionName \"[^\"]*\"/versionName \"$new_version\"/" "$p/android/app/build.gradle"
                rm -f "$p/android/app/build.gradle.bak"
                log_success "업데이트: $p/android/app/build.gradle"
            fi
            ;;
        "react-native-expo")
            if [ -f "$p/app.json" ]; then
                jq ".expo.version = \"$new_version\"" "$p/app.json" > tmp.json && mv tmp.json "$p/app.json"
                log_success "업데이트: $p/app.json"
            else
                log_warning "react-native-expo: $p/app.json 없음 — 건너뜀"
            fi
            ;;
        "basic")
            : ;;
        *)
            log_warning "알 수 없는 타입: $t — 건너뜀"
            ;;
    esac
}
```

- [ ] **Step 4: 테스트 실행 — 전부 통과 확인**

Run: `bash .github/scripts/test/test_version_manager_paths.sh`
Expected: `결과: PASS=10 FAIL=0`, exit 0

- [ ] **Step 5: 기존 truncate 테스트 회귀 확인**

Run: `bash .github/scripts/test/test_truncate_release_notes.sh`
Expected: 전부 PASS (무관 파일이지만 테스트 인프라 공유 확인)

- [ ] **Step 6: 커밋**

```bash
git add .github/scripts/version_manager.sh .github/scripts/test/test_version_manager_paths.sh
git commit -m "version_manager.sh 멀티타입 모노레포 경로 동기화 지원 : feat : version.yml project_paths 맵을 읽어 타입별 버전 파일을 서브폴더에서 동기화 — get_type_path 헬퍼 추가, VERSION_FILE과 sync_for_type에 경로 prefix 적용, 경로에 파일 없으면 경고 후 skip, project_paths 키 없으면 기존 루트 동작 100% 유지"
```

(주의: 커밋 메시지에 이모지·태그 금지, AI 관여 trailer 일체 금지 — 프로젝트 컨벤션)

---

### Task 3: template_integrator.sh 경로 감지·확정 루틴

**Files:**
- Modify: `template_integrator.sh:744` 부근 (전역 변수 — `INCLUDE_SYNOLOGY` 선언 다음 줄)
- Modify: `template_integrator.sh:795-802` (인자 파싱 — `--no-synology` case 다음)
- Modify: `template_integrator.sh:941` 부근 (`detect_project_types` 함수 뒤에 헬퍼 4종 + resolve 추가)
- Modify: `template_integrator.sh:1358-1465` (`create_version_yml` — paths 블록 기록)
- Modify: `template_integrator.sh:2699` 부근 (`execute_integration`의 `case $MODE` 직전 — resolve 호출)

- [ ] **Step 1: 전역 변수 추가** (`INCLUDE_SYNOLOGY` 선언 바로 아래)

```bash
PROJECT_PATHS_CSV=""  # 타입별 경로 "flutter=app,react=client" — 빈 값이면 미확정 (bash 3.2 호환: 연관배열 금지)
```

- [ ] **Step 2: `--paths` 인자 파싱 추가** (`--no-synology` case 바로 다음)

```bash
        --paths)
            # "flutter=app,react=client" 형식 — 비대화형 경로 지정
            PROJECT_PATHS_CSV="$2"
            shift 2
            ;;
```

또한 `show_help`(`:666` 부근)의 옵션 목록에 한 줄 추가:

```bash
  --paths "T=P,..."        타입별 프로젝트 경로 (모노레포용, 예: --paths "flutter=app,react=client")
```

- [ ] **Step 3: 경로 헬퍼 4종 추가** (`detect_project_types` 함수 정의 끝 `:941` 직후)

```bash
# ===================================================================
# 타입별 프로젝트 경로 (project_paths) 감지·확정
# ===================================================================

# PROJECT_PATHS_CSV에서 타입의 경로 조회 (없으면 빈 문자열)
get_path_for_type() {
    local t=$1
    local pair
    local _ifs_bak="$IFS"
    IFS=','
    for pair in $PROJECT_PATHS_CSV; do
        IFS="$_ifs_bak"
        case "$pair" in
            "$t="*) echo "${pair#*=}"; return ;;
        esac
        IFS=','
    done
    IFS="$_ifs_bak"
    echo ""
}

# PROJECT_PATHS_CSV에 타입=경로 저장 (이미 있으면 교체)
set_path_for_type() {
    local t=$1
    local p=$2
    local out=""
    local pair
    local _ifs_bak="$IFS"
    IFS=','
    for pair in $PROJECT_PATHS_CSV; do
        IFS="$_ifs_bak"
        [ -z "$pair" ] && { IFS=','; continue; }
        case "$pair" in
            "$t="*) IFS=','; continue ;;
        esac
        out="${out:+$out,}$pair"
        IFS=','
    done
    IFS="$_ifs_bak"
    PROJECT_PATHS_CSV="${out:+$out,}$t=$p"
}

# 타입의 대표 마커 파일명 (감지·version.yml 주석용)
marker_for_type() {
    case "$1" in
        flutter) echo "pubspec.yaml" ;;
        react|next|node|react-native) echo "package.json" ;;
        react-native-expo) echo "app.json" ;;
        python) echo "pyproject.toml" ;;
        spring) echo "build.gradle" ;;
        *) echo "" ;;
    esac
}

# 타입별 마커 파일 후보 검색 — 후보 디렉토리 상대경로를 줄단위 출력 (루트는 ".")
# maxdepth 3 + 잡음 폴더 제외 + 타입별 오탐 필터 (스펙 §4.2~4.3)
find_type_path_candidates() {
    local t=$1
    local names=""
    case "$t" in
        flutter)            names="pubspec.yaml" ;;
        react|next|node)    names="package.json" ;;
        react-native)       names="package.json" ;;
        react-native-expo)  names="app.json" ;;
        python)             names="pyproject.toml setup.py requirements.txt" ;;
        spring)             names="build.gradle build.gradle.kts pom.xml" ;;
        *) return 0 ;;
    esac

    local n found=""
    for n in $names; do
        found=$(find . -maxdepth 3 \
            \( -name node_modules -o -name .git -o -name build -o -name dist \
               -o -name .dart_tool -o -name android -o -name ios -o -name .gradle \
               -o -name venv -o -name .venv -o -name __pycache__ \) -prune \
            -o -type f -name "$n" -print 2>/dev/null)
        [ -n "$found" ] && break  # 우선순위 높은 마커에서 발견되면 그것만 사용
    done
    [ -z "$found" ] && return 0

    local f d _libdir
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        d=$(dirname "$f")
        d="${d#./}"
        if [ "$d" = "." ] || [ -z "$d" ]; then d="."; fi
        case "$t" in
            flutter)
                # example/ 제외 + lib/ 동반 확인 (오탐 방지)
                case "$d" in *example*) continue ;; esac
                if [ "$d" = "." ]; then _libdir="lib"; else _libdir="$d/lib"; fi
                [ -d "$_libdir" ] || continue
                ;;
            spring)
                # Flutter/RN의 android/build.gradle 오탐 제외
                case "$d" in *android*) continue ;; esac
                ;;
        esac
        echo "$d"
    done <<< "$found" | sort -u
}
```

- [ ] **Step 4: `resolve_project_paths` 함수 추가** (Step 3 코드 바로 아래)

```bash
# 선택된 모든 타입의 경로를 감지·확인하여 PROJECT_PATHS_CSV 확정 (스펙 §4)
resolve_project_paths() {
    local _all_types=("${PROJECT_TYPES[@]:-$PROJECT_TYPE}")
    local _targets=()
    local _t
    for _t in "${_all_types[@]}"; do
        [ "$_t" = "basic" ] && continue
        _targets+=("$_t")
    done
    [ ${#_targets[@]} -eq 0 ] && return 0  # basic만이면 경로 불필요

    print_step "타입별 프로젝트 경로 확인 중..."
    print_to_user ""
    print_to_user "💡 경로 = 레포 루트에서 그 프로젝트 폴더까지의 상대경로입니다."
    print_to_user "   예) 레포루트/app/pubspec.yaml 이면 → \"app\""
    print_to_user "       레포루트/packages/web/package.json 이면 → \"packages/web\""
    print_to_user "       레포 루트에 바로 있으면 → \".\""
    print_to_user ""

    for _t in "${_targets[@]}"; do
        # 1) --paths로 이미 지정됨 → 최우선
        local _preset
        _preset=$(get_path_for_type "$_t")
        if [ -n "$_preset" ]; then
            print_info "  $_t → $_preset (--paths 지정)"
            continue
        fi

        local _marker
        _marker=$(marker_for_type "$_t")

        # 2) 루트에 마커 존재 → "." 자동 확정 (질문 없이 안내만)
        if [ -f "$_marker" ]; then
            set_path_for_type "$_t" "."
            print_info "  $_t → . (루트의 $_marker)"
            continue
        fi

        # 3) 기존 version.yml의 project_paths 값 → 기본 제안값
        local _existing=""
        if [ -f "version.yml" ]; then
            if command -v yq >/dev/null 2>&1; then
                _existing=$(yq -r ".project_paths.\"$_t\" // \"\"" version.yml 2>/dev/null || echo "")
                [ "$_existing" = "null" ] && _existing=""
            else
                _existing=$(sed -n '/^project_paths:/,/^[^ ]/p' version.yml | sed -n "s/^  $_t:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1)
            fi
        fi

        # 4) 후보 검색
        local _candidates _count=0
        _candidates=$(find_type_path_candidates "$_t")
        [ -n "$_candidates" ] && _count=$(echo "$_candidates" | grep -c .)

        local _chosen=""

        # ── 비대화형 (--force 또는 TTY 없음): 스펙 §4.5 ──
        if [ "$FORCE_MODE" = true ] || [ "$TTY_AVAILABLE" != true ]; then
            if [ -n "$_existing" ]; then
                _chosen="$_existing"
                print_info "  $_t → $_chosen (기존 project_paths 유지)"
            elif [ "$_count" -eq 1 ]; then
                _chosen="$_candidates"
                print_info "  $_t → $_chosen (자동 감지)"
            else
                _chosen="."
                print_warning "  $_t → 후보 ${_count}개로 자동 확정 불가, 루트(.)로 기록 (--paths \"$_t=경로\"로 지정 가능)"
            fi
            set_path_for_type "$_t" "$_chosen"
            continue
        fi

        # ── 대화형: 후보 개수별 분기 (스펙 §4.4) ──
        if [ "$_count" -eq 1 ]; then
            print_to_user ""
            print_to_user "  🔍 $_t: ${_candidates}/${_marker} 발견"
            if ask_yes_no "  $_t 경로를 '$_candidates'(으)로 설정할까요? (Y=예 / N=직접입력): " "Y"; then
                _chosen="$_candidates"
            fi
        elif [ "$_count" -gt 1 ]; then
            print_to_user ""
            print_to_user "  🔍 $_t: 후보 ${_count}개 발견"
            local _i=1 _c
            while IFS= read -r _c; do
                print_to_user "    $_i) $_c  ($_c/$_marker)"
                _i=$((_i+1))
            done <<< "$_candidates"
            print_to_user "    m) 직접 입력"
            local _sel=""
            while true; do
                safe_read "  선택: " _sel ""
                if [ "$_sel" = "m" ] || [ "$_sel" = "M" ]; then
                    break
                fi
                if [[ "$_sel" =~ ^[0-9]+$ ]] && [ "$_sel" -ge 1 ] && [ "$_sel" -lt "$_i" ]; then
                    _chosen=$(echo "$_candidates" | sed -n "${_sel}p")
                    break
                fi
                print_error "  잘못된 입력입니다. 1-$((_i-1)) 또는 m을 입력하세요."
            done
        else
            print_to_user ""
            print_warning "  $_t: 프로젝트를 찾지 못했습니다 (maxdepth 3)."
        fi

        # ── 직접 입력 (위에서 미확정 시) ──
        while [ -z "$_chosen" ]; do
            local _input="" _prompt
            _prompt="  $_t 상대경로 입력 (예: app, client/web — 루트면 그냥 Enter"
            if [ -n "$_existing" ]; then
                _prompt="$_prompt, 현재값: $_existing"
            fi
            _prompt="$_prompt): "
            safe_read "$_prompt" _input ""
            # 정규화: 공백 제거, 백슬래시→슬래시, 끝 슬래시·앞 ./ 제거
            _input=$(echo "$_input" | tr -d ' ' | sed 's#\\#/#g; s#/$##; s#^\./##')
            if [ -z "$_input" ]; then
                if [ -n "$_existing" ]; then _input="$_existing"; else _input="."; fi
            fi
            # 검증: 입력 경로에 마커 존재 확인 (python은 보조 마커도 인정)
            if [ -f "$_input/$_marker" ] \
               || { [ "$_t" = "python" ] && { [ -f "$_input/setup.py" ] || [ -f "$_input/requirements.txt" ]; }; }; then
                _chosen="$_input"
            else
                print_warning "  $_input/$_marker 파일이 없습니다."
                if ask_yes_no "  그래도 이 경로를 사용할까요? (Y/N): " "N"; then
                    _chosen="$_input"
                fi
            fi
        done

        set_path_for_type "$_t" "$_chosen"
        print_success "  $_t → $_chosen"
    done

    # ── 요약 출력 + 동일 파일 중복 안내 (스펙 §4.4) ──
    print_to_user ""
    print_to_user "📂 타입별 버전 파일 경로 확정:"
    local _pair _pt _pp _m _file _lines=""
    local _ifs_bak="$IFS"
    IFS=','
    for _pair in $PROJECT_PATHS_CSV; do
        IFS="$_ifs_bak"
        _pt="${_pair%%=*}"
        _pp="${_pair#*=}"
        _m=$(marker_for_type "$_pt")
        if [ "$_pp" = "." ]; then _file="$_m"; else _file="$_pp/$_m"; fi
        print_to_user "   $_pt → $_file"
        _lines="${_lines}${_file}|${_pt}"$'\n'
        IFS=','
    done
    IFS="$_ifs_bak"

    # 같은 파일을 둘 이상의 타입이 바라보면 경고 (멱등 동작이라 막지는 않음)
    local _dups
    _dups=$(printf '%s' "$_lines" | awk -F'|' '{cnt[$1]++; t[$1]=t[$1]" "$2} END{for (f in cnt) if (cnt[f]>1) print f":"t[f]}')
    if [ -n "$_dups" ]; then
        local _dl
        while IFS= read -r _dl; do
            [ -z "$_dl" ] && continue
            print_warning "  ⚠️ 같은 파일(${_dl%%:*})을 여러 타입(${_dl#*:} )이 바라봅니다."
            print_warning "     sync 시 같은 버전이 기록되므로 동작엔 문제없지만, 의도한 구성인지 확인하세요."
        done <<< "$_dups"
    fi
    print_to_user ""
}
```

참고: `safe_read`는 기존 `ask_yes_no()`(`:574-599`)가 쓰는 입력 헬퍼 — 세 번째 인자는 read 옵션(빈 문자열 = 한 줄 입력). 시그니처가 다르면 `ask_yes_no` 구현부에 맞춰 동일 패턴으로 호출할 것.

- [ ] **Step 5: `create_version_yml`에 project_paths 블록 기록**

`:1413` (`fi` — version.yml 존재 분기 끝) 다음, `cat > version.yml << EOF` 직전에 블록 생성 코드 삽입:

```bash
    # project_paths 블록 생성 (resolve_project_paths가 확정한 값 — 빈 값이면 블록 생략)
    local _paths_block=""
    if [ -n "$PROJECT_PATHS_CSV" ]; then
        _paths_block="project_paths:                # 타입별 프로젝트 폴더 (레포 루트 기준 상대경로)"$'\n'
        local _pair _pt _pp _pm _pf
        local _ifs_bak="$IFS"
        IFS=','
        for _pair in $PROJECT_PATHS_CSV; do
            IFS="$_ifs_bak"
            _pt="${_pair%%=*}"
            _pp="${_pair#*=}"
            _pm=$(marker_for_type "$_pt")
            if [ "$_pp" = "." ]; then _pf="$_pm"; else _pf="$_pp/$_pm"; fi
            _paths_block="${_paths_block}  ${_pt}: \"${_pp}\"   # ${_pf}"$'\n'
            IFS=','
        done
        IFS="$_ifs_bak"
    fi
```

그리고 기존 단일 heredoc(`:1415-1462`)을 3단 구성으로 변경 — `project_type:` 라인까지 첫 heredoc, paths 블록 append, metadata 둘째 heredoc:

```bash
    cat > version.yml << EOF
# ===================================================================
# 프로젝트 버전 관리 파일
# ===================================================================
#
# (기존 주석 동일 유지 — 아래 한 줄만 '사용법' 항목에 추가)
# 4. project_paths: 타입별 프로젝트 폴더 (레포 루트 기준 상대경로, 모노레포용)
# (… 기존 주석 나머지 동일 …)
# ===================================================================

version: "$version"
version_code: $existing_version_code  # app build number
project_types: $_types_json   # 멀티타입 배열 — 첫 항목이 primary, 직접 편집 가능
project_type: "$_primary_type"  # project_types[0] 자동 미러 — 직접 수정 금지 (spring, flutter, next, react, react-native, react-native-expo, node, python, basic)
EOF

    if [ -n "$_paths_block" ]; then
        printf '%s' "$_paths_block" >> version.yml
    fi

    cat >> version.yml << EOF
metadata:
  last_updated: "$(date -u +"%Y-%m-%d %H:%M:%S")"
  last_updated_by: "template_integrator"
  default_branch: "$branch"
  integrated_from: "SUH-DEVOPS-TEMPLATE"
  integration_date: "$(date -u +"%Y-%m-%d")"
EOF
```

(주의: "(기존 주석 동일 유지)"는 실제 작업 시 기존 `:1416-1450`의 주석 원문을 그대로 두고 `# 3. project_type...` 다음에 `# 4. project_paths...` 한 줄만 추가하라는 뜻 — 주석을 지우지 말 것.)

- [ ] **Step 6: `execute_integration`에 resolve 호출 추가**

`:2699` `# 2. 모드별 통합` 주석과 `case $MODE in` 사이에 삽입:

```bash
    # 타입별 경로 확정 — version.yml에 project_paths 기록 (full/version 모드만)
    if [ "$MODE" = "full" ] || [ "$MODE" = "version" ]; then
        resolve_project_paths
    fi
```

- [ ] **Step 7: 문법 검증**

Run: `bash -n template_integrator.sh`
Expected: 출력 없음 (문법 오류 없음)

- [ ] **Step 8: 비대화형 자동 감지 검증 (픽스처)**

Run (Git Bash, 네트워크 필요 — 템플릿 다운로드):

```bash
FIX=$(mktemp -d) && cd "$FIX" && git init -q
mkdir -p app/lib client ai
printf 'name: demo\nversion: 0.0.1+1\n' > app/pubspec.yaml
printf '{"name":"demo","version":"0.0.1","dependencies":{"react":"^18"}}\n' > client/package.json
printf '[project]\nname = "demo"\nversion = "0.0.1"\n' > ai/pyproject.toml
bash /d/0-suh/project/suh-github-template/template_integrator.sh \
  --mode version --force --type flutter,react,python
sed -n '/^project_paths:/,/^metadata:/p' version.yml
```

Expected 출력 (순서 무관):

```
project_paths:                # 타입별 프로젝트 폴더 (레포 루트 기준 상대경로)
  flutter: "app"   # app/pubspec.yaml
  react: "client"   # client/package.json
  python: "ai"   # ai/pyproject.toml
metadata:
```

추가 확인: 같은 픽스처에서 `--paths "flutter=app,react=client,python=ai"`를 줘도 동일 결과.

- [ ] **Step 9: 커밋**

```bash
git add template_integrator.sh
git commit -m "template_integrator.sh 타입별 프로젝트 경로 감지·확정 추가 : feat : 멀티타입 모노레포에서 마커 파일을 maxdepth 3으로 검색해 후보 0/1/N 분기로 확인·선택·수동입력 받고 version.yml project_paths에 기록 — 루트 마커는 자동 확정, --paths 옵션으로 비대화형 지정, 동일 파일 중복 시 경고 안내"
```

---

### Task 4: template_integrator.ps1 동일 기능 (PS 5.1)

**Files:**
- Modify: `template_integrator.ps1:59-83` (param 블록 — `$NoSynology` 다음)
- Modify: `template_integrator.ps1:108` 부근 (상수 영역 — `-Paths` 파싱 + 전역)
- Modify: `template_integrator.ps1:639` 부근 (`Detect-ProjectTypes` 함수 뒤 — 헬퍼 + Resolve 함수)
- Modify: `template_integrator.ps1:1070-1182` (`Create-VersionYml`)
- Modify: `template_integrator.ps1:2458` 부근 (`switch ($Mode)` 직전 — Resolve 호출)
- Modify: `template_integrator.ps1:508` 부근 (도움말에 `-Paths` 설명 추가)

**금지 문법 주의 (PS 5.1):** `&&`/`||` 파이프 체인, 삼항 `?:`, `??`, `?.` 전부 사용 금지.

- [ ] **Step 1: param 추가** (`[switch]$NoSynology,` 다음)

```powershell
    [Parameter(Mandatory=$false)]
    [string]$Paths = "",
```

- [ ] **Step 2: 전역 초기화 + `-Paths` 파싱** (상수 정의 영역, `$VERSION_FILE = "version.yml"` 다음)

```powershell
# 타입별 프로젝트 경로 (project_paths) — resolve 또는 -Paths로 채워짐
$script:ProjectPaths = [ordered]@{}
if (-not [string]::IsNullOrWhiteSpace($Paths)) {
    foreach ($pair in $Paths.Split(',')) {
        $kv = $pair.Trim().Split('=', 2)
        if ($kv.Count -eq 2 -and $kv[0].Trim() -and $kv[1].Trim()) {
            $script:ProjectPaths[$kv[0].Trim()] = $kv[1].Trim().Replace('\','/').TrimEnd('/')
        }
    }
}
```

- [ ] **Step 3: 헬퍼 + Resolve 함수 추가** (`Detect-ProjectTypes` 함수 정의 끝 다음)

```powershell
# ===================================================================
# 타입별 프로젝트 경로 (project_paths) 감지·확정
# ===================================================================

# 검색 제외 폴더 (스펙 §4.3)
$script:PathExcludeRegex = '\\(node_modules|\.git|build|dist|\.dart_tool|android|ios|\.gradle|venv|\.venv|__pycache__)(\\|$)'

function Get-MarkerForType {
    param([string]$ProjType)
    switch ($ProjType) {
        "flutter" { return "pubspec.yaml" }
        { $_ -in @("react","next","node","react-native") } { return "package.json" }
        "react-native-expo" { return "app.json" }
        "python" { return "pyproject.toml" }
        "spring" { return "build.gradle" }
        default { return "" }
    }
}

# 타입별 마커 파일 후보 검색 — 후보 디렉토리 상대경로 배열 반환 (루트는 ".")
function Find-TypePathCandidates {
    param([string]$ProjType)

    $markerNames = @()
    switch ($ProjType) {
        "flutter"           { $markerNames = @("pubspec.yaml") }
        { $_ -in @("react","next","node","react-native") } { $markerNames = @("package.json") }
        "react-native-expo" { $markerNames = @("app.json") }
        "python"            { $markerNames = @("pyproject.toml","setup.py","requirements.txt") }
        "spring"            { $markerNames = @("build.gradle","build.gradle.kts","pom.xml") }
        default             { return @() }
    }

    $root = (Get-Location).Path
    foreach ($name in $markerNames) {
        # -Depth 2 = 루트 포함 3단계 (bash find -maxdepth 3 대응)
        $files = @(Get-ChildItem -Path . -Recurse -Depth 2 -Filter $name -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch $script:PathExcludeRegex })
        if ($files.Count -eq 0) { continue }

        $dirs = @()
        foreach ($f in $files) {
            $dir = Split-Path -Parent $f.FullName
            $rel = $dir.Substring($root.Length).TrimStart('\')
            if ([string]::IsNullOrEmpty($rel)) { $rel = "." } else { $rel = $rel.Replace('\','/') }

            if ($ProjType -eq "flutter") {
                # example/ 제외 + lib/ 동반 확인 (오탐 방지)
                if ($rel -match 'example') { continue }
                if ($rel -eq ".") { $libDir = "lib" } else { $libDir = "$rel/lib" }
                if (-not (Test-Path $libDir -PathType Container)) { continue }
            }
            if ($ProjType -eq "spring" -and $rel -match 'android') { continue }

            if ($dirs -notcontains $rel) { $dirs += $rel }
        }
        if ($dirs.Count -gt 0) { return $dirs }
    }
    return @()
}

# 선택된 모든 타입의 경로를 감지·확인하여 $script:ProjectPaths 확정 (스펙 §4)
function Resolve-ProjectPaths {
    $allTypes = if ($script:ProjectTypes.Count -gt 0) { $script:ProjectTypes } else { @($script:ProjectType) }
    $targets = @($allTypes | Where-Object { $_ -ne "basic" })
    if ($targets.Count -eq 0) { return }  # basic만이면 경로 불필요

    Print-Step "타입별 프로젝트 경로 확인 중..."
    Write-Host ""
    Write-Host "💡 경로 = 레포 루트에서 그 프로젝트 폴더까지의 상대경로입니다."
    Write-Host "   예) 레포루트/app/pubspec.yaml 이면 → `"app`""
    Write-Host "       레포루트/packages/web/package.json 이면 → `"packages/web`""
    Write-Host "       레포 루트에 바로 있으면 → `".`""
    Write-Host ""

    foreach ($t in $targets) {
        # 1) -Paths로 이미 지정됨 → 최우선
        if ($script:ProjectPaths.Contains($t)) {
            Print-Info "  $t → $($script:ProjectPaths[$t]) (-Paths 지정)"
            continue
        }

        $marker = Get-MarkerForType $t

        # 2) 루트에 마커 존재 → "." 자동 확정
        if (Test-Path $marker -PathType Leaf) {
            $script:ProjectPaths[$t] = "."
            Print-Info "  $t → . (루트의 $marker)"
            continue
        }

        # 3) 기존 version.yml의 project_paths 값 → 기본 제안값
        $existing = ""
        if (Test-Path "version.yml") {
            $inPaths = $false
            foreach ($line in (Get-Content "version.yml")) {
                if ($line -match '^project_paths:') { $inPaths = $true; continue }
                if ($inPaths) {
                    if ($line -match "^\s{2}$([regex]::Escape($t)):\s*`"([^`"]*)`"") {
                        $existing = $matches[1]
                        break
                    }
                    if ($line -match '^[^\s]') { break }  # 다른 최상위 키 → 섹션 종료
                }
            }
        }

        # 4) 후보 검색
        $candidates = @(Find-TypePathCandidates $t)
        $chosen = ""

        # ── 비대화형 (-Force): 스펙 §4.5 ──
        if ($Force) {
            if ($existing) {
                $chosen = $existing
                Print-Info "  $t → $chosen (기존 project_paths 유지)"
            } elseif ($candidates.Count -eq 1) {
                $chosen = $candidates[0]
                Print-Info "  $t → $chosen (자동 감지)"
            } else {
                $chosen = "."
                Print-Warning "  $t → 후보 $($candidates.Count)개로 자동 확정 불가, 루트(.)로 기록 (-Paths `"$t=경로`"로 지정 가능)"
            }
            $script:ProjectPaths[$t] = $chosen
            continue
        }

        # ── 대화형: 후보 개수별 분기 (스펙 §4.4) ──
        if ($candidates.Count -eq 1) {
            Write-Host ""
            Write-Host "  🔍 ${t}: $($candidates[0])/$marker 발견"
            if (Ask-YesNo "  $t 경로를 '$($candidates[0])'(으)로 설정할까요? (Y=예 / N=직접입력)" "Y") {
                $chosen = $candidates[0]
            }
        } elseif ($candidates.Count -gt 1) {
            Write-Host ""
            Write-Host "  🔍 ${t}: 후보 $($candidates.Count)개 발견"
            for ($i = 0; $i -lt $candidates.Count; $i++) {
                Write-Host "    $($i+1)) $($candidates[$i])  ($($candidates[$i])/$marker)"
            }
            Write-Host "    m) 직접 입력"
            while ($true) {
                $sel = Read-UserInput "  선택"
                if ($sel -eq "m" -or $sel -eq "M") { break }
                $selNum = 0
                if ([int]::TryParse($sel, [ref]$selNum) -and $selNum -ge 1 -and $selNum -le $candidates.Count) {
                    $chosen = $candidates[$selNum - 1]
                    break
                }
                Print-Error "  잘못된 입력입니다. 1-$($candidates.Count) 또는 m을 입력하세요."
            }
        } else {
            Write-Host ""
            Print-Warning "  ${t}: 프로젝트를 찾지 못했습니다 (depth 3)."
        }

        # ── 직접 입력 (위에서 미확정 시) ──
        while ([string]::IsNullOrEmpty($chosen)) {
            $promptText = "  $t 상대경로 입력 (예: app, client/web — 루트면 그냥 Enter"
            if ($existing) { $promptText = "$promptText, 현재값: $existing" }
            $promptText = "$promptText)"
            $userInput = Read-UserInput $promptText
            if ($null -eq $userInput) { $userInput = "" }
            $userInput = $userInput.Trim().Replace('\','/').TrimEnd('/') -replace '^\./', ''
            if ([string]::IsNullOrEmpty($userInput)) {
                if ($existing) { $userInput = $existing } else { $userInput = "." }
            }
            # 검증: 입력 경로에 마커 존재 확인 (python은 보조 마커도 인정)
            $markerOk = Test-Path "$userInput/$marker" -PathType Leaf
            if (-not $markerOk -and $t -eq "python") {
                if ((Test-Path "$userInput/setup.py") -or (Test-Path "$userInput/requirements.txt")) { $markerOk = $true }
            }
            if ($markerOk) {
                $chosen = $userInput
            } else {
                Print-Warning "  $userInput/$marker 파일이 없습니다."
                if (Ask-YesNo "  그래도 이 경로를 사용할까요? (Y/N)" "N") { $chosen = $userInput }
            }
        }

        $script:ProjectPaths[$t] = $chosen
        Print-Success "  $t → $chosen"
    }

    # ── 요약 + 동일 파일 중복 안내 (스펙 §4.4) ──
    Write-Host ""
    Write-Host "📂 타입별 버전 파일 경로 확정:"
    $fileToTypes = @{}
    foreach ($key in $script:ProjectPaths.Keys) {
        $p = $script:ProjectPaths[$key]
        $m = Get-MarkerForType $key
        if ($p -eq ".") { $file = $m } else { $file = "$p/$m" }
        Write-Host "   $key → $file"
        if (-not $fileToTypes.ContainsKey($file)) { $fileToTypes[$file] = @() }
        $fileToTypes[$file] += $key
    }
    foreach ($file in $fileToTypes.Keys) {
        if ($fileToTypes[$file].Count -gt 1) {
            Print-Warning "  ⚠️ 같은 파일($file)을 여러 타입($($fileToTypes[$file] -join ', '))이 바라봅니다."
            Print-Warning "     sync 시 같은 버전이 기록되므로 동작엔 문제없지만, 의도한 구성인지 확인하세요."
        }
    }
    Write-Host ""
}
```

- [ ] **Step 4: `Create-VersionYml`에 paths 블록 기록**

`:1117` (`$currentDate = ...`) 직전에 블록 생성 추가:

```powershell
    # project_paths 블록 (Resolve-ProjectPaths가 확정한 값 — 비어있으면 생략)
    $pathsBlock = ""
    if ($script:ProjectPaths.Count -gt 0) {
        $sb = New-Object System.Text.StringBuilder
        [void]$sb.AppendLine('project_paths:                # 타입별 프로젝트 폴더 (레포 루트 기준 상대경로)')
        foreach ($key in $script:ProjectPaths.Keys) {
            $p = $script:ProjectPaths[$key]
            $m = Get-MarkerForType $key
            if ($p -eq ".") { $file = $m } else { $file = "$p/$m" }
            [void]$sb.AppendLine("  ${key}: `"$p`"   # $file")
        }
        $pathsBlock = $sb.ToString()
    }
```

기존 단일 here-string(`:1130-1177`)을 둘로 분리 — `project_type:` 라인까지 `$part1`, metadata부터 `$part2`로 하고 합성:

```powershell
    $part1 = @"
# ===================================================================
# (기존 주석 동일 유지 — '사용법' 항목에 아래 한 줄 추가)
# 4. project_paths: 타입별 프로젝트 폴더 (레포 루트 기준 상대경로, 모노레포용)
# (… 기존 주석 나머지 동일 …)
# ===================================================================

version: "$Version"
version_code: $existingVersionCode  # app build number
project_types: $typesJson   # 멀티타입 배열 — 첫 항목이 primary, 직접 편집 가능
project_type: "$primaryType"  # project_types[0] 자동 미러 — 직접 수정 금지 (spring, flutter, next, react, react-native, react-native-expo, node, python, basic)

"@

    $part2 = @"
metadata:
  last_updated: "$currentDate"
  last_updated_by: "template_integrator"
  default_branch: "$Branch"
  integrated_from: "SUH-DEVOPS-TEMPLATE"
  integration_date: "$integrationDate"
"@

    $versionYmlContent = $part1.TrimEnd("`r","`n") + "`r`n" + $pathsBlock + $part2
    Set-Content -Path "version.yml" -Value $versionYmlContent -Encoding UTF8
```

(주의 1: 기존 here-string의 주석 원문을 그대로 보존하고 `# 3. project_type...` 다음에 `# 4.` 한 줄만 추가.
주의 2: here-string 닫는 `"@`는 반드시 컬럼 0.)

- [ ] **Step 5: `switch ($Mode)` 직전에 Resolve 호출 추가** (`:2458` `# 2. 모드별 통합` 주석 다음)

```powershell
    # 타입별 경로 확정 — version.yml에 project_paths 기록 (full/version 모드만)
    if ($Mode -eq "full" -or $Mode -eq "version") {
        Resolve-ProjectPaths
    }
```

- [ ] **Step 6: 도움말에 `-Paths` 추가** (`:508` `-Synology` 설명 부근)

```powershell
  -Paths "T=P,..."      타입별 프로젝트 경로 (모노레포용, 예: -Paths "flutter=app,react=client")
```

- [ ] **Step 7: 파서 검증**

Run (PowerShell):

```powershell
$errs = $null
[void][System.Management.Automation.Language.Parser]::ParseFile("D:\0-suh\project\suh-github-template\template_integrator.ps1", [ref]$null, [ref]$errs)
$errs
```

Expected: `$errs` 비어 있음 (파스 에러 0)

- [ ] **Step 8: 비대화형 자동 감지 검증 (픽스처)**

Run (PowerShell, 네트워크 필요):

```powershell
$FIX = Join-Path $env:TEMP ("ppfix_" + (Get-Random))
New-Item -ItemType Directory -Force "$FIX\app\lib","$FIX\client","$FIX\ai" | Out-Null
Set-Location $FIX; git init -q
Set-Content "app\pubspec.yaml" "name: demo`nversion: 0.0.1+1" -Encoding utf8
Set-Content "client\package.json" '{"name":"demo","version":"0.0.1","dependencies":{"react":"^18"}}' -Encoding utf8
Set-Content "ai\pyproject.toml" "[project]`nname = `"demo`"`nversion = `"0.0.1`"" -Encoding utf8
& "D:\0-suh\project\suh-github-template\template_integrator.ps1" -Mode version -Force -Type "flutter,react,python"
Select-String -Path version.yml -Pattern "project_paths" -Context 0,4
```

Expected: `project_paths:` 블록에 `flutter: "app"`, `react: "client"`, `python: "ai"` 세 줄.

- [ ] **Step 9: 커밋**

```bash
git add template_integrator.ps1
git commit -m "template_integrator.ps1 타입별 프로젝트 경로 감지·확정 추가 : feat : sh와 동일한 project_paths 감지·확인·수동입력 루틴을 PowerShell 5.1 호환으로 구현 — 루트 마커 자동 확정, -Paths 옵션 비대화형 지정, 동일 파일 중복 경고, version.yml에 마커 파일 주석과 함께 기록"
```

---

### Task 5: 문서화

**Files:**
- Modify: `CLAUDE.md` (멀티타입 blockquote 부근)
- 커밋 포함: `docs/superpowers/specs/2026-06-11-monorepo-project-paths-design.md`, `docs/superpowers/plans/2026-06-11-monorepo-project-paths.md`

- [ ] **Step 1: CLAUDE.md 멀티타입 안내에 한 줄 추가**

기존:

```markdown
> **멀티타입**: 단일 레포에 여러 타입 공존 시 `--type spring,react,python` csv로 지정. `version.yml`의 `project_types` 배열에 저장되며, 단수 `project_type` 키는 배열 첫 항목으로 자동 미러된다.
```

아래로 교체 (한 줄 추가):

```markdown
> **멀티타입**: 단일 레포에 여러 타입 공존 시 `--type spring,react,python` csv로 지정. `version.yml`의 `project_types` 배열에 저장되며, 단수 `project_type` 키는 배열 첫 항목으로 자동 미러된다.
>
> **모노레포 경로**: 타입별 프로젝트가 서브폴더에 있으면 `version.yml`의 `project_paths` 맵(타입 → 레포 루트 기준 상대경로)으로 지정한다. integrator가 통합 시 자동 감지·확인하며, 키가 없으면 루트 기준(기존 동작). 비대화형은 `--paths "flutter=app,react=client"`(.ps1은 `-Paths`). `version_manager.sh`가 이 경로를 따라 서브폴더 버전 파일을 동기화한다.
```

- [ ] **Step 2: 커밋**

```bash
git add CLAUDE.md docs/superpowers/specs/2026-06-11-monorepo-project-paths-design.md docs/superpowers/plans/2026-06-11-monorepo-project-paths.md
git commit -m "멀티타입 모노레포 project_paths 스키마 문서화 : docs : CLAUDE.md에 project_paths 맵 사용법 추가, 설계 스펙·구현 계획 문서 등록"
```

---

### Task 6: passQL 실전 리허설 (수동 검증)

**Files:** 없음 (passQL 레포 — `d:\0-suh\project\passQL` — 에서 수동 실행)

- [ ] **Step 1: passQL 작업트리 클린 확인**

Run: `git -C d:/0-suh/project/passQL status --short`
Expected: 깨끗하거나, 변경분이 커밋/스태시된 상태 (integrator 결과를 diff로 보기 위함)

- [ ] **Step 2: 최신 템플릿으로 integrator 실행** (main에 머지·푸시된 뒤)

passQL에서 사용자가 실행:

```powershell
$wc=New-Object Net.WebClient;$wc.Encoding=[Text.Encoding]::UTF8;iex $wc.DownloadString("https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.ps1")
```

진행 중 확인 포인트:
1. 타입 선택: `flutter,react,python` (+spring은 사용자 판단)
2. version.yml 덮어쓰기 질문 → **Y** (project_paths가 기록되려면 필수)
3. 경로 확인 프롬프트: `flutter → app`, `react → client`, `python → ai` 자동 감지 → Y
4. 기존 커스텀 워크플로우(`PROJECT-PYTHON-AI-*`, `*-PASSQL-*`, `VERCEL`, `REACT-BUILD-CHECK`)는 이름 충돌이 없어 건드리지 않음 — `git status`로 확인

- [ ] **Step 3: 결과 검증**

```powershell
Get-Content d:\0-suh\project\passQL\version.yml | Select-String -Pattern "project_types|project_paths" -Context 0,4
```

Expected: `project_types: ["flutter","react","python"]`(또는 spring 포함) + `project_paths` 블록에 app/client/ai.

- [ ] **Step 4: sync 동작 검증 (로컬, Git Bash + yq/jq 있을 때)**

```bash
cd /d/0-suh/project/passQL
bash .github/scripts/version_manager.sh sync
```

Expected: `app/pubspec.yaml`, `client/package.json`, `ai/pyproject.toml`이 version.yml 버전으로 정렬됨 (또는 이미 동일하면 "이미 동기화" 로그). 이후 main push 시 `PROJECT-COMMON-VERSION-CONTROL` 워크플로우가 같은 스크립트로 자동 동기화.

- [ ] **Step 5: 신규 추가된 타입별 CI 워크플로우 정리 (passQL 정책)**

자동 추가된 `PROJECT-FLUTTER-*`, `PROJECT-REACT-CI/CICD`, `PROJECT-PYTHON-CI` 중 기존 커스텀 CI/CD와 중복되는 것은 **사용자 판단으로** 삭제/유지 결정 (이 계획의 비범위 — 통합 당시 안내만).

---

## Self-Review 결과

- **스펙 커버리지**: §3 스키마(Task 3-5/4-4), §4 감지·확인·비대화형·path 설명·동일파일 경고(Task 3-3~4 / 4-3), §5 version_manager 3지점+경고 skip(Task 2), §6 워크플로우 무수정(작업 없음 확인), §7 테스트 4종+증분(Task 1)+passQL 리허설(Task 6), §8 문서화(Task 5) — 전부 매핑됨.
- **플레이스홀더**: 코드 블록 전부 실제 코드. "(기존 주석 동일 유지)"는 원문 보존 지시로 명시.
- **타입 일관성**: `get_type_path`/`marker_for_type`/`find_type_path_candidates`/`resolve_project_paths`/`PROJECT_PATHS_CSV`(.sh), `Get-MarkerForType`/`Find-TypePathCandidates`/`Resolve-ProjectPaths`/`$script:ProjectPaths`(.ps1) — 호출부와 정의 일치 확인.
- **호환성 가드**: bash 3.2(연관배열 미사용, csv 문자열), PS 5.1(`&&`·삼항 미사용), `update_project_file_version` 무수정, `project_paths` 부재 시 `"."` 폴백.
