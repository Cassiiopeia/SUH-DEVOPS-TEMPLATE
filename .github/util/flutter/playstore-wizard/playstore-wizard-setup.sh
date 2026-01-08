#!/bin/bash

# ===================================================================
# Flutter Android Play Store 초기화 스크립트
# ===================================================================
#
# 이 스크립트는 Flutter 프로젝트에 Android Play Store 배포를 위한
# 빌드 환경 설정을 자동으로 구성합니다.
#
# ★ 마법사 우선 아키텍처 ★
# - 모든 설정 파일은 이 마법사가 생성합니다
# - GitHub Actions 워크플로우는 생성된 파일을 그대로 사용합니다
# - 초기 설정 후 수정 불필요 (One-time setup)
#
# 빌드 파이프라인:
#   1. flutter build appbundle (AAB 생성)
#   2. fastlane deploy_internal (Play Store 업로드)
#
# 사용법:
#   ./playstore-wizard-setup.sh PROJECT_PATH APPLICATION_ID KEY_ALIAS STORE_PASSWORD KEY_PASSWORD VALIDITY_DAYS CERT_CN CERT_O CERT_L CERT_C
#
# 예시:
#   ./playstore-wizard-setup.sh /path/to/project com.example.app my-release-key MyPass123 MyPass123 99999 "My Name" "My Org" "Seoul" "KR"
#
# 생성/수정되는 파일:
#   - android/.gitignore                    (.gitignore 업데이트) ★ 먼저 실행
#   - android/app/keystore/key.jks         (Keystore 생성) ★ 핵심
#   - android/key.properties               (서명 정보) ★ 핵심
#   - android/app/build.gradle.kts         (서명 설정 패치) ★ 핵심
#   - android/fastlane/Fastfile.playstore  (Play Store 업로드 설정) ★ 핵심
#   - android/Gemfile                      (Fastlane 의존성)
#
# ===================================================================

set -e  # 에러 발생 시 스크립트 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 출력 함수
print_step() {
    echo -e "${CYAN}▶${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}→${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# 파일을 사용 중인 프로세스 찾기 및 종료
stop_processes_using_file() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        return 1
    fi
    
    print_info "파일을 사용 중인 프로세스 찾는 중: $file_path"
    
    local processes_killed=0
    
    # lsof 명령어 사용 (Linux/macOS)
    if command -v lsof >/dev/null 2>&1; then
        local pids
        pids=$(lsof -t "$file_path" 2>/dev/null)
        if [ -n "$pids" ]; then
            for pid in $pids; do
                if kill -0 "$pid" 2>/dev/null; then
                    local proc_name
                    proc_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
                    print_warning "프로세스 종료 중: $proc_name (PID: $pid)"
                    kill -9 "$pid" 2>/dev/null && processes_killed=1
                    sleep 0.5
                fi
            done
        fi
    fi
    
    # 모든 Java/Gradle 프로세스 종료 (파일이 잠겨있을 때)
    if [ $processes_killed -eq 0 ]; then
        print_warning "파일을 사용하는 프로세스를 찾지 못했습니다. 모든 Java/Gradle 프로세스 종료 시도 중..."
        for proc_name in java javaw gradle gradlew; do
            local pids
            pids=$(pgrep -f "$proc_name" 2>/dev/null || true)
            if [ -n "$pids" ]; then
                for pid in $pids; do
                    print_warning "프로세스 종료 중: $proc_name (PID: $pid)"
                    kill -9 "$pid" 2>/dev/null && processes_killed=1
                    sleep 0.5
                done
            fi
        done
    fi
    
    if [ $processes_killed -eq 1 ]; then
        print_info "프로세스 종료 완료. 파일 핸들이 해제될 때까지 5초 대기 중..."
        sleep 5
        return 0
    fi
    
    return 1
}

# 도움말
show_help() {
    cat << EOF
${CYAN}Flutter Android Play Store 초기화 스크립트${NC}

${YELLOW}★ 마법사 우선 아키텍처 ★${NC}
  모든 설정 파일은 이 마법사가 생성하고,
  GitHub Actions 워크플로우는 생성된 파일을 그대로 사용합니다.

${BLUE}빌드 파이프라인:${NC}
  1. flutter build appbundle (AAB 생성)
  2. fastlane deploy_internal (Play Store 업로드)

${BLUE}사용법:${NC}
  ./playstore-wizard-setup.sh PROJECT_PATH APPLICATION_ID KEY_ALIAS STORE_PASSWORD KEY_PASSWORD VALIDITY_DAYS CERT_CN CERT_O CERT_L CERT_C

${BLUE}매개변수:${NC}
  PROJECT_PATH      Flutter 프로젝트 루트 경로
  APPLICATION_ID    Android 앱 Application ID (예: com.example.app)
  KEY_ALIAS         Keystore alias 이름
  STORE_PASSWORD    Keystore 비밀번호
  KEY_PASSWORD      Key 비밀번호
  VALIDITY_DAYS     유효기간 (일 단위, 예: 99999)
  CERT_CN           인증서 Common Name (예: "My Name")
  CERT_O            인증서 Organization (예: "My Company")
  CERT_L            인증서 Locality (예: "Seoul")
  CERT_C            인증서 Country Code (예: "KR")

${BLUE}예시:${NC}
  ./playstore-wizard-setup.sh /path/to/project com.example.app my-release-key MyPass123 MyPass123 99999 "My Name" "My Company" "Seoul" "KR"

${BLUE}생성/수정되는 파일:${NC}
  - android/.gitignore                    .gitignore 업데이트 ★ 먼저 실행
  - android/app/keystore/key.jks         Keystore 생성 ★
  - android/key.properties               서명 정보 ★
  - android/app/build.gradle.kts         서명 설정 패치 ★
  - android/fastlane/Fastfile.playstore  Play Store 업로드 설정 ★
  - android/Gemfile                      Fastlane 의존성

EOF
}

# 매개변수 검증
validate_params() {
    if [ "$#" -lt 10 ]; then
        print_error "매개변수가 부족합니다."
        echo ""
        show_help
        exit 1
    fi

    PROJECT_PATH="$1"
    APPLICATION_ID="$2"
    KEY_ALIAS="$3"
    STORE_PASSWORD="$4"
    KEY_PASSWORD="$5"
    VALIDITY_DAYS="$6"
    CERT_CN="$7"
    CERT_O="$8"
    CERT_L="$9"
    CERT_C="${10}"

    # 프로젝트 경로 확인
    if [ ! -d "$PROJECT_PATH" ]; then
        print_error "프로젝트 경로가 존재하지 않습니다: $PROJECT_PATH"
        exit 1
    fi

    # pubspec.yaml 확인 (Flutter 프로젝트)
    if [ ! -f "$PROJECT_PATH/pubspec.yaml" ]; then
        print_error "Flutter 프로젝트가 아닙니다 (pubspec.yaml 없음)"
        exit 1
    fi

    # android 폴더 확인
    if [ ! -d "$PROJECT_PATH/android" ]; then
        print_error "Android 폴더가 없습니다. 'flutter create .' 명령을 먼저 실행하세요."
        exit 1
    fi

    # Application ID 형식 확인
    if [[ ! "$APPLICATION_ID" =~ \. ]]; then
        print_error "Application ID 형식이 올바르지 않습니다: $APPLICATION_ID"
        print_error "예시: com.example.app"
        exit 1
    fi

    # 비밀번호 확인
    if [ -z "$STORE_PASSWORD" ] || [ -z "$KEY_PASSWORD" ]; then
        print_error "Keystore 비밀번호와 Key 비밀번호는 필수입니다."
        exit 1
    fi

    # 유효기간 확인
    if ! [[ "$VALIDITY_DAYS" =~ ^[0-9]+$ ]]; then
        print_error "유효기간은 숫자여야 합니다: $VALIDITY_DAYS"
        exit 1
    fi

    # 인증서 정보 확인
    if [ -z "$CERT_CN" ] || [ -z "$CERT_O" ] || [ -z "$CERT_L" ] || [ -z "$CERT_C" ]; then
        print_error "인증서 정보(CN, O, L, C)는 모두 필수입니다."
        exit 1
    fi

    # Country Code 길이 확인
    if [ ${#CERT_C} -ne 2 ]; then
        print_error "Country Code는 2자리여야 합니다: $CERT_C"
        exit 1
    fi
}

# 템플릿 디렉토리 찾기
find_template_dir() {
    # 스크립트 위치 기준
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TEMPLATE_DIR="$SCRIPT_DIR/templates"

    if [ ! -d "$TEMPLATE_DIR" ]; then
        print_error "템플릿 디렉토리를 찾을 수 없습니다: $TEMPLATE_DIR"
        exit 1
    fi

    print_info "템플릿 디렉토리: $TEMPLATE_DIR"
}

# .gitignore 업데이트 (먼저 실행!)
update_gitignore() {
    print_step ".gitignore 업데이트 중..."

    # Git 저장소 확인
    if [ ! -d "$PROJECT_PATH/.git" ]; then
        print_info "Git 저장소가 아닙니다. .gitignore 업데이트를 건너뜁니다."
        return 0
    fi

    local gitignore_path="$PROJECT_PATH/.gitignore"
    local android_gitignore_path="$PROJECT_PATH/android/.gitignore"
    local gitignore_updated=false

    # 루트 .gitignore 처리 (파일이 존재할 때만)
    if [ -f "$gitignore_path" ]; then
        GITIGNORE_ENTRIES=(
            "android/key.properties"
            "android/app/keystore/"
            "*.jks"
            "*.keystore"
            ".env"
            ".env.local"
            ".env.*.local"
        )

        for entry in "${GITIGNORE_ENTRIES[@]}"; do
            if ! grep -qF "$entry" "$gitignore_path" 2>/dev/null; then
                echo "" >> "$gitignore_path"
                echo "# Play Store CI/CD - 민감한 파일 (자동 생성됨)" >> "$gitignore_path"
                echo "$entry" >> "$gitignore_path"
                print_info "루트 .gitignore에 추가: $entry"
                gitignore_updated=true
            fi
        done
    fi
    # 루트 .gitignore가 없으면 생성하지 않음 (Git 미사용 프로젝트 가능성)

    # android/.gitignore 처리
    if [ -f "$android_gitignore_path" ]; then
        # 항목 확인 및 추가
        if ! grep -qF "key.properties" "$android_gitignore_path" 2>/dev/null; then
            echo "" >> "$android_gitignore_path"
            echo "# Play Store Keystore (자동 생성됨)" >> "$android_gitignore_path"
            echo "key.properties" >> "$android_gitignore_path"
            echo "keystore/" >> "$android_gitignore_path"
            print_info "android/.gitignore에 추가됨"
            gitignore_updated=true
        fi
    else
        # android/.gitignore가 없으면 생성
        mkdir -p "$PROJECT_PATH/android"
        cat > "$android_gitignore_path" << EOF
# Play Store CI/CD - 민감한 파일 (자동 생성됨)
key.properties
keystore/
*.jks
*.keystore

# 환경 변수 파일
.env
.env.local
.env.*.local
EOF
        print_info "android/.gitignore 생성됨"
        gitignore_updated=true
    fi

    if [ "$gitignore_updated" = true ]; then
        print_success ".gitignore 업데이트 완료"
    else
        print_info ".gitignore에 이미 모든 항목이 포함되어 있습니다."
    fi
}

# .gitignore 변경사항 커밋 (Keystore 생성 전에 실행!)
commit_gitignore() {
    print_step ".gitignore 변경사항 커밋 중..."

    # Git 저장소 확인
    if [ ! -d "$PROJECT_PATH/.git" ]; then
        print_info "Git 저장소가 아닙니다. 커밋을 건너뜁니다."
        return 0
    fi

    # Git 명령어 사용 가능 여부 확인
    if ! command -v git >/dev/null 2>&1; then
        print_warning "Git이 설치되어 있지 않습니다. 커밋을 건너뜁니다."
        return 0
    fi

    local gitignore_path="$PROJECT_PATH/.gitignore"
    local android_gitignore_path="$PROJECT_PATH/android/.gitignore"
    local has_changes=false

    # .gitignore 변경사항 확인
    if [ -f "$gitignore_path" ]; then
        if ! git -C "$PROJECT_PATH" diff --quiet "$gitignore_path" 2>/dev/null; then
            has_changes=true
        fi
    fi

    if [ -f "$android_gitignore_path" ]; then
        if ! git -C "$PROJECT_PATH" diff --quiet "$android_gitignore_path" 2>/dev/null; then
            has_changes=true
        fi
    fi

    if [ "$has_changes" = true ]; then
        # 이미 추적 중인 파일 제거 (있는 경우)
        if git -C "$PROJECT_PATH" ls-files --error-unmatch "$PROJECT_PATH/android/key.properties" >/dev/null 2>&1; then
            print_warning "이미 추적 중인 key.properties를 Git에서 제거합니다..."
            git -C "$PROJECT_PATH" rm --cached "$PROJECT_PATH/android/key.properties" 2>/dev/null || true
        fi

        if git -C "$PROJECT_PATH" ls-files --error-unmatch "$PROJECT_PATH/android/app/keystore/key.jks" >/dev/null 2>&1; then
            print_warning "이미 추적 중인 keystore 파일을 Git에서 제거합니다..."
            git -C "$PROJECT_PATH" rm --cached "$PROJECT_PATH/android/app/keystore/key.jks" 2>/dev/null || true
        fi

        # .gitignore 커밋
        if [ -f "$gitignore_path" ]; then
            git -C "$PROJECT_PATH" add "$gitignore_path" 2>/dev/null || true
        fi
        if [ -f "$android_gitignore_path" ]; then
            git -C "$PROJECT_PATH" add "$android_gitignore_path" 2>/dev/null || true
        fi

        if git -C "$PROJECT_PATH" diff --cached --quiet 2>/dev/null; then
            print_info ".gitignore에 변경사항이 없습니다 (이미 커밋됨)."
        else
            if git -C "$PROJECT_PATH" commit -m "chore: Add keystore files to .gitignore" 2>/dev/null; then
                print_success ".gitignore 변경사항 커밋 완료"
            else
                print_warning "커밋 실패 (이미 커밋되었거나 변경사항 없음)"
            fi
        fi
    else
        print_info ".gitignore에 변경사항이 없습니다."
    fi
}

# keystore 생성 스킵 여부
KEYSTORE_SKIPPED=0

# Keystore 생성
create_keystore() {
    print_step "Keystore 생성 중..."

    local keystore_dir="$PROJECT_PATH/android/app/keystore"
    local keystore_path="$keystore_dir/key.jks"

    # 디렉토리 생성
    mkdir -p "$keystore_dir"

    # 기존 keystore 확인
    if [ -f "$keystore_path" ]; then
        print_info "기존 keystore가 존재합니다: $keystore_path"
        print_info "기존 keystore 덮어쓰기 중..."
        
        # 기존 keystore에서 alias 삭제 시도 (파일 삭제 전에)
        print_info "기존 keystore에서 alias 삭제 시도 중..."
        if keytool -delete -alias "$KEY_ALIAS" -keystore "$keystore_path" -storepass "$STORE_PASSWORD" 2>/dev/null; then
            print_info "기존 alias가 keystore에서 삭제되었습니다"
        else
            print_warning "keystore에서 alias 삭제 실패 (존재하지 않거나 비밀번호가 다를 수 있음)"
            print_warning "파일 삭제/교체를 시도합니다..."
        fi
        
        # 백업 파일이 있으면 삭제
        if [ -f "${keystore_path}.bak" ]; then
            rm -f "${keystore_path}.bak"
        fi
        
        # 파일 백업 시도
        if mv "$keystore_path" "${keystore_path}.bak" 2>/dev/null; then
            print_info "기존 keystore 백업: ${keystore_path}.bak"
        else
            # 파일이 잠겨있으면 프로세스 종료 후 재시도
            print_warning "keystore 파일 이동 실패. 파일을 사용 중인 프로세스 종료 시도 중..."
            
            if stop_processes_using_file "$keystore_path"; then
                if rm -f "$keystore_path" 2>/dev/null; then
                    print_info "기존 keystore 삭제됨 (프로세스 종료 후)"
                else
                    print_error "프로세스 종료 후에도 keystore 파일 삭제 실패: $keystore_path"
                    print_error "파일을 수동으로 삭제하거나 파일을 사용하는 프로그램을 닫으세요."
                    exit 1
                fi
            else
                print_error "keystore 파일 삭제 실패: $keystore_path"
                print_error "파일을 수동으로 삭제하거나 파일을 사용하는 프로그램을 닫으세요."
                exit 1
            fi
        fi
    fi

    # keytool 명령어 생성
    local dname="CN=$CERT_CN, O=$CERT_O, L=$CERT_L, C=$CERT_C"
    
    print_info "Keystore 정보:"
    print_info "  • 경로: $keystore_path"
    print_info "  • Alias: $KEY_ALIAS"
    print_info "  • 유효기간: ${VALIDITY_DAYS} days"
    print_info "  • 인증서: $dname"

    # keytool 실행 (비밀번호는 stdin으로 전달)
    echo -e "${STORE_PASSWORD}\n${STORE_PASSWORD}\n${KEY_PASSWORD}\n${KEY_PASSWORD}\n${dname}\ny\n" | \
        keytool -genkey -v \
        -keystore "$keystore_path" \
        -alias "$KEY_ALIAS" \
        -keyalg RSA \
        -keysize 2048 \
        -validity "$VALIDITY_DAYS" \
        -storepass "$STORE_PASSWORD" \
        -keypass "$KEY_PASSWORD" \
        -dname "$dname" \
        2>&1 | grep -v "Warning:" || true

    if [ -f "$keystore_path" ]; then
        print_success "Keystore 생성 완료: $keystore_path"
    else
        print_error "Keystore 생성 실패!"
        exit 1
    fi
}

# key.properties 생성
create_key_properties() {
    print_step "key.properties 생성 중..."

    # keystore 생성이 스킵되었으면 key.properties도 스킵
    if [ "$KEYSTORE_SKIPPED" = "1" ]; then
        print_warning "key.properties 생성 스킵 (keystore가 덮어쓰기되지 않음)"
        print_warning "⚠️ 기존 keystore를 사용하므로 key.properties의 비밀번호를 수동으로 확인하세요!"
        print_warning "   기존 keystore의 비밀번호를 android/key.properties에 입력해야 합니다."
        print_warning "   또는 Step 2로 돌아가서 keystore를 덮어쓰기(y)로 다시 생성하세요."
        return 0
    fi

    local key_properties_path="$PROJECT_PATH/android/key.properties"

    # 기존 파일 백업 및 삭제
    if [ -f "$key_properties_path" ]; then
        print_info "기존 key.properties 발견. 덮어쓰기 중..."
        backup_path="${key_properties_path}.bak"
        
        # 백업 파일이 있으면 삭제
        if [ -f "$backup_path" ]; then
            rm -f "$backup_path"
        fi
        
        # 파일 백업 시도
        if cp "$key_properties_path" "$backup_path" 2>/dev/null && rm -f "$key_properties_path" 2>/dev/null; then
            print_info "기존 key.properties 백업: $backup_path"
        else
            # 파일이 잠겨있으면 프로세스 종료 후 재시도
            print_warning "key.properties 파일 백업/삭제 실패. 파일을 사용 중인 프로세스 종료 시도 중..."
            
            if stop_processes_using_file "$key_properties_path"; then
                if rm -f "$key_properties_path" 2>/dev/null; then
                    print_info "기존 key.properties 삭제됨 (프로세스 종료 후)"
                else
                    print_error "프로세스 종료 후에도 key.properties 파일 삭제 실패: $key_properties_path"
                    print_error "파일을 수동으로 삭제하거나 파일을 사용하는 프로그램을 닫으세요."
                    exit 1
                fi
            else
                print_error "key.properties 파일 삭제 실패: $key_properties_path"
                print_error "파일을 수동으로 삭제하거나 파일을 사용하는 프로그램을 닫으세요."
                exit 1
            fi
        fi
    fi

    # 파일 쓰기 시도
    if ! cat > "$key_properties_path" << EOF
# Release Keystore Configuration
# WARNING: Do not commit this file to version control!
# This file is automatically generated by Play Store Wizard

storeFile=app/keystore/key.jks
storePassword=$STORE_PASSWORD
keyAlias=$KEY_ALIAS
keyPassword=$KEY_PASSWORD
EOF
    then
        # 파일이 잠겨있으면 프로세스 종료 후 재시도
        print_warning "key.properties 파일 쓰기 실패. 파일을 사용 중인 프로세스 종료 시도 중..."
        
        if stop_processes_using_file "$key_properties_path"; then
            if ! cat > "$key_properties_path" << EOF
# Release Keystore Configuration
# WARNING: Do not commit this file to version control!
# This file is automatically generated by Play Store Wizard

storeFile=app/keystore/key.jks
storePassword=$STORE_PASSWORD
keyAlias=$KEY_ALIAS
keyPassword=$KEY_PASSWORD
EOF
            then
                print_error "프로세스 종료 후에도 key.properties 파일 쓰기 실패"
                print_error "파일이 여전히 잠겨있을 수 있습니다. 파일을 사용하는 프로그램을 수동으로 닫고 다시 시도하세요."
                exit 1
            else
                print_info "프로세스 종료 후 key.properties 쓰기 성공"
            fi
        else
            print_error "key.properties 파일 쓰기 실패"
            print_error "파일이 다른 프로세스에서 사용 중일 수 있습니다. 파일을 사용하는 프로그램을 닫고 다시 시도하세요."
            exit 1
        fi
    fi
    
    # 파일이 제대로 생성되었는지 확인
    if [ ! -f "$key_properties_path" ]; then
        print_error "key.properties 파일이 생성되지 않았습니다: $key_properties_path"
        exit 1
    fi
    
    # 파일 내용 확인
    if ! grep -q "storePassword" "$key_properties_path" 2>/dev/null; then
        print_error "key.properties 파일이 존재하지만 내용이 유효하지 않습니다: $key_properties_path"
        exit 1
    fi

    print_success "key.properties 생성 완료: $key_properties_path"
    print_info "  • Store Password: $STORE_PASSWORD"
    print_info "  • Key Alias: $KEY_ALIAS"
    print_info "  • Key Password: $KEY_PASSWORD"
}

# build.gradle.kts에 서명 설정 추가
patch_build_gradle() {
    print_step "build.gradle.kts에 서명 설정 추가 중..."

    local gradle_file="$PROJECT_PATH/android/app/build.gradle.kts"
    local patch_script="$SCRIPT_DIR/patch-build-gradle.py"

    if [ ! -f "$gradle_file" ]; then
        print_error "build.gradle.kts 파일을 찾을 수 없습니다: $gradle_file"
        exit 1
    fi

    if [ ! -f "$patch_script" ]; then
        print_error "패치 스크립트를 찾을 수 없습니다: $patch_script"
        exit 1
    fi

    # Python 3 설치 확인
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3가 설치되어 있지 않습니다"
        print_warning "Python 3를 설치한 후 다시 시도하세요"
        exit 1
    fi

    # Python 스크립트 실행
    python3 "$patch_script" "$gradle_file"

    if [ $? -ne 0 ]; then
        print_error "build.gradle.kts 패치 실패!"
        exit 1
    fi

    print_success "build.gradle.kts 자동 설정 완료!"
}

# Fastfile.playstore 생성
create_fastfile() {
    print_step "Fastfile.playstore 생성 중..."

    local fastlane_dir="$PROJECT_PATH/android/fastlane"
    local fastfile_path="$fastlane_dir/Fastfile.playstore"
    local template_fastfile="$TEMPLATE_DIR/Fastfile.playstore.template"

    # fastlane 디렉토리 생성
    mkdir -p "$fastlane_dir"

    # 기존 파일 백업
    if [ -f "$fastfile_path" ]; then
        print_warning "기존 Fastfile.playstore 백업: ${fastfile_path}.bak"
        cp "$fastfile_path" "${fastfile_path}.bak"
    fi

    # 템플릿 파일 존재 확인
    if [ -f "$template_fastfile" ]; then
        # 템플릿에서 복사하고 플레이스홀더 치환
        sed "s/{{APPLICATION_ID}}/$APPLICATION_ID/g" "$template_fastfile" > "$fastfile_path"
        print_info "템플릿에서 생성됨"
    else
        # 템플릿이 없으면 직접 생성
        cat > "$fastfile_path" << EOF
# Fastfile for Play Store Internal Testing Deployment
# Path: android/fastlane/Fastfile.playstore
# Generated by Flutter Play Store CI/CD Helper

default_platform(:android)

platform :android do
  desc "Deploy to Play Store Internal Testing"
  lane :deploy_internal do
    # Environment variables
    aab_path = ENV["AAB_PATH"] || "../build/app/outputs/bundle/release/app-release.aab"
    json_key = ENV["GOOGLE_PLAY_JSON_KEY"] || "~/.config/gcloud/service-account.json"

    puts "========================================="
    puts "Deploying to Play Store Internal Testing"
    puts "========================================="
    puts "AAB Path: \#{aab_path}"
    puts "Service Account: \#{json_key}"
    puts ""

    # Verify AAB exists
    unless File.exist?(aab_path)
      UI.user_error!("AAB file not found: \#{aab_path}")
    end

    # Verify Service Account exists
    unless File.exist?(json_key)
      UI.user_error!("Service Account JSON not found: \#{json_key}")
    end

    # Upload to Play Store
    # ⚠️ release_status 설정 가이드:
    #   - "draft": 앱이 Play Console에서 아직 한 번도 출시되지 않은 경우 (신규 앱)
    #   - "completed": 앱이 이미 Play Console에서 검토 완료되어 활성화된 경우
    # 신규 앱은 반드시 "draft"로 시작해야 합니다.
    upload_to_play_store(
      package_name: "$APPLICATION_ID",
      track: "internal",
      aab: aab_path,
      json_key: json_key,
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true,
      release_status: "draft"  # 신규 앱: "draft" → 승인 후: "completed"로 변경
    )

    puts ""
    puts "========================================="
    puts "Successfully deployed to Internal Testing!"
    puts "========================================="
  end
end
EOF
    fi

    print_success "Fastfile.playstore 생성 완료: $fastfile_path"
    print_info "  → GitHub Actions 워크플로우에서 이 파일을 직접 사용합니다"
}

# Gemfile 생성
create_gemfile() {
    print_step "Gemfile 생성 중..."

    local gemfile_path="$PROJECT_PATH/android/Gemfile"

    # 기존 파일 백업
    if [ -f "$gemfile_path" ]; then
        print_warning "기존 Gemfile 백업: ${gemfile_path}.bak"
        cp "$gemfile_path" "${gemfile_path}.bak"
    fi

    cat > "$gemfile_path" << 'EOF'
# frozen_string_literal: true

source "https://rubygems.org"

# Fastlane - Android 빌드 자동화
gem "fastlane", "~> 2.225"
EOF

    print_success "Gemfile 생성 완료: $gemfile_path"
}

# 완료 메시지
print_completion() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          🎉 Android Play Store 배포 설정 완료! 🎉             ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}★ 마법사 우선 아키텍처 ★${NC}"
    echo "  모든 설정이 완료되었습니다. 워크플로우는 이 파일들을 그대로 사용합니다."
    echo ""
    echo -e "${CYAN}생성/수정된 파일:${NC}"
    echo "  ✅ android/.gitignore                    (.gitignore 업데이트)"
    echo "  ✅ android/app/keystore/key.jks         (Keystore 생성) ★"
    echo "  ✅ android/key.properties               (서명 정보) ★"
    echo "  ✅ android/app/build.gradle.kts         (서명 설정 패치) ★"
    echo "  ✅ android/fastlane/Fastfile.playstore  (Play Store 업로드) ★"
    echo "  ✅ android/Gemfile                      (Fastlane 의존성)"
    echo ""
    echo -e "${CYAN}설정된 정보:${NC}"
    echo "  • Application ID: $APPLICATION_ID"
    echo "  • Key Alias: $KEY_ALIAS"
    echo "  • Keystore 유효기간: ${VALIDITY_DAYS} days"
    echo ""
    echo -e "${CYAN}빌드 파이프라인:${NC}"
    echo "  1. flutter build appbundle (AAB 생성)"
    echo "  2. fastlane deploy_internal (Fastfile.playstore 사용)"
    echo ""
    echo -e "${YELLOW}다음 단계:${NC}"
    echo "  1. GitHub Secrets 설정:"
    echo "     • RELEASE_KEYSTORE_BASE64 (keystore 파일을 base64 인코딩)"
    echo "     • RELEASE_KEYSTORE_PASSWORD"
    echo "     • RELEASE_KEY_ALIAS"
    echo "     • RELEASE_KEY_PASSWORD"
    echo "     • GOOGLE_PLAY_SERVICE_ACCOUNT_JSON_BASE64"
    echo ""
    echo "  2. 추가 변경사항 커밋 (필요시):"
    echo "     git add android/"
    echo "     git commit -m \"chore: Android Play Store 배포 설정\""
    echo "     (참고: .gitignore는 이미 자동으로 커밋되었습니다)"
    echo ""
    echo "  3. deploy 브랜치로 푸시하여 빌드 테스트"
    echo ""

}

# ===================================================================
# 메인 실행
# ===================================================================

main() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       Flutter Android Play Store 초기화 스크립트               ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # 도움말 옵션 확인
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_help
        exit 0
    fi

    # 매개변수 검증
    validate_params "$@"

    echo -e "${BLUE}프로젝트 경로:${NC} $PROJECT_PATH"
    echo -e "${BLUE}Application ID:${NC} $APPLICATION_ID"
    echo -e "${BLUE}Key Alias:${NC} $KEY_ALIAS"
    echo -e "${BLUE}유효기간:${NC} ${VALIDITY_DAYS} days"
    echo ""

    # 템플릿 디렉토리 찾기
    find_template_dir

    # 파일 생성 (순서 중요!)
    update_gitignore      # 1. 먼저 .gitignore 업데이트
    commit_gitignore      # 2. .gitignore 커밋 (Keystore 생성 전!)
    create_keystore       # 3. 이제 Keystore 생성 (안전)
    create_key_properties
    patch_build_gradle
    create_fastfile
    create_gemfile

    # 완료
    print_completion
}

# 스크립트 실행
main "$@"
