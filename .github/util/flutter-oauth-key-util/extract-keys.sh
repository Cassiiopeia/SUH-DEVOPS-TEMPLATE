#!/bin/bash

# ===================================================================
# Flutter OAuth Key Extractor (macOS/Linux)
# ===================================================================
#
# 이 스크립트는 Android keystore에서 OAuth 인증에 필요한 키를 추출합니다.
#
# 지원하는 OAuth 제공자:
#   - Google / Firebase (SHA-1, SHA-256)
#   - Kakao (Key Hash)
#   - Facebook (Key Hash)
#   - Naver (안내만 제공)
#
# 사용법:
#   ./extract-keys.sh                    # 대화형 모드
#   ./extract-keys.sh --debug            # 디버그 키스토어 자동 사용
#   ./extract-keys.sh -k /path/to/keystore -a alias -p password
#
# ===================================================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 기본값
KEYSTORE_PATH=""
ALIAS=""
PASSWORD=""
DEBUG_MODE=false
OUTPUT_FILE="oauth-keys.json"

# 출력 함수
print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BOLD}🔐 Flutter OAuth Key Extractor${NC}                                  ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  Extract SHA-1, SHA-256, Key Hash from Android Keystore         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}  For Google, Firebase, Kakao, Facebook, Naver OAuth             ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    echo -e "${CYAN}▶${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✔${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✖${NC} $1"
}

# 도움말
show_help() {
    cat << EOF
${BOLD}Flutter OAuth Key Extractor${NC}

${BOLD}사용법:${NC}
  ./extract-keys.sh [옵션]

${BOLD}옵션:${NC}
  -k, --keystore PATH    키스토어 파일 경로
  -a, --alias NAME       키 별칭 (기본: androiddebugkey)
  -p, --password PASS    키스토어 비밀번호 (기본: android)
  --debug                디버그 키스토어 자동 사용
  -o, --output FILE      출력 파일명 (기본: oauth-keys.json)
  -h, --help             도움말

${BOLD}예시:${NC}
  # 대화형 모드
  ./extract-keys.sh

  # 디버그 키스토어 (자동)
  ./extract-keys.sh --debug

  # 릴리즈 키스토어
  ./extract-keys.sh -k ~/my-release-key.jks -a my-alias -p mypassword

${BOLD}출력:${NC}
  oauth-keys.json 파일이 생성됩니다.
  index.html을 열어서 결과를 확인하세요.

EOF
}

# 파라미터 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        -k|--keystore)
            KEYSTORE_PATH="$2"
            shift 2
            ;;
        -a|--alias)
            ALIAS="$2"
            shift 2
            ;;
        -p|--password)
            PASSWORD="$2"
            shift 2
            ;;
        --debug)
            DEBUG_MODE=true
            shift
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "알 수 없는 옵션: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
done

# keytool 확인
check_keytool() {
    if ! command -v keytool &> /dev/null; then
        print_error "keytool을 찾을 수 없습니다."
        print_info "JDK를 설치해주세요: https://adoptium.net/"
        exit 1
    fi
    print_success "keytool 확인됨"
}

# openssl 확인
check_openssl() {
    if ! command -v openssl &> /dev/null; then
        print_error "openssl을 찾을 수 없습니다."
        print_info "openssl을 설치해주세요."
        exit 1
    fi
    print_success "openssl 확인됨"
}

# 디버그 키스토어 경로 찾기
find_debug_keystore() {
    local debug_keystore=""

    # macOS / Linux 기본 경로
    if [[ -f "$HOME/.android/debug.keystore" ]]; then
        debug_keystore="$HOME/.android/debug.keystore"
    fi

    echo "$debug_keystore"
}

# 대화형 모드
interactive_mode() {
    print_step "키스토어 설정"
    echo ""
    echo "  1) 디버그 키스토어 (자동 감지)"
    echo "  2) 릴리즈 키스토어 (경로 입력)"
    echo ""

    read -p "  선택 (1/2): " choice

    case $choice in
        1)
            KEYSTORE_PATH=$(find_debug_keystore)
            if [[ -z "$KEYSTORE_PATH" ]]; then
                print_error "디버그 키스토어를 찾을 수 없습니다."
                print_info "경로: ~/.android/debug.keystore"
                exit 1
            fi
            ALIAS="androiddebugkey"
            PASSWORD="android"
            print_info "디버그 키스토어: $KEYSTORE_PATH"
            ;;
        2)
            read -p "  키스토어 경로: " KEYSTORE_PATH
            if [[ ! -f "$KEYSTORE_PATH" ]]; then
                print_error "파일을 찾을 수 없습니다: $KEYSTORE_PATH"
                exit 1
            fi
            read -p "  별칭 (alias): " ALIAS
            read -sp "  비밀번호: " PASSWORD
            echo ""
            ;;
        *)
            print_error "잘못된 선택입니다."
            exit 1
            ;;
    esac
}

# SHA-1 추출
extract_sha1() {
    local sha1=$(keytool -list -v \
        -keystore "$KEYSTORE_PATH" \
        -alias "$ALIAS" \
        -storepass "$PASSWORD" 2>/dev/null | \
        grep "SHA1:" | awk '{print $2}')

    echo "$sha1"
}

# SHA-256 추출
extract_sha256() {
    local sha256=$(keytool -list -v \
        -keystore "$KEYSTORE_PATH" \
        -alias "$ALIAS" \
        -storepass "$PASSWORD" 2>/dev/null | \
        grep "SHA256:" | awk '{print $2}')

    echo "$sha256"
}

# Key Hash 추출 (Kakao, Facebook용)
extract_key_hash() {
    local key_hash=$(keytool -exportcert \
        -keystore "$KEYSTORE_PATH" \
        -alias "$ALIAS" \
        -storepass "$PASSWORD" 2>/dev/null | \
        openssl sha1 -binary | \
        openssl base64)

    echo "$key_hash"
}

# JSON 생성
generate_json() {
    local sha1="$1"
    local sha256="$2"
    local key_hash="$3"
    local sha1_no_colon=$(echo "$sha1" | tr -d ':')
    local sha256_no_colon=$(echo "$sha256" | tr -d ':')
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat > "$OUTPUT_FILE" << EOF
{
  "generated_at": "$timestamp",
  "keystore": {
    "path": "$KEYSTORE_PATH",
    "alias": "$ALIAS",
    "type": "$(if [[ "$DEBUG_MODE" == true ]] || [[ "$KEYSTORE_PATH" == *"debug"* ]]; then echo "debug"; else echo "release"; fi)"
  },
  "keys": {
    "sha1": "$sha1",
    "sha1_no_colon": "$sha1_no_colon",
    "sha256": "$sha256",
    "sha256_no_colon": "$sha256_no_colon",
    "key_hash_base64": "$key_hash"
  },
  "platforms": {
    "google_firebase": {
      "sha1": "$sha1_no_colon",
      "sha256": "$sha256_no_colon",
      "console_url": "https://console.firebase.google.com"
    },
    "kakao": {
      "key_hash": "$key_hash",
      "console_url": "https://developers.kakao.com"
    },
    "facebook": {
      "key_hash": "$key_hash",
      "console_url": "https://developers.facebook.com"
    },
    "naver": {
      "note": "Package Name 기반 설정",
      "console_url": "https://developers.naver.com"
    }
  }
}
EOF
}

# 결과 출력
print_results() {
    local sha1="$1"
    local sha256="$2"
    local key_hash="$3"

    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}📱 추출된 OAuth 키${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Google / Firebase
    echo -e "${RED}🔥 Google / Firebase${NC}"
    echo -e "────────────────────────────────────────────────────────────────────"
    echo -e "  SHA-1:          ${GREEN}$sha1${NC}"
    echo -e "  SHA-1 (콜론없음): ${GREEN}$(echo $sha1 | tr -d ':')${NC}"
    echo -e "  SHA-256:        ${GREEN}$sha256${NC}"
    echo ""

    # Kakao
    echo -e "${YELLOW}🟡 Kakao${NC}"
    echo -e "────────────────────────────────────────────────────────────────────"
    echo -e "  Key Hash:       ${GREEN}$key_hash${NC}"
    echo ""

    # Facebook
    echo -e "${BLUE}🔵 Facebook${NC}"
    echo -e "────────────────────────────────────────────────────────────────────"
    echo -e "  Key Hash:       ${GREEN}$key_hash${NC}"
    echo ""

    echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# 메인 실행
main() {
    print_banner

    # 의존성 확인
    print_step "의존성 확인 중..."
    check_keytool
    check_openssl
    echo ""

    # 디버그 모드 또는 대화형 모드
    if [[ "$DEBUG_MODE" == true ]]; then
        KEYSTORE_PATH=$(find_debug_keystore)
        if [[ -z "$KEYSTORE_PATH" ]]; then
            print_error "디버그 키스토어를 찾을 수 없습니다."
            exit 1
        fi
        ALIAS="androiddebugkey"
        PASSWORD="android"
        print_info "디버그 키스토어: $KEYSTORE_PATH"
    elif [[ -z "$KEYSTORE_PATH" ]]; then
        interactive_mode
    fi

    # 키스토어 확인
    if [[ ! -f "$KEYSTORE_PATH" ]]; then
        print_error "키스토어 파일을 찾을 수 없습니다: $KEYSTORE_PATH"
        exit 1
    fi

    echo ""
    print_step "키 추출 중..."

    # 키 추출
    SHA1=$(extract_sha1)
    if [[ -z "$SHA1" ]]; then
        print_error "SHA-1 추출 실패. 비밀번호 또는 별칭을 확인해주세요."
        exit 1
    fi

    SHA256=$(extract_sha256)
    KEY_HASH=$(extract_key_hash)

    print_success "키 추출 완료"

    # 결과 출력
    print_results "$SHA1" "$SHA256" "$KEY_HASH"

    # JSON 생성
    generate_json "$SHA1" "$SHA256" "$KEY_HASH"
    print_success "결과 저장됨: $OUTPUT_FILE"
    echo ""
    print_info "index.html을 열어서 결과를 확인하고 복사하세요!"
    echo ""
}

# 스크립트 실행
main
