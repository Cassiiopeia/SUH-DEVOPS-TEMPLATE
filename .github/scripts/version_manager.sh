#!/bin/bash

# ===================================================================
# 범용 버전 관리 스크립트 v2.0
# ===================================================================
#
# 이 스크립트는 다양한 프로젝트 타입에서 버전 정보를 추출하고 업데이트합니다.
# version.yml 파일의 설정에 따라 적절한 파일에서 버전을 읽고 업데이트합니다.
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
# ===================================================================

set -euo pipefail

# 전역 변수 초기화
PROJECT_TYPE=""
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

# version.yml에서 설정 읽기
read_version_config() {
    if [ ! -f "version.yml" ]; then
        log_error "version.yml 파일을 찾을 수 없습니다!"
        exit 1
    fi
    
    log_debug "version.yml 파싱 시작"
    
    # 기본 파싱
    PROJECT_TYPE=$(grep "^project_type:" version.yml | sed 's/project_type:[[:space:]]*[\"'\'']*\([^\"'\''#]*\)[\"'\''#]*.*/\1/' | sed 's/[[:space:]]*$//' | head -1)
    CURRENT_VERSION=$(grep "^version:" version.yml | sed 's/version:[[:space:]]*[\"'\'']*\([^\"'\'']*\)[\"'\'']*$/\1/' | head -1)
    
    # 프로젝트 타입별 버전 파일 설정
    case "$PROJECT_TYPE" in
        "spring")
            VERSION_FILE="build.gradle"
            ;;
        "flutter")
            VERSION_FILE="pubspec.yaml"
            ;;
        "react"|"node")
            VERSION_FILE="package.json"
            ;;
        "react-native")
            # iOS 우선, 없으면 Android
            if find ios -name "Info.plist" -type f 2>/dev/null | head -1 | read -r ios_plist; then
                VERSION_FILE="$ios_plist"
            else
                VERSION_FILE="android/app/build.gradle"
            fi
            ;;
        "react-native-expo")
            VERSION_FILE="app.json"
            ;;
        "basic"|*)
            VERSION_FILE="version.yml"
            ;;
    esac

    log_info "프로젝트 설정"
    log_info "  타입: $PROJECT_TYPE"
    log_info "  버전 파일: $VERSION_FILE"
    log_info "  현재 버전: $CURRENT_VERSION"
}

# 버전 형식 검증
validate_version() {
    local version=$1
    if [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        log_error "잘못된 버전 형식: '$version' (x.y.z 형식이어야 함)"
        return 1
    fi
}

# version_code 가져오기
get_version_code() {
    if [ ! -f "version.yml" ]; then
        log_warning "version.yml 파일이 없습니다. 기본값 1 반환"
        echo "1"
        return
    fi

    local code=$(grep "^version_code:" version.yml | sed 's/version_code:[[:space:]]*\([0-9]*\).*/\1/' | head -1)

    if [ -z "$code" ]; then
        log_warning "version_code 필드가 없습니다. 자동으로 추가합니다 (초기값: 1)"

        # version.yml에 version_code 필드 추가 (version 다음 줄에)
        if grep -q "^version:" version.yml; then
            # macOS와 Linux 호환 방식으로 추가
            awk '/^version:/ {print; print "version_code: 1  # app build number"; next} 1' version.yml > version.yml.tmp
            mv version.yml.tmp version.yml
            log_success "version_code 필드 추가 완료: 1"
        else
            log_error "version.yml에 version 필드가 없습니다."
        fi

        echo "1"
    else
        log_debug "현재 version_code: $code"
        echo "$code"
    fi
}

# version_code 증가
increment_version_code() {
    local current_code=$(get_version_code)
    local new_code=$((current_code + 1))

    log_info "VERSION_CODE 증가: $current_code → $new_code"

    # version.yml 업데이트
    if grep -q "^version_code:" version.yml; then
        # 기존 필드 업데이트
        sed -i.bak "s/^version_code:.*/version_code: $new_code  # app build number/" version.yml
    else
        # 필드 없으면 추가 (version 다음 줄에)
        sed -i.bak "/^version:/a\\
version_code: $new_code  # app build number" version.yml
    fi
    rm -f version.yml.bak

    log_success "VERSION_CODE 업데이트 완료: $new_code"
    echo "$new_code"
}

# patch 버전 증가
increment_patch_version() {
    local version=$1
    if ! validate_version "$version"; then
        return 1
    fi

    local major=$(echo "$version" | cut -d. -f1)
    local minor=$(echo "$version" | cut -d. -f2)
    local patch=$(echo "$version" | cut -d. -f3)

    patch=$((patch + 1))
    echo "${major}.${minor}.${patch}"
}

# 버전 비교 함수 개선
compare_versions() {
    local v1=$1
    local v2=$2

    log_debug "버전 비교: '$v1' vs '$v2'"

    # 버전을 배열로 분리
    IFS='.' read -ra v1_parts <<< "$v1"
    IFS='.' read -ra v2_parts <<< "$v2"

    # major, minor, patch 순서로 비교
    for i in 0 1 2; do
        local a=$(echo "${v1_parts[$i]:-0}" | sed 's/^0*\([0-9]\)/\1/; s/^0*$/0/')
        local b=$(echo "${v2_parts[$i]:-0}" | sed 's/^0*\([0-9]\)/\1/; s/^0*$/0/')

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

# 높은 버전 반환 함수 단순화
get_higher_version() {
    local v1=$1
    local v2=$2

    log_debug "높은 버전 선택: '$v1' vs '$v2'"

    compare_versions "$v1" "$v2"
    case $? in
        0) # 같음
            echo "$v1"
            ;;
        1) # v1 > v2
            echo "$v1"
            ;;
        2) # v1 < v2
            echo "$v2"
            ;;
    esac
}

# 프로젝트 파일에서 실제 버전 추출
get_project_file_version() {
    if [ "$PROJECT_TYPE" = "basic" ] || [ ! -f "$VERSION_FILE" ]; then
        echo "$CURRENT_VERSION"
        return
    fi

    local project_version=""

    case "$PROJECT_TYPE" in
        "spring")
            project_version=$(sed -nE "s/^[[:space:]]*version[[:space:]]*=[[:space:]]*['\"]([0-9]+\.[0-9]+\.[0-9]+)['\"].*/\1/p" "$VERSION_FILE" | head -1)
            ;;
        "flutter")
            project_version=$(grep "^version:" "$VERSION_FILE" | sed 's/version: *\([0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/' | head -1)
            ;;
        "react"|"node")
            if command -v jq >/dev/null 2>&1; then
                project_version=$(jq -r '.version // empty' "$VERSION_FILE" 2>/dev/null)
            else
                project_version=$(grep '"version":' "$VERSION_FILE" | sed 's/.*"version": *"\([^"]*\)".*/\1/' | head -1)
            fi
            ;;
        "react-native")
            if [[ "$VERSION_FILE" == *"Info.plist" ]]; then
                if command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
                    project_version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$VERSION_FILE" 2>/dev/null)
                else
                    project_version=$(grep -A1 "CFBundleShortVersionString" "$VERSION_FILE" | tail -1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/' | head -1)
                fi
            else
                project_version=$(grep -oP 'versionName *"\K[^"]+' "$VERSION_FILE" | head -1)
            fi
            ;;
        "react-native-expo")
            if command -v jq >/dev/null 2>&1; then
                project_version=$(jq -r '.expo.version // empty' "$VERSION_FILE" 2>/dev/null)
            else
                # expo 객체 내의 version 필드만 추출
                project_version=$(awk '/\"expo\":/,/^[[:space:]]*}/ { if ($0 ~ /\"version\":/) { gsub(/.*"version":[[:space:]]*"/, ""); gsub(/".*/, ""); print; exit } }' "$VERSION_FILE")
            fi
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

# 버전 동기화 함수
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

            # 프로젝트 파일 업데이트
            if [ "$higher_version" != "$project_version" ]; then
                update_project_file_version "$higher_version"
            fi

            echo "$higher_version"
        else
            log_warning "버전 형식 오류로 동기화 불가"
            echo "$yml_version"
        fi
    else
        log_success "버전이 이미 동기화되어 있음: $yml_version"
        echo "$yml_version"
    fi
}

# 프로젝트 파일 버전 업데이트
update_project_file_version() {
    local new_version=$1

    if [ "$PROJECT_TYPE" = "basic" ] || [ ! -f "$VERSION_FILE" ]; then
        log_info "기본 타입이거나 프로젝트 파일 없음, 건너뛰기"
        return
    fi

    log_info "프로젝트 파일 업데이트: $VERSION_FILE -> $new_version"

    case "$PROJECT_TYPE" in
        "spring")
            # 모든 build.gradle 파일 업데이트
            find . -maxdepth 2 -name "build.gradle" -type f | while read -r gradle_file; do
                sed -i.bak "s/version = '[^']*'/version = '$new_version'/g; s/version = \"[^\"]*\"/version = \"$new_version\"/g" "$gradle_file"
                rm -f "${gradle_file}.bak"
                log_success "업데이트: $gradle_file"
            done
            ;;
        "flutter")
            sed -i.bak "s/^version:.*/version: $new_version/" "$VERSION_FILE"
            rm -f "${VERSION_FILE}.bak"
            ;;
        "react"|"node")
            if command -v jq >/dev/null 2>&1; then
                jq ".version = \"$new_version\"" "$VERSION_FILE" > tmp.json && mv tmp.json "$VERSION_FILE"
            else
                sed -i.bak "s/\"version\": *\"[^\"]*\"/\"version\": \"$new_version\"/" "$VERSION_FILE"
                rm -f "${VERSION_FILE}.bak"
            fi
            ;;
        "react-native")
            if [[ "$VERSION_FILE" == *"Info.plist" ]]; then
                # iOS 업데이트
                find ios -name "Info.plist" -type f | while read -r plist_file; do
                    if grep -q "CFBundleShortVersionString" "$plist_file"; then
                        sed -i.bak '/CFBundleShortVersionString/{n;s/<string>[^<]*<\/string>/<string>'$new_version'<\/string>/;}' "$plist_file"
                        rm -f "${plist_file}.bak"
                    fi
                done
            else
                # Android 업데이트
                sed -i.bak "s/versionName \"[^\"]*\"/versionName \"$new_version\"/" "$VERSION_FILE"
                rm -f "${VERSION_FILE}.bak"
            fi
            ;;
        "react-native-expo")
            if command -v jq >/dev/null 2>&1; then
                jq ".expo.version = \"$new_version\"" "$VERSION_FILE" > tmp.json && mv tmp.json "$VERSION_FILE"
            else
                # expo 객체 내의 version만 정확히 업데이트
                awk -v new_ver="$new_version" '
                    /^[[:space:]]*"expo"[[:space:]]*:/ { in_expo=1 }
                    in_expo && /^[[:space:]]*"version"[[:space:]]*:/ {
                        sub(/"version"[[:space:]]*:[[:space:]]*"[^"]*"/, "\"version\": \"" new_ver "\"")
                    }
                    /^[[:space:]]*}/ && in_expo { in_expo=0 }
                    { print }
                ' "$VERSION_FILE" > tmp.json && mv tmp.json "$VERSION_FILE"
            fi
            ;;
    esac

    log_success "프로젝트 파일 업데이트 완료: $new_version"
}

# 모든 버전 파일 업데이트
update_all_versions() {
    local new_version=$1

    log_info "모든 버전 파일 업데이트: $new_version"

    # version.yml 업데이트
    update_version_yml "$new_version"

    # 프로젝트 파일 업데이트
    update_project_file_version "$new_version"

    log_success "모든 버전 파일 업데이트 완료: $new_version"
}

# version.yml 업데이트
update_version_yml() {
    local new_version=$1
    local timestamp
    local user

    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    user=${GITHUB_ACTOR:-$(whoami)}

    log_debug "version.yml 업데이트: $new_version"

    # version.yml 업데이트
    sed -i.bak "s/version: *[\"']*[^\"']*[\"']*/version: \"$new_version\"/" version.yml

    # metadata 섹션 업데이트 (있는 경우만)
    if grep -q "last_updated:" version.yml; then
        sed -i.bak "s/last_updated: *[\"']*[^\"']*[\"']*/last_updated: \"$timestamp\"/" version.yml
    fi
    if grep -q "last_updated_by:" version.yml; then
        sed -i.bak "s/last_updated_by: *[\"']*[^\"']*[\"']*/last_updated_by: \"$user\"/" version.yml
    fi
    rm -f version.yml.bak

    # 전역 변수 업데이트
    CURRENT_VERSION="$new_version"

    log_success "version.yml 업데이트 완료: $new_version"
}

# 메인 함수
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
            local code=$(get_version_code)
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
            local new_version=$2
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
            exit 1
            ;;
    esac
}

# 스크립트 실행
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi