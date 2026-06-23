#!/bin/bash

# ===================================================================
# Flutter iOS TestFlight 초기화 스크립트
# ===================================================================
#
# 이 스크립트는 Flutter 프로젝트에 iOS TestFlight 배포를 위한
# 빌드 환경 설정을 자동으로 구성합니다.
#
# ★ 마법사 우선 아키텍처 ★
# - 모든 설정 파일은 이 마법사가 생성합니다
# - GitHub Actions 워크플로우는 생성된 파일을 그대로 사용합니다
# - 초기 설정 후 수정 불필요 (One-time setup)
#
# 빌드 파이프라인:
#   1. flutter build ios --no-codesign (Flutter 빌드)
#   2. xcodebuild archive (Xcode 아카이브 생성)
#   3. xcodebuild -exportArchive (IPA 생성)
#   4. fastlane upload_testflight (TestFlight 업로드)
#
# 사용법:
#   ./init.sh PROJECT_PATH BUNDLE_ID TEAM_ID PROFILE_NAME [USES_ENCRYPTION]
#
# 예시:
#   ./init.sh /path/to/project com.example.myapp ABC1234DEF "MyApp Distribution"
#   ./init.sh /path/to/project com.example.myapp ABC1234DEF "MyApp Distribution" false
#
# 생성/수정되는 파일:
#   - ios/Gemfile                    (Fastlane 의존성)
#   - ios/fastlane/Fastfile          (TestFlight 업로드 설정) ★ 핵심
#   - ios/ExportOptions.plist        (IPA 익스포트 설정) ★ 핵심
#   - ios/Runner.xcodeproj           (Manual Signing 패치) ★ 핵심
#   - ios/Runner/Info.plist          (암호화 설정)
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

# 크로스플랫폼 in-place sed.
#   BSD sed(macOS): -i 뒤에 백업 접미사(빈 문자열 '')가 필수.
#   GNU sed(Linux/Windows Git Bash): -i 뒤에 바로 식. '' 를 주면 식으로 오인해 깨진다.
# 첫 호출 시 1회만 OS 종류를 감지해 캐시한다. 사용법은 GNU 형태와 동일: sed_inplace 's/a/b/' file
SED_FLAVOR=""
sed_inplace() {
    if [ -z "$SED_FLAVOR" ]; then
        # BSD sed는 --version을 모른다(에러). GNU sed만 --version 성공.
        if sed --version >/dev/null 2>&1; then
            SED_FLAVOR="gnu"
        else
            SED_FLAVOR="bsd"
        fi
    fi
    if [ "$SED_FLAVOR" = "gnu" ]; then
        sed -i "$@"
    else
        sed -i '' "$@"
    fi
}

# 도움말
show_help() {
    cat << EOF
${CYAN}Flutter iOS TestFlight 초기화 스크립트${NC}

${YELLOW}★ 마법사 우선 아키텍처 ★${NC}
  모든 설정 파일은 이 마법사가 생성하고,
  GitHub Actions 워크플로우는 생성된 파일을 그대로 사용합니다.

${BLUE}빌드 파이프라인:${NC}
  1. flutter build ios --no-codesign (Flutter 빌드)
  2. xcodebuild archive (Xcode 아카이브 생성)
  3. xcodebuild -exportArchive (IPA 생성)
  4. fastlane upload_testflight (TestFlight 업로드)

${BLUE}사용법:${NC}
  ./init.sh PROJECT_PATH BUNDLE_ID TEAM_ID PROFILE_NAME [USES_ENCRYPTION]

${BLUE}매개변수:${NC}
  PROJECT_PATH      Flutter 프로젝트 루트 경로
  BUNDLE_ID         iOS 앱 Bundle ID (예: com.example.myapp)
  TEAM_ID           Apple Developer Team ID (10자리)
  PROFILE_NAME      Provisioning Profile 이름
  USES_ENCRYPTION   암호화 사용 여부 (true/false, 기본값: false)

${BLUE}예시:${NC}
  ./init.sh /path/to/project com.example.myapp ABC1234DEF "MyApp Distribution"
  ./init.sh /path/to/project com.example.myapp ABC1234DEF "MyApp Distribution" false

${BLUE}생성/수정되는 파일:${NC}
  - ios/Gemfile                    Fastlane 의존성
  - ios/fastlane/Fastfile          TestFlight 업로드 설정 ★
  - ios/ExportOptions.plist        IPA 익스포트 설정 ★
  - ios/Runner.xcodeproj           Manual Signing 패치 ★
  - ios/Runner/Info.plist          암호화 설정 (ITSAppUsesNonExemptEncryption)

EOF
}

# 매개변수 검증
validate_params() {
    if [ "$#" -lt 4 ]; then
        print_error "매개변수가 부족합니다."
        echo ""
        show_help
        exit 1
    fi

    PROJECT_PATH="$1"
    BUNDLE_ID="$2"
    TEAM_ID="$3"
    PROFILE_NAME="$4"
    # 5번째 매개변수: 암호화 사용 여부 (기본값: false)
    USES_NON_EXEMPT_ENCRYPTION="${5:-false}"

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

    # ios 폴더 확인
    if [ ! -d "$PROJECT_PATH/ios" ]; then
        print_error "iOS 폴더가 없습니다. 'flutter create .' 명령을 먼저 실행하세요."
        exit 1
    fi

    # Bundle ID 형식 확인
    if [[ ! "$BUNDLE_ID" =~ \. ]]; then
        print_error "Bundle ID 형식이 올바르지 않습니다: $BUNDLE_ID"
        print_error "예시: com.example.myapp"
        exit 1
    fi

    # Team ID 길이 확인
    if [ ${#TEAM_ID} -ne 10 ]; then
        print_error "Team ID는 10자리여야 합니다: $TEAM_ID"
        exit 1
    fi

    # 암호화 설정 값 검증 (true/false만 허용)
    if [ "$USES_NON_EXEMPT_ENCRYPTION" != "true" ] && [ "$USES_NON_EXEMPT_ENCRYPTION" != "false" ]; then
        print_warning "암호화 설정 값이 올바르지 않습니다: $USES_NON_EXEMPT_ENCRYPTION"
        print_warning "기본값 'false'를 사용합니다."
        USES_NON_EXEMPT_ENCRYPTION="false"
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

# Gemfile 생성
create_gemfile() {
    print_step "Gemfile 생성 중..."

    local gemfile_path="$PROJECT_PATH/ios/Gemfile"

    # 기존 파일 백업
    if [ -f "$gemfile_path" ]; then
        print_warning "기존 Gemfile 백업: ${gemfile_path}.bak"
        cp "$gemfile_path" "${gemfile_path}.bak"
    fi

    cat > "$gemfile_path" << 'EOF'
# frozen_string_literal: true

source "https://rubygems.org"

# Fastlane - iOS 빌드 자동화
# Ruby 3.4+ 공식 지원 버전 (2.228+)
gem "fastlane", "~> 2.228"

# multi_json - google-apis transitive 의존성이 gemspec에 선언 누락한 upstream 버그 회피 (Gem::LoadError 방지)
gem "multi_json"

# CocoaPods - iOS 의존성 관리
gem "cocoapods", "~> 1.15"
EOF

    print_success "Gemfile 생성 완료: $gemfile_path"
}

# Fastfile 생성 (템플릿에서 복사)
# ★ 이 파일이 GitHub Actions 워크플로우에서 직접 사용됩니다 ★
create_fastfile() {
    print_step "Fastfile 생성 중..."

    local fastlane_dir="$PROJECT_PATH/ios/fastlane"
    local fastfile_path="$fastlane_dir/Fastfile"
    local template_fastfile="$TEMPLATE_DIR/Fastfile.ios.template"

    # fastlane 디렉토리 생성
    mkdir -p "$fastlane_dir"

    # 기존 파일 백업
    if [ -f "$fastfile_path" ]; then
        print_warning "기존 Fastfile 백업: ${fastfile_path}.bak"
        cp "$fastfile_path" "${fastfile_path}.bak"
    fi

    # 템플릿 파일 존재 확인
    if [ ! -f "$template_fastfile" ]; then
        print_error "Fastfile 템플릿을 찾을 수 없습니다: $template_fastfile"
        exit 1
    fi

    # 템플릿에서 복사
    cp "$template_fastfile" "$fastfile_path"

    print_success "Fastfile 생성 완료: $fastfile_path"
    print_info "  → GitHub Actions 워크플로우에서 이 파일을 직접 사용합니다"
}

# ExportOptions.plist 생성 (xcodebuild -exportArchive에 필요)
create_export_options_plist() {
    print_step "ExportOptions.plist 생성 중..."

    local export_options_path="$PROJECT_PATH/ios/ExportOptions.plist"
    local template_export_options="$TEMPLATE_DIR/ExportOptions.plist"

    # 기존 파일 백업
    if [ -f "$export_options_path" ]; then
        print_warning "기존 ExportOptions.plist 백업: ${export_options_path}.bak"
        cp "$export_options_path" "${export_options_path}.bak"
    fi

    # 템플릿 파일 존재 확인
    if [ -f "$template_export_options" ]; then
        # 템플릿에서 복사하고 플레이스홀더 치환
        cat "$template_export_options" | \
            sed "s/{{TEAM_ID}}/$TEAM_ID/g" | \
            sed "s/{{BUNDLE_ID}}/$BUNDLE_ID/g" | \
            sed "s/{{PROFILE_NAME}}/$PROFILE_NAME/g" > "$export_options_path"
        print_info "  → 템플릿에서 생성됨"
    else
        # 템플릿이 없으면 직접 생성
        cat > "$export_options_path" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store</string>
    <key>teamID</key>
    <string>$TEAM_ID</string>
    <key>provisioningProfiles</key>
    <dict>
        <key>$BUNDLE_ID</key>
        <string>$PROFILE_NAME</string>
    </dict>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>Apple Distribution</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadBitcode</key>
    <false/>
    <key>uploadSymbols</key>
    <true/>
</dict>
</plist>
EOF
    fi

    print_success "ExportOptions.plist 생성 완료: $export_options_path"
    print_info "  • Team ID: $TEAM_ID"
    print_info "  • Bundle ID: $BUNDLE_ID"
    print_info "  • Profile Name: $PROFILE_NAME"
}

# .gitignore 업데이트 (선택사항)
update_gitignore() {
    print_step ".gitignore 확인 중..."

    local gitignore_path="$PROJECT_PATH/ios/.gitignore"

    # Gemfile.lock은 일반적으로 커밋하지 않음
    if [ -f "$gitignore_path" ]; then
        if ! grep -q "Gemfile.lock" "$gitignore_path"; then
            echo "" >> "$gitignore_path"
            echo "# Fastlane" >> "$gitignore_path"
            echo "Gemfile.lock" >> "$gitignore_path"
            print_info "Gemfile.lock을 .gitignore에 추가했습니다"
        fi
    fi

    print_success ".gitignore 확인 완료"
}

# Info.plist에 암호화 설정 추가 (Export Compliance)
update_info_plist_encryption() {
    print_step "Info.plist에 암호화 설정 추가 중..."

    local info_plist_path="$PROJECT_PATH/ios/Runner/Info.plist"

    if [ ! -f "$info_plist_path" ]; then
        print_error "Info.plist 파일을 찾을 수 없습니다: $info_plist_path"
        return 1
    fi

    # 이미 ITSAppUsesNonExemptEncryption 키가 있는지 확인
    if grep -q "ITSAppUsesNonExemptEncryption" "$info_plist_path"; then
        print_info "ITSAppUsesNonExemptEncryption이 이미 설정되어 있습니다"
        # 기존 값을 업데이트
        if [ "$USES_NON_EXEMPT_ENCRYPTION" = "true" ]; then
            sed_inplace 's/<key>ITSAppUsesNonExemptEncryption<\/key>[[:space:]]*<false\/>/<key>ITSAppUsesNonExemptEncryption<\/key>\
	<true\/>/g' "$info_plist_path"
        else
            sed_inplace 's/<key>ITSAppUsesNonExemptEncryption<\/key>[[:space:]]*<true\/>/<key>ITSAppUsesNonExemptEncryption<\/key>\
	<false\/>/g' "$info_plist_path"
        fi
        print_success "ITSAppUsesNonExemptEncryption 값 업데이트 완료"
        return 0
    fi

    # 백업 생성
    cp "$info_plist_path" "${info_plist_path}.bak"
    print_info "백업 생성: ${info_plist_path}.bak"

    # </dict> 바로 앞에 ITSAppUsesNonExemptEncryption 추가
    local encryption_value
    if [ "$USES_NON_EXEMPT_ENCRYPTION" = "true" ]; then
        encryption_value="true"
    else
        encryption_value="false"
    fi

    # macOS sed 사용 - </dict> 앞에 새 키 추가
    sed_inplace "s/<\/dict>/<key>ITSAppUsesNonExemptEncryption<\/key>\\
	<${encryption_value}\/>\\
<\/dict>/g" "$info_plist_path"

    # 변경 확인
    if grep -q "ITSAppUsesNonExemptEncryption" "$info_plist_path"; then
        print_success "ITSAppUsesNonExemptEncryption 추가 완료: <$encryption_value/>"
        rm "${info_plist_path}.bak"
    else
        print_error "ITSAppUsesNonExemptEncryption 추가 실패!"
        mv "${info_plist_path}.bak" "$info_plist_path"
        return 1
    fi

    return 0
}

# Xcode 프로젝트의 Bundle ID 변경 (Apple Developer 설정과 일치시키기 위해)
update_bundle_id() {
    print_step "Bundle ID 확인 및 업데이트 중..."

    local pbxproj_path="$PROJECT_PATH/ios/Runner.xcodeproj/project.pbxproj"

    if [ ! -f "$pbxproj_path" ]; then
        print_error "project.pbxproj 파일을 찾을 수 없습니다: $pbxproj_path"
        return 1
    fi

    # 입력한 Bundle ID가 이미 존재하면 스킵
    if grep -q "PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;" "$pbxproj_path"; then
        print_info "Bundle ID가 이미 올바르게 설정되어 있습니다: $BUNDLE_ID"
        return 0
    fi

    # 현재 project.pbxproj에 있는 Runner 앱의 Bundle ID 추출 (RunnerTests 제외)
    local CURRENT_BUNDLE_ID=$(grep "PRODUCT_BUNDLE_IDENTIFIER = " "$pbxproj_path" | grep -v "RunnerTests" | head -1 | sed 's/.*= //' | sed 's/;$//' | tr -d '[:space:]')

    if [ -z "$CURRENT_BUNDLE_ID" ]; then
        print_error "현재 Bundle ID를 찾을 수 없습니다"
        return 1
    fi

    print_info "현재 Bundle ID: $CURRENT_BUNDLE_ID"
    print_info "변경할 Bundle ID: $BUNDLE_ID"

    # Bundle ID가 다르면 변경
    if [ "$CURRENT_BUNDLE_ID" != "$BUNDLE_ID" ]; then
        print_warning "Bundle ID가 다릅니다. 자동으로 변경합니다..."

        # 백업 생성
        cp "$pbxproj_path" "${pbxproj_path}.bundleid.bak"

        # Runner 앱의 Bundle ID 변경 (정확히 매칭)
        sed_inplace "s/PRODUCT_BUNDLE_IDENTIFIER = $CURRENT_BUNDLE_ID;/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;/g" "$pbxproj_path"

        # RunnerTests의 Bundle ID도 함께 변경 (Runner 앱의 Bundle ID + .RunnerTests)
        local CURRENT_TESTS_BUNDLE_ID="${CURRENT_BUNDLE_ID}.RunnerTests"
        local NEW_TESTS_BUNDLE_ID="${BUNDLE_ID}.RunnerTests"
        sed_inplace "s/PRODUCT_BUNDLE_IDENTIFIER = $CURRENT_TESTS_BUNDLE_ID;/PRODUCT_BUNDLE_IDENTIFIER = $NEW_TESTS_BUNDLE_ID;/g" "$pbxproj_path"

        # 변경 확인
        if grep -q "PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;" "$pbxproj_path"; then
            print_success "Bundle ID 변경 완료: $CURRENT_BUNDLE_ID → $BUNDLE_ID"
            rm "${pbxproj_path}.bundleid.bak"
        else
            print_error "Bundle ID 변경 실패!"
            mv "${pbxproj_path}.bundleid.bak" "$pbxproj_path"
            return 1
        fi
    fi

    return 0
}

# Xcode 프로젝트에 DEVELOPMENT_TEAM 및 Manual Signing 추가 (CI 빌드에 필수)
patch_xcode_project() {
    print_step "Xcode 프로젝트에 DEVELOPMENT_TEAM 및 Manual Signing 설정 중..."

    local pbxproj_path="$PROJECT_PATH/ios/Runner.xcodeproj/project.pbxproj"

    if [ ! -f "$pbxproj_path" ]; then
        print_error "project.pbxproj 파일을 찾을 수 없습니다: $pbxproj_path"
        return 1
    fi

    # 먼저 Bundle ID 업데이트 수행
    update_bundle_id
    if [ $? -ne 0 ]; then
        print_error "Bundle ID 업데이트 실패"
        return 1
    fi

    # 백업 생성
    cp "$pbxproj_path" "${pbxproj_path}.bak"
    print_info "백업 생성: ${pbxproj_path}.bak"

    # 이미 DEVELOPMENT_TEAM이 있는지 확인
    if grep -q "DEVELOPMENT_TEAM = $TEAM_ID" "$pbxproj_path"; then
        print_info "DEVELOPMENT_TEAM이 이미 설정되어 있습니다"
        # CODE_SIGN_STYLE도 확인하고 필요시 추가
        if ! grep -q "CODE_SIGN_STYLE = Manual" "$pbxproj_path"; then
            print_info "CODE_SIGN_STYLE = Manual 추가 중..."
            # Automatic을 Manual로 변경하거나 새로 추가
            if grep -q "CODE_SIGN_STYLE = Automatic" "$pbxproj_path"; then
                sed_inplace "s/CODE_SIGN_STYLE = Automatic;/CODE_SIGN_STYLE = Manual;/g" "$pbxproj_path"
            else
                # DEVELOPMENT_TEAM 라인 다음에 CODE_SIGN_STYLE 추가
                sed_inplace "s/DEVELOPMENT_TEAM = $TEAM_ID;/DEVELOPMENT_TEAM = $TEAM_ID;\\
				CODE_SIGN_STYLE = Manual;/g" "$pbxproj_path"
            fi
            print_success "CODE_SIGN_STYLE = Manual 설정 완료"
        fi

        # PROVISIONING_PROFILE_SPECIFIER 업데이트
        if grep -q "PROVISIONING_PROFILE_SPECIFIER" "$pbxproj_path"; then
            sed_inplace "s/\"PROVISIONING_PROFILE_SPECIFIER\" = \"[^\"]*\";/\"PROVISIONING_PROFILE_SPECIFIER\" = \"$PROFILE_NAME\";/g" "$pbxproj_path"
            print_success "PROVISIONING_PROFILE_SPECIFIER 업데이트 완료"
        fi

        rm "${pbxproj_path}.bak"
        print_success "Xcode 프로젝트 확인 완료"
        return 0
    fi

    # DEVELOPMENT_TEAM이 있지만 다른 값이면 교체
    if grep -q "DEVELOPMENT_TEAM = " "$pbxproj_path"; then
        print_info "기존 DEVELOPMENT_TEAM 값을 업데이트합니다"
        sed_inplace "s/DEVELOPMENT_TEAM = [^;]*;/DEVELOPMENT_TEAM = $TEAM_ID;/g" "$pbxproj_path"
        print_success "DEVELOPMENT_TEAM 업데이트 완료"

        # CODE_SIGN_STYLE = Manual 설정
        if grep -q "CODE_SIGN_STYLE = Automatic" "$pbxproj_path"; then
            sed_inplace "s/CODE_SIGN_STYLE = Automatic;/CODE_SIGN_STYLE = Manual;/g" "$pbxproj_path"
            print_success "CODE_SIGN_STYLE = Manual 설정 완료"
        elif ! grep -q "CODE_SIGN_STYLE = Manual" "$pbxproj_path"; then
            sed_inplace "s/DEVELOPMENT_TEAM = $TEAM_ID;/DEVELOPMENT_TEAM = $TEAM_ID;\\
				CODE_SIGN_STYLE = Manual;/g" "$pbxproj_path"
            print_success "CODE_SIGN_STYLE = Manual 추가 완료"
        fi

        # CODE_SIGN_IDENTITY 설정
        if ! grep -q 'CODE_SIGN_IDENTITY = "Apple Distribution"' "$pbxproj_path"; then
            sed_inplace "s/CODE_SIGN_STYLE = Manual;/CODE_SIGN_STYLE = Manual;\\
				CODE_SIGN_IDENTITY = \"Apple Distribution\";/g" "$pbxproj_path"
            print_success "CODE_SIGN_IDENTITY = Apple Distribution 추가 완료"
        fi

        # PROVISIONING_PROFILE_SPECIFIER 설정 (핵심!)
        if ! grep -q "PROVISIONING_PROFILE_SPECIFIER" "$pbxproj_path"; then
            sed_inplace "s/CODE_SIGN_IDENTITY = \"Apple Distribution\";/CODE_SIGN_IDENTITY = \"Apple Distribution\";\\
				\"PROVISIONING_PROFILE_SPECIFIER\" = \"$PROFILE_NAME\";/g" "$pbxproj_path"
            print_success "PROVISIONING_PROFILE_SPECIFIER = $PROFILE_NAME 추가 완료"
        else
            # 기존 값이 있으면 업데이트
            sed_inplace "s/\"PROVISIONING_PROFILE_SPECIFIER\" = \"[^\"]*\";/\"PROVISIONING_PROFILE_SPECIFIER\" = \"$PROFILE_NAME\";/g" "$pbxproj_path"
            print_success "PROVISIONING_PROFILE_SPECIFIER 업데이트 완료"
        fi

        # 구버전 CODE_SIGN_IDENTITY 설정 업데이트
        if grep -q '"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "iPhone Developer"' "$pbxproj_path"; then
            sed_inplace 's/"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "iPhone Developer"/"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution"/g' "$pbxproj_path"
            print_success "CODE_SIGN_IDENTITY[sdk=iphoneos*] 업데이트 완료"
        fi

        rm "${pbxproj_path}.bak"
        return 0
    fi

    # Runner 타겟의 buildSettings에 DEVELOPMENT_TEAM 추가
    # PRODUCT_BUNDLE_IDENTIFIER 라인 다음에 추가
    print_info "DEVELOPMENT_TEAM 추가 중..."

    # Bundle ID가 존재하는지 확인 (update_bundle_id에서 이미 처리했으므로 존재해야 함)
    if ! grep -q "PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;" "$pbxproj_path"; then
        print_error "Bundle ID를 project.pbxproj에서 찾을 수 없습니다!"
        echo ""
        print_error "┌─────────────────────────────────────────────────────────────────┐"
        print_error "│ 입력한 Bundle ID: $BUNDLE_ID"
        print_error "├─────────────────────────────────────────────────────────────────┤"
        print_error "│ project.pbxproj에 존재하는 Bundle ID들:"
        # 실제 존재하는 Bundle ID 목록 출력
        grep "PRODUCT_BUNDLE_IDENTIFIER = " "$pbxproj_path" | sed 's/.*= /  • /' | sed 's/;$//' | sort -u | while read line; do
            print_error "│ $line"
        done
        print_error "└─────────────────────────────────────────────────────────────────┘"
        echo ""
        print_error "해결 방법:"
        print_info "1. 위 목록에서 정확한 Bundle ID를 확인하세요 (대소문자 구분!)"
        print_info "2. 올바른 Bundle ID로 스크립트를 다시 실행하세요"
        print_info "   예: ./init.sh \"$PROJECT_PATH\" \"정확한.번들.아이디\" \"$TEAM_ID\" \"$PROFILE_NAME\""
        mv "${pbxproj_path}.bak" "$pbxproj_path"
        return 1
    fi

    # macOS sed 사용 (BSD sed)
    # Runner 앱의 Bundle ID 라인 다음에 Manual Signing 관련 설정 모두 추가
    # - DEVELOPMENT_TEAM: Apple 팀 ID
    # - CODE_SIGN_STYLE: Manual (자동 서명 비활성화)
    # - CODE_SIGN_IDENTITY: Apple Distribution (배포용 인증서)
    # - PROVISIONING_PROFILE_SPECIFIER: 프로비저닝 프로파일 이름
    sed_inplace "s/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;\\
				DEVELOPMENT_TEAM = $TEAM_ID;\\
				CODE_SIGN_STYLE = Manual;\\
				CODE_SIGN_IDENTITY = \"Apple Distribution\";\\
				\"PROVISIONING_PROFILE_SPECIFIER\" = \"$PROFILE_NAME\";/g" "$pbxproj_path"

    # 구버전 CODE_SIGN_IDENTITY 설정이 있으면 Apple Distribution으로 변경
    if grep -q '"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "iPhone Developer"' "$pbxproj_path"; then
        sed_inplace 's/"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "iPhone Developer"/"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution"/g' "$pbxproj_path"
        print_success "CODE_SIGN_IDENTITY[sdk=iphoneos*] 업데이트 완료"
    fi

    # 변경 확인
    if grep -q "DEVELOPMENT_TEAM = $TEAM_ID" "$pbxproj_path" && grep -q "CODE_SIGN_STYLE = Manual" "$pbxproj_path"; then
        print_success "DEVELOPMENT_TEAM 추가 완료: $TEAM_ID"
        print_success "CODE_SIGN_STYLE = Manual 설정 완료"
        rm "${pbxproj_path}.bak"
    else
        print_error "DEVELOPMENT_TEAM 또는 CODE_SIGN_STYLE 추가 실패!"
        echo ""
        print_error "디버그 정보:"
        print_info "  • 입력한 Bundle ID: $BUNDLE_ID"
        print_info "  • 입력한 Team ID: $TEAM_ID"
        print_info "  • project.pbxproj 경로: $pbxproj_path"
        echo ""
        print_error "가능한 원인:"
        print_info "  1. sed 명령어 실행 중 오류 발생"
        print_info "  2. 파일 쓰기 권한 문제"
        echo ""
        print_warning "수동 설정 방법:"
        print_info "  Xcode 열기 → Runner 타겟 → Signing & Capabilities → Team 선택"
        mv "${pbxproj_path}.bak" "$pbxproj_path"
        return 1
    fi

    print_success "Xcode 프로젝트 설정 완료 (Manual Signing 적용됨)"
}

# 완료 메시지
print_completion() {
    # 암호화 설정 표시 텍스트
    local encryption_display
    if [ "$USES_NON_EXEMPT_ENCRYPTION" = "true" ]; then
        encryption_display="Standard encryption (true)"
    else
        encryption_display="None - HTTPS only (false)"
    fi

    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          🎉 iOS TestFlight 배포 설정 완료! 🎉                  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}★ 마법사 우선 아키텍처 ★${NC}"
    echo "  모든 설정이 완료되었습니다. 워크플로우는 이 파일들을 그대로 사용합니다."
    echo ""
    echo -e "${CYAN}생성/수정된 파일:${NC}"
    echo "  ✅ ios/Gemfile                    (Fastlane 의존성)"
    echo "  ✅ ios/fastlane/Fastfile          (TestFlight 업로드) ★ 워크플로우에서 직접 사용"
    echo "  ✅ ios/ExportOptions.plist        (IPA 익스포트 설정) ★ 핵심"
    echo "  ✅ ios/Runner.xcodeproj           (Manual Signing 패치) ★ 핵심"
    echo "  ✅ ios/Runner/Info.plist          (암호화 설정)"
    echo ""
    echo -e "${CYAN}설정된 정보:${NC}"
    echo "  • Bundle ID: $BUNDLE_ID"
    echo "  • Team ID: $TEAM_ID"
    echo "  • Profile Name: $PROFILE_NAME"
    echo "  • Code Sign Style: Manual"
    echo "  • 암호화 설정: $encryption_display"
    echo ""
    echo -e "${CYAN}빌드 파이프라인:${NC}"
    echo "  1. flutter build ios --no-codesign"
    echo "  2. xcodebuild archive"
    echo "  3. xcodebuild -exportArchive (ExportOptions.plist 사용)"
    echo "  4. fastlane upload_testflight (Fastfile의 lane 사용)"
    echo ""
    echo -e "${YELLOW}다음 단계:${NC}"
    echo "  1. GitHub Secrets 설정:"
    echo "     • APPLE_CERTIFICATE_BASE64"
    echo "     • APPLE_CERTIFICATE_PASSWORD"
    echo "     • APPLE_PROVISIONING_PROFILE_BASE64"
    echo "     • IOS_PROVISIONING_PROFILE_NAME"
    echo "     • APP_STORE_CONNECT_API_KEY_ID"
    echo "     • APP_STORE_CONNECT_ISSUER_ID"
    echo "     • APP_STORE_CONNECT_API_KEY_BASE64"
    echo ""
    echo "  2. 변경사항 커밋:"
    echo "     git add ios/"
    echo "     git commit -m \"chore: iOS TestFlight 배포 설정\""
    echo ""
    echo "  3. deploy 브랜치로 푸시하여 빌드 테스트"
    echo ""
    echo "🎛️  배포 모드 설정 (선택):"
    echo "   GitHub repo Variables에 IOS_DEPLOY_MODE 를 설정하면 기본 배포 범위를 정할 수 있습니다."
    echo "     store_only    : TestFlight 업로드까지만 (기본)"
    echo "     store_prepare : App Store 제출 직전까지 (사람이 ASC에서 Add for Review)"
    echo "     store_submit  : App Store 심사 자동 제출 (정식 출시 1회 수동 이후부터 가능)"
    echo "   워크플로우 수동 실행 시 deploy_mode 입력이 이 변수보다 우선합니다."
}

# ===================================================================
# 메인 실행
# ===================================================================

main() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       Flutter iOS TestFlight 초기화 스크립트                   ║${NC}"
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
    echo -e "${BLUE}Bundle ID:${NC} $BUNDLE_ID"
    echo -e "${BLUE}Team ID:${NC} $TEAM_ID"
    echo -e "${BLUE}Profile Name:${NC} $PROFILE_NAME"
    echo -e "${BLUE}암호화 사용:${NC} $USES_NON_EXEMPT_ENCRYPTION"
    echo ""

    # 템플릿 디렉토리 찾기
    find_template_dir

    # 파일 생성
    create_gemfile
    create_fastfile
    create_export_options_plist
    update_gitignore
    patch_xcode_project
    update_info_plist_encryption

    # 완료
    print_completion
}

# 스크립트 실행
main "$@"
