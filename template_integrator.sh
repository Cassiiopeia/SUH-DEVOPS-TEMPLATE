#!/bin/bash

# ===================================================================
# GitHub 템플릿 통합 스크립트 v1.0.0
# ===================================================================
#
# 이 스크립트는 기존 프로젝트에 SUH-DEVOPS-TEMPLATE의 기능을
# 선택적으로 통합합니다.
#
# 주요 기능:
# 1. 기존 README.md 보존 및 버전 정보 섹션 자동 추가
# 2. package.json, pubspec.yaml 등에서 버전과 타입 자동 감지
# 3. GitHub Actions 워크플로우 선택적 복사
# 4. 충돌 파일 자동 처리 및 백업
# 5. version.yml 생성 (기존 프로젝트 정보 유지)
#
# 사용법:
# 
# 방법 1: 로컬 다운로드 후 실행
# curl -o template_integrator.sh \
#   https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh
# chmod +x template_integrator.sh
# ./template_integrator.sh [옵션]
#
# 방법 2: 원격 실행 - 대화형 (추천)
# bash <(curl -fsSL https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main/template_integrator.sh)
#
# 방법 3: 원격 실행 - 자동화 (CI/CD)
# bash <(curl -fsSL https://raw.../template_integrator.sh) --mode full --force
# curl -fsSL https://raw.../template_integrator.sh | bash -s -- --mode version --force
#
# 옵션:
#   -m, --mode MODE          통합 모드 선택 (기본: interactive)
#                            • full        - 전체 통합 (버전관리+워크플로우+이슈템플릿)
#                            • version     - 버전 관리 시스템만
#                            • workflows   - GitHub Actions 워크플로우만
#                            • issues      - 이슈/PR 템플릿만
#                            • skills      - Agent Skill 설치만 (Claude, Cursor)
#                            • interactive - 대화형 선택 (기본값)
#   -v, --version VERSION    초기 버전 설정 (자동 감지, 수동 지정 가능)
#   -t, --type TYPE          프로젝트 타입 (자동 감지, 수동 지정 가능)
#                            지원: spring, flutter, react, react-native,
#                                  react-native-expo, node, python, basic
#   --no-backup              백업 생성 안 함 (기본: 백업 생성)
#   --force                  확인 없이 즉시 실행
#   -h, --help               도움말 표시
#
# 예시:
#   # 대화형 모드 (추천)
#   ./template_integrator.sh
#
#   # 버전 관리 시스템만 추가
#   ./template_integrator.sh --mode version
#
#   # 전체 통합 (자동 감지)
#   ./template_integrator.sh --mode full
#
#   # Node.js 프로젝트로 버전 1.0.0 설정
#   ./template_integrator.sh --mode full --version 1.0.0 --type node
#
# ===================================================================

set -e  # 에러 발생 시 스크립트 중단

# ===================================================================
# SSL 인증서 관련 환경 변수 초기화
# 사용자 환경에서 잘못 설정된 CA 경로 문제 방지
# (예: curl: (77) error setting certificate verify locations: CAfile: /tmp/cacert.pem)
# ===================================================================
unset CURL_CA_BUNDLE
unset SSL_CERT_FILE
unset SSL_CERT_DIR
unset REQUESTS_CA_BUNDLE

# stdin 모드 및 TTY 가용성 감지
STDIN_MODE=false
TTY_AVAILABLE=true

# 터미널 상태 감지 함수
detect_terminal() {
    # stdin이 터미널인지 확인
    if [ -t 0 ]; then
        STDIN_MODE=false
        TTY_AVAILABLE=true
        return
    fi
    
    # stdin은 파이프지만 /dev/tty 접근 가능한지 확인
    STDIN_MODE=true
    if [ -c /dev/tty ] 2>/dev/null; then
        # /dev/tty 읽기 테스트
        if exec 3< /dev/tty 2>/dev/null; then
            exec 3>&-  # 파일 디스크립터 닫기
            TTY_AVAILABLE=true
        else
            TTY_AVAILABLE=false
        fi
    else
        TTY_AVAILABLE=false
    fi
}

# 색상 정의 (비활성화 - 안정성 향상)
RED=''
GREEN=''
YELLOW=''
BLUE=''
CYAN=''
MAGENTA=''
NC=''

# 템플릿 저장소 URL
TEMPLATE_REPO="https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE.git"
TEMP_DIR=".template_download_temp"

# 상수 정의
readonly TEMPLATE_RAW_URL="https://raw.githubusercontent.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE/main"
readonly VERSION_FILE="version.yml"
readonly WORKFLOWS_DIR=".github/workflows"
readonly SCRIPTS_DIR=".github/scripts"
readonly PROJECT_TYPES_DIR="project-types"
readonly DEFAULT_VERSION="1.3.14"

# 다운로드한 템플릿의 실제 버전 (download_template에서 설정됨)
TEMPLATE_VERSION=""

# 워크플로우 파일명 패턴
readonly WORKFLOW_PREFIX="PROJECT"
readonly WORKFLOW_COMMON_PREFIX="PROJECT-COMMON"
readonly WORKFLOW_TEMPLATE_INIT="PROJECT-TEMPLATE-INITIALIZER.yaml"

# 출력 함수 (/dev/tty 우선, 없으면 stderr로 폴백하여 명령어 치환 시 데이터 오염 방지)

# 출력 대상 선택 헬퍼 (중복 제거)
get_output_target() {
    if [ -w /dev/tty ] 2>/dev/null; then
        echo "/dev/tty"
    else
        echo "/dev/stderr"
    fi
}

# 안전한 출력 헬퍼
safe_echo() {
    local target=$(get_output_target)
    if [ "$target" = "/dev/tty" ]; then
        echo "$@" >/dev/tty
    else
        echo "$@" >&2
    fi
}

safe_echo_e() {
    local target=$(get_output_target)
    if [ "$target" = "/dev/tty" ]; then
        echo -e "$@" >/dev/tty
    else
        echo -e "$@" >&2
    fi
}

print_header() {
    safe_echo ""
    safe_echo_e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    safe_echo_e "${CYAN}║$1${NC}"
    safe_echo_e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    safe_echo ""
}

# 멋진 배너 출력 (템플릿 버전 표시)
print_banner() {
    local version=$1
    local mode=$2
    
    safe_echo ""
    safe_echo "╔══════════════════════════════════════════════════════════════════╗"
    safe_echo "║ 🔮  ✦ S U H · D E V O P S · T E M P L A T E ✦                    ║"
    safe_echo "╚══════════════════════════════════════════════════════════════════╝"
    safe_echo "       🌙 Version : v${version}"
    safe_echo "       🐵 Author  : Cassiiopeia"
    safe_echo "       🪐 Mode    : ${mode}"
    safe_echo "       📦 Repo    : github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE"
    safe_echo ""
}

print_step() {
    safe_echo_e "${CYAN}🔅${NC} $1"
}

print_info() {
    safe_echo_e "  ${BLUE}🔸${NC} $1"
}

print_success() {
    safe_echo_e "${GREEN}✨${NC} $1"
}

print_warning() {
    safe_echo_e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    safe_echo_e "${RED}💥${NC} $1"
}

print_question() {
    safe_echo_e "${MAGENTA}💫${NC} $1"
}

# 안전한 read 함수 (/dev/tty 사용)
safe_read() {
    local prompt="$1"
    local varname="$2"
    local options="$3"
    
    if [ "$TTY_AVAILABLE" = true ]; then
        printf "%s" "$prompt" > /dev/tty
        
        if [ "$options" = "-n 1" ]; then
            IFS= read -r -n 1 "$varname" < /dev/tty
        elif [ -n "$options" ]; then
            IFS= read -r $options "$varname" < /dev/tty
        else
            IFS= read -r "$varname" < /dev/tty
        fi
        return 0
    else
        return 1
    fi
}

# 안전한 출력 함수 (TTY 우선, stderr 폴백)
print_to_user() {
    safe_echo "$@"
}

# Y/N 질문 함수 (기본값 지원)
# 반환: 0 (Yes), 1 (No)
ask_yes_no() {
    local prompt="$1"
    local default="${2:-N}"  # 기본값 N
    local reply
    
    while true; do
        if safe_read "$prompt" reply "-n 1"; then
            print_to_user ""
            
            # Enter 키 처리
            if [[ -z "$reply" ]]; then
                reply="$default"
            fi
            
            if [[ "$reply" =~ ^[Yy]$ ]]; then
                return 0
            elif [[ "$reply" =~ ^[Nn]$ ]]; then
                return 1
            else
                print_error "잘못된 입력입니다. Y/y 또는 N/n을 입력해주세요. (Enter는 $default)"
                print_to_user ""
            fi
        else
            return 1
        fi
    done
}

# Y/N/E 질문 함수 (예/아니오/편집)
# 출력: "yes", "no", "edit" (set -e 모드 호환)
ask_yes_no_edit() {
    local reply
    local reply_normalized
    
    while true; do
        if safe_read "선택: " reply "-n 1"; then
            print_to_user ""
            
            # 입력값 정규화 (tr 에러 무시, 공백 제거, 소문자 변환)
            reply_normalized=$(printf '%s' "$reply" | tr -d '[:space:]' 2>/dev/null | tr '[:upper:]' '[:lower:]' 2>/dev/null)
            
            # 정규화 실패 시 원본 사용 (한국어 등)
            if [ -z "$reply_normalized" ] && [ -n "$reply" ]; then
                print_error "영문자만 입력해주세요. (Y/y, E/e, N/n)"
                print_to_user ""
                continue
            fi
            
            case "$reply_normalized" in
                ""|"y")
                    echo "yes"
                    return 0
                    ;;
                "n")
                    echo "no"
                    return 0
                    ;;
                "e")
                    echo "edit"
                    return 0
                    ;;
                *)
                    print_error "잘못된 입력입니다. Y/y, E/e, 또는 N/n을 입력해주세요."
                    print_to_user ""
                    ;;
            esac
        else
            print_error "입력을 읽을 수 없습니다"
            exit 1
        fi
    done
}

# 도움말 표시
show_help() {
    cat << EOF
${CYAN}GitHub 템플릿 통합 스크립트 v1.0.0${NC}

${BLUE}사용법:${NC}
  ./template_integrator.sh [옵션]

${BLUE}통합 모드:${NC}
  ${GREEN}full${NC}        - 전체 통합 (버전관리 + 워크플로우 + 이슈템플릿)
  ${GREEN}version${NC}     - 버전 관리 시스템만 (version.yml + scripts)
  ${GREEN}workflows${NC}   - GitHub Actions 워크플로우만
  ${GREEN}issues${NC}      - 이슈/PR 템플릿만
  ${GREEN}skills${NC}      - Agent Skill 설치만 (Claude, Cursor)
  ${GREEN}interactive${NC} - 대화형 선택 (기본값, 추천)

${BLUE}옵션:${NC}
  -m, --mode MODE          통합 모드 선택
  -v, --version VERSION    초기 버전 (미지정 시 자동 감지)
  -t, --type TYPE          프로젝트 타입 (미지정 시 자동 감지)
  --no-backup              백업 생성 안 함
  --force                  확인 없이 즉시 실행
  --synology               Synology 워크플로우 포함 (기본: 제외)
  --no-synology            Synology 워크플로우 제외
  -h, --help               이 도움말 표시

${BLUE}지원 프로젝트 타입:${NC}
  • ${GREEN}node${NC} / ${GREEN}react${NC} / ${GREEN}react-native${NC} - Node.js 기반 프로젝트
  • ${GREEN}spring${NC}            - Spring Boot 백엔드
  • ${GREEN}flutter${NC}           - Flutter 모바일 앱
  • ${GREEN}python${NC}            - Python 프로젝트
  • ${GREEN}basic${NC}             - 기타 프로젝트

${BLUE}자동 감지 기능:${NC}
  우선순위 1 (명확한 프레임워크 마커):
    • pubspec.yaml → Flutter
    • build.gradle/pom.xml → Spring Boot
    • pyproject.toml → Python
  우선순위 2 (Node.js 에코시스템 세부 분류):
    • package.json 내용 분석
      - @react-native → React Native
      - "next" → Next.js
      - "react" → React
      - 기타 → Node.js

${BLUE}사용 예시:${NC}
  # 로컬 실행 - 대화형 모드 (추천)
  ${GREEN}./template_integrator.sh${NC}

  # 원격 실행 - 대화형 모드 (curl 사용)
  ${GREEN}bash <(curl -fsSL https://raw.../template_integrator.sh)${NC}

  # 버전 관리만 추가
  ${GREEN}./template_integrator.sh --mode version${NC}

  # 전체 통합 (자동 감지)
  ${GREEN}./template_integrator.sh --mode full${NC}

  # 원격 실행 + 파라미터 (CI/CD, 자동화)
  ${GREEN}bash <(curl -fsSL https://raw.../template_integrator.sh) --mode full --force${NC}

  # 수동 설정
  ${GREEN}./template_integrator.sh --mode full --version 1.0.0 --type node${NC}

${BLUE}통합 후 작업:${NC}
  1. ${CYAN}README.md${NC} - 버전 정보 섹션 자동 추가됨 (기존 내용 보존)
  2. ${CYAN}version.yml${NC} - 버전 관리 설정 파일 생성
  3. ${CYAN}.github/workflows/${NC} - 워크플로우 파일 추가
  4. ${CYAN}.template_integration/${NC} - 백업 및 롤백 스크립트

${BLUE}stdin 모드 (curl | bash):${NC}
  ${GREEN}bash <(curl)${NC} 또는 ${GREEN}curl | bash${NC} 방식으로 실행 시:
  • /dev/tty를 통해 대화형 입력 가능 (Homebrew 방식)
  • CI/CD 환경(TTY 없음)에서는 --mode, --force 옵션 필수
  
  ${GREEN}# CI/CD 환경 예시${NC}
  ${GREEN}curl -fsSL URL | bash -s -- --mode version --force${NC}

${YELLOW}⚠️  주의사항:${NC}
  • 기존 README.md, LICENSE는 절대 덮어쓰지 않습니다
  • 충돌하는 워크플로우는 .bak 파일로 백업됩니다
  • Git 저장소가 아니면 경고만 표시하고 계속 진행합니다
  • 문서 파일(*.md)은 자동 제외됩니다

${BLUE}롤백:${NC}
  ${GREEN}./.template_integration/rollback.sh${NC}

EOF
}

# 기본값 설정
MODE="interactive"
VERSION=""
PROJECT_TYPE=""
FORCE_MODE=false
IS_INTERACTIVE_MODE=false  # interactive_mode()에서 왔는지 추적
INCLUDE_SYNOLOGY=""  # Synology 워크플로우 포함 여부 (빈 값: 미설정, true/false: 명시적 설정)

# 지원하는 프로젝트 타입
VALID_TYPES=("spring" "flutter" "react" "react-native" "react-native-expo" "node" "python" "basic")

# 파라미터 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -t|--type)
            PROJECT_TYPE="$2"
            shift 2
            ;;
        --force)
            FORCE_MODE=true
            shift
            ;;
        --synology|--include-synology)
            INCLUDE_SYNOLOGY=true
            shift
            ;;
        --no-synology)
            INCLUDE_SYNOLOGY=false
            shift
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

# 프로젝트 타입 자동 감지
detect_project_type() {
    print_step "프로젝트 타입 자동 감지 중..."

    # ===================================================
    # 우선순위 1: 명확한 프레임워크 마커 파일 체크
    # Flutter, Spring, Python은 고유한 마커 파일을 가지므로 우선 체크
    # ===================================================

    # Flutter
    if [ -f "pubspec.yaml" ]; then
        print_info "감지됨: Flutter"
        echo "flutter"
        return
    fi

    # Spring Boot
    if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ] || [ -f "pom.xml" ]; then
        print_info "감지됨: Spring Boot"
        echo "spring"
        return
    fi

    # Python
    if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
        print_info "감지됨: Python"
        echo "python"
        return
    fi

    # ===================================================
    # 우선순위 2: Node.js 에코시스템 세부 분류
    # package.json은 여러 프로젝트 타입에서 보조 도구로 사용될 수 있으므로 나중에 체크
    # ===================================================

    # Node.js / React / React Native / Next.js
    if [ -f "package.json" ]; then
        # React Native 체크
        if grep -q "@react-native" package.json || grep -q "react-native" package.json; then
            # Expo 체크
            if grep -q "expo" package.json; then
                print_info "감지됨: React Native (Expo)"
                echo "react-native-expo"
                return
            else
                print_info "감지됨: React Native"
                echo "react-native"
                return
            fi
        fi

        # Next.js 체크 (React보다 먼저 체크해야 함)
        if grep -q "\"next\"" package.json; then
            print_info "감지됨: Next.js"
            echo "next"
            return
        fi

        # React 체크
        if grep -q "\"react\"" package.json; then
            print_info "감지됨: React"
            echo "react"
            return
        fi

        # 기본 Node.js
        print_info "감지됨: Node.js"
        echo "node"
        return
    fi

    # ===================================================
    # 감지 실패
    # ===================================================
    print_warning "프로젝트 타입을 감지하지 못했습니다. 기본(basic) 타입으로 설정합니다."
    echo "basic"
}

# 버전 자동 감지
detect_version() {
    print_step "버전 정보 자동 감지 중..."
    
    local detected_version=""
    
    # package.json
    if [ -f "package.json" ] && command -v jq >/dev/null 2>&1; then
        detected_version=$(jq -r '.version // empty' package.json 2>/dev/null)
        if [ -n "$detected_version" ]; then
            print_info "package.json에서 발견: v$detected_version"
            echo "$detected_version"
            return
        fi
    fi
    
    # build.gradle (Spring Boot)
    if [ -f "build.gradle" ]; then
        detected_version=$(grep -oP "version\s*=\s*['\"]?\K[0-9]+\.[0-9]+\.[0-9]+" build.gradle | head -1)
        if [ -n "$detected_version" ]; then
            print_info "build.gradle에서 발견: v$detected_version"
            echo "$detected_version"
            return
        fi
    fi
    
    # pubspec.yaml (Flutter)
    if [ -f "pubspec.yaml" ]; then
        detected_version=$(grep -oP "version:\s*\K[0-9]+\.[0-9]+\.[0-9]+" pubspec.yaml | head -1)
        if [ -n "$detected_version" ]; then
            print_info "pubspec.yaml에서 발견: v$detected_version"
            echo "$detected_version"
            return
        fi
    fi
    
    # pyproject.toml (Python)
    if [ -f "pyproject.toml" ]; then
        detected_version=$(grep -oP "version\s*=\s*['\"]?\K[0-9]+\.[0-9]+\.[0-9]+" pyproject.toml | head -1)
        if [ -n "$detected_version" ]; then
            print_info "pyproject.toml에서 발견: v$detected_version"
            echo "$detected_version"
            return
        fi
    fi
    
    # Git 태그
    if git rev-parse --git-dir > /dev/null 2>&1; then
        detected_version=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
        if [ -n "$detected_version" ]; then
            print_info "Git 태그에서 발견: v$detected_version"
            echo "$detected_version"
            return
        fi
    fi
    
    # 기본값
    print_warning "버전을 감지하지 못했습니다. 기본값 0.0.1로 설정합니다."
    echo "0.0.1"
}

# Default branch 감지
detect_default_branch() {
    local detected=""
    
    # GitHub CLI
    if command -v gh >/dev/null 2>&1; then
        detected=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "")
        if [ -n "$detected" ]; then
            echo "$detected"
            return
        fi
    fi
    
    # git symbolic-ref
    detected=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "")
    if [ -n "$detected" ]; then
        echo "$detected"
        return
    fi
    
    # git remote show
    detected=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | sed 's/.*: //' || echo "")
    if [ -n "$detected" ]; then
        echo "$detected"
        return
    fi
    
    # 기본값
    echo "main"
}

# 구분선 출력 (40자)
print_separator_line() {
    local line="────────────────────────────────────────"
    safe_echo "$line"
}

# 섹션 헤더 출력 (80자 구분선)
print_section_header() {
    local emoji="$1"
    local title="$2"
    local line="────────────────────────────────────────────────────────────────────────────────"
    
    safe_echo ""
    safe_echo "$line"
    safe_echo "$emoji $title"
    safe_echo "$line"
}

# 질문 헤더 출력 (40자 구분선)
print_question_header() {
    local emoji="$1"
    local question="$2"
    
    safe_echo ""
    print_separator_line
    safe_echo "$emoji $question"
    print_separator_line
    safe_echo ""
}

# 프로젝트 타입 선택 메뉴
show_project_type_menu() {
    print_to_user ""
    print_to_user "프로젝트 타입을 선택하세요:"
    print_to_user ""
    print_to_user "  1) spring            - Spring Boot 백엔드"
    print_to_user "  2) flutter           - Flutter 모바일 앱"
    print_to_user "  3) react             - React 웹 앱"
    print_to_user "  4) react-native      - React Native 모바일 앱"
    print_to_user "  5) react-native-expo - React Native Expo 앱"
    print_to_user "  6) node              - Node.js 프로젝트"
    print_to_user "  7) python            - Python 프로젝트"
    print_to_user "  8) basic             - 기타 프로젝트"
    print_to_user ""
    
    local choice
    local valid_input=false
    
    while [ "$valid_input" = false ]; do
        if safe_read "선택 (1-8): " choice "-n 1"; then
            print_to_user ""
            
            if [[ "$choice" =~ ^[1-8]$ ]]; then
                valid_input=true
                case $choice in
                    1) echo "spring" ;;
                    2) echo "flutter" ;;
                    3) echo "react" ;;
                    4) echo "react-native" ;;
                    5) echo "react-native-expo" ;;
                    6) echo "node" ;;
                    7) echo "python" ;;
                    8) echo "basic" ;;
                esac
            else
                print_error "잘못된 입력입니다. 1-8 사이의 숫자를 입력해주세요."
                print_to_user ""
            fi
        else
            # TTY를 읽을 수 없는 환경 - 기존 값 유지
            print_error "입력을 읽을 수 없습니다. 기존 값을 유지합니다."
            echo "$PROJECT_TYPE"
            return 1
        fi
    done
}

# 프로젝트 감지 및 확인
detect_and_confirm_project() {
    # 자동 감지 (최초 1회만)
    if [ -z "$PROJECT_TYPE" ]; then
        PROJECT_TYPE=$(detect_project_type)
    fi
    if [ -z "$VERSION" ]; then
        VERSION=$(detect_version)
    fi
    if [ -z "$DETECTED_BRANCH" ]; then
        DETECTED_BRANCH=$(detect_default_branch)
    fi
    
    local confirmed=false
    
    # 확인 루프 - Edit 선택 시 다시 확인 질문으로 돌아옴
    while [ "$confirmed" = false ]; do
        print_section_header "🛰️" "프로젝트 분석 결과"
        
        # 감지 결과 표시
        print_to_user ""
        print_to_user "       📂 Project Type     : $PROJECT_TYPE"
        print_to_user "       🌙 Version          : $VERSION"
        print_to_user "       🌿 Default Branch   : $DETECTED_BRANCH"
        print_to_user ""
        
        # 사용자 확인
        print_to_user "이 정보가 맞습니까?"
        print_to_user "  Y/y - 예, 계속 진행"
        print_to_user "  E/e - 수정하기"
        print_to_user "  N/n - 아니오, 취소"
        print_to_user ""
        
        # Y/N/E 입력 받기
        local user_choice
        user_choice=$(ask_yes_no_edit)
        
        case "$user_choice" in
            "yes")
                confirmed=true
                print_success "프로젝트 정보 확인 완료"
                print_to_user ""
                ;;
            "no")
                print_info "취소되었습니다"
                exit 0
                ;;
            "edit")
                handle_project_edit_menu
                # 루프 계속 - 다시 확인 질문으로
                ;;
            *)
                print_error "예상치 못한 오류가 발생했습니다"
                exit 1
                ;;
        esac
    done
}

# 프로젝트 정보 수정 메뉴
handle_project_edit_menu() {
    print_question_header "💫" "어떤 항목을 수정하시겠습니까?"
    
    print_to_user "  1) Project Type"
    print_to_user "  2) Version"
    print_to_user "  3) Default Branch (기본 브랜치)"
    print_to_user "  4) 모두 맞음, 계속"
    print_to_user ""
        
    local edit_choice
    local edit_valid=false
    
    while [ "$edit_valid" = false ]; do
        if safe_read "선택 (1-4): " edit_choice "-n 1"; then
            print_to_user ""
            
            if [[ "$edit_choice" =~ ^[1-4]$ ]]; then
                edit_valid=true
                
                case $edit_choice in
                    1)
                        # Project Type 수정
                        PROJECT_TYPE=$(show_project_type_menu)
                        print_success "Project Type이 '$PROJECT_TYPE'(으)로 변경되었습니다"
                        print_to_user ""
                        ;;
                    2)
                        # Version 수정
                        local new_version
                        print_to_user ""
                        
                        if safe_read "새 버전을 입력하세요 (예: 1.0.0): " new_version ""; then
                            print_to_user ""
                            
                            if [[ "$new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                                VERSION="$new_version"
                                print_success "Version이 '$VERSION'(으)로 변경되었습니다"
                            else
                                print_error "잘못된 버전 형식입니다. 기존 값을 유지합니다. (올바른 형식: x.y.z)"
                            fi
                            print_to_user ""
                        else
                            print_warning "입력을 읽을 수 없습니다. 기존 값을 유지합니다."
                            print_to_user ""
                        fi
                        ;;
                    3)
                        # Default Branch 수정
                        local new_branch
                        print_to_user ""
                        print_to_user "💡 이 설정은 GitHub Actions 워크플로우에서 사용할 기본 브랜치입니다."
                        print_to_user ""
                        
                        if safe_read "기본 브랜치 이름을 입력하세요 (예: main, develop): " new_branch ""; then
                            print_to_user ""
                            
                            if [ -n "$new_branch" ]; then
                                DETECTED_BRANCH="$new_branch"
                                print_success "Default Branch가 '$DETECTED_BRANCH'(으)로 변경되었습니다"
                            else
                                print_error "브랜치 이름이 비어있습니다. 기존 값을 유지합니다."
                            fi
                            print_to_user ""
                        else
                            print_warning "입력을 읽을 수 없습니다. 기존 값을 유지합니다."
                            print_to_user ""
                        fi
                        ;;
                    4)
                        # 모두 맞음, 계속
                        print_success "프로젝트 정보 확인 완료"
                        print_to_user ""
                        # 메인 루프로 돌아가지 않고 바로 종료
                        return 0
                        ;;
                esac
            else
                print_error "잘못된 입력입니다. 1-4 사이의 숫자를 입력해주세요."
                print_to_user ""
            fi
        else
            # TTY를 읽을 수 없는 환경 - 대화형 편집 불가
            print_error "대화형 입력이 불가능한 환경입니다."
            print_warning "자동화 환경에서는 --type, --version 옵션을 직접 지정해주세요."
            print_to_user ""
            return 1
        fi
    done
}

# 템플릿 다운로드
download_template() {
    # 이미 다운로드되었으면 건너뛰기 (중복 호출 방지)
    if [ -d "$TEMP_DIR" ] && [ -d "$TEMP_DIR/.github" ]; then
        print_info "템플릿이 이미 다운로드되어 있습니다. 건너뜁니다."
        return
    fi

    print_step "템플릿 다운로드 중..."

    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    
    git clone --depth 1 --quiet "$TEMPLATE_REPO" "$TEMP_DIR" 2>/dev/null || {
        print_error "템플릿 다운로드 실패"
        exit 1
    }
    
    # 문서 파일 제거 (프로젝트 특화 문서는 복사하지 않음)
    print_info "템플릿 내부 문서 제외 중..."
    local docs_to_remove=(
        "CONTRIBUTING.md"
        "CLAUDE.md"
    )
    
    for doc in "${docs_to_remove[@]}"; do
        if [ -f "$TEMP_DIR/$doc" ]; then
            rm -f "$TEMP_DIR/$doc"
        fi
    done

    # 플러그인 전용 파일/폴더 제거 (마켓플레이스 전용, template_integrator로 배포하지 않음)
    print_info "플러그인 전용 파일 제외 중..."
    local plugin_items_to_remove=(
        ".claude-plugin"    # Claude Code 플러그인 매니페스트
        "scripts"           # 플러그인 스크립트 (마켓플레이스 전용)
    )
    # 주의: skills/ 폴더는 Cursor IDE 복사용으로 보존 (offer_ide_tools_install에서 사용 후 정리)

    for item in "${plugin_items_to_remove[@]}"; do
        if [ -d "$TEMP_DIR/$item" ]; then
            rm -rf "$TEMP_DIR/$item"
        elif [ -f "$TEMP_DIR/$item" ]; then
            rm -f "$TEMP_DIR/$item"
        fi
    done

    # 사용자 적용 가이드 문서는 포함 (SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md)
    print_info "사용자 적용 가이드 문서 다운로드 중..."
    if [ -f "$TEMP_DIR/SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md" ]; then
        print_info "✓ SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md"
    fi

    # 다운로드한 템플릿에서 버전 읽기 (TEMPLATE_VERSION 전역 변수에 저장)
    if [ -f "$TEMP_DIR/version.yml" ]; then
        # version.yml에서 version 값 추출 (예: version: "2.7.5" → 2.7.5)
        TEMPLATE_VERSION=$(grep -E '^version:\s*' "$TEMP_DIR/version.yml" 2>/dev/null | sed 's/version:[[:space:]]*["'\'']*\([^"'\'']*\)["'\'']*$/\1/' | head -1)
        if [ -z "$TEMPLATE_VERSION" ]; then
            TEMPLATE_VERSION="$DEFAULT_VERSION"
        fi
    else
        TEMPLATE_VERSION="$DEFAULT_VERSION"
    fi

    print_success "템플릿 다운로드 완료"
}


# README.md 버전 섹션 추가
add_version_section_to_readme() {
    local version=$1
    
    print_step "README.md에 버전 관리 섹션 추가 중..."
    
    if [ ! -f "README.md" ]; then
        print_warning "README.md 파일이 없습니다. 건너뜁니다."
        return
    fi
    
    # 이미 버전 섹션이 있는지 확인 (영어 마커만 체크 - 파싱 호환성)
    if grep -q "<!-- AUTO-VERSION-SECTION" README.md; then
        print_info "이미 버전 관리 섹션이 있습니다. (마커 감지)"
        return
    fi

    # 버전 라인 체크 (버전 번호 패턴 감지)
    if grep -qiE "##[[:space:]]*(최신[[:space:]]*버전|최신버전|Version|버전)[[:space:]]*:[[:space:]]*v[0-9]+\.[0-9]+\.[0-9]+" README.md; then
        print_info "이미 버전 관리 섹션이 있습니다. (버전 라인 감지)"
        return
    fi

    # README.md 끝에 버전 섹션 추가
    cat >> README.md << EOF

---

<!-- AUTO-VERSION-SECTION: DO NOT EDIT MANUALLY -->
## 최신 버전 : v${version}

[전체 버전 기록 보기](CHANGELOG.md)
EOF
    
    print_success "README.md에 버전 관리 섹션 추가 완료"
    print_info "📝 위치: README.md 파일 하단"
    print_info "🔄 자동 업데이트: PROJECT-README-VERSION-UPDATE.yaml 워크플로우"
}

# version.yml 생성
create_version_yml() {
    local version=$1
    local type=$2
    local branch=$3
    local existing_version_code=1  # 기본값
    
    print_step "version.yml 생성 중..."
    
    if [ -f "version.yml" ]; then
        # 기존 version.yml에서 version_code 추출
        # 주석이 아닌 실제 데이터 라인에서만 추출 (주석 내 'version_code: 1' 오탐지 방지)
        if command -v yq >/dev/null 2>&1; then
            existing_version_code=$(yq -r '.version_code // 1' version.yml 2>/dev/null || echo "1")
        else
            # grep: 주석(#)으로 시작하지 않는 라인에서만 version_code 추출
            # macOS 호환: grep -P 대신 sed 사용 (BSD grep은 -P 미지원)
            existing_version_code=$(grep -E '^version_code:\s*[0-9]+' version.yml 2>/dev/null | sed 's/[^0-9]//g' | head -1 || echo "1")
        fi
        
        # 숫자 검증 (0보다 큰 정수만 허용)
        if ! [[ "$existing_version_code" =~ ^[0-9]+$ ]] || [ "$existing_version_code" -le 0 ]; then
            existing_version_code=1
        fi
        
        print_info "기존 version_code 감지: $existing_version_code"
        
        print_warning "version.yml이 이미 존재합니다"
        if [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
            print_separator_line
            print_to_user ""
            print_to_user "version.yml을 덮어쓰시겠습니까?"
            print_to_user "  Y/y - 예, 덮어쓰기"
            print_to_user "  N/n - 아니오, 건너뛰기 (기본)"
            print_to_user ""
            
            if ! ask_yes_no "선택: " "N"; then
                print_info "version.yml 생성 건너뜁니다"
                return
            fi
        fi
    fi
    
    cat > version.yml << EOF
# ===================================================================
# 프로젝트 버전 관리 파일
# ===================================================================
#
# 이 파일은 다양한 프로젝트 타입에서 버전 정보를 중앙 관리하기 위한 파일입니다.
# GitHub Actions 워크플로우가 이 파일을 읽어 자동으로 버전을 관리합니다.
#
# 사용법:
# 1. version: "1.0.0" - 사용자에게 표시되는 버전
# 2. version_code: 1 - Play Store/App Store 빌드 번호 (1부터 자동 증가)
# 3. project_type: 프로젝트 타입 지정
#
# 자동 버전 업데이트:
# - patch: 자동으로 세 번째 자리 증가 (x.x.x -> x.x.x+1)
# - version_code: 매 빌드마다 자동으로 1씩 증가
# - minor/major: 수동으로 직접 수정 필요
#
# 프로젝트 타입별 동기화 파일:
# - spring: build.gradle (version = "x.y.z")
# - flutter: pubspec.yaml (version: x.y.z+i, buildNumber 포함)
# - react/node: package.json ("version": "x.y.z")
# - react-native: iOS Info.plist 또는 Android build.gradle
# - react-native-expo: app.json (expo.version)
# - python: pyproject.toml (version = "x.y.z")
# - basic/기타: version.yml 파일만 사용
#
# 연관된 워크플로우:
# - .github/workflows/PROJECT-VERSION-CONTROL.yaml
# - .github/workflows/PROJECT-README-VERSION-UPDATE.yaml
# - .github/workflows/PROJECT-AUTO-CHANGELOG-CONTROL.yaml
#
# 주의사항:
# - project_type은 최초 설정 후 변경하지 마세요
# - 버전은 항상 높은 버전으로 자동 동기화됩니다
# ===================================================================

version: "$version"
version_code: $existing_version_code  # app build number
project_type: "$type"  # spring, flutter, react, react-native, react-native-expo, node, python, basic
metadata:
  last_updated: "$(date -u +"%Y-%m-%d %H:%M:%S")"
  last_updated_by: "template_integrator"
  default_branch: "$branch"
  integrated_from: "SUH-DEVOPS-TEMPLATE"
  integration_date: "$(date -u +"%Y-%m-%d")"
EOF

    print_success "version.yml 생성 완료"
}

# ===================================================================
# Synology 옵션 관리 함수
# ===================================================================

# version.yml에서 템플릿 옵션 읽기
read_template_options() {
    local version_file="version.yml"

    if [ ! -f "$version_file" ]; then
        return
    fi

    # synology 옵션 읽기 (metadata.template.options.synology)
    # YAML 파싱: template 섹션 내의 synology 값 찾기
    local in_template=false
    local in_options=false

    while IFS= read -r line; do
        # template: 섹션 시작 확인
        if [[ "$line" =~ ^[[:space:]]*template: ]]; then
            in_template=true
            continue
        fi

        # template 섹션 내부에서 options: 확인
        if [ "$in_template" = true ] && [[ "$line" =~ ^[[:space:]]+options: ]]; then
            in_options=true
            continue
        fi

        # options 섹션 내부에서 synology 값 확인
        if [ "$in_template" = true ] && [ "$in_options" = true ]; then
            if [[ "$line" =~ ^[[:space:]]+synology:[[:space:]]*(.+) ]]; then
                local synology_val="${BASH_REMATCH[1]}"
                # 따옴표 제거 및 trim
                synology_val=$(echo "$synology_val" | tr -d '"' | tr -d "'" | xargs)

                if [ "$synology_val" = "true" ]; then
                    INCLUDE_SYNOLOGY=true
                    print_info "이전 설정에서 Synology 옵션 감지: 포함"
                elif [ "$synology_val" = "false" ]; then
                    INCLUDE_SYNOLOGY=false
                    print_info "이전 설정에서 Synology 옵션 감지: 제외"
                fi
                return
            fi

            # 다른 최상위 키 만나면 options 섹션 종료
            if [[ "$line" =~ ^[[:space:]]{0,4}[a-z_]+: ]]; then
                in_options=false
                in_template=false
            fi
        fi

        # template 섹션 종료 확인 (들여쓰기가 줄어들면)
        if [ "$in_template" = true ] && [[ "$line" =~ ^[a-z_]+: ]]; then
            in_template=false
            in_options=false
        fi
    done < "$version_file"
}

# version.yml에 템플릿 옵션 저장
save_template_options() {
    local version_file="version.yml"
    local template_version="${1:-unknown}"
    local today=$(date -u +"%Y-%m-%d")

    if [ ! -f "$version_file" ]; then
        return
    fi

    # 기존에 template 섹션이 있는지 확인
    if grep -q "^[[:space:]]*template:" "$version_file"; then
        # 기존 template 섹션 업데이트
        # macOS/Linux 호환을 위해 임시 파일 방식 사용

        # options.synology 값 업데이트 또는 추가
        if grep -q "synology:" "$version_file"; then
            # synology 값 업데이트
            sed "s/synology:.*$/synology: $INCLUDE_SYNOLOGY/" "$version_file" > "$version_file.tmp" && mv "$version_file.tmp" "$version_file"
        else
            # synology 값이 없으면 options 섹션에 추가
            if grep -q "options:" "$version_file"; then
                # options 다음 줄에 synology 추가 (macOS 호환)
                sed "/options:/a\\
      synology: $INCLUDE_SYNOLOGY" "$version_file" > "$version_file.tmp" && mv "$version_file.tmp" "$version_file"
            fi
        fi

        # last_update_date 업데이트
        if grep -q "last_update_date:" "$version_file"; then
            sed "s/last_update_date:.*$/last_update_date: \"$today\"/" "$version_file" > "$version_file.tmp" && mv "$version_file.tmp" "$version_file"
        fi
    else
        # template 섹션 새로 추가 (metadata 섹션 끝에)
        # 파일 끝에 추가
        cat >> "$version_file" << EOF
  template:
    source: "SUH-DEVOPS-TEMPLATE"
    version: "$template_version"
    integrated_date: "$today"
    last_update_date: "$today"
    options:
      synology: $INCLUDE_SYNOLOGY
EOF
        print_info "version.yml에 템플릿 설정 저장됨"
    fi
}

# 버전 비교 함수 (v1 > v2 이면 1, v1 < v2 이면 -1, 같으면 0)
compare_versions() {
    local v1="$1"
    local v2="$2"

    # 버전에서 v 접두사 제거
    v1="${v1#v}"
    v2="${v2#v}"

    # 버전을 . 기준으로 분리 (IFS 격리)
    local V1_PARTS
    local V2_PARTS
    V1_PARTS=($(echo "$v1" | tr '.' ' '))
    V2_PARTS=($(echo "$v2" | tr '.' ' '))

    for i in 0 1 2; do
        local p1="${V1_PARTS[$i]:-0}"
        local p2="${V2_PARTS[$i]:-0}"

        if [ "$p1" -gt "$p2" ] 2>/dev/null; then
            echo 1
            return
        elif [ "$p1" -lt "$p2" ] 2>/dev/null; then
            echo -1
            return
        fi
    done

    echo 0
}

# Breaking Changes 확인 및 알림
check_breaking_changes() {
    local current_version="$1"  # 프로젝트의 현재 템플릿 버전
    local new_version="$2"      # 업데이트될 템플릿 버전

    # 버전 정보가 없으면 (레거시 프로젝트) 스킵
    if [ -z "$current_version" ] || [ "$current_version" = "unknown" ]; then
        return 0
    fi

    # --force 모드면 스킵
    if [ "$FORCE_MODE" = true ]; then
        return 0
    fi

    # TTY 없으면 스킵
    if [ "$TTY_AVAILABLE" = false ]; then
        return 0
    fi

    # breaking-changes.json 다운로드
    local bc_url="${TEMPLATE_RAW_URL}/.github/config/breaking-changes.json"
    local bc_json
    bc_json=$(curl -fsSL "$bc_url" 2>/dev/null) || return 0

    # JSON 파싱 실패 시 스킵
    if [ -z "$bc_json" ]; then
        return 0
    fi

    # jq 없으면 스킵 (JSON 파싱 불가)
    if ! command -v jq &> /dev/null; then
        print_warning "jq가 설치되지 않아 breaking change 확인을 건너뜁니다."
        return 0
    fi

    # breaking changes 버전 목록 추출 (버전 키만)
    local versions
    versions=$(echo "$bc_json" | jq -r 'keys[] | select(startswith("_") | not)' 2>/dev/null) || return 0

    # 해당 버전 범위의 breaking changes 수집
    local critical_changes=()
    local warning_changes=()

    for ver in $versions; do
        # current_version < ver <= new_version 인 경우만 해당
        local cmp_current
        local cmp_new
        cmp_current=$(compare_versions "$ver" "$current_version")
        cmp_new=$(compare_versions "$ver" "$new_version")

        if [ "$cmp_current" = "1" ] && [ "$cmp_new" != "1" ]; then
            local severity
            local title
            local message
            severity=$(echo "$bc_json" | jq -r ".[\"$ver\"].severity // \"warning\"" 2>/dev/null)
            title=$(echo "$bc_json" | jq -r ".[\"$ver\"].title // \"\"" 2>/dev/null)
            message=$(echo "$bc_json" | jq -r ".[\"$ver\"].message // \"\"" 2>/dev/null)

            if [ "$severity" = "critical" ]; then
                critical_changes+=("v$ver|$title|$message")
            else
                warning_changes+=("v$ver|$title|$message")
            fi
        fi
    done

    # breaking change가 없으면 리턴
    local total_changes=$((${#critical_changes[@]} + ${#warning_changes[@]}))
    if [ "$total_changes" -eq 0 ]; then
        return 0
    fi

    # 알림 표시
    echo "" >&2
    echo "╔══════════════════════════════════════════════════════════════════╗" >&2
    echo "║  ⚠️  BREAKING CHANGES (v$current_version → v$new_version)" >&2
    echo "╠══════════════════════════════════════════════════════════════════╣" >&2

    # Critical changes 표시
    for change in "${critical_changes[@]}"; do
        IFS='|' read -r ver title msg <<< "$change"
        echo "║" >&2
        echo "║  ${RED}[CRITICAL]${NC} $ver - $title" >&2
        echo "║  → $msg" >&2
    done

    # Warning changes 표시
    for change in "${warning_changes[@]}"; do
        IFS='|' read -r ver title msg <<< "$change"
        echo "║" >&2
        echo "║  ${YELLOW}[WARNING]${NC} $ver - $title" >&2
        echo "║  → $msg" >&2
    done

    echo "║" >&2
    echo "╚══════════════════════════════════════════════════════════════════╝" >&2
    echo "" >&2

    # Critical이 있으면 Y/N 확인
    if [ ${#critical_changes[@]} -gt 0 ]; then
        print_warning "CRITICAL 변경사항이 있습니다."
        print_to_user ""
        print_to_user "계속 진행하시겠습니까?"
        print_to_user "  Y/y - 예, 계속 진행"
        print_to_user "  N/n - 아니오, 취소"
        print_to_user ""

        if ! ask_yes_no "선택: " "N"; then
            print_info "취소되었습니다"
            exit 0
        fi
    fi

    return 0
}

# 현재 프로젝트의 템플릿 버전 읽기
get_current_template_version() {
    local version_file="version.yml"

    if [ ! -f "$version_file" ]; then
        echo "unknown"
        return
    fi

    # metadata.template.version 읽기
    local in_template=false
    while IFS= read -r line; do
        if [[ "$line" =~ ^[[:space:]]*template: ]]; then
            in_template=true
        elif [ "$in_template" = true ]; then
            if [[ "$line" =~ ^[[:space:]]*version:[[:space:]]*[\"\']?([0-9.]+)[\"\']? ]]; then
                echo "${BASH_REMATCH[1]}"
                return
            elif [[ "$line" =~ ^[[:space:]]*[a-z_]+: ]] && [[ ! "$line" =~ ^[[:space:]]{4,} ]]; then
                # 다른 최상위 키를 만나면 종료
                break
            fi
        fi
    done < "$version_file"

    echo "unknown"
}

# Synology 워크플로우 포함 여부 질문
ask_synology_option() {
    local type_dir="$1"
    local synology_dir="$type_dir/synology"
    local common_synology_dir="$(dirname "$type_dir")/common/synology"

    # 타입별/공통 synology 폴더 모두 없으면 건너뛰기
    if [ ! -d "$synology_dir" ] && [ ! -d "$common_synology_dir" ]; then
        return
    fi

    # 이미 CLI로 지정된 경우 건너뛰기
    if [ "$INCLUDE_SYNOLOGY" = true ] || [ "$INCLUDE_SYNOLOGY" = false ]; then
        return
    fi

    # 기존 version.yml에서 설정 읽기 시도
    read_template_options

    # 이전 설정이 있으면 건너뛰기
    if [ "$INCLUDE_SYNOLOGY" = true ] || [ "$INCLUDE_SYNOLOGY" = false ]; then
        return
    fi

    # TTY 없으면 건너뛰기 (기본값: 제외)
    if [ "$TTY_AVAILABLE" = false ]; then
        INCLUDE_SYNOLOGY=false
        return
    fi

    # synology 폴더 내 파일 개수 확인 (타입별 + 공통)
    local synology_files=0
    if [ -d "$synology_dir" ]; then
        for f in "$synology_dir"/*.{yaml,yml}; do
            [ -e "$f" ] && synology_files=$((synology_files + 1))
        done
    fi
    if [ -d "$common_synology_dir" ]; then
        for f in "$common_synology_dir"/*.{yaml,yml}; do
            [ -e "$f" ] && synology_files=$((synology_files + 1))
        done
    fi

    if [ $synology_files -eq 0 ]; then
        return
    fi

    print_separator_line
    print_to_user ""
    print_to_user "🗄️ Synology 워크플로우가 발견되었습니다. ($synology_files개 파일)"
    print_to_user "   Synology NAS에 배포하는 워크플로우를 포함하시겠습니까?"
    print_to_user ""
    print_to_user "   포함되는 워크플로우:"
    if [ -d "$synology_dir" ]; then
        for f in "$synology_dir"/*.{yaml,yml}; do
            [ -e "$f" ] || continue
            local fname=$(basename "$f")
            print_to_user "     • $fname"
        done
    fi
    if [ -d "$common_synology_dir" ]; then
        for f in "$common_synology_dir"/*.{yaml,yml}; do
            [ -e "$f" ] || continue
            local fname=$(basename "$f")
            print_to_user "     • $fname (공통)"
        done
    fi
    print_to_user ""
    print_to_user "  Y/y - 예, 포함"
    print_to_user "  N/n - 아니오, 제외 (기본)"
    print_to_user ""

    if ask_yes_no "선택: " "N"; then
        INCLUDE_SYNOLOGY=true
        print_info "Synology 워크플로우를 포함합니다"
    else
        INCLUDE_SYNOLOGY=false
        print_info "Synology 워크플로우를 제외합니다"
    fi
}

# 워크플로우 다운로드 (폴더 기반, 선택적 업데이트)
copy_workflows() {
    print_step "프로젝트 타입별 워크플로우 다운로드 중..."
    print_info "프로젝트 타입: $PROJECT_TYPE"

    mkdir -p "$WORKFLOWS_DIR"

    local copied=0
    local skipped=0
    local template_added=0
    local project_types_dir="$TEMP_DIR/$WORKFLOWS_DIR/$PROJECT_TYPES_DIR"

    # project-types 폴더 존재 확인
    if [ ! -d "$project_types_dir" ]; then
        print_error "템플릿 저장소의 폴더 구조가 올바르지 않습니다."
        print_error "project-types 폴더를 찾을 수 없습니다."
        exit 1
    fi

    # 1. Common 워크플로우 다운로드 (항상 최신으로 업데이트)
    # *.{yaml,yml} 글로브는 common/ 직접 하위 파일만 매칭 (common/synology/ 등 하위 디렉토리 제외)
    print_info "공통 워크플로우 다운로드 중..."
    if [ -d "$project_types_dir/common" ]; then
        for workflow in "$project_types_dir/common"/*.{yaml,yml}; do
            [ -e "$workflow" ] || continue
            local filename=$(basename "$workflow")

            # COMMON은 항상 덮어쓰기 (핵심 기능)
            if [ -f "$WORKFLOWS_DIR/$filename" ]; then
                print_info "$filename 업데이트"
            fi

            cp "$workflow" "$WORKFLOWS_DIR/"
            echo "  ✓ $filename"
            copied=$((copied + 1))
        done
    else
        print_warning "common 폴더를 찾을 수 없습니다. 건너뜁니다."
    fi

    # 2. 타입별 워크플로우 처리 (선택적 업데이트)
    local type_dir="$project_types_dir/$PROJECT_TYPE"
    if [ -d "$type_dir" ]; then
        # 먼저 이미 존재하는 파일 목록 수집
        local existing_files=()
        local new_files=()

        for workflow in "$type_dir"/*.{yaml,yml}; do
            [ -e "$workflow" ] || continue
            local filename=$(basename "$workflow")

            if [ -f "$WORKFLOWS_DIR/$filename" ]; then
                existing_files+=("$filename")
            else
                new_files+=("$filename")
            fi
        done

        # 신규 파일은 바로 복사
        if [ ${#new_files[@]} -gt 0 ]; then
            print_info "$PROJECT_TYPE 신규 워크플로우 다운로드 중..."
            for filename in "${new_files[@]}"; do
                cp "$type_dir/$filename" "$WORKFLOWS_DIR/"
                echo "  ✓ $filename (신규)"
                copied=$((copied + 1))
            done
        fi

        # 이미 존재하는 파일 처리
        if [ ${#existing_files[@]} -gt 0 ]; then
            echo ""
            print_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            print_warning "⚠️  이미 존재하는 타입별 워크플로우: ${#existing_files[@]}개"
            print_warning "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            for f in "${existing_files[@]}"; do
                echo "   • $f"
            done
            echo ""
            print_info "처리 방법을 선택하세요:"
            echo ""
            echo "  (T) .template.yaml로 추가"
            echo "      → 기존 파일 유지 + 새 버전을 참고용으로 추가"
            echo "      → 예: PROJECT-FLUTTER-*.yaml.template.yaml"
            echo ""
            echo "  (S) 건너뛰기"
            echo "      → 기존 파일만 유지, 아무것도 추가 안 함"
            echo ""
            echo "  (O) 덮어쓰기 (기존 방식)"
            echo "      → 기존 파일을 .bak으로 백업 후 덮어쓰기"
            echo ""

            local choice
            safe_read "선택 [T/S/O]: " choice "-n 1"
            echo ""

            case "${choice^^}" in
                T)
                    # .template.yaml로 추가
                    print_info "새 버전을 .template.yaml로 추가합니다..."
                    for filename in "${existing_files[@]}"; do
                        local template_name="${filename%.yaml}.template.yaml"
                        # 기존 .template.yaml이 있으면 삭제
                        rm -f "$WORKFLOWS_DIR/$template_name"
                        cp "$type_dir/$filename" "$WORKFLOWS_DIR/$template_name"
                        echo "  ✓ $template_name (참고용 추가)"
                        template_added=$((template_added + 1))
                    done
                    print_info "💡 .template.yaml 파일은 GitHub Actions에서 실행되지 않습니다."
                    print_info "   필요한 변경사항을 참고하여 기존 파일에 수동으로 반영하세요."
                    ;;
                S)
                    # 건너뛰기
                    print_info "기존 파일을 유지합니다..."
                    for filename in "${existing_files[@]}"; do
                        echo "  ⏭ $filename (건너뜀)"
                        skipped=$((skipped + 1))
                    done
                    ;;
                O)
                    # 기존 방식 (덮어쓰기)
                    print_info "기존 파일을 백업 후 덮어씁니다..."
                    for filename in "${existing_files[@]}"; do
                        mv "$WORKFLOWS_DIR/$filename" "$WORKFLOWS_DIR/${filename}.bak"
                        cp "$type_dir/$filename" "$WORKFLOWS_DIR/"
                        echo "  ✓ $filename (백업: ${filename}.bak)"
                        copied=$((copied + 1))
                    done
                    ;;
                *)
                    # 기본값: 건너뛰기
                    print_warning "잘못된 선택. 기존 파일을 유지합니다."
                    for filename in "${existing_files[@]}"; do
                        echo "  ⏭ $filename (건너뜀)"
                        skipped=$((skipped + 1))
                    done
                    ;;
            esac
        else
            print_info "$PROJECT_TYPE 타입의 기존 워크플로우가 없습니다."
        fi
    else
        print_info "$PROJECT_TYPE 타입의 전용 워크플로우가 없습니다. (공통 워크플로우만 사용)"
    fi

    # 3. Synology 하위폴더 처리 (선택적)
    local synology_copied=0
    local synology_dir="$project_types_dir/$PROJECT_TYPE/synology"

    if [ -d "$synology_dir" ]; then
        if [ "$INCLUDE_SYNOLOGY" = true ]; then
            print_info "Synology 워크플로우 다운로드 중..."
            for workflow in "$synology_dir"/*.{yaml,yml}; do
                [ -e "$workflow" ] || continue
                local filename=$(basename "$workflow")

                # 이미 존재하는 경우 처리
                if [ -f "$WORKFLOWS_DIR/$filename" ]; then
                    # 기존 파일 백업 후 덮어쓰기
                    mv "$WORKFLOWS_DIR/$filename" "$WORKFLOWS_DIR/${filename}.bak"
                    cp "$workflow" "$WORKFLOWS_DIR/"
                    echo "  ✓ $filename (Synology, 백업: ${filename}.bak)"
                else
                    cp "$workflow" "$WORKFLOWS_DIR/"
                    echo "  ✓ $filename (Synology)"
                fi
                synology_copied=$((synology_copied + 1))
                copied=$((copied + 1))
            done
        else
            # Synology 제외됨 - 사용자에게 알림
            local synology_count=0
            for f in "$synology_dir"/*.{yaml,yml}; do
                [ -e "$f" ] && synology_count=$((synology_count + 1))
            done
            if [ $synology_count -gt 0 ]; then
                print_info "Synology 워크플로우 $synology_count개 제외됨 (--synology 옵션으로 포함 가능)"
            fi
        fi
    fi

    # 4. Common Synology 워크플로우 처리 (선택적)
    local common_synology_dir="$project_types_dir/common/synology"
    if [ -d "$common_synology_dir" ]; then
        if [ "$INCLUDE_SYNOLOGY" = true ]; then
            print_info "공통 Synology 워크플로우 다운로드 중..."
            for workflow in "$common_synology_dir"/*.{yaml,yml}; do
                [ -e "$workflow" ] || continue
                local filename=$(basename "$workflow")

                # 타입별 synology에서 이미 복사된 파일이면 스킵
                if [ -f "$WORKFLOWS_DIR/$filename" ]; then
                    print_warning "$filename: 타입별 Synology에 동일 파일 존재. 타입별 버전 유지."
                    continue
                fi

                cp "$workflow" "$WORKFLOWS_DIR/"
                echo "  ✓ $filename (공통 Synology)"
                synology_copied=$((synology_copied + 1))
                copied=$((copied + 1))
            done
        else
            local common_syn_count=0
            for f in "$common_synology_dir"/*.{yaml,yml}; do
                [ -e "$f" ] && common_syn_count=$((common_syn_count + 1))
            done
            if [ $common_syn_count -gt 0 ]; then
                print_info "공통 Synology 워크플로우 $common_syn_count개 제외됨 (--synology 옵션으로 포함 가능)"
            fi
        fi
    fi

    # 결과 요약
    echo ""
    print_success "워크플로우 처리 완료 (타입: $PROJECT_TYPE)"
    echo "   📥 복사됨: $copied 개"
    if [ $synology_copied -gt 0 ]; then
        echo "   🗄️ Synology: $synology_copied 개"
    fi
    if [ $template_added -gt 0 ]; then
        echo "   📄 참고용 추가 (.template.yaml): $template_added 개"
    fi
    if [ $skipped -gt 0 ]; then
        echo "   ⏭ 건너뜀: $skipped 개"
    fi

    # 복사된 워크플로우 수를 전역 변수로 저장 (최종 요약에서 사용)
    WORKFLOWS_COPIED=$copied

    # CI/CD 워크플로우 안내
    if [ "$PROJECT_TYPE" = "spring" ]; then
        echo ""
        print_info "🔐 Spring CI/CD 워크플로우 사용 시 GitHub Secrets 설정:"
        echo "     Repository > Settings > Secrets and variables > Actions"
        echo "     필수 Secrets:"
        echo "       - APPLICATION_PROD_YML (Spring 운영 설정)"
        echo "       - DOCKERHUB_USERNAME, DOCKERHUB_TOKEN"
        echo "       - SERVER_HOST, SERVER_USER, SERVER_PASSWORD"
        echo "       - GRADLE_PROPERTIES (Nexus 사용 시)"
    fi
}

# 스크립트 다운로드
copy_scripts() {
    print_step "버전 관리 스크립트 다운로드 중..."
    
    mkdir -p "$SCRIPTS_DIR"
    
    local scripts=(
        "version_manager.sh"
        "changelog_manager.py"
    )
    
    local copied=0
    for script in "${scripts[@]}"; do
        local src="$TEMP_DIR/$SCRIPTS_DIR/$script"
        local dst="$SCRIPTS_DIR/$script"
        
        if [ -f "$src" ]; then
            cp "$src" "$dst"
            chmod +x "$dst"
            echo "  ✓ $script"
            copied=$((copied + 1))
        fi
    done
    
    print_success "$copied 개 스크립트 다운로드 완료"
}

# .github/config 폴더 복사
copy_config_folder() {
    print_step ".github/config 폴더 복사 중..."

    local src_config_dir="$TEMP_DIR/.github/config"
    local dst_config_dir=".github/config"

    if [ ! -d "$src_config_dir" ]; then
        print_info ".github/config 폴더가 템플릿에 없습니다. 건너뜁니다."
        return
    fi

    # 기존 config 파일이 있으면 알림
    if [ -d "$dst_config_dir" ] && [ "$(ls -A "$dst_config_dir" 2>/dev/null)" ]; then
        print_info "기존 config 파일이 있습니다. 덮어씁니다."
    fi

    mkdir -p "$dst_config_dir"

    # 항상 최신으로 덮어쓰기
    cp -r "$src_config_dir/"* "$dst_config_dir/" 2>/dev/null || true

    # 복사된 파일 개수 계산
    local copied=$(ls -1 "$dst_config_dir" 2>/dev/null | wc -l | tr -d ' ')
    print_success ".github/config 폴더 복사 완료 ($copied 개 파일)"
}

# 이슈 템플릿 다운로드
copy_issue_templates() {
    print_step "이슈/PR 템플릿 다운로드 중..."
    
    mkdir -p .github/ISSUE_TEMPLATE
    
    # 기존 템플릿 백업 (백업 디렉토리 없어도 실패하지 않음)
    if [ -d ".github/ISSUE_TEMPLATE" ] && [ "$(ls -A .github/ISSUE_TEMPLATE 2>/dev/null)" ]; then
        print_info "기존 이슈 템플릿이 있습니다. 덮어씁니다."
    fi
    
    # 템플릿 다운로드
    if [ -d "$TEMP_DIR/.github/ISSUE_TEMPLATE" ]; then
        cp -r "$TEMP_DIR/.github/ISSUE_TEMPLATE/"* .github/ISSUE_TEMPLATE/ 2>/dev/null || true
    fi
    
    # PR 템플릿
    if [ -f "$TEMP_DIR/.github/PULL_REQUEST_TEMPLATE.md" ]; then
        cp "$TEMP_DIR/.github/PULL_REQUEST_TEMPLATE.md" .github/
        print_success "이슈/PR 템플릿 다운로드 완료"
    fi
}

# Discussion 템플릿 다운로드
copy_discussion_templates() {
    print_step "GitHub Discussions 템플릿 다운로드 중..."
    
    # 템플릿에 DISCUSSION_TEMPLATE이 없으면 건너뛰기
    if [ ! -d "$TEMP_DIR/.github/DISCUSSION_TEMPLATE" ]; then
        print_info "DISCUSSION_TEMPLATE이 템플릿에 없습니다. 건너뜁니다."
        return
    fi
    
    mkdir -p .github/DISCUSSION_TEMPLATE
    
    # 기존 템플릿이 있으면 알림
    if [ -d ".github/DISCUSSION_TEMPLATE" ] && [ "$(ls -A .github/DISCUSSION_TEMPLATE 2>/dev/null)" ]; then
        print_info "기존 Discussion 템플릿이 있습니다. 덮어씁니다."
    fi
    
    # 템플릿 다운로드
    cp -r "$TEMP_DIR/.github/DISCUSSION_TEMPLATE/"* .github/DISCUSSION_TEMPLATE/ 2>/dev/null || true
    print_success "GitHub Discussions 템플릿 다운로드 완료"
}

# .coderabbit.yaml 다운로드
copy_coderabbit_config() {
    print_step "CodeRabbit 설정 파일 다운로드 여부 확인 중..."
    
    if [ ! -f "$TEMP_DIR/.coderabbit.yaml" ]; then
        print_info ".coderabbit.yaml 파일이 템플릿에 없습니다. 건너뜁니다."
        return
    fi
    
    # 기존 파일이 있으면 사용자 확인
    if [ -f ".coderabbit.yaml" ]; then
        print_warning ".coderabbit.yaml이 이미 존재합니다"
        
        if [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
            print_separator_line
            print_to_user ""
            print_to_user ".coderabbit.yaml을 덮어쓰시겠습니까?"
            print_to_user "  Y/y - 예, 덮어쓰기"
            print_to_user "  N/n - 아니오, 건너뛰기 (기본)"
            print_to_user ""
            
            if ! ask_yes_no "선택: " "N"; then
                print_info ".coderabbit.yaml 다운로드 건너뜁니다"
                return
            fi
            
            # 백업
            cp .coderabbit.yaml .coderabbit.yaml.bak
            print_info "기존 파일을 .coderabbit.yaml.bak으로 백업했습니다"
        elif [ "$FORCE_MODE" = true ]; then
            # Force 모드에서는 백업하고 덮어쓰기
            cp .coderabbit.yaml .coderabbit.yaml.bak 2>/dev/null || true
            print_info "강제 모드: 기존 파일 덮어씁니다"
        else
            # TTY 없고 Force도 아니면 건너뛰기
            print_info "대화형 모드가 아닙니다. 기존 파일을 유지합니다."
            return
        fi
    fi
    
    # 다운로드 실행
    cp "$TEMP_DIR/.coderabbit.yaml" .coderabbit.yaml
    print_success ".coderabbit.yaml 다운로드 완료"
    print_info "💡 CodeRabbit AI 리뷰가 활성화됩니다 (language: ko-KR)"
}

# gitignore 항목 정규화 함수 (중복 체크용)
# 예: "/.idea" -> ".idea", ".idea" -> ".idea", "./idea" -> ".idea"
# 예: "/.claude/settings.local.json" -> ".claude/settings.local.json"
normalize_gitignore_entry() {
    local entry="$1"
    # 주석 제거
    entry="${entry%%#*}"
    # 앞뒤 공백 제거
    entry=$(echo "$entry" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    # 앞의 슬래시 제거 (루트 경로 표시 제거)
    entry="${entry#/}"
    # "./" 제거 (현재 디렉토리 표시 제거, 하지만 ".idea" 같은 숨김 폴더는 보존)
    entry="${entry#./}"
    # 뒤의 슬래시 제거 (디렉토리 표시 제거)
    entry="${entry%/}"
    # 빈 문자열이면 원본 반환
    if [ -z "$entry" ]; then
        echo "$1"
    else
        echo "$entry"
    fi
}

# gitignore 파일에서 항목 존재 여부 확인 (정규화된 비교)
check_gitignore_entry_exists() {
    local target_entry="$1"
    local gitignore_file="$2"
    
    # 정규화된 타겟 항목
    local normalized_target=$(normalize_gitignore_entry "$target_entry")
    
    # gitignore 파일의 각 라인 확인
    while IFS= read -r line || [ -n "$line" ]; do
        # 주석 라인 건너뛰기
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # 빈 라인 건너뛰기
        if [[ -z "$line" || "$line" =~ ^[[:space:]]*$ ]]; then
            continue
        fi
        
        # 정규화된 라인과 비교
        local normalized_line=$(normalize_gitignore_entry "$line")
        
        if [ "$normalized_line" = "$normalized_target" ]; then
            return 0  # 존재함
        fi
    done < "$gitignore_file"
    
    return 1  # 존재하지 않음
}

# .gitignore 생성 또는 업데이트
ensure_gitignore() {
    print_step ".gitignore 파일 확인 및 업데이트 중..."
    
    local required_entries=(
        "/.idea"
        "/.claude/settings.local.json"
    )
    
    # .gitignore가 없으면 생성
    if [ ! -f ".gitignore" ]; then
        print_info ".gitignore 파일이 없습니다. 생성합니다."
        
        cat > .gitignore << 'EOF'
# IDE Settings
/.idea

# Claude AI Settings
/.claude/settings.local.json
EOF
        
        print_success ".gitignore 파일 생성 완료"
        return
    fi
    
    # 기존 파일이 있으면 누락된 항목만 추가
    print_info "기존 .gitignore 파일 발견. 필수 항목 확인 중..."
    
    local added=0
    local entries_to_add=()
    
    for entry in "${required_entries[@]}"; do
        # 정규화된 비교로 중복 체크
        if ! check_gitignore_entry_exists "$entry" ".gitignore"; then
            entries_to_add+=("$entry")
            added=$((added + 1))
        fi
    done
    
    if [ $added -eq 0 ]; then
        print_info "필수 항목이 이미 모두 존재합니다. 건너뜁니다."
        return
    fi
    
    # 항목 추가 (마지막에 섹션으로 추가)
    print_info "$added 개 항목 추가 중..."
    
    # 파일 끝에 빈 줄이 없으면 추가
    if [ -n "$(tail -c 1 .gitignore 2>/dev/null)" ]; then
        echo "" >> .gitignore
    fi
    
    # 섹션 헤더 추가
    echo "" >> .gitignore
    echo "# ====================================================================" >> .gitignore
    echo "# SUH-DEVOPS-TEMPLATE: Auto-added entries" >> .gitignore
    echo "# ====================================================================" >> .gitignore
    
    for entry in "${entries_to_add[@]}"; do
        echo "$entry" >> .gitignore
        print_info "  ✓ $entry"
    done
    
    print_success ".gitignore 업데이트 완료 ($added 개 항목 추가)"
}

# SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md 다운로드
copy_setup_guide() {
    print_step "템플릿 설정 가이드 다운로드 중..."
    
    if [ ! -f "$TEMP_DIR/SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md" ]; then
        print_info "SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md 파일이 템플릿에 없습니다. 건너뜁니다."
        return
    fi
    
    # 항상 최신 버전으로 다운로드 (기존 파일 덮어쓰기)
    cp "$TEMP_DIR/SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md" .
    print_success "템플릿 설정 가이드 다운로드 완료 (최신 버전)"
    print_info "📖 템플릿 사용법을 SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md에서 확인하세요"
}

# ===================================================================
# 프로젝트 타입별 유틸리티 모듈 다운로드
# ===================================================================
# 프로젝트 타입에 따라 추가 유틸리티 모듈(마법사 등)을 다운로드합니다.
# 현재 지원: flutter (ios-testflight-setup-wizard, android-playstore-setup-wizard)
# 확장 가능: 다른 프로젝트 타입에도 util 모듈 추가 시 자동 지원
# ===================================================================

# util 모듈 설명 표시
show_util_module_description() {
    local project_type=$1

    case $project_type in
        flutter)
            print_separator_line
            print_to_user ""
            print_to_user "📦 Flutter 추가 유틸리티 모듈:"
            print_to_user ""
            print_to_user "  🧙 ios-testflight-setup-wizard"
            print_to_user "     iOS TestFlight 배포에 필요한 설정 파일들을"
            print_to_user "     웹 브라우저에서 쉽게 생성할 수 있는 마법사입니다."
            print_to_user "     → ExportOptions.plist, Fastfile 등 자동 생성"
            print_to_user ""
            print_to_user "  🧙 android-playstore-setup-wizard"
            print_to_user "     Android Play Store 배포에 필요한 설정 파일들을"
            print_to_user "     웹 브라우저에서 쉽게 생성할 수 있는 마법사입니다."
            print_to_user "     → Fastfile, build.gradle 서명 설정 등 자동 생성"
            print_to_user ""
            ;;
        # 다른 프로젝트 타입 추가 시 여기에 case 추가
        # spring)
        #     print_to_user "📦 Spring 추가 유틸리티 모듈:"
        #     ...
        #     ;;
        *)
            # 알 수 없는 타입은 일반 메시지
            print_separator_line
            print_to_user ""
            print_to_user "📦 $project_type 추가 유틸리티 모듈이 있습니다."
            print_to_user ""
            ;;
    esac
}

# util 모듈 사용 가이드 표시
show_util_usage_guide() {
    local project_type=$1

    case $project_type in
        flutter)
            print_to_user ""
            print_info "📖 Flutter 마법사 사용법:"
            print_to_user "   iOS TestFlight:"
            print_to_user "     1. 브라우저에서 열기:"
            print_to_user "        .github/util/flutter/ios-testflight-setup-wizard/index.html"
            print_to_user "     2. 필요한 정보 입력 후 파일 생성"
            print_to_user "     3. 생성된 파일을 ios/ 폴더에 복사"
            print_to_user ""
            print_to_user "   Android Play Store:"
            print_to_user "     1. 브라우저에서 열기:"
            print_to_user "        .github/util/flutter/android-playstore-setup-wizard/index.html"
            print_to_user "     2. 필요한 정보 입력 후 파일 생성"
            print_to_user "     3. 생성된 파일을 android/ 폴더에 복사"
            print_to_user ""
            ;;
        *)
            print_to_user ""
            print_info "📖 util 모듈 사용법:"
            print_to_user "   .github/util/$project_type/ 폴더 내 README.md를 참고하세요."
            print_to_user ""
            ;;
    esac
}

# 프로젝트 타입별 util 모듈 다운로드
copy_util_modules() {
    local project_type=$1
    local util_src="$TEMP_DIR/.github/util/$project_type"
    local util_dst=".github/util/$project_type"

    # util 모듈 존재 확인
    if [ ! -d "$util_src" ]; then
        # util 모듈이 없으면 조용히 건너뜀 (모든 타입에 모듈이 있는 건 아님)
        return
    fi

    print_step "$project_type 추가 유틸리티 모듈 확인 중..."

    # 모듈 설명 표시
    show_util_module_description "$project_type"

    # 사용자 확인 (force 모드가 아니고 TTY 가용 시)
    if [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
        print_to_user "이 유틸리티 모듈을 다운로드하시겠습니까?"
        print_to_user "  Y/y - 예, 다운로드하기"
        print_to_user "  N/n - 아니오, 건너뛰기 (기본)"
        print_to_user ""

        if ! ask_yes_no "선택: " "N"; then
            print_info "util 모듈 다운로드 건너뜁니다"
            return
        fi
    elif [ "$FORCE_MODE" = true ]; then
        # Force 모드에서는 자동으로 다운로드
        print_info "강제 모드: util 모듈 자동 다운로드"
    else
        # TTY 없고 Force도 아니면 건너뛰기
        print_info "대화형 모드가 아닙니다. util 모듈을 건너뜁니다."
        print_info "util 모듈을 다운로드하려면 --force 옵션을 사용하세요."
        return
    fi

    # 다운로드 실행
    mkdir -p "$util_dst"
    cp -r "$util_src/"* "$util_dst/" 2>/dev/null || true

    # 복사된 모듈 개수 계산
    local module_count=0
    for dir in "$util_dst"/*/; do
        [ -d "$dir" ] && module_count=$((module_count + 1))
    done

    print_success "util 모듈 다운로드 완료 ($module_count 개 모듈)"

    # 복사된 모듈 목록 표시
    for dir in "$util_dst"/*/; do
        [ -d "$dir" ] || continue
        local module_name=$(basename "$dir")
        echo "  ✓ $module_name"
    done

    # 사용 가이드 표시
    show_util_usage_guide "$project_type"

    # 복사된 모듈 수를 전역 변수로 저장 (최종 요약에서 사용)
    UTIL_MODULES_COPIED=$module_count
}


# 대화형 모드
interactive_mode() {
    # Interactive 모드 플래그 설정
    IS_INTERACTIVE_MODE=true
    
    # 템플릿 버전 가져오기 (원격 version.yml)
    local template_version=""
    
    # GitHub 원격 저장소의 version.yml에서 버전 가져오기
    if command -v curl >/dev/null 2>&1; then
        template_version=$(curl -fsSL --max-time 3 \
            "${TEMPLATE_RAW_URL}/${VERSION_FILE}" \
            2>/dev/null | grep "^version:" | sed 's/version:[[:space:]]*[\"'\'']*\([^\"'\'']*\)[\"'\'']*$/\1/' | head -1)
    fi
    
    # 폴백: 버전을 가져오지 못한 경우 기본값 사용
    if [ -z "$template_version" ]; then
        template_version="$DEFAULT_VERSION"
    fi
    
    print_banner "$template_version" "Interactive (대화형 모드)"
    
    # stdin 모드 정보 표시
    if [ "$STDIN_MODE" = true ] && [ "$TTY_AVAILABLE" = true ]; then
        print_info "원격 실행 모드 감지: /dev/tty를 통해 대화형 입력 사용"
        if [ -w /dev/tty ] 2>/dev/null; then echo "" >/dev/tty; else echo "" >&2; fi
    fi
    
    # 터미널 상태 확인
    if [ "$TTY_AVAILABLE" = false ]; then
        print_error "대화형 입력이 불가능한 환경입니다 (CI/CD, non-interactive shell)"
        print_error "다음 중 하나를 사용하세요:"
        if [ -w /dev/tty ] 2>/dev/null; then
            echo "" >/dev/tty
            echo "  ${GREEN}bash <(curl -fsSL URL) --mode full --force${NC}" >/dev/tty
            echo "  ${GREEN}bash <(curl -fsSL URL) --mode version${NC}" >/dev/tty
            echo "  ${GREEN}curl -fsSL URL | bash -s -- --mode version --force${NC}" >/dev/tty
            echo "" >/dev/tty
        else
            echo "" >&2
            echo "  ${GREEN}bash <(curl -fsSL URL) --mode full --force${NC}" >&2
            echo "  ${GREEN}bash <(curl -fsSL URL) --mode version${NC}" >&2
            echo "  ${GREEN}curl -fsSL URL | bash -s -- --mode version --force${NC}" >&2
            echo "" >&2
        fi
        exit 1
    fi
    
    # 프로젝트 감지 및 확인
    detect_and_confirm_project

    # 템플릿 다운로드 (모드 선택 전 필요 — 모드 선택 후 Synology 질문에서 사용)
    download_template

    print_question_header "🚀" "어떤 기능을 통합하시겠습니까?"

    print_to_user "  1) 전체 통합 (버전관리 + 워크플로우 + 이슈템플릿)"
    print_to_user "  2) 버전 관리 시스템만"
    print_to_user "  3) GitHub Actions 워크플로우만"
    print_to_user "  4) 이슈/PR 템플릿만"
    print_to_user "  5) Agent Skill 설치 (Claude, Cursor)"
    print_to_user "  6) 취소"
    print_to_user ""

    local choice
    local valid_input=false

    # 입력 검증 루프 - 올바른 값(1-6)이 입력될 때까지 반복
    while [ "$valid_input" = false ]; do
        if safe_read "선택 (1-6): " choice "-n 1"; then
            print_to_user ""

            # 입력값 검증: 1-6 숫자만 허용
            if [[ "$choice" =~ ^[1-6]$ ]]; then
                valid_input=true
                case $choice in
                    1) MODE="full" ;;
                    2) MODE="version" ;;
                    3) MODE="workflows" ;;
                    4) MODE="issues" ;;
                    5) MODE="skills" ;;
                    6)
                        print_info "취소되었습니다"
                        exit 0
                        ;;
                esac
            else
                # 잘못된 입력 시 에러 메시지 표시 후 재입력 요청
                print_error "잘못된 입력입니다. 1-6 사이의 숫자를 입력해주세요."
                print_to_user ""
            fi
        else
            # safe_read 실패 (이론상 여기 도달 안 함)
            print_error "입력을 읽을 수 없습니다"
            exit 1
        fi
    done

    # Synology 옵션 질문: 워크플로우를 포함하는 모드(full/workflows)에서만 질문
    if [ "$MODE" = "full" ] || [ "$MODE" = "workflows" ]; then
        local type_dir="$TEMP_DIR/$WORKFLOWS_DIR/$PROJECT_TYPES_DIR/$PROJECT_TYPE"
        ask_synology_option "$type_dir"
    fi
}

# 통합 실행
execute_integration() {
    # Breaking Changes 확인 (업데이트 시)
    local current_template_version
    current_template_version=$(get_current_template_version)
    if [ "$current_template_version" != "unknown" ]; then
        check_breaking_changes "$current_template_version" "$DEFAULT_VERSION"
    fi

    # CLI 모드에서만 자동 감지 및 확인 (interactive 모드에서는 이미 감지 완료, skills 모드는 프로젝트 정보 불필요)
    if [ "$IS_INTERACTIVE_MODE" = false ] && [ "$MODE" != "skills" ]; then
        if [ -z "$PROJECT_TYPE" ]; then
            PROJECT_TYPE=$(detect_project_type)
        fi

        if [ -z "$VERSION" ]; then
            VERSION=$(detect_version)
        fi

        if [ -z "$DETECTED_BRANCH" ]; then
            DETECTED_BRANCH=$(detect_default_branch)
        fi

        # CLI 모드에서만 통합 정보 표시
        print_question_header "🪐" "통합 정보"

        print_to_user "🔭 프로젝트 타입  : $PROJECT_TYPE"
        print_to_user "🌙 초기 버전     : v$VERSION"
        print_to_user "🌿 Default 브랜치 : $DETECTED_BRANCH"
        print_to_user "💫 통합 모드     : $MODE"
        print_separator_line
        print_to_user ""

        # CLI 모드에서만 확인 질문 (force 모드가 아닐 때만)
        if [ "$FORCE_MODE" = false ]; then
            if [ "$TTY_AVAILABLE" = true ]; then
                print_to_user "이 정보로 통합을 진행하시겠습니까?"
                print_to_user "  Y/y - 예, 계속 진행"
                print_to_user "  N/n - 아니오, 취소"
                print_to_user ""

                if ! ask_yes_no "선택: " "Y"; then
                    print_info "취소되었습니다"
                    exit 0
                fi
            else
                # TTY 없음 - --force 필수
                print_error "--force 옵션이 필요합니다 (non-interactive 환경)"
                echo "" >&2
                echo "  bash <(curl -fsSL URL) --mode $MODE --force" >&2
                echo "" >&2
                exit 1
            fi
        fi
    fi
    
    echo "" >&2

    # 1. 템플릿 다운로드 (CLI 모드에서만, interactive 모드는 이미 다운로드됨)
    if [ "$IS_INTERACTIVE_MODE" = false ]; then
        download_template

        # CLI 모드에서도 Synology 질문 (워크플로우 모드에서만)
        if [ "$MODE" = "full" ] || [ "$MODE" = "workflows" ]; then
            local type_dir="$TEMP_DIR/$WORKFLOWS_DIR/$PROJECT_TYPES_DIR/$PROJECT_TYPE"
            ask_synology_option "$type_dir"
        fi
    fi

    # 2. 모드별 통합
    case $MODE in
        full)
            create_version_yml "$VERSION" "$PROJECT_TYPE" "$DETECTED_BRANCH"
            add_version_section_to_readme "$VERSION"
            copy_workflows
            copy_scripts
            copy_config_folder
            copy_util_modules "$PROJECT_TYPE"
            copy_issue_templates
            copy_discussion_templates
            copy_coderabbit_config
            ensure_gitignore
            copy_setup_guide
            ;;
        version)
            create_version_yml "$VERSION" "$PROJECT_TYPE" "$DETECTED_BRANCH"
            add_version_section_to_readme "$VERSION"
            copy_scripts
            copy_config_folder
            ensure_gitignore
            copy_setup_guide
            ;;
        workflows)
            copy_workflows
            copy_scripts
            copy_config_folder
            copy_util_modules "$PROJECT_TYPE"
            copy_setup_guide
            ;;
        issues)
            copy_issue_templates
            copy_discussion_templates
            ;;
        skills)
            # skills 모드: 템플릿 통합 없이 IDE 도구 설치만 진행
            offer_ide_tools_install

            # 임시 파일 정리 후 간결한 완료 메시지 출력하고 종료
            rm -rf "$TEMP_DIR"
            print_summary
            return 0
            ;;
    esac

    # 2.1 템플릿 옵션 저장 (Synology 설정 등)
    if [ "$MODE" = "full" ] || [ "$MODE" = "workflows" ]; then
        # INCLUDE_SYNOLOGY가 설정되지 않은 경우 기본값 false 사용
        # (basic 타입 등 Synology 폴더가 없는 경우를 위한 처리)
        if [ -z "$INCLUDE_SYNOLOGY" ]; then
            INCLUDE_SYNOLOGY=false
        fi
        # 다운로드한 템플릿의 실제 버전 전달 (TEMPLATE_VERSION 사용)
        save_template_options "$TEMPLATE_VERSION"
    fi

    # 3. IDE 도구(Skills) 설치 제안
    offer_ide_tools_install

    # 4. 임시 파일 정리
    rm -rf "$TEMP_DIR"

    # 완료 메시지
    print_summary
}

# ===================================================================
# IDE 도구(Skills) 설치 제안
# Claude Code: 플러그인 마켓플레이스 자동 설치
# Cursor: skills/ → .cursor/skills/ 복사
# ===================================================================

offer_ide_tools_install() {
    local claude_available=false

    # Claude Code CLI 존재 여부 감지
    if command -v claude &> /dev/null; then
        claude_available=true
    fi

    # ─── 현재 설치 상태 수집 ───
    local installed_scope=""
    local installed_version=""
    if [ "$claude_available" = true ]; then
        local plugin_json
        plugin_json=$(claude plugin list --json 2>/dev/null || echo "[]")
        local plugin_entry
        plugin_entry=$(echo "$plugin_json" | grep -A5 '"cassiiopeia@' | head -10)
        if [ -n "$plugin_entry" ]; then
            installed_scope=$(echo "$plugin_entry" | grep '"scope"' | sed 's/.*"scope": *"\([^"]*\)".*/\1/')
            installed_version=$(echo "$plugin_entry" | grep '"version"' | sed 's/.*"version": *"\([^"]*\)".*/\1/')
        fi
    fi

    # ─── 통합 상태 표시 ───
    echo "" >&2
    print_separator_line
    print_step "IDE Skills 현재 상태"
    echo "" >&2

    # Claude Code 상태
    if [ "$claude_available" = true ]; then
        if [ -n "$installed_scope" ]; then
            local cv_tag=""
            [ -n "$TEMPLATE_VERSION" ] && [ "$installed_version" = "$TEMPLATE_VERSION" ] && cv_tag=" ✓ 최신버전"
            [ -n "$TEMPLATE_VERSION" ] && [ "$installed_version" != "$TEMPLATE_VERSION" ] && cv_tag=" → 업데이트 가능: v${TEMPLATE_VERSION}"
            print_info "Claude Code  ${installed_scope}   v${installed_version}${cv_tag}"
        else
            print_info "Claude Code : 미설치"
        fi
    else
        print_info "Claude Code : CLI 미감지 (수동 설치 필요)"
    fi

    # Cursor 상태 (user/project 각각)
    local _cur_u_ver="" _cur_p_ver=""
    local _cur_u_meta="${HOME}/.cursor/skills/cursor-skills-meta.json"
    local _cur_p_meta=".cursor/skills/cursor-skills-meta.json"
    [ -f "$_cur_u_meta" ] && _cur_u_ver=$(grep '"version"' "$_cur_u_meta" | sed 's/.*"version": *"\([^"]*\)".*/\1/' | head -1)
    [ -f "$_cur_p_meta" ] && _cur_p_ver=$(grep '"version"' "$_cur_p_meta" | sed 's/.*"version": *"\([^"]*\)".*/\1/' | head -1)

    if [ -z "$_cur_u_ver" ] && [ -z "$_cur_p_ver" ]; then
        print_info "Cursor      : 미설치"
    else
        if [ -n "$_cur_u_ver" ]; then
            local utag=""
            [ -n "$TEMPLATE_VERSION" ] && [ "$_cur_u_ver" = "$TEMPLATE_VERSION" ] && utag=" ✓ 최신버전"
            [ -n "$TEMPLATE_VERSION" ] && [ "$_cur_u_ver" != "$TEMPLATE_VERSION" ] && utag=" → 업데이트 가능: v${TEMPLATE_VERSION}"
            print_info "Cursor       user   v${_cur_u_ver} (~/.cursor/skills/)${utag}"
        fi
        if [ -n "$_cur_p_ver" ]; then
            local ptag=""
            [ -n "$TEMPLATE_VERSION" ] && [ "$_cur_p_ver" = "$TEMPLATE_VERSION" ] && ptag=" ✓ 최신버전"
            [ -n "$TEMPLATE_VERSION" ] && [ "$_cur_p_ver" != "$TEMPLATE_VERSION" ] && ptag=" → 업데이트 가능: v${TEMPLATE_VERSION}"
            print_info "Cursor       project v${_cur_p_ver} (.cursor/skills/)${ptag}"
        fi
    fi
    echo "" >&2

    # ─── Claude Code 섹션 ───
    print_step "[ Claude Code 플러그인 관리 ]"
    echo "" >&2

    if [ "$claude_available" = true ]; then
        if [ -n "$installed_scope" ]; then
            local update_label="업데이트 (최신 버전으로)"
            if [ -n "$TEMPLATE_VERSION" ] && [ "$installed_version" = "$TEMPLATE_VERSION" ]; then
                update_label="업데이트 (이미 최신 — 재적용)"
            fi

            if [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
                print_to_user "  1 - ${update_label}"
                print_to_user "  2 - 재설치 (scope 변경)"
                print_to_user "  3 - 삭제"
                print_to_user "      삭제 대상: cassiiopeia@cassiiopeia-marketplace (scope: ${installed_scope})"
                print_to_user "                 ~/.claude/plugins/data/cassiiopeia@cassiiopeia-marketplace/"
                print_to_user "  4 - 건너뛰기"
                print_to_user ""

                local choice
                if [ -c /dev/tty ]; then
                    read -r choice < /dev/tty
                else
                    read -r choice
                fi

                case "$choice" in
                    1)
                        print_step "플러그인 업데이트 중..."
                        if claude plugin update cassiiopeia@cassiiopeia-marketplace --scope "$installed_scope" 2>/dev/null; then
                            print_success "업데이트 완료 (scope: ${installed_scope})"
                        else
                            print_warning "업데이트 실패. 수동으로 실행해주세요:"
                            echo "    claude plugin update cassiiopeia@cassiiopeia-marketplace --scope ${installed_scope}" >&2
                        fi
                        ;;
                    2)
                        print_step "기존 플러그인 삭제 중 (scope: ${installed_scope})..."
                        claude plugin uninstall cassiiopeia@cassiiopeia-marketplace --scope "$installed_scope" 2>/dev/null || true
                        _remove_claude_plugin_data
                        local new_scope
                        new_scope=$(_ask_claude_scope)
                        _do_claude_plugin_install "$new_scope"
                        ;;
                    3)
                        print_step "플러그인 삭제 중..."
                        print_info "  삭제 대상: cassiiopeia@cassiiopeia-marketplace (scope: ${installed_scope})"
                        print_info "             ~/.claude/plugins/data/cassiiopeia@cassiiopeia-marketplace/"
                        if claude plugin uninstall cassiiopeia@cassiiopeia-marketplace --scope "$installed_scope" 2>/dev/null; then
                            print_success "플러그인 uninstall 완료"
                            _remove_claude_plugin_data
                        else
                            print_warning "삭제 실패. 수동으로 실행해주세요:"
                            echo "    claude plugin uninstall cassiiopeia@cassiiopeia-marketplace --scope ${installed_scope}" >&2
                        fi
                        ;;
                    *)
                        print_info "Claude Code 플러그인 변경 없이 건너뜁니다"
                        ;;
                esac
            else
                # FORCE 모드: 업데이트
                print_step "플러그인 업데이트 중 (FORCE)..."
                claude plugin update cassiiopeia@cassiiopeia-marketplace --scope "$installed_scope" 2>/dev/null || true
                print_success "업데이트 완료 (scope: ${installed_scope})"
            fi
        else
            # 미설치 → scope 선택 후 신규 설치
            if [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
                print_to_user "Claude Code 플러그인(DevOps Skills)을 설치하시겠습니까?"
                print_to_user "  설치 시 /cassiiopeia:analyze, /cassiiopeia:review 등 19+ 스킬 사용 가능"
                print_to_user ""
                print_to_user "  Y/y - 예, 설치하기 (추천)"
                print_to_user "  N/n - 아니오, 건너뛰기"
                print_to_user ""

                if ask_yes_no "선택: " "Y"; then
                    local scope
                    scope=$(_ask_claude_scope)
                    _do_claude_plugin_install "$scope"
                else
                    print_info "Claude Code 플러그인 설치 건너뜁니다"
                    echo "  수동 설치: claude plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE" >&2
                    echo "             claude plugin install cassiiopeia@cassiiopeia-marketplace --scope user" >&2
                fi
            else
                _do_claude_plugin_install "user"
            fi
        fi
    else
        echo "  💡 Claude Code 사용자: claude plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE" >&2
        echo "                         claude plugin install cassiiopeia@cassiiopeia-marketplace --scope user" >&2
    fi

    # ─── Cursor 섹션 ───
    # Cursor는 마켓플레이스 미지원 — 파일 직접 복사로 관리한다.
    # scope 개념:
    #   user    = ~/.cursor/skills/      (모든 프로젝트 공통)
    #   project = ./.cursor/skills/      (현재 프로젝트 전용)
    local cursor_user_meta="${HOME}/.cursor/skills/cursor-skills-meta.json"
    local cursor_proj_meta=".cursor/skills/cursor-skills-meta.json"
    local cursor_user_ver="" cursor_proj_ver=""
    [ -f "$cursor_user_meta" ] && cursor_user_ver=$(grep '"version"' "$cursor_user_meta" | sed 's/.*"version": *"\([^"]*\)".*/\1/' | head -1)
    [ -f "$cursor_proj_meta" ] && cursor_proj_ver=$(grep '"version"' "$cursor_proj_meta" | sed 's/.*"version": *"\([^"]*\)".*/\1/' | head -1)

    # 스킬 파일 소스 후보
    local skills_src_remote="" skills_src_local=""
    [ -d "$TEMP_DIR/skills" ] && skills_src_remote="$TEMP_DIR/skills"
    [ -d "skills" ]           && skills_src_local="skills"

    echo "" >&2
    print_step "[ Cursor Skills 관리 ]"
    echo "" >&2

    # 설치 여부 판단 — user/project 각각 독립 처리
    local cursor_any_installed=false
    [ -n "$cursor_user_ver" ] && cursor_any_installed=true
    [ -n "$cursor_proj_ver" ] && cursor_any_installed=true

    if [ "$cursor_any_installed" = true ]; then
        # 설치된 위치별 상태 표시
        if [ -n "$cursor_user_ver" ]; then
            local utag=""
            [ -n "$TEMPLATE_VERSION" ] && [ "$cursor_user_ver" = "$TEMPLATE_VERSION" ] && utag=" ✓ 최신버전"
            [ -n "$TEMPLATE_VERSION" ] && [ "$cursor_user_ver" != "$TEMPLATE_VERSION" ] && utag=" → 업데이트 가능: v${TEMPLATE_VERSION}"
            print_info "  user    v${cursor_user_ver} (~/.cursor/skills/)${utag}"
        fi
        if [ -n "$cursor_proj_ver" ]; then
            local ptag=""
            [ -n "$TEMPLATE_VERSION" ] && [ "$cursor_proj_ver" = "$TEMPLATE_VERSION" ] && ptag=" ✓ 최신버전"
            [ -n "$TEMPLATE_VERSION" ] && [ "$cursor_proj_ver" != "$TEMPLATE_VERSION" ] && ptag=" → 업데이트 가능: v${TEMPLATE_VERSION}"
            print_info "  project v${cursor_proj_ver} (.cursor/skills/)${ptag}"
        fi
        echo "" >&2

        if [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
            print_to_user "어떻게 하시겠습니까?"
            print_to_user "  1 - 업데이트 (기존 scope 유지)"
            print_to_user "  2 - 신규 설치 (다른 scope에 추가)"
            print_to_user "  3 - 삭제"
            print_to_user "  4 - 건너뛰기"
            print_to_user ""

            local cursor_choice
            if [ -c /dev/tty ]; then
                read -r cursor_choice < /dev/tty
            else
                read -r cursor_choice
            fi

            case "$cursor_choice" in
                1)
                    # 업데이트: 기존 설치 scope 유지 (둘 다 있으면 scope 선택)
                    local target_scope
                    if [ -n "$cursor_user_ver" ] && [ -n "$cursor_proj_ver" ]; then
                        target_scope=$(_ask_cursor_scope "$cursor_user_ver" "$cursor_proj_ver")
                    elif [ -n "$cursor_user_ver" ]; then
                        target_scope="user"
                    else
                        target_scope="project"
                    fi
                    local src
                    src=$(_ask_cursor_skills_src "$skills_src_remote" "$skills_src_local")
                    if [ -z "$src" ]; then
                        print_warning "사용 가능한 소스가 없습니다."
                    else
                        _do_cursor_skills_copy "$target_scope" "$src"
                    fi
                    ;;
                2)
                    # 신규 설치: scope 자유 선택 (다른 scope에 추가)
                    local target_scope
                    target_scope=$(_ask_cursor_scope "" "")
                    local src
                    src=$(_ask_cursor_skills_src "$skills_src_remote" "$skills_src_local")
                    if [ -z "$src" ]; then
                        print_warning "사용 가능한 소스가 없습니다."
                    else
                        _do_cursor_skills_copy "$target_scope" "$src"
                    fi
                    ;;
                3)
                    _ask_cursor_delete "$cursor_user_ver" "$cursor_proj_ver"
                    ;;
                *)
                    print_info "Cursor Skills 변경 없이 건너뜁니다"
                    ;;
            esac
        else
            # FORCE 모드: project scope, 원격 우선
            local src="${skills_src_remote:-$skills_src_local}"
            [ -n "$src" ] && _do_cursor_skills_copy "project" "$src" "force"
        fi
    else
        # 미설치 → 설치
        if [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
            print_to_user "Cursor IDE Skills를 설치하시겠습니까?"
            print_to_user "  /analyze, /review 등 20개 스킬 사용 가능 (마켓플레이스 미지원 — 파일 직접 복사)"
            print_to_user ""
            print_to_user "  Y/y - 예, 설치하기 (추천)"
            print_to_user "  N/n - 아니오, 건너뛰기"
            print_to_user ""

            if ask_yes_no "선택: " "Y"; then
                local target_scope
                target_scope=$(_ask_cursor_scope "" "")
                local src
                src=$(_ask_cursor_skills_src "$skills_src_remote" "$skills_src_local")
                if [ -z "$src" ]; then
                    print_warning "사용 가능한 소스가 없습니다. 건너뜁니다."
                else
                    _do_cursor_skills_copy "$target_scope" "$src"
                fi
            else
                print_info "Cursor Skills 설치 건너뜁니다"
            fi
        else
            # FORCE 모드: project scope, 원격 우선
            local src="${skills_src_remote:-$skills_src_local}"
            [ -n "$src" ] && _do_cursor_skills_copy "project" "$src" "force"
        fi
    fi
}

# ─── Claude Code 헬퍼 ───────────────────────────────────────────

# scope 선택 (user / project)
_ask_claude_scope() {
    print_to_user ""
    print_to_user "설치 scope를 선택하세요:"
    print_to_user "  1 - user    (모든 프로젝트에서 사용, 추천)"
    print_to_user "  2 - project (현재 프로젝트에서만 사용)"
    print_to_user ""

    local scope_choice
    if [ -c /dev/tty ]; then
        read -r scope_choice < /dev/tty
    else
        read -r scope_choice
    fi

    case "$scope_choice" in
        2) echo "project" ;;
        *) echo "user" ;;
    esac
}

# 마켓플레이스 등록 + 플러그인 설치
_do_claude_plugin_install() {
    local scope="$1"
    print_step "Claude Code 마켓플레이스 등록 중..."
    if claude plugin marketplace add Cassiiopeia/SUH-DEVOPS-TEMPLATE 2>/dev/null; then
        print_success "마켓플레이스 등록 완료"
    else
        print_info "마켓플레이스 이미 등록되어 있거나 등록 생략"
    fi

    print_step "Claude Code 플러그인 설치 중 (scope: ${scope})..."
    if claude plugin install cassiiopeia@cassiiopeia-marketplace --scope "$scope" 2>/dev/null; then
        print_success "Claude Code 플러그인 설치 완료 (cassiiopeia, scope: ${scope})"
    else
        print_warning "플러그인 설치 실패. 수동으로 설치해주세요:"
        echo "    claude plugin install cassiiopeia@cassiiopeia-marketplace --scope ${scope}" >&2
        echo "" >&2
    fi
}

# plugin data(config) 디렉토리 삭제
# Claude Code는 ~/.claude/plugins/data/{id}/ 에 plugin 설정을 저장한다.
_remove_claude_plugin_data() {
    # Claude Code plugin data 경로: ~/.claude/plugins/data/{plugin-id}/
    # plugin id는 "cassiiopeia@cassiiopeia-marketplace" 형태 그대로 사용된다.
    local data_dir="${HOME}/.claude/plugins/data/cassiiopeia@cassiiopeia-marketplace"

    if [ -d "$data_dir" ]; then
        rm -rf "$data_dir" 2>/dev/null
        print_success "플러그인 데이터(config) 삭제 완료"
    fi
    # data 디렉토리가 없는 경우는 정상 — 별도 메시지 불필요
}

# ─── Cursor 헬퍼 ────────────────────────────────────────────────

# cursor-skills-meta.json 생성/갱신
# 인자: $1=scope(user|project, 생략 시 project), $2=설치경로(생략 시 .cursor/skills)
_write_cursor_skills_meta() {
    local scope="${1:-project}"
    local dest_dir="${2:-.cursor/skills}"
    local version="${TEMPLATE_VERSION:-unknown}"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")
    local meta_file="${dest_dir}/cursor-skills-meta.json"

    # 업데이트 시 installedAt 기존 값 보존
    local installed_at="$timestamp"
    if [ -f "$meta_file" ]; then
        local existing
        existing=$(grep '"installedAt"' "$meta_file" | sed 's/.*"installedAt": *"\([^"]*\)".*/\1/')
        [ -n "$existing" ] && installed_at="$existing"
    fi

    mkdir -p "$dest_dir"
    cat > "$meta_file" <<EOF
{
  "name": "cassiiopeia",
  "version": "${version}",
  "scope": "${scope}",
  "source": "https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE",
  "installPath": "${dest_dir}",
  "installedAt": "${installed_at}",
  "lastUpdated": "${timestamp}"
}
EOF
}

# .cursor/skills/ 전체 삭제 (메타데이터 포함)
_remove_cursor_skills() {
    if [ -d ".cursor/skills" ]; then
        rm -rf .cursor/skills 2>/dev/null
        print_success "Cursor Skills 삭제 완료 (.cursor/skills/ 제거)"
    else
        print_info "삭제할 Cursor Skills 없음"
    fi
}

# Cursor scope 선택 (user / project)
# 인자: $1=현재 user 버전(없으면 빈 문자열), $2=현재 project 버전
_ask_cursor_scope() {
    local user_ver="$1"
    local proj_ver="$2"
    print_to_user ""
    print_to_user "설치 scope를 선택하세요:"
    if [ -n "$user_ver" ]; then
        print_to_user "  1 - user    (모든 프로젝트 공통, ~/.cursor/skills/)  현재: v${user_ver}"
    else
        print_to_user "  1 - user    (모든 프로젝트 공통, ~/.cursor/skills/)"
    fi
    if [ -n "$proj_ver" ]; then
        print_to_user "  2 - project (현재 프로젝트 전용, .cursor/skills/)   현재: v${proj_ver}"
    else
        print_to_user "  2 - project (현재 프로젝트 전용, .cursor/skills/)"
    fi
    print_to_user ""

    local scope_choice
    if [ -c /dev/tty ]; then
        read -r scope_choice < /dev/tty
    else
        read -r scope_choice
    fi

    case "$scope_choice" in
        1) echo "user" ;;
        *) echo "project" ;;
    esac
}

# Cursor Skills 실제 복사 실행
# 인자: $1=scope(user|project), $2=소스경로, $3=force(선택)
_do_cursor_skills_copy() {
    local scope="$1"
    local src="$2"
    local dest
    if [ "$scope" = "user" ]; then
        dest="${HOME}/.cursor/skills"
    else
        dest=".cursor/skills"
    fi

    print_step "Cursor Skills 복사 중 (scope: ${scope})..."
    mkdir -p "$dest"
    if cp -r "$src/"* "$dest/" 2>/dev/null; then
        _write_cursor_skills_meta "$scope" "$dest"
        print_success "Cursor Skills 완료 (scope: ${scope}, 경로: ${dest}/)"
    else
        print_warning "Cursor Skills 복사 실패"
    fi
}

# Cursor Skills 삭제 (scope 선택)
# 인자: $1=현재 user 버전, $2=현재 project 버전
_ask_cursor_delete() {
    local user_ver="$1"
    local proj_ver="$2"

    print_to_user "삭제할 scope를 선택하세요:"
    [ -n "$user_ver" ]  && print_to_user "  1 - user    (~/.cursor/skills/)  v${user_ver}"
    [ -n "$proj_ver" ]  && print_to_user "  2 - project (.cursor/skills/)    v${proj_ver}"
    [ -n "$user_ver" ] && [ -n "$proj_ver" ] && print_to_user "  3 - 모두 삭제"
    print_to_user "  0 - 취소"
    print_to_user ""

    local del_choice
    if [ -c /dev/tty ]; then
        read -r del_choice < /dev/tty
    else
        read -r del_choice
    fi

    case "$del_choice" in
        1)
            if [ -n "$user_ver" ]; then
                print_info "삭제 대상: ~/.cursor/skills/ (v${user_ver})"
                rm -rf "${HOME}/.cursor/skills" 2>/dev/null
                print_success "user scope Cursor Skills 삭제 완료"
            else
                print_warning "user scope에 설치된 Skills 없음"
            fi
            ;;
        2)
            if [ -n "$proj_ver" ]; then
                print_info "삭제 대상: .cursor/skills/ (v${proj_ver})"
                rm -rf ".cursor/skills" 2>/dev/null
                print_success "project scope Cursor Skills 삭제 완료"
            else
                print_warning "project scope에 설치된 Skills 없음"
            fi
            ;;
        3)
            if [ -n "$user_ver" ] && [ -n "$proj_ver" ]; then
                print_info "삭제 대상: ~/.cursor/skills/ (v${user_ver}), .cursor/skills/ (v${proj_ver})"
                rm -rf "${HOME}/.cursor/skills" ".cursor/skills" 2>/dev/null
                print_success "모든 Cursor Skills 삭제 완료"
            else
                print_warning "잘못된 선택입니다"
            fi
            ;;
        *)
            print_info "삭제 취소"
            ;;
    esac
}

# Cursor Skills 복사 소스 선택 (원격/로컬 가용 여부에 따라 메뉴 구성)
# 인자: $1=원격소스경로, $2=로컬소스경로
# stdout으로 선택된 경로 반환, 없으면 빈 문자열
_ask_cursor_skills_src() {
    local remote_src="$1"
    local local_src="$2"

    # 선택지가 하나뿐이면 바로 반환
    if [ -n "$remote_src" ] && [ -z "$local_src" ]; then
        echo "$remote_src"
        return
    fi
    if [ -z "$remote_src" ] && [ -n "$local_src" ]; then
        echo "$local_src"
        return
    fi
    if [ -z "$remote_src" ] && [ -z "$local_src" ]; then
        echo ""
        return
    fi

    # 양쪽 다 있을 때만 사용자에게 선택 요청
    print_to_user ""
    print_to_user "설치 소스를 선택하세요:"
    print_to_user "  1 - 원격 최신 (repo에서 다운로드, 추천)"
    print_to_user "  2 - 로컬 (현재 디렉토리 skills/ 폴더)"
    print_to_user ""

    local src_choice
    if [ -c /dev/tty ]; then
        read -r src_choice < /dev/tty
    else
        read -r src_choice
    fi

    case "$src_choice" in
        2) echo "$local_src" ;;
        *) echo "$remote_src" ;;
    esac
}

# 완료 요약
print_summary() {
    echo "" >&2
    print_separator_line
    echo "" >&2
    echo "✨ SUH-DEVOPS-TEMPLATE Setup Complete!" >&2
    echo "" >&2
    print_separator_line
    echo "" >&2
    echo "통합된 기능:" >&2
    
    case $MODE in
        full)
            echo "  ✅ 버전 관리 시스템 (version.yml)" >&2
            echo "  ✅ README.md 자동 버전 업데이트" >&2
            echo "  ✅ GitHub Actions 워크플로우" >&2
            if [ -n "$UTIL_MODULES_COPIED" ] && [ "$UTIL_MODULES_COPIED" -gt 0 ]; then
                echo "  ✅ 유틸리티 모듈 ($UTIL_MODULES_COPIED 개)" >&2
            fi
            echo "  ✅ 이슈/PR/Discussion 템플릿" >&2
            echo "  ✅ CodeRabbit AI 리뷰 설정" >&2
            echo "  ✅ .gitignore 필수 항목" >&2
            echo "  ✅ 템플릿 설정 가이드 (SETUP-GUIDE.md)" >&2
            ;;
        version)
            echo "  ✅ 버전 관리 시스템 (version.yml)" >&2
            echo "  ✅ README.md 자동 버전 업데이트" >&2
            echo "  ✅ .gitignore 필수 항목" >&2
            echo "  ✅ 템플릿 설정 가이드 (SETUP-GUIDE.md)" >&2
            ;;
        workflows)
            echo "  ✅ GitHub Actions 워크플로우" >&2
            if [ -n "$UTIL_MODULES_COPIED" ] && [ "$UTIL_MODULES_COPIED" -gt 0 ]; then
                echo "  ✅ 유틸리티 모듈 ($UTIL_MODULES_COPIED 개)" >&2
            fi
            echo "  ✅ 템플릿 설정 가이드 (SETUP-GUIDE.md)" >&2
            ;;
        issues)
            echo "  ✅ 이슈/PR/Discussion 템플릿" >&2
            ;;
        skills)
            echo "  ✅ Agent Skill 설치 (Claude, Cursor)" >&2
            ;;
    esac

    # skills 모드: 파일/워크플로우 추가 없으므로 간결하게 종료
    if [ "$MODE" = "skills" ]; then
        echo "" >&2
        echo "  📖 TEMPLATE REPO: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE" >&2
        echo "" >&2
        print_separator_line
        echo "" >&2
        return
    fi

    echo "" >&2
    echo "추가된 파일:" >&2
    echo "  📄 version.yml (버전: $VERSION, 타입: $PROJECT_TYPE)" >&2
    echo "  📝 README.md (버전 섹션 추가)" >&2
    echo "" >&2
    echo "추가된 워크플로우:" >&2
    
    # 워크플로우 분류 저장용 배열
    local common_workflows=()
    local type_workflows=()
    local existing_workflows=()
    
    # 실제 복사된 워크플로우와 기존 파일 구분
    if [ -d "$WORKFLOWS_DIR" ]; then
        for wf in "$WORKFLOWS_DIR/$WORKFLOW_PREFIX"-*.{yaml,yml}; do
            [ -e "$wf" ] || continue
            local filename=$(basename "$wf")
            
            # TEMPLATE-INITIALIZER는 기존 파일로 분류
            if [[ "$filename" == "$WORKFLOW_TEMPLATE_INIT" ]]; then
                existing_workflows+=("$filename")
            elif [[ "$filename" =~ ^${WORKFLOW_COMMON_PREFIX}- ]]; then
                common_workflows+=("$filename")
            elif [[ "$filename" =~ ^${WORKFLOW_PREFIX}-$(echo "$PROJECT_TYPE" | tr '[:lower:]' '[:upper:]')- ]]; then
                type_workflows+=("$filename")
            fi
        done
    fi
    
    # 새로 설치된 워크플로우 출력
    if [ ${#common_workflows[@]} -gt 0 ] || [ ${#type_workflows[@]} -gt 0 ]; then
        echo "  📦 새로 설치됨 (${WORKFLOWS_COPIED:-0}개):" >&2
        
        # 공통 워크플로우
        for wf in "${common_workflows[@]}"; do
            echo "     📌 $wf" >&2
        done
        
        # 타입별 워크플로우
        for wf in "${type_workflows[@]}"; do
            echo "     🎯 $wf" >&2
        done
    fi
    
    # 기존 파일 유지됨 표시
    if [ ${#existing_workflows[@]} -gt 0 ]; then
        echo "" >&2
        echo "  🔧 기존 파일 유지됨:" >&2
        for wf in "${existing_workflows[@]}"; do
            echo "     📌 $wf (템플릿 전용)" >&2
        done
    fi
    
    echo "" >&2
    echo "  🔧 .github/scripts/" >&2
    echo "     ├─ version_manager.sh" >&2
    echo "     └─ changelog_manager.py" >&2
    echo "" >&2
    
    # util 모듈 정보 표시
    if [ -n "$UTIL_MODULES_COPIED" ] && [ "$UTIL_MODULES_COPIED" -gt 0 ]; then
        echo "  🧙 유틸리티 모듈:" >&2
        if [ -d ".github/util/$PROJECT_TYPE" ]; then
            for dir in ".github/util/$PROJECT_TYPE"/*/; do
                [ -d "$dir" ] || continue
                local module_name=$(basename "$dir")
                echo "     ├─ $module_name" >&2
            done
        fi
        echo "" >&2
    fi

    # 프로젝트 타입별 안내
    if [ "$PROJECT_TYPE" = "spring" ]; then
        echo "  💡 Spring 프로젝트 추가 설정:" >&2
        echo "     • build.gradle의 버전 정보가 자동 동기화됩니다" >&2
        echo "     • CI/CD 워크플로우에서 GitHub Secrets 설정이 필요합니다" >&2
        echo "     • 자세한 설정 방법: .github/workflows/project-types/spring/README.md" >&2
        echo "" >&2
    fi

    # Flutter util 모듈 안내
    if [ "$PROJECT_TYPE" = "flutter" ] && [ -n "$UTIL_MODULES_COPIED" ] && [ "$UTIL_MODULES_COPIED" -gt 0 ]; then
        echo "  💡 Flutter 배포 마법사 사용법:" >&2
        echo "     • iOS TestFlight: .github/util/flutter/ios-testflight-setup-wizard/index.html" >&2
        echo "     • Android Play Store: .github/util/flutter/android-playstore-setup-wizard/index.html" >&2
        echo "     • 브라우저에서 열어 필요한 정보 입력 후 파일 생성" >&2
        echo "" >&2
    fi
    
    echo "  📖 TEMPLATE REPO: https://github.com/Cassiiopeia/SUH-DEVOPS-TEMPLATE" >&2
    echo "  📚 워크플로우 가이드: .github/workflows/project-types/README.md" >&2
    echo "" >&2
    
    # 필수 3가지 작업 안내
    print_separator_line
    echo "" >&2
    echo -e "${YELLOW}⚠️  다음 3가지 작업을 완료해주세요:${NC}" >&2
    echo "" >&2
    echo "  1️⃣  GitHub Personal Access Token 설정" >&2
    echo "     → Repository Settings > Secrets > Actions" >&2
    echo "     → Secret Name: _GITHUB_PAT_TOKEN" >&2
    echo "     → Scopes: repo, workflow" >&2
    echo "" >&2
    echo "  2️⃣  deploy 브랜치 생성" >&2
    echo "     → git checkout -b deploy && git push -u origin deploy" >&2
    echo "" >&2
    echo "  3️⃣  CodeRabbit 활성화" >&2
    echo "     → https://coderabbit.ai 방문하여 저장소 활성화" >&2
    echo "" >&2
    print_separator_line
    echo "" >&2
    echo -e "${CYAN}📖 자세한 설정 방법은 다음 파일을 참고하세요:${NC}" >&2
    echo "   → SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md" >&2
    echo "" >&2
}

# 메인 실행
main() {
    # 터미널 상태 감지 (최우선)
    detect_terminal
    
    # stdin 모드 디버그 정보 (개발 시 유용)
    if [ "$STDIN_MODE" = true ]; then
        if [ "$TTY_AVAILABLE" = true ]; then
            print_info "실행 모드: 원격 (stdin), TTY 가용"
        else
            print_info "실행 모드: 원격 (stdin), TTY 불가 (자동화 환경)"
        fi
        echo "" >&2
    fi
    
    # Git 저장소 확인 (경고만 표시)
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_warning "Git 저장소가 아닙니다. 일부 기능이 제한될 수 있습니다."
        echo "" >&2
    fi
    
    # 대화형 모드
    if [ "$MODE" = "interactive" ]; then
        interactive_mode
    fi
    
    # 통합 실행
    execute_integration
}

# 스크립트 실행
main "$@"

