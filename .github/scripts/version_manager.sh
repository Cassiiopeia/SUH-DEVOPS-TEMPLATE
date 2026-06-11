#!/bin/bash

# ===================================================================
# 범용 버전 관리 스크립트 v3.0
# ===================================================================
#
# 이 스크립트는 다양한 프로젝트 타입에서 버전 정보를 추출하고 업데이트합니다.
# version.yml 파일의 설정에 따라 적절한 파일에서 버전을 읽고 업데이트합니다.
#
# v3.0 변경사항:
# - YAML 파일은 yq로 정확하게 파싱 (주석 보존)
# - JSON 파일은 jq로 정확하게 파싱
# - Groovy/XML/TOML은 sed 유지
#
# 사용법:
# ./version_manager.sh [command] [options]
#
# Commands:
# - get: 현재 버전 가져오기 (동기화 포함)
# - increment: patch 버전 증가 (x.x.x -> x.x.x+1)
# - set: 특정 버전으로 설정
# - validate: 버전 형식 검증
# - sync: 버전 파일 간 동기화
#
# 필수 도구:
# - yq: YAML 파싱
# - jq: JSON 파싱
#
# ===================================================================

set -euo pipefail

# 전역 변수 초기화
PROJECT_TYPE=""
PROJECT_TYPES_CSV=""   # 멀티타입 — project_types 배열을 csv로 보관 (빈 문자열이면 legacy 단수)
VERSION_FILE=""
CURRENT_VERSION=""

# 로깅 함수들
log_info() {
    echo "ℹ️  $1" >&2
}

log_success() {
    echo "✅ $1" >&2
}

log_error() {
    echo "❌ $1" >&2
}

log_warning() {
    echo "⚠️  $1" >&2
}

log_debug() {
    if [ "${DEBUG:-}" = "true" ]; then
        echo "🔍 DEBUG: $1" >&2
    fi
}

# ===================================================================
# 필수 도구 확인
# ===================================================================
check_required_tools() {
    local project_type=$1
    local missing_tools=()

    # yq는 모든 프로젝트에 필요 (version.yml 처리)
    if ! command -v yq >/dev/null 2>&1; then
        missing_tools+=("yq")
    fi

    # JSON 프로젝트는 jq 필요
    case "$project_type" in
        "react"|"next"|"node"|"react-native-expo")
            if ! command -v jq >/dev/null 2>&1; then
                missing_tools+=("jq")
            fi
            ;;
    esac

    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_error "필수 도구가 설치되어 있지 않습니다: ${missing_tools[*]}"
        log_error "GitHub Actions ubuntu-latest에는 기본 설치되어 있습니다."
        log_error "로컬 설치:"
        log_error "  yq: https://github.com/mikefarah/yq#install"
        log_error "  jq: https://jqlang.github.io/jq/download/"
        exit 1
    fi

    log_debug "필수 도구 확인 완료: yq, jq"
}

# ===================================================================
# version.yml에서 설정 읽기 (yq 사용)
# ===================================================================
# version.yml의 project_types 배열을 csv로 반환 (키 없으면 빈 문자열 — legacy)
parse_project_types() {
    if [ ! -f "version.yml" ]; then
        echo ""
        return
    fi
    # project_types 배열 → "spring,react" 형태 csv. 키 없으면 빈 문자열
    yq -r '.project_types // [] | join(",")' version.yml 2>/dev/null || echo ""
}

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

# project_type 단수 키를 project_types[0]으로 강제 동기화 (사용자 수동 편집 실수 자동 복구)
sync_project_type_field() {
    local types_csv=$1
    [ -z "$types_csv" ] && return 0

    local first
    first=$(echo "$types_csv" | cut -d',' -f1)

    local current_single
    current_single=$(yq -r '.project_type // ""' version.yml)

    if [ "$current_single" != "$first" ]; then
        log_info "project_type 정합화: '$current_single' → '$first' (project_types[0])"
        yq -i ".project_type = \"$first\"" version.yml
    fi
}

read_version_config() {
    if [ ! -f "version.yml" ]; then
        log_error "version.yml 파일을 찾을 수 없습니다!"
        exit 1
    fi

    log_debug "version.yml 파싱 시작 (yq 사용)"

    # 1. project_types 배열 파싱 (멀티타입)
    PROJECT_TYPES_CSV=$(parse_project_types)

    # 2. 정합화 — 배열 있으면 project_type 단수 키를 첫 항목으로 강제
    if [ -n "$PROJECT_TYPES_CSV" ]; then
        sync_project_type_field "$PROJECT_TYPES_CSV"
    fi

    # 3. 단수 키 + 현재 버전 읽기 (정합화 이후)
    PROJECT_TYPE=$(yq -r '.project_type // "basic"' version.yml)
    CURRENT_VERSION=$(yq -r '.version // "0.0.0"' version.yml)

    # 4. 필수 도구 확인 — 배열이면 모든 타입 검사, 아니면 단수
    if [ -n "$PROJECT_TYPES_CSV" ]; then
        local _t
        IFS=',' read -ra _types <<< "$PROJECT_TYPES_CSV"
        for _t in "${_types[@]}"; do check_required_tools "$_t"; done
    else
        check_required_tools "$PROJECT_TYPE"
    fi

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

    log_info "프로젝트 설정"
    if [ -n "$PROJECT_TYPES_CSV" ]; then
        log_info "  타입(배열): $PROJECT_TYPES_CSV"
    fi
    log_info "  타입(primary): $PROJECT_TYPE"
    log_info "  버전 파일(primary): $VERSION_FILE"
    log_info "  현재 버전: $CURRENT_VERSION"
}

# ===================================================================
# 버전 형식 검증
# ===================================================================
validate_version() {
    local version=$1
    if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        log_error "잘못된 버전 형식: '$version' (x.y.z 형식이어야 함)"
        return 1
    fi
}

# ===================================================================
# version_code 가져오기
# ===================================================================
get_version_code() {
    if [ ! -f "version.yml" ]; then
        log_warning "version.yml 파일이 없습니다. 기본값 1 반환"
        echo "1"
        return
    fi

    local code
    code=$(yq -r '.version_code // ""' version.yml)

    if [ -z "$code" ] || [ "$code" = "null" ]; then
        log_warning "version_code 필드가 없습니다. 자동으로 추가합니다 (초기값: 1)"

        # yq로 version_code 필드 추가 (version 바로 다음에)
        yq -i '.version_code = 1 | .version_code line_comment = "app build number"' version.yml

        log_success "version_code 필드 추가 완료: 1"
        echo "1"
    else
        log_debug "현재 version_code: $code"
        echo "$code"
    fi
}

# ===================================================================
# version_code 증가
# ===================================================================
increment_version_code() {
    local current_code
    current_code=$(get_version_code)
    local new_code=$((current_code + 1))

    log_info "VERSION_CODE 증가: $current_code → $new_code"

    # yq로 version_code 업데이트
    yq -i ".version_code = $new_code | .version_code line_comment = \"app build number\"" version.yml

    log_success "VERSION_CODE 업데이트 완료: $new_code"
    echo "$new_code"
}

# ===================================================================
# patch 버전 증가
# ===================================================================
increment_patch_version() {
    local version=$1
    if ! validate_version "$version"; then
        return 1
    fi

    local major minor patch
    major=$(echo "$version" | cut -d. -f1)
    minor=$(echo "$version" | cut -d. -f2)
    patch=$(echo "$version" | cut -d. -f3)

    patch=$((patch + 1))
    echo "${major}.${minor}.${patch}"
}

# ===================================================================
# 버전 비교 함수
# ===================================================================
compare_versions() {
    local v1=$1
    local v2=$2

    log_debug "버전 비교: '$v1' vs '$v2'"

    # 버전을 배열로 분리
    IFS='.' read -ra v1_parts <<< "$v1"
    IFS='.' read -ra v2_parts <<< "$v2"

    # major, minor, patch 순서로 비교
    for i in 0 1 2; do
        local a b
        a=$(echo "${v1_parts[$i]:-0}" | sed 's/^0*\([0-9]\)/\1/; s/^0*$/0/')
        b=$(echo "${v2_parts[$i]:-0}" | sed 's/^0*\([0-9]\)/\1/; s/^0*$/0/')

        if [ "$a" -gt "$b" ]; then
            log_debug "$v1 > $v2 (위치 $i: $a > $b)"
            return 1
        elif [ "$a" -lt "$b" ]; then
            log_debug "$v1 < $v2 (위치 $i: $a < $b)"
            return 2
        fi
    done

    log_debug "$v1 = $v2 (동일)"
    return 0
}

# ===================================================================
# 높은 버전 반환 함수
# ===================================================================
get_higher_version() {
    local v1=$1
    local v2=$2

    log_debug "높은 버전 선택: '$v1' vs '$v2'"

    compare_versions "$v1" "$v2"
    case $? in
        0) echo "$v1" ;;  # 같음
        1) echo "$v1" ;;  # v1 > v2
        2) echo "$v2" ;;  # v1 < v2
    esac
}

# ===================================================================
# 프로젝트 파일에서 실제 버전 추출
# ===================================================================
get_project_file_version() {
    if [ "$PROJECT_TYPE" = "basic" ] || [ ! -f "$VERSION_FILE" ]; then
        echo "$CURRENT_VERSION"
        return
    fi

    local project_version=""

    case "$PROJECT_TYPE" in
        "spring")
            # Groovy: sed 유지
            project_version=$(sed -nE "s/^[[:space:]]*version[[:space:]]*=[[:space:]]*['\"]([0-9]+\.[0-9]+\.[0-9]+)['\"].*/\1/p" "$VERSION_FILE" | head -1)
            ;;
        "flutter")
            # YAML: yq 사용 (버전에서 +buildNumber 제거)
            local full_version
            full_version=$(yq -r '.version // ""' "$VERSION_FILE")
            project_version=$(echo "$full_version" | cut -d'+' -f1)
            ;;
        "react"|"next"|"node")
            # JSON: jq 사용
            project_version=$(jq -r '.version // ""' "$VERSION_FILE")
            ;;
        "react-native")
            if [[ "$VERSION_FILE" == *"Info.plist" ]]; then
                # plist: PlistBuddy 또는 sed
                if command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
                    project_version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$VERSION_FILE" 2>/dev/null || true)
                else
                    project_version=$(grep -A1 "CFBundleShortVersionString" "$VERSION_FILE" | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/' | head -1)
                fi
            else
                # Groovy: sed 유지
                project_version=$(grep -oP 'versionName *"\K[^"]+' "$VERSION_FILE" | head -1 || true)
            fi
            ;;
        "react-native-expo")
            # JSON: jq 사용
            project_version=$(jq -r '.expo.version // ""' "$VERSION_FILE")
            ;;
        "python")
            # TOML: sed 유지 (파서 없음)
            project_version=$(sed -nE "s/^version[[:space:]]*=[[:space:]]*\"([0-9]+\.[0-9]+\.[0-9]+)\".*/\1/p" "$VERSION_FILE" | head -1)
            ;;
        *)
            project_version="$CURRENT_VERSION"
            ;;
    esac

    # 빈 값이면 version.yml 버전 사용
    if [ -z "$project_version" ]; then
        project_version="$CURRENT_VERSION"
    fi

    log_debug "프로젝트 파일 버전: '$project_version'"
    echo "$project_version"
}

# ===================================================================
# 버전 동기화 함수
# ===================================================================
sync_versions() {
    local yml_version="$CURRENT_VERSION"
    local project_version
    project_version=$(get_project_file_version)

    log_info "버전 동기화 검사"
    log_info "  version.yml: $yml_version"
    log_info "  프로젝트 파일: $project_version"

    if [ "$yml_version" != "$project_version" ]; then
        if validate_version "$yml_version" && validate_version "$project_version"; then
            local higher_version
            higher_version=$(get_higher_version "$yml_version" "$project_version")

            log_info "버전 불일치 감지, 높은 버전으로 동기화: $higher_version"

            # version.yml 업데이트
            if [ "$higher_version" != "$yml_version" ]; then
                update_version_yml "$higher_version"
                CURRENT_VERSION="$higher_version"
            fi

            # 프로젝트 파일 업데이트 (멀티타입이면 모든 타입 파일 순회)
            if [ "$higher_version" != "$project_version" ]; then
                sync_all_project_files "$higher_version"
            fi

            echo "$higher_version"
        else
            log_warning "버전 형식 오류로 동기화 불가"
            echo "$yml_version"
        fi
    else
        # primary 기준 버전은 일치하지만, 멀티타입에서는 비-primary 타입 파일이
        # 어긋나 있을 수 있으므로 항상 전 타입을 yml 버전으로 정합화한다.
        if [ -n "${PROJECT_TYPES_CSV:-}" ]; then
            log_info "멀티타입 — 전 타입 파일을 version.yml 버전으로 정합화: $yml_version"
            sync_all_project_files "$yml_version"
        fi
        log_success "버전이 이미 동기화되어 있음: $yml_version"
        echo "$yml_version"
    fi
}

# ===================================================================
# 프로젝트 파일 버전 업데이트
# ===================================================================
update_project_file_version() {
    local new_version=$1

    if [ "$PROJECT_TYPE" = "basic" ] || [ ! -f "$VERSION_FILE" ]; then
        log_info "기본 타입이거나 프로젝트 파일 없음, 건너뛰기"
        return
    fi

    log_info "프로젝트 파일 업데이트: $VERSION_FILE -> $new_version"

    case "$PROJECT_TYPE" in
        "spring")
            # Groovy: sed 유지 (파서 없음)
            find . -maxdepth 2 -name "build.gradle" -type f | while read -r gradle_file; do
                sed -i.bak "s/version = '[^']*'/version = '$new_version'/g; s/version = \"[^\"]*\"/version = \"$new_version\"/g" "$gradle_file"
                rm -f "${gradle_file}.bak"
                log_success "업데이트: $gradle_file"
            done
            ;;
        "flutter")
            # YAML: yq 사용 (version + build number)
            local code
            code=$(get_version_code)
            local full_version="$new_version+$code"

            log_debug "Flutter 버전 저장: $new_version (version) + $code (code) = $full_version"

            yq -i ".version = \"$full_version\"" "$VERSION_FILE"
            ;;
        "react"|"next"|"node")
            # JSON: jq 사용
            jq ".version = \"$new_version\"" "$VERSION_FILE" > tmp.json && mv tmp.json "$VERSION_FILE"
            ;;
        "react-native")
            if [[ "$VERSION_FILE" == *"Info.plist" ]]; then
                # plist: sed 유지 (XML 파서 복잡)
                find ios -name "Info.plist" -type f | while read -r plist_file; do
                    if grep -q "CFBundleShortVersionString" "$plist_file"; then
                        sed -i.bak '/CFBundleShortVersionString/{n;s/<string>[^<]*<\/string>/<string>'"$new_version"'<\/string>/;}' "$plist_file"
                        rm -f "${plist_file}.bak"
                    fi
                done
            else
                # Groovy: sed 유지
                sed -i.bak "s/versionName \"[^\"]*\"/versionName \"$new_version\"/" "$VERSION_FILE"
                rm -f "${VERSION_FILE}.bak"
            fi
            ;;
        "react-native-expo")
            # JSON: jq 사용
            jq ".expo.version = \"$new_version\"" "$VERSION_FILE" > tmp.json && mv tmp.json "$VERSION_FILE"
            ;;
        "python")
            # TOML: sed 유지 (파서 없음)
            sed -i.bak "s/^version = \"[^\"]*\"/version = \"$new_version\"/" "$VERSION_FILE"
            rm -f "${VERSION_FILE}.bak"
            ;;
    esac

    log_success "프로젝트 파일 업데이트 완료: $new_version"
}

# ===================================================================
# 특정 타입에 대해 프로젝트 파일 sync (멀티타입 지원)
# update_project_file_version은 VERSION_FILE(primary) 단일만 다루므로,
# 멀티타입에서는 각 타입의 sync 파일을 독립적으로 찾아 업데이트한다.
# ===================================================================
sync_for_type() {
    local t=$1
    local new_version=$2
    local p
    p=$(get_type_path "$t")

    log_info "타입별 sync: $t → $new_version (경로: $p)"

    case "$t" in
        "spring")
            if [ -d "$p" ]; then
                find "$p" -maxdepth 2 -name "build.gradle" -type f 2>/dev/null | while read -r gradle_file; do
                    sed -i.bak "s/version = '[^']*'/version = '$new_version'/g; s/version = \"[^\"]*\"/version = \"$new_version\"/g" "$gradle_file"
                    rm -f "${gradle_file}.bak"
                    log_success "업데이트: $gradle_file"
                done
            else
                log_warning "spring: $p 디렉토리 없음 — 건너뜀"
            fi
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
            if [ -d "$p/ios" ]; then
                find "$p/ios" -name "Info.plist" -type f 2>/dev/null | while read -r plist_file; do
                    if grep -q "CFBundleShortVersionString" "$plist_file"; then
                        sed -i.bak '/CFBundleShortVersionString/{n;s/<string>[^<]*<\/string>/<string>'"$new_version"'<\/string>/;}' "$plist_file"
                        rm -f "${plist_file}.bak"
                        log_success "업데이트: $plist_file"
                    fi
                done
            else
                log_warning "react-native: $p/ios 디렉토리 없음 — 건너뜀"
            fi
            if [ -f "$p/android/app/build.gradle" ]; then
                sed -i.bak "s/versionName \"[^\"]*\"/versionName \"$new_version\"/" "$p/android/app/build.gradle"
                rm -f "$p/android/app/build.gradle.bak"
                log_success "업데이트: $p/android/app/build.gradle"
            else
                log_warning "react-native: $p/android/app/build.gradle 없음 — 건너뜀"
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

# ===================================================================
# 모든 타입 sync (멀티 또는 단일)
# ===================================================================
sync_all_project_files() {
    local new_version=$1

    if [ -n "${PROJECT_TYPES_CSV:-}" ]; then
        log_info "멀티타입 sync 시작: $PROJECT_TYPES_CSV"
        local _t
        IFS=',' read -ra _types <<< "$PROJECT_TYPES_CSV"
        for _t in "${_types[@]}"; do
            sync_for_type "$_t" "$new_version"
        done
    else
        # Legacy 단일 — 기존 update_project_file_version 호출 (하위 호환)
        update_project_file_version "$new_version"
    fi
}

# ===================================================================
# 모든 버전 파일 업데이트
# ===================================================================
update_all_versions() {
    local new_version=$1

    log_info "모든 버전 파일 업데이트: $new_version"

    # version.yml 업데이트
    update_version_yml "$new_version"

    # 프로젝트 파일 업데이트 (멀티타입이면 배열 순회)
    sync_all_project_files "$new_version"

    log_success "모든 버전 파일 업데이트 완료: $new_version"
}

# ===================================================================
# version.yml 업데이트
# ===================================================================
update_version_yml() {
    local new_version=$1
    local timestamp
    local user

    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    user=${GITHUB_ACTOR:-$(whoami)}

    log_debug "version.yml 업데이트: $new_version (yq 사용)"

    # yq로 version 필드만 정확히 업데이트 (주석 보존)
    yq -i ".version = \"$new_version\"" version.yml

    # metadata 섹션 업데이트 (필드가 있는 경우만)
    if yq -e '.metadata.last_updated' version.yml >/dev/null 2>&1; then
        yq -i ".metadata.last_updated = \"$timestamp\"" version.yml
    fi
    if yq -e '.metadata.last_updated_by' version.yml >/dev/null 2>&1; then
        yq -i ".metadata.last_updated_by = \"$user\"" version.yml
    fi

    # 전역 변수 업데이트
    CURRENT_VERSION="$new_version"

    log_success "version.yml 업데이트 완료: $new_version"
}

# ===================================================================
# 메인 함수
# ===================================================================
main() {
    local command=${1:-get}

    # 설정 읽기
    read_version_config

    case "$command" in
        "get")
            # 현재 버전 가져오기 (동기화 포함)
            local version
            version=$(sync_versions)
            log_success "현재 버전: $version"
            echo "$version"
            ;;
        "get-code")
            # 현재 version_code 반환
            local code
            code=$(get_version_code)
            log_success "현재 VERSION_CODE: $code"
            echo "$code"
            ;;
        "increment-code")
            # version_code만 증가 (별도 사용 가능)
            increment_version_code
            ;;
        "increment")
            # 먼저 동기화 수행
            log_info "버전 동기화 확인"
            local current_version
            current_version=$(sync_versions)

            if ! validate_version "$current_version"; then
                log_error "잘못된 버전 형식: $current_version"
                exit 1
            fi

            # 패치 버전 증가
            local new_version
            new_version=$(increment_patch_version "$current_version")

            if [ -z "$new_version" ]; then
                log_error "버전 증가 실패"
                exit 1
            fi

            log_info "버전 업데이트: $current_version → $new_version"

            # 모든 버전 파일 업데이트
            update_all_versions "$new_version"

            # version_code도 함께 증가
            increment_version_code > /dev/null

            log_success "버전 업데이트 완료: $new_version"
            echo "$new_version"
            ;;
        "set")
            local new_version=${2:-}
            if [ -z "$new_version" ]; then
                log_error "새 버전을 지정해주세요: $0 set 1.2.3"
                exit 1
            fi

            if ! validate_version "$new_version"; then
                log_error "잘못된 버전 형식: $new_version (x.y.z 형식이어야 합니다)"
                exit 1
            fi

            log_info "버전 설정: $new_version"
            update_all_versions "$new_version"
            log_success "버전 설정 완료: $new_version"
            echo "$new_version"
            ;;
        "sync")
            # 버전 동기화만 수행
            local synced_version
            synced_version=$(sync_versions)
            log_success "버전 동기화 완료: $synced_version"
            echo "$synced_version"
            ;;
        "validate")
            local version=${2:-$CURRENT_VERSION}
            if [ -z "$version" ]; then
                version=$(get_project_file_version)
            fi

            if validate_version "$version"; then
                log_success "유효한 버전 형식: $version"
                echo "$version"
                exit 0
            else
                log_error "잘못된 버전 형식: $version"
                exit 1
            fi
            ;;
        *)
            echo "사용법: $0 {get|get-code|increment|increment-code|set|sync|validate} [version]" >&2
            echo "" >&2
            echo "Commands:" >&2
            echo "  get           - 현재 버전 가져오기 (동기화 포함)" >&2
            echo "  get-code      - 현재 VERSION_CODE 가져오기" >&2
            echo "  increment     - patch 버전 증가 + VERSION_CODE 증가" >&2
            echo "  increment-code - VERSION_CODE만 증가" >&2
            echo "  set           - 특정 버전으로 설정" >&2
            echo "  sync          - 버전 파일 간 동기화" >&2
            echo "  validate      - 버전 형식 검증" >&2
            echo "" >&2
            echo "Examples:" >&2
            echo "  $0 get" >&2
            echo "  $0 get-code" >&2
            echo "  $0 increment" >&2
            echo "  $0 increment-code" >&2
            echo "  $0 set 1.2.3" >&2
            echo "  $0 sync" >&2
            echo "  $0 validate 1.2.3" >&2
            echo "" >&2
            echo "필수 도구:" >&2
            echo "  yq - YAML 파싱 " >&2
            echo "  jq - JSON 파싱 " >&2
            exit 1
            ;;
    esac
}

# 스크립트 실행
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
