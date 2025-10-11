#!/bin/bash

# ===================================================================
# GitHub 템플릿 초기화 스크립트 v2.0.0
# ===================================================================
#
# 이 스크립트는 GitHub 템플릿을 통해 새 프로젝트가 생성될 때
# 수동으로 실행하여 프로젝트를 초기 상태로 설정합니다.
#
# 주요 기능:
# 1. version.yml을 지정된 버전과 타입으로 초기화
# 2. default_branch 자동 감지 및 설정
# 3. 워크플로우 트리거 브랜치 자동 변경
# 4. CHANGELOG.md, CHANGELOG.json 파일 삭제
# 5. README.md를 기본 템플릿으로 초기화
# 6. 이슈 템플릿의 assignee를 현재 저장소 소유자로 변경
#
# 사용법:
# ./template_initializer.sh [옵션]
#
# 옵션:
#   -v, --version VERSION    초기 버전 설정 (기본: 0.0.0)
#   -t, --type TYPE          프로젝트 타입 (기본: basic)
#                            지원: spring, flutter, react, react-native,
#                                  react-native-expo, node, python, basic
#   -h, --help               도움말 표시
#
# 예시:
#   ./template_initializer.sh --version 1.0.0 --type spring
#   ./template_initializer.sh -v 1.0.0 -t python
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

# 로깅 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# 도움말 표시
show_help() {
    cat << EOF
${CYAN}GitHub 템플릿 초기화 스크립트 v2.0.0${NC}

${BLUE}사용법:${NC}
  ./template_initializer.sh [옵션]

${BLUE}옵션:${NC}
  -v, --version VERSION    초기 버전 설정 (기본: 0.0.0)
  -t, --type TYPE          프로젝트 타입 (기본: basic)
                           지원 타입:
                             • spring          - Spring Boot 백엔드
                             • flutter         - Flutter 모바일 앱
                             • react           - React 웹 앱
                             • react-native    - React Native 모바일 앱
                             • react-native-expo - React Native Expo 앱
                             • node            - Node.js 프로젝트
                             • python          - Python 프로젝트
                             • basic           - 기본 (프레임워크 없음)
  -h, --help               이 도움말 표시

${BLUE}사용 예시:${NC}
  # 기본 초기화 (버전 0.0.0, 타입 basic)
  ./template_initializer.sh

  # Spring Boot 프로젝트로 버전 1.0.0으로 초기화
  ./template_initializer.sh --version 1.0.0 --type spring

  # Python 프로젝트로 초기화
  ./template_initializer.sh -v 1.0.0 -t python

  # 짧은 형식
  ./template_initializer.sh -v 2.0.0 -t react

${BLUE}초기화 작업:${NC}
  1. Default 브랜치 자동 감지 (main/master 등)
  2. version.yml 생성 (버전, 타입, default_branch 설정)
  3. 워크플로우 트리거 브랜치 자동 변경
  4. CHANGELOG 파일 삭제
  5. LICENSE, CONTRIBUTING.md 삭제
  6. 테스트 폴더 삭제
  7. README.md 초기화
  8. 이슈 템플릿 assignee 변경

EOF
}

# 기본값 설정
VERSION="0.0.0"
PROJECT_TYPE="basic"
GITHUB_USER="${GITHUB_ACTOR:-$(whoami)}"
REPO_OWNER="${GITHUB_REPOSITORY%/*}"

# 지원하는 프로젝트 타입
VALID_TYPES=("spring" "flutter" "react" "react-native" "react-native-expo" "node" "python" "basic")

# 파라미터 파싱
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -t|--type)
            PROJECT_TYPE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "알 수 없는 옵션: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
done

# 버전 형식 검증
validate_version() {
    if [[ ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "잘못된 버전 형식: $1"
        log_error "올바른 형식: x.y.z (예: 1.0.0, 2.1.3)"
        exit 1
    fi
}

# 프로젝트 타입 검증
validate_project_type() {
    local type=$1
    local valid=false
    
    for valid_type in "${VALID_TYPES[@]}"; do
        if [ "$type" = "$valid_type" ]; then
            valid=true
            break
        fi
    done
    
    if [ "$valid" = false ]; then
        log_error "지원하지 않는 프로젝트 타입: $type"
        log_error "지원 타입: ${VALID_TYPES[*]}"
        exit 1
    fi
}

# Default branch 자동 감지
detect_default_branch() {
    local detected=""
    
    log_step "Default branch 자동 감지 중..."
    
    # 방법 1: GitHub CLI
    if command -v gh >/dev/null 2>&1; then
        detected=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo "")
        if [ -n "$detected" ]; then
            log_info "gh CLI로 감지: $detected"
            echo "$detected"
            return
        fi
    fi
    
    # 방법 2: git symbolic-ref
    detected=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "")
    if [ -n "$detected" ]; then
        log_info "git symbolic-ref로 감지: $detected"
        echo "$detected"
        return
    fi
    
    # 방법 3: git remote show
    detected=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | sed 's/.*: //' || echo "")
    if [ -n "$detected" ]; then
        log_info "git remote show로 감지: $detected"
        echo "$detected"
        return
    fi
    
    # 최종 폴백
    log_warning "자동 감지 실패, 기본값 사용: main"
    echo "main"
}

# version.yml 생성
create_version_yml() {
    local version=$1
    local type=$2
    local branch=$3
    local user=$4
    
    log_step "version.yml 파일 생성 중..."
    log_info "  버전: $version"
    log_info "  타입: $type"
    log_info "  브랜치: $branch"
    log_info "  사용자: $user"
    
    cat > version.yml << EOF
# ===================================================================
# 프로젝트 버전 관리 파일
# ===================================================================
#
# 이 파일은 다양한 프로젝트 타입에서 버전 정보를 중앙 관리하기 위한 파일
# GitHub Actions 워크플로우가 이 파일을 읽어 자동으로 버전을 관리
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
# - flutter: pubspec.yaml (version: 1.0.0+1, buildNumber 포함)
# - react/node: package.json ("version": "x.y.z")
# - react-native: iOS Info.plist 또는 Android build.gradle
# - react-native-expo: app.json (expo.version)
# - python: pyproject.toml (version = "x.y.z")
# - basic/기타: version.yml 파일만 사용
#
# 주의사항:
# - project_type은 최초 설정 후 변경하지 마세요
# - 버전은 항상 높은 버전으로 자동 동기화됩니다
# ===================================================================

version: "$version"
version_code: 1  # app build number
project_type: "$type" # spring, flutter, react, react-native, react-native-expo, node, python, basic
metadata:
  last_updated: "$(date -u +"%Y-%m-%d %H:%M:%S")"
  last_updated_by: "$user"
  default_branch: "$branch"
EOF
    
    log_success "version.yml 파일이 생성되었습니다."
}

# 워크플로우 트리거 브랜치 변경
update_workflow_triggers() {
    local branch=$1
    
    # main 브랜치면 변경 불필요
    if [ "$branch" = "main" ]; then
        log_info "브랜치가 main이므로 워크플로우 변경 불필요"
        return
    fi
    
    log_step "워크플로우 트리거 브랜치 변경 중: main → $branch"
    
    local count=0
    
    # .github/workflows 디렉토리의 모든 YAML 파일 (초기화 워크플로우 제외)
    find .github/workflows -type f \( -name "*.yml" -o -name "*.yaml" \) ! -name "PROJECT-TEMPLATE-INITIALIZER.yaml" 2>/dev/null | while read -r file; do
        local changed=false
        
        # 패턴 1: branches: ["main"]
        if grep -q 'branches: \["main"\]' "$file"; then
            sed -i "s/branches: \[\"main\"\]/branches: [\"$branch\"]/" "$file"
            changed=true
        fi
        
        # 패턴 2: branches: ['main']
        if grep -q "branches: \['main'\]" "$file"; then
            sed -i "s/branches: \['main'\]/branches: ['$branch']/" "$file"
            changed=true
        fi
        
        # 패턴 3: - main (리스트 항목)
        if grep -q '^[[:space:]]*-[[:space:]]*main[[:space:]]*$' "$file"; then
            sed -i "s/^\\([[:space:]]*-[[:space:]]*\\)main[[:space:]]*$/\\1$branch/" "$file"
            changed=true
        fi
        
        if [ "$changed" = true ]; then
            echo "  ✓ $(basename "$file")"
        fi
    done
    
    log_success "워크플로우 트리거 브랜치 변경 완료"
}

# 템플릿 관련 파일 삭제
cleanup_template_files() {
    log_step "템플릿 관련 파일 삭제 중..."
    
    # CHANGELOG 파일들 삭제
    if [ -f "CHANGELOG.md" ]; then
        rm -f CHANGELOG.md
        log_info "  ✓ CHANGELOG.md 삭제"
    fi
    
    if [ -f "CHANGELOG.json" ]; then
        rm -f CHANGELOG.json
        log_info "  ✓ CHANGELOG.json 삭제"
    fi
    
    # LICENSE 파일 삭제
    if [ -f "LICENSE" ]; then
        rm -f LICENSE
        log_info "  ✓ LICENSE 삭제"
    fi
    
    # CONTRIBUTING.md 파일 삭제
    if [ -f "CONTRIBUTING.md" ]; then
        rm -f CONTRIBUTING.md
        log_info "  ✓ CONTRIBUTING.md 삭제"
    fi
    
    # 테스트 폴더들 삭제
    if [ -d ".github/scripts/test" ]; then
        rm -rf .github/scripts/test
        log_info "  ✓ .github/scripts/test 폴더 삭제"
    fi
    
    if [ -d ".github/workflows/test" ]; then
        rm -rf .github/workflows/test
        log_info "  ✓ .github/workflows/test 폴더 삭제"
    fi
    
    log_success "템플릿 관련 파일 삭제 완료"
}

# README.md 초기화
initialize_readme() {
    local project_name=$1
    local version=$2
    
    log_step "README.md 파일 초기화 중..."
    
    cat > README.md << EOF
# $project_name

<!-- 수정하지마세요 자동으로 동기화 됩니다 -->
## 최신 버전 : v$version

[전체 버전 기록 보기](CHANGELOG.md)

</br>

<!-- 템플릿 초기화 완료: $(TZ=Asia/Seoul date +"%Y-%m-%d %H:%M:%S KST") -->
EOF
    
    log_success "README.md 파일이 초기화되었습니다."
}

# 이슈 템플릿 assignee 업데이트
update_issue_templates() {
    log_step "이슈 템플릿 assignee 업데이트 중..."
    
    local updated=0
    
    # bug_report.md 업데이트
    if [ -f ".github/ISSUE_TEMPLATE/bug_report.md" ]; then
        sed -i "s/assignees: \[Cassiiopeia\]/assignees: [$REPO_OWNER]/" .github/ISSUE_TEMPLATE/bug_report.md
        log_info "  ✓ bug_report.md"
        updated=$((updated + 1))
    fi
    
    # design_request.md 업데이트
    if [ -f ".github/ISSUE_TEMPLATE/design_request.md" ]; then
        sed -i "s/assignees: \[Cassiiopeia\]/assignees: [$REPO_OWNER]/" .github/ISSUE_TEMPLATE/design_request.md
        log_info "  ✓ design_request.md"
        updated=$((updated + 1))
    fi
    
    # feature_request.md 업데이트
    if [ -f ".github/ISSUE_TEMPLATE/feature_request.md" ]; then
        sed -i "s/assignees: \[Cassiiopeia\]/assignees: [$REPO_OWNER]/" .github/ISSUE_TEMPLATE/feature_request.md
        log_info "  ✓ feature_request.md"
        updated=$((updated + 1))
    fi
    
    log_success "이슈 템플릿 $updated 개 업데이트 완료"
}

# 초기화 완료 요약 출력
print_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                🎉 템플릿 초기화 완료! 🎉                      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}초기화된 설정:${NC}"
    echo -e "  ${BLUE}버전:${NC} $VERSION"
    echo -e "  ${BLUE}프로젝트 타입:${NC} $PROJECT_TYPE"
    echo -e "  ${BLUE}Default 브랜치:${NC} $DETECTED_BRANCH"
    echo -e "  ${BLUE}사용자:${NC} $GITHUB_USER"
    echo ""
    echo -e "${CYAN}완료된 작업:${NC}"
    echo "  ✅ version.yml 생성"
    echo "  ✅ Default branch 자동 감지 및 설정"
    if [ "$DETECTED_BRANCH" != "main" ]; then
        echo "  ✅ 워크플로우 트리거 브랜치 변경 (main → $DETECTED_BRANCH)"
    fi
    echo "  ✅ CHANGELOG 파일 삭제"
    echo "  ✅ LICENSE, CONTRIBUTING.md 삭제"
    echo "  ✅ 테스트 폴더 삭제"
    echo "  ✅ README.md 초기화"
    echo "  ✅ 이슈 템플릿 assignee 변경"
    echo ""
    echo -e "${YELLOW}다음 단계:${NC}"
    echo "  1. 프로젝트에 맞게 README.md를 수정하세요"
    echo "  2. 필요한 경우 version.yml의 project_type을 확인하세요"
    echo "  3. 첫 번째 커밋을 푸시하여 자동화 시스템을 테스트하세요"
    echo ""
    echo -e "${CYAN}유용한 명령어:${NC}"
    echo "  git add ."
    echo "  git commit -m \"chore: 템플릿 초기화 완료 v$VERSION\""
    echo "  git push origin $DETECTED_BRANCH"
    echo ""
}

# 메인 실행 함수
main() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          GitHub 템플릿 초기화 스크립트 v2.0.0                 ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # 파라미터 검증
    validate_version "$VERSION"
    validate_project_type "$PROJECT_TYPE"
    
    # 프로젝트 이름 추출 (저장소명)
    if [ -n "$GITHUB_REPOSITORY" ]; then
        PROJECT_NAME="${GITHUB_REPOSITORY#*/}"
    else
        PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
    fi
    
    log_info "프로젝트명: $PROJECT_NAME"
    log_info "설정된 버전: $VERSION"
    log_info "설정된 타입: $PROJECT_TYPE"
    echo ""
    
    # Default branch 감지
    DETECTED_BRANCH=$(detect_default_branch)
    echo ""
    
    # 1. version.yml 생성
    create_version_yml "$VERSION" "$PROJECT_TYPE" "$DETECTED_BRANCH" "$GITHUB_USER"
    echo ""
    
    # 2. 워크플로우 트리거 변경
    update_workflow_triggers "$DETECTED_BRANCH"
    echo ""
    
    # 3. 템플릿 파일 삭제
    cleanup_template_files
    echo ""
    
    # 4. README 초기화
    initialize_readme "$PROJECT_NAME" "$VERSION"
    echo ""
    
    # 5. 이슈 템플릿 업데이트
    update_issue_templates
    echo ""
    
    # 6. 완료 요약
    print_summary
}

# 스크립트 실행
main "$@"
