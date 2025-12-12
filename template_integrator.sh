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
  ${GREEN}interactive${NC} - 대화형 선택 (기본값, 추천)

${BLUE}옵션:${NC}
  -m, --mode MODE          통합 모드 선택
  -v, --version VERSION    초기 버전 (미지정 시 자동 감지)
  -t, --type TYPE          프로젝트 타입 (미지정 시 자동 감지)
  --no-backup              백업 생성 안 함
  --force                  확인 없이 즉시 실행
  -h, --help               이 도움말 표시

${BLUE}지원 프로젝트 타입:${NC}
  • ${GREEN}node${NC} / ${GREEN}react${NC} / ${GREEN}react-native${NC} - Node.js 기반 프로젝트
  • ${GREEN}spring${NC}            - Spring Boot 백엔드
  • ${GREEN}flutter${NC}           - Flutter 모바일 앱
  • ${GREEN}python${NC}            - Python 프로젝트
  • ${GREEN}basic${NC}             - 기타 프로젝트

${BLUE}자동 감지 기능:${NC}
  • package.json 발견 → Node.js 프로젝트로 감지
  • @react-native 의존성 → React Native
  • build.gradle → Spring Boot
  • pubspec.yaml → Flutter
  • pyproject.toml → Python

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
    
    # Node.js / React / React Native
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
    
    # Spring Boot
    if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ] || [ -f "pom.xml" ]; then
        print_info "감지됨: Spring Boot"
        echo "spring"
        return
    fi
    
    # Flutter
    if [ -f "pubspec.yaml" ]; then
        print_info "감지됨: Flutter"
        echo "flutter"
        return
    fi
    
    # Python
    if [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
        print_info "감지됨: Python"
        echo "python"
        return
    fi
    
    # 감지 실패
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
        "ARCHITECTURE.md"
        "CONTRIBUTING.md"
    )
    
    for doc in "${docs_to_remove[@]}"; do
        if [ -f "$TEMP_DIR/$doc" ]; then
            rm -f "$TEMP_DIR/$doc"
        fi
    done
    
    # 사용자 적용 가이드 문서는 포함 (SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md)
    print_info "사용자 적용 가이드 문서 다운로드 중..."
    if [ -f "$TEMP_DIR/SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md" ]; then
        print_info "✓ SUH-DEVOPS-TEMPLATE-SETUP-GUIDE.md"
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
    
    # 이미 버전 섹션이 있는지 확인 (다중 패턴 체크로 강화)
    # 1. 주석 체크 (가장 확실한 방법)
    if grep -qiE "(<!-- AUTO-VERSION-SECTION|<!-- END-AUTO-VERSION-SECTION)" README.md; then
        print_info "이미 버전 관리 섹션이 있습니다. (주석 감지)"
        return
    fi
    
    # 2. 버전 라인 체크 (버전 번호 포함 필수 - False Positive 방지)
    # 버전 번호 패턴(v1.0.0 형식)이 포함된 경우만 버전 섹션으로 인식
    if grep -qiE "##[[:space:]]*(최신[[:space:]]*버전|최신버전|Version|버전)[[:space:]]*:[[:space:]]*v[0-9]+\.[0-9]+\.[0-9]+" README.md; then
        print_info "이미 버전 관리 섹션이 있습니다. (버전 라인 감지)"
        return
    fi
    
    # README.md 끝에 버전 섹션 추가
    cat >> README.md << EOF

---

<!-- AUTO-VERSION-SECTION: DO NOT EDIT MANUALLY -->
<!-- 이 섹션은 .github/workflows/PROJECT-README-VERSION-UPDATE.yaml에 의해 자동으로 업데이트됩니다 -->
## 최신 버전 : v${version}

[전체 버전 기록 보기](CHANGELOG.md)
<!-- END-AUTO-VERSION-SECTION -->
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
    
    print_step "version.yml 생성 중..."
    
    if [ -f "version.yml" ]; then
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
version_code: 1  # app build number
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

# 워크플로우 다운로드 (폴더 기반, 단순화)
copy_workflows() {
    print_step "프로젝트 타입별 워크플로우 다운로드 중..."
    print_info "프로젝트 타입: $PROJECT_TYPE"
    
    mkdir -p "$WORKFLOWS_DIR"
    
    local copied=0
    local project_types_dir="$TEMP_DIR/$WORKFLOWS_DIR/$PROJECT_TYPES_DIR"
    
    # project-types 폴더 존재 확인
    if [ ! -d "$project_types_dir" ]; then
        print_error "템플릿 저장소의 폴더 구조가 올바르지 않습니다."
        print_error "project-types 폴더를 찾을 수 없습니다."
        exit 1
    fi
    
    # 1. Common 워크플로우 다운로드 (필수)
    print_info "공통 워크플로우 다운로드 중..."
    if [ -d "$project_types_dir/common" ]; then
        for workflow in "$project_types_dir/common"/*.{yaml,yml}; do
            [ -e "$workflow" ] || continue
            local filename=$(basename "$workflow")
            
            if [ -f "$WORKFLOWS_DIR/$filename" ]; then
                print_warning "$filename 이미 존재 → ${filename}.bak으로 백업"
                mv "$WORKFLOWS_DIR/$filename" "$WORKFLOWS_DIR/${filename}.bak"
            fi
            
            cp "$workflow" "$WORKFLOWS_DIR/"
            echo "  ✓ $filename"
            copied=$((copied + 1))
        done
    else
        print_warning "common 폴더를 찾을 수 없습니다. 건너뜁니다."
    fi
    
    # 2. 타입별 워크플로우 다운로드 (optional 구분 없이 전체 다운로드)
    local type_dir="$project_types_dir/$PROJECT_TYPE"
    if [ -d "$type_dir" ]; then
        print_info "$PROJECT_TYPE 전용 워크플로우 다운로드 중..."
        
        for workflow in "$type_dir"/*.{yaml,yml}; do
            [ -e "$workflow" ] || continue
            
            local filename=$(basename "$workflow")
            
            if [ -f "$WORKFLOWS_DIR/$filename" ]; then
                print_warning "$filename 이미 존재 → ${filename}.bak으로 백업"
                mv "$WORKFLOWS_DIR/$filename" "$WORKFLOWS_DIR/${filename}.bak"
            fi
            
            cp "$workflow" "$WORKFLOWS_DIR/"
            echo "  ✓ $filename"
            copied=$((copied + 1))
        done
    else
        print_info "$PROJECT_TYPE 타입의 전용 워크플로우가 없습니다. (공통 워크플로우만 사용)"
    fi
    
    print_success "$copied 개 워크플로우 다운로드 완료 (타입: $PROJECT_TYPE)"
    
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
        # 정확한 매칭 확인 (주석 제외)
        if ! grep -qxF "$entry" .gitignore 2>/dev/null; then
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

# .cursor 폴더 다운로드
copy_cursor_folder() {
    print_step ".cursor 폴더 다운로드 여부 확인 중..."
    
    if [ ! -d "$TEMP_DIR/.cursor" ]; then
        print_info ".cursor 폴더가 템플릿에 없습니다. 건너뜁니다."
        return
    fi
    
    # 사용자 동의 확인
    if [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
        print_separator_line
        print_to_user ""
        print_to_user ".cursor 폴더를 다운로드하시겠습니까? (Cursor IDE 설정)"
        print_to_user "  Y/y - 예, 다운로드하기"
        print_to_user "  N/n - 아니오, 건너뛰기 (기본)"
        print_to_user ""
        
        if ! ask_yes_no "선택: " "N"; then
            print_info ".cursor 폴더 다운로드 건너뜁니다"
            return
        fi
    fi
    
    # 다운로드 실행
    mkdir -p .cursor
    cp -r "$TEMP_DIR/.cursor/"* .cursor/ 2>/dev/null || true
    print_success ".cursor 폴더 다운로드 완료"
}

# .claude 폴더 다운로드
copy_claude_folder() {
    print_step ".claude 폴더 다운로드 여부 확인 중..."

    if [ ! -d "$TEMP_DIR/.claude" ]; then
        print_info ".claude 폴더가 템플릿에 없습니다. 건너뜁니다."
        return
    fi

    # 사용자 동의 확인
    if [ "$FORCE_MODE" = false ] && [ "$TTY_AVAILABLE" = true ]; then
        print_separator_line
        print_to_user ""
        print_to_user ".claude 폴더를 다운로드하시겠습니까? (Claude Code 설정)"
        print_to_user "  Y/y - 예, 다운로드하기"
        print_to_user "  N/n - 아니오, 건너뛰기 (기본)"
        print_to_user ""

        if ! ask_yes_no "선택: " "N"; then
            print_info ".claude 폴더 다운로드 건너뜁니다"
            return
        fi
    fi

    # 다운로드 실행
    mkdir -p .claude
    cp -r "$TEMP_DIR/.claude/"* .claude/ 2>/dev/null || true
    print_success ".claude 폴더 다운로드 완료"
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
    
    print_question_header "🚀" "어떤 기능을 통합하시겠습니까?"
    
    print_to_user "  1) 전체 통합 (버전관리 + 워크플로우 + 이슈템플릿)"
    print_to_user "  2) 버전 관리 시스템만"
    print_to_user "  3) GitHub Actions 워크플로우만"
    print_to_user "  4) 이슈/PR 템플릿만"
    print_to_user "  5) 취소"
    print_to_user ""
    
    local choice
    local valid_input=false
    
    # 입력 검증 루프 - 올바른 값(1-5)이 입력될 때까지 반복
    while [ "$valid_input" = false ]; do
        if safe_read "선택 (1-5): " choice "-n 1"; then
            print_to_user ""
            
            # 입력값 검증: 1-5 숫자만 허용
            if [[ "$choice" =~ ^[1-5]$ ]]; then
                valid_input=true
                case $choice in
                    1) MODE="full" ;;
                    2) MODE="version" ;;
                    3) MODE="workflows" ;;
                    4) MODE="issues" ;;
                    5) 
                        print_info "취소되었습니다"
                        exit 0
                        ;;
                esac
            else
                # 잘못된 입력 시 에러 메시지 표시 후 재입력 요청
                print_error "잘못된 입력입니다. 1-5 사이의 숫자를 입력해주세요."
                print_to_user ""
            fi
        else
            # safe_read 실패 (이론상 여기 도달 안 함)
            print_error "입력을 읽을 수 없습니다"
            exit 1
        fi
    done
}

# 통합 실행
execute_integration() {
    # CLI 모드에서만 자동 감지 및 확인 (interactive 모드에서는 이미 감지 완료)
    if [ "$IS_INTERACTIVE_MODE" = false ]; then
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
    
    # 1. 템플릿 다운로드
    download_template
    
    # 2. 모드별 통합
    case $MODE in
        full)
            create_version_yml "$VERSION" "$PROJECT_TYPE" "$DETECTED_BRANCH"
            add_version_section_to_readme "$VERSION"
            copy_workflows
            copy_scripts
            copy_util_modules "$PROJECT_TYPE"
            copy_issue_templates
            copy_discussion_templates
            copy_coderabbit_config
            ensure_gitignore
            copy_cursor_folder
            copy_claude_folder
            copy_setup_guide
            ;;
        version)
            create_version_yml "$VERSION" "$PROJECT_TYPE" "$DETECTED_BRANCH"
            add_version_section_to_readme "$VERSION"
            copy_scripts
            ensure_gitignore
            copy_setup_guide
            ;;
        workflows)
            copy_workflows
            copy_scripts
            copy_util_modules "$PROJECT_TYPE"
            copy_setup_guide
            ;;
        issues)
            copy_issue_templates
            copy_discussion_templates
            ;;
    esac
    
    # 3. 임시 파일 정리
    rm -rf "$TEMP_DIR"
    
    # 완료 메시지
    print_summary
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
    esac
    
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
            elif [[ "$filename" =~ ^${WORKFLOW_PREFIX}-${PROJECT_TYPE^^}- ]]; then
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

